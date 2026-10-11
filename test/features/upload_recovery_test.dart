import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/features/account/data/account_models.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/photo_controller.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/reviews/data/review_models.dart';

import '../support/account_fake.dart';
import '../support/communication_harness.dart';
import '../support/fakes.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);
PickedBuyerImage image() =>
    PickedBuyerImage(bytes: png, filename: 'photo.png', mimeType: 'image/png');

class DeferredPicker extends PhotoPickerAdapter {
  DeferredPicker(this.result);
  final Future<PickedBuyerImage?> result;
  @override
  Future<PickedBuyerImage?> pick({bool review = false}) => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CommunicationHarness h;
  late FakeAccountRepository repo;
  late PhotoController photo;
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    repo = FakeAccountRepository();
    repo.onPhoto = () async => png;
    photo = PhotoController(h.session, repo);
  });
  tearDown(() {
    photo.dispose();
    h.dispose();
  });
  Future<bool> upload() =>
      photo.upload(data: png, filename: 'photo.png', mimeType: 'image/png');
  Future<void> waitForRequest() async {
    for (var i = 0; i < 100 && h.adapter.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(h.adapter.requests, isNotEmpty);
  }

  for (final failure in [
    const ApiFailure(FailureKind.timeout),
    const ApiFailure(FailureKind.offline),
    const ApiFailure(FailureKind.decode),
    const ApiFailure(FailureKind.http, status: 500),
    const ApiFailure(FailureKind.cancelled),
  ]) {
    test(
      'profile ${failure.kind}/${failure.status} blocks another write until current state is read',
      () async {
        repo.onUpload = () async => throw failure;
        expect(await upload(), isFalse);
        expect(photo.requiresReconciliation, isTrue);
        expect(photo.selectionConsumed, isTrue);
        expect(repo.accountReads, 0);
        expect(await upload(), isFalse);
        expect(await photo.remove(), isFalse);
        expect(repo.uploads, 1);
        await photo.load();
        expect(photo.requiresReconciliation, isFalse);
        expect(repo.uploads, 1);
      },
    );
  }
  test(
    'profile reconciliation reads the new version and keeps denial blocked',
    () async {
      photo.photoUrl = '/api/v1/customer/account/profile-photo?v=old';
      photo.requiresReconciliation = true;
      final data = fixture('account-management', 'op-007')['account'];
      data['profile']['profilePhotoUrl'] =
          '/api/v1/customer/account/profile-photo?v=new';
      repo.value = CustomerAccount.parse(data);
      repo.onPhoto = () async =>
          throw const ApiFailure(FailureKind.http, status: 403);
      await photo.load();
      expect(repo.requestedPhotoUrl, endsWith('v=new'));
      expect(photo.requiresReconciliation, isTrue);
      expect(photo.bytes, isNull);
      repo.onPhoto = () async =>
          throw const ApiFailure(FailureKind.http, status: 404);
      await photo.load();
      expect(photo.requiresReconciliation, isFalse);
      expect(photo.photoUrl, isNull);
      repo.onAccount = () async =>
          throw const ApiFailure(FailureKind.http, status: 404);
      await photo.load();
      expect(photo.requiresReconciliation, isTrue);
    },
  );
  test(
    'confirmed profile upload remains success when its private preview fails',
    () async {
      repo.onPhoto = () async => throw const ApiFailure(FailureKind.offline);
      expect(await upload(), isTrue);
      expect(photo.selectionConsumed, isTrue);
      expect(photo.requiresReconciliation, isTrue);
      expect(photo.error, isNotNull);
      expect(await upload(), isFalse);
      expect(repo.uploads, 1);
    },
  );
  test('late progress cannot overwrite a subsequent upload', () async {
    expect(await upload(), isTrue);
    final obsolete = repo.uploadProgress!;
    final response = Completer<CustomerAccount>();
    repo.onUpload = () => response.future;
    final sending = upload();
    repo.uploadProgress!(1, 10);
    expect(photo.progress, .1);
    obsolete(10, 10);
    expect(photo.progress, .1);
    response.complete(repo.value);
    expect(await sending, isTrue);
  });
  test(
    'profile malformed projection retains uncertainty without replay',
    () async {
      repo.onUpload = () async =>
          throw const FormatException('Synthetic bad projection');
      expect(await upload(), isFalse);
      expect(photo.requiresReconciliation, isTrue);
      expect(await upload(), isFalse);
      expect(repo.uploads, 1);
    },
  );
  test(
    'profile read serializes mutation and rejects a late account after logout',
    () async {
      final read = Completer<CustomerAccount>();
      repo.onAccount = () => read.future;
      final pending = photo.load();
      expect(await upload(), isFalse);
      expect(await photo.remove(), isFalse);
      await h.session.signOut();
      read.complete(repo.value);
      await pending;
      expect(photo.bytes, isNull);
      expect(repo.photoReads, 0);
      expect(repo.uploads, 0);
    },
  );
  test('profile cancel is individual and survives consent; late success is ignored', () async {
    final response = Completer<CustomerAccount>();
    repo.onUpload = () => response.future;
    final sending = upload();
    photo.cancelUpload();
    expect(repo.uploadCancellation!.isCancelled, isTrue);
    expect(h.session.verifiedLease!.cancellation.isCancelled, isFalse);
    expect(photo.requiresReconciliation, isTrue);
    h.policies.consent = ConsentStatus.parse(consentJson(required: true));
    await h.session.refreshConsent();
    response.complete(repo.value);
    expect(await sending, isFalse);
    expect(photo.bytes, isNull);
    h.policies.consent = ConsentStatus.parse(consentJson());
    await h.session.refreshConsent();
    expect(photo.requiresReconciliation, isTrue);
    expect(await upload(), isFalse);
    await photo.load();
    expect(photo.requiresReconciliation, isFalse);
    expect(repo.uploads, 1);
  });
  test(
    'uncertain removal requires checking current photo before a replacement',
    () async {
      repo.onRemove = () async => throw const ApiFailure(FailureKind.timeout);
      expect(await photo.remove(), isFalse);
      expect(await upload(), isFalse);
      await photo.load();
      expect(photo.requiresReconciliation, isFalse);
      expect(repo.removals, 1);
    },
  );
  test(
    'profile throttle retains input and prevents immediate reread or upload',
    () async {
      repo.onUpload = () async => throw ApiFailure(
        FailureKind.http,
        status: 429,
        retryAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      expect(await upload(), isFalse);
      expect(photo.selectionConsumed, isFalse);
      await photo.load();
      expect(await upload(), isFalse);
      expect(repo.uploads, 1);
      expect(repo.accountReads, 0);
    },
  );

  test('Review cancel retains committed photos and blocks writes through failed check', () async {
    final c = h.state.review(customerId, otherId, reviewId: customerId);
    final committed = ReviewPhoto.parse(
      fixture('product-review-ratings', 'op-053')['data'],
    );
    c.photos = [committed];
    c.selected = image();
    final response = Completer<ResponseBody>();
    h.reply = (_) => response.future;
    final sending = c.upload();
    await waitForRequest();
    c.cancelUpload();
    response.complete(
      jsonReply(fixture('product-review-ratings', 'op-053'), status: 201),
    );
    await sending;
    expect(c.uncertainPhoto, isTrue);
    expect(c.selected, isNull);
    expect(c.photos.single.id, committed.id);
    c.selected = image();
    await c.upload();
    h.reply = (_) => jsonReply({}, status: 500);
    await c.reconcilePhotos();
    expect(c.photos.single.id, committed.id);
    expect(c.uncertainPhoto, isTrue);
    expect(h.adapter.requests.where((r) => r.method == 'POST').length, 1);
    h.reply = h.defaultReply;
    await c.reconcilePhotos();
    expect(c.uncertainPhoto, isFalse);
    expect(c.selected, isNull);
    expect(h.adapter.requests.where((r) => r.method == 'POST').length, 1);
  });
  test('Review known validation failure retains text/photos and permits correcting only that image', () async {
    final c = h.state.review(customerId, otherId);
    c.draft = 'Confirmed text';
    await c.submit();
    c.selected = image();
    await c.upload();
    final review = c.review;
    c.selected = image();
    h.reply = (_) => jsonReply({
      'errors': {
        'image': ['Synthetic error'],
      },
    }, status: 422);
    await c.upload();
    expect(c.review, same(review));
    expect(c.photos.length, 1);
    expect(c.selected, isNotNull);
    expect(c.uncertainPhoto, isFalse);
    expect(c.fieldErrors['image'], isNotNull);
    h.reply = h.defaultReply;
    await c.upload();
    expect(c.photos.length, 1); // Repeated returned ID is deduplicated.
    expect(c.selected, isNull);
  });
  test(
    'malformed Review upload response is uncertain and cannot be resent',
    () async {
      final c = h.state.review(customerId, otherId, reviewId: customerId);
      c.selected = image();
      h.reply = (_) => jsonReply({'data': {}}, status: 201);
      await c.upload();
      expect(c.uncertainPhoto, isTrue);
      expect(c.selected, isNull);
      c.selected = image();
      await c.upload();
      expect(h.adapter.requests.length, 1);
    },
  );
  test('Review selection dismissal preserves preview; clearing rejects late picker completion', () async {
    final c = h.state.review(customerId, otherId, reviewId: customerId);
    final original = image();
    c.selected = original;
    await c.select(DeferredPicker(Future.value(null)));
    expect(c.selected, same(original));
    final selection = Completer<PickedBuyerImage?>();
    final picking = c.select(DeferredPicker(selection.future));
    c.clearSelection();
    selection.complete(image());
    await picking;
    expect(c.selected, isNull);
    expect(c.selecting, isFalse);
  });
  test('canonical Review scan stops fetching after identity loss', () async {
    final c = h.state.review(customerId, otherId, reviewId: customerId);
    final response = Completer<ResponseBody>();
    h.reply = (_) => response.future;
    final checking = c.reconcilePhotos();
    await waitForRequest();
    final page = fixture('product-review-ratings', 'op-051');
    page['data'][0]['id'] = otherId;
    page['meta']['last_page'] = 2;
    await h.session.signOut();
    response.complete(jsonReply(page));
    await checking;
    expect(h.adapter.requests.length, 1);
    expect(c.review, isNull);
    expect(c.photos, isEmpty);
  });
  test('canonical five photos prevent further selection or upload', () async {
    final c = h.state.review(customerId, otherId, reviewId: customerId);
    final page = fixture('product-review-ratings', 'op-051');
    final wire = fixture('product-review-ratings', 'op-053')['data'];
    page['data'][0]['photos'] = List.generate(
      5,
      (i) => {
        ...wire,
        'id':
            '${(i + 1).toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
      },
    );
    h.reply = (_) => jsonReply(page);
    await c.reconcilePhotos();
    expect(c.photos.length, 5);
    await c.select(DeferredPicker(Future.value(image())));
    expect(c.selected, isNull);
    c.selected = image();
    await c.upload();
    expect(h.adapter.requests.length, 1);
  });
}
