import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_models.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/account_controllers.dart';
import 'package:aisley_mobile_buyer/features/auth/data/auth_models.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_controller.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_models.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/recent_merge_coordinator.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_status_controller.dart';

import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';

import '../support/fakes.dart';
import '../support/account_fake.dart';
import 'phase_2_contract_test.dart' show profileInput;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAuth auth;
  late FakePolicies policies;
  late SessionController session;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuth();
    policies = FakePolicies();
    session = SessionController(
      auth,
      policies,
      MemoryTokenStore()..token = 'synthetic-test-token',
    );
    await session.bootstrap();
  });
  tearDown(() => session.dispose());

  Future<void> switchTo(String id) async {
    auth.identity = CustomerIdentity.parse(identityJson(id: id));
    auth.onLogin = () async => LoginResult.parse({
      'message': 'OK',
      'customer': identityJson(id: id),
      'token': 'synthetic-session-$id',
    });
    await session.signIn('buyer@example.invalid', 'Synthetic123');
  }

  test(
    'obsolete Product search cannot replace a newer Shops response',
    () async {
      final old = Completer<ResponseBody>();
      final adapter = FakeAdapter(
        (options) => options.uri.path.endsWith('/products/search')
            ? old.future
            : jsonReply(fixture('search', 'op-020')),
      );
      final api = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(api.close);
      final repo = DiscoveryRepository(api: api, session: session);
      addTearDown(repo.dispose);
      final controller = DiscoverySearchController(repo);
      addTearDown(controller.dispose);
      final earlier = controller.search('old');
      await Future<void>.delayed(Duration.zero);
      controller.setMode(SearchMode.shops);
      await controller.search('new');
      old.complete(jsonReply(fixture('search', 'op-019')));
      await earlier;
      expect(controller.query, 'new');
      expect(controller.products, isNull);
      expect(controller.shops, isNotNull);
    },
  );

  test(
    'public/private Home caches are separate through A to B to A switching',
    () async {
      var publicCalls = 0, privateCalls = 0;
      final public = FakeAdapter((_) {
        publicCalls++;
        return jsonReply(fixture('customer-homepage', 'op-047'));
      });
      final private = FakeAdapter((_) {
        privateCalls++;
        final body = fixture('customer-homepage', 'op-047');
        body['viewer']['isAuthenticated'] = true;
        body['viewer']['displayName'] =
            '${session.customer!.displayName} response $privateCalls';
        return jsonReply(body);
      });
      final api = ApiClient(
        testConfig,
        publicClient: Dio()..httpClientAdapter = public,
        privateClient: Dio()..httpClientAdapter = private,
      );
      addTearDown(api.close);
      final repo = DiscoveryRepository(api: api, session: session);
      addTearDown(repo.dispose);
      final a = await repo.home();
      expect((await repo.home()).viewer.displayName, a.viewer.displayName);
      await switchTo(otherId);
      expect((await repo.home()).viewer.displayName, 'Buyer B response 2');
      await switchTo(customerId);
      expect((await repo.home()).viewer.displayName, 'Buyer A response 3');
      await session.signOut();
      expect((await repo.home()).viewer.isAuthenticated, isFalse);
      expect((await repo.home()).viewer.isAuthenticated, isFalse);
      expect(privateCalls, 3);
      expect(publicCalls, 1);
    },
  );

  test('late private photo/profile/preference reads cannot restore data after logout', () async {
    final photo = Completer<Uint8List>(),
        account = Completer<CustomerAccount>(),
        preference = Completer<PromotionPreference>();
    final repo = FakeAccountRepository()
      ..onPhoto = (() => photo.future)
      ..onAccount = (() => account.future)
      ..onPreference = (() => preference.future);
    final image = PhotoController(session, repo),
        profile = ProfileController(session, repo),
        promotion = PromotionPreferenceController(session, repo);
    addTearDown(image.dispose);
    addTearDown(profile.dispose);
    addTearDown(promotion.dispose);
    final reads = [image.load(), profile.load(), promotion.load()];
    await session.signOut();
    photo.complete(Uint8List.fromList([1, 2, 3]));
    account.complete(repo.value);
    preference.complete(
      const PromotionPreference(optedIn: true, optedInAt: null),
    );
    await Future.wait(reads);
    expect(image.bytes, isNull);
    expect(profile.account, isNull);
    expect(promotion.preference, isNull);
  });

  test('consent loss immediately clears private controllers and hearts while preserving identity', () async {
    final photo = PhotoController(session, FakeAccountRepository());
    addTearDown(photo.dispose);
    await photo.load();
    expect(photo.bytes, isNotNull);
    policies.consent = ConsentStatus.parse(consentJson(required: true));
    await session.refreshConsent();
    expect(session.customer, isNotNull);
    expect(session.active, isFalse);
    expect(photo.bytes, isNull);
  });

  test('Wishlist serializes per Product and drops queued A actions before switching to B', () async {
    final first = Completer<ResponseBody>();
    var count = 0;
    final adapter = FakeAdapter((options) {
      count++;
      return count == 1
          ? first.future
          : jsonReply(
              fixture(
                'wishlist',
                options.method == 'PUT' ? 'op-039' : 'op-040',
              ),
            );
    });
    final api = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final saved = SavedStatusController(session, WishlistRepository(api));
    addTearDown(saved.dispose);
    final save = saved.setSaved(customerId, true),
        remove = saved.setSaved(customerId, false);
    await Future<void>.delayed(Duration.zero);
    for (var attempt = 0; attempt < 20 && count == 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(count, 1);
    await switchTo(otherId);
    first.complete(jsonReply(fixture('wishlist', 'op-039')));
    await Future.wait([save, remove]);
    expect(count, 1);
    expect(saved.isSaved(customerId), isNull);
    expect(saved.isPending(customerId), isFalse);
    await saved.setSaved(customerId, true);
    expect(count, 2);
    expect(saved.isSaved(customerId), isTrue);
  });

  test(
    'uncertain Wishlist save rereads status and never retries the mutation',
    () async {
      final adapter = FakeAdapter(
        (options) => options.method == 'PUT'
            ? jsonReply({}, status: 503)
            : jsonReply({
                'data': {customerId: true},
              }),
      );
      final api = ApiClient(
        testConfig,
        privateClient: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(api.close);
      final saved = SavedStatusController(session, WishlistRepository(api));
      addTearDown(saved.dispose);
      await saved.setSaved(customerId, true);
      expect(adapter.requests.map((request) => request.method), ['PUT', 'GET']);
      expect(saved.isSaved(customerId), isTrue);
    },
  );

  test('strict upload size/format boundaries and uncertain reread block another upload', () async {
    final repo = FakeAccountRepository();
    final photo = PhotoController(session, repo);
    addTearDown(photo.dispose);
    expect(
      await photo.upload(
        data: Uint8List(10485760),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      isFalse,
    );
    expect(
      await photo.upload(
        data: Uint8List(10),
        filename: 'photo.heic',
        mimeType: 'image/heic',
      ),
      isFalse,
    );
    expect(repo.uploads, 0);
    expect(
      await photo.upload(
        data: Uint8List(10485759),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      isTrue,
    );
    expect(repo.uploads, 1);
    repo.onUpload = () async => throw const ApiFailure(FailureKind.timeout);
    repo.onPhoto = () async => throw const ApiFailure(FailureKind.offline);
    expect(
      await photo.upload(
        data: Uint8List(10),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      isFalse,
    );
    expect(photo.requiresReconciliation, isTrue);
    expect(
      await photo.upload(
        data: Uint8List(10),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      isFalse,
    );
    expect(repo.uploads, 2);
  });

  test('uncertain profile change confirms matching reread without replay or blocking the session', () async {
    final data =
        fixture('account-management', 'op-007')['account']
            as Map<String, dynamic>;
    data['profile'] = <String, dynamic>{
      ...data['profile'],
      'firstName': 'Buyer',
      'middleName': null,
      'lastName': 'Example',
      'contactNumber': '00000000000',
      'sex': 'prefer_not_to_say',
      'birthDate': '2000-01-01',
    };
    final repo = FakeAccountRepository()
      ..value = CustomerAccount.parse(data)
      ..onProfile = (_) async => throw const ApiFailure(FailureKind.timeout);
    final profile = ProfileController(session, repo);
    addTearDown(profile.dispose);
    expect(await profile.save(profileInput), isTrue);
    expect(repo.profileWrites, 1);
    expect(repo.accountReads, 1);
    expect(session.active, isTrue);
  });

  test('password validation errors and uncertain outcome require reauthentication before another submission', () async {
    final repo = FakeAccountRepository()
      ..onPassword = () async => throw const ApiFailure(
        FailureKind.http,
        status: 422,
        fields: {
          'current_password': ['Check this field.'],
        },
      );
    final password = PasswordController(session, repo);
    addTearDown(password.dispose);
    expect(
      await password.change(
        currentPassword: 'Synthetic123',
        password: 'Synthetic456',
        confirmation: 'Synthetic456',
      ),
      isFalse,
    );
    expect(password.fieldErrors['current_password'], isNotNull);
    repo.onPassword = () async => throw const ApiFailure(FailureKind.timeout);
    await password.change(
      currentPassword: 'Synthetic123',
      password: 'Synthetic456',
      confirmation: 'Synthetic456',
    );
    expect(password.requiresReconciliation, isTrue);
    await password.change(
      currentPassword: 'Synthetic123',
      password: 'Synthetic456',
      confirmation: 'Synthetic456',
    );
    expect(repo.passwordWrites, 2);
  });

  test('guest storage omits corruption, serializes concurrent views and keeps the newest twelve public hints', () async {
    final now = DateTime.utc(2026, 10, 4);
    SharedPreferences.setMockInitialValues({
      GuestRecentStore.storageKey: [
        'corrupt',
        jsonEncode(
          GuestRecentHint(productId: customerId, viewedAt: now).toJson(),
        ),
      ],
    });
    final store = GuestRecentStore(clock: () => now);
    expect((await store.read()).single.productId, customerId);
    await Future.wait([
      for (var index = 1; index <= 15; index++)
        store.record(
          '${index.toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
          now.subtract(Duration(seconds: index)),
        ),
    ]);
    final hints = await store.read();
    expect(hints.length, 12);
    expect(hints.first.productId, customerId);
    final preferences = await SharedPreferences.getInstance();
    for (final raw in preferences.getStringList(GuestRecentStore.storageKey)!) {
      expect((jsonDecode(raw) as Map).keys.toSet(), {'productId', 'viewedAt'});
    }
  });

  test('denied guest storage retains bounded in-memory hints with a truthful persistence flag', () async {
    final now = DateTime.utc(2026, 10, 4);
    final store = GuestRecentStore(
      preferences: () async => throw StateError('denied'),
      clock: () => now,
    );
    await store.record(customerId, now);
    expect((await store.read()).single.productId, customerId);
    expect(store.persisted, isFalse);
  });

  test('partial guest merge removes only acknowledged timestamps and never delays identity verification', () async {
    final now = DateTime.utc(2026, 10, 4);
    final store = GuestRecentStore(clock: () => now);
    await store.record(customerId, now.subtract(const Duration(minutes: 2)));
    await store.record(otherId, now.subtract(const Duration(minutes: 1)));
    final pending = Completer<ResponseBody>();
    final adapter = FakeAdapter((_) => pending.future);
    final api = ApiClient(
      testConfig,
      privateClient: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    final merger = RecentMergeCoordinator(
      session: session,
      repository: RecentlyViewedRepository(api, clock: () => now),
      guestStore: store,
    );
    addTearDown(merger.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(session.active, isTrue);
    expect(merger.busy, isTrue);
    await store.record(customerId, now);
    pending.complete(
      jsonReply({
        'data': {
          'mergedProductIds': [customerId],
          'mergedCount': 1,
        },
      }),
    );
    for (var index = 0; index < 10 && merger.busy; index++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((await store.read()).map((hint) => hint.productId).toSet(), {
      customerId,
      otherId,
    });
  });
}
