import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/communication_state.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/ui/responsive_layout.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/account_home_screen.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/profile_screen.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/photo_screen.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/review_composer_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/batch_result_screen.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/password_screen.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/preferences_screen.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_book_screen.dart';
import 'package:aisley_mobile_buyer/features/addresses/presentation/address_form_screen.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/login_screen.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/recovery_screen.dart';
import 'package:aisley_mobile_buyer/features/auth/presentation/registration_screen.dart';
import 'package:aisley_mobile_buyer/features/cart/presentation/cart_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/home_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/product_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/search_controller.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/shop_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/presentation/shop_directory_screen.dart';
import 'package:aisley_mobile_buyer/features/notifications/presentation/notification_screens.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_screen.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/consent_screen.dart';
import 'package:aisley_mobile_buyer/features/policies/presentation/policy_reader_screen.dart';
import 'package:aisley_mobile_buyer/features/policies/data/policy_models.dart';
import 'package:aisley_mobile_buyer/features/questions/presentation/questions_screen.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/reviews_screen.dart';
import 'package:aisley_mobile_buyer/features/saved/data/saved_repository.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_products_screen.dart';
import 'package:aisley_mobile_buyer/features/saved/presentation/saved_products_controller.dart';
import 'package:aisley_mobile_buyer/features/shop_messages/presentation/shop_screens.dart';
import 'package:aisley_mobile_buyer/features/support/presentation/support_screens.dart';

import '../support/commerce_harness.dart';
import '../support/communication_harness.dart';
import '../support/account_fake.dart';
import '../support/fakes.dart';

const phoneTabletSizes = [
  Size(320, 640),
  Size(360, 800),
  Size(390, 844),
  Size(412, 915),
  Size(600, 960),
  Size(800, 1280),
];

Map<String, dynamic> longFixture(String feature, String operation) {
  final value = fixture(feature, operation);
  void expand(Object? item) {
    if (item is Map) {
      for (final key in item.keys) {
        if (const [
              'title',
              'name',
              'shortDescription',
              'body',
              'subject',
            ].contains(key) &&
            item[key] is String) {
          item[key] =
              '${item[key]} with a long synthetic label that wraps across narrow screens';
        } else if (key == 'price' && item[key] is num) {
          item[key] = 999999999.99;
        } else {
          expand(item[key]);
        }
      }
    } else if (item is List) {
      for (final child in item) {
        expand(child);
      }
    }
  }

  expand(value);
  return value;
}

void main() {
  for (final feature in [
    'login',
    'register',
    'recovery',
    'consent',
    'policy',
    'home',
    'directory',
    'search',
    'shop',
    'product',
    'account',
    'profile',
    'photo',
    'review composer',
    'batch',
    'password',
    'preferences',
    'addresses',
    'address form',
    'cart',
    'checkout',
    'orders',
    'order',
    'wishlist',
    'history',
    'questions',
    'reviews',
    'notifications',
    'message',
    'support',
    'ticket composer',
    'ticket',
  ]) {
    testWidgets(
      '$feature survives mounted phone/tablet, landscape, keyboard and text resizing',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final h = CommerceHarness();
        await tester.runAsync(h.initialize);
        final communication = CommunicationHarness();
        await tester.runAsync(communication.initialize);
        final state = CommunicationState(h.session, h.api);
        final base = h.dependencies();
        final d = AppDependencies(
          config: base.config,
          auth: h.auth,
          policies: h.policies,
          session: h.session,
          launcher: base.launcher,
          discovery: base.discovery,
          commerce: h.commerce,
          communication: state,
          addresses: base.addresses,
          recentlyViewed: base.recentlyViewed,
          wishlist: WishlistRepository(h.api),
          savedStatus: base.savedStatus,
          accounts: FakeAccountRepository(),
          photoPicker: PhotoPickerAdapter(),
          clock: () => h.now,
        );
        addTearDown(() {
          state.dispose();
          communication.dispose();
          base.discovery!.dispose();
          base.savedStatus!.dispose();
          h.dispose();
        });
        h.cartJson = longFixture('view-cart', 'op-025');
        h.orderJson = longFixture('order-status', 'op-033');
        h.reply = (r) {
          final path = r.uri.path;
          if (path == '/api/v1/products/$customerId') {
            return jsonReply(longFixture('view-product', 'op-024'));
          }
          if (path == '/api/v1/customer/conversations/$customerId') {
            final value = longFixture('chat-messaging', 'op-059');
            value['data']['send_allowed'] = true;
            return jsonReply(value);
          }
          if (path.endsWith('/orders')) {
            return jsonReply(longFixture('order-status', 'op-032'));
          }
          if (path.endsWith('/home')) {
            return jsonReply(longFixture('customer-homepage', 'op-047'));
          }
          if (path.endsWith('/products/search')) {
            return jsonReply(longFixture('search', 'op-019'));
          }
          if (path.endsWith('/customer/shops')) {
            return jsonReply(longFixture('browse-shop', 'op-021'));
          }
          if (path.endsWith('/products') && path.contains('/shops/')) {
            return jsonReply(longFixture('browse-shop', 'op-022'));
          }
          if (path.endsWith('/shops/sample-shop')) {
            return jsonReply(longFixture('browse-shop', 'op-023'));
          }
          if (path.endsWith('/wishlist')) {
            return jsonReply(longFixture('wishlist', 'op-039'));
          }
          if (path.endsWith('/recently-viewed')) {
            return jsonReply(longFixture('recently-viewed-items', 'op-042'));
          }
          if (path.contains('conversations') ||
              path.contains('support-tickets') ||
              path.contains('notifications') ||
              path.endsWith('/questions') ||
              path.endsWith('/reviews')) {
            return communication.defaultReply(r);
          }
          return h.defaultReply(r);
        };
        if (feature == 'checkout') {
          h.commerce.checkout.begin(
            CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
          );
          await tester.runAsync(() async {
            await h.commerce.checkout.loadAddresses();
            await h.commerce.checkout.getQuote();
          });
        }
        final screen = switch (feature) {
          'login' => LoginScreen(session: h.session),
          'register' => RegistrationScreen(
            repository: h.auth,
            clock: () => h.now,
          ),
          'recovery' => RecoveryScreen(
            repository: h.auth,
            launcher: d.launcher,
          ),
          'consent' => ConsentScreen(
            repository: h.policies,
            session: h.session,
            launcher: d.launcher,
            returnTo: '/',
          ),
          'policy' => PolicyReaderScreen(
            repository: h.policies,
            launcher: d.launcher,
            type: PolicyType.terms,
          ),
          'home' => ShoppingPage(body: HomeScreen(dependencies: d)),
          'directory' => ShoppingPage(
            body: ShopDirectoryScreen(dependencies: d),
          ),
          'search' => SearchScreen(
            dependencies: d,
            mode: SearchMode.products,
            query: 'sample',
            page: 1,
            validRoute: true,
          ),
          'shop' => ShopScreen(
            dependencies: d,
            slug: 'sample-shop',
            query: '',
            category: null,
            page: 1,
          ),
          'product' => ProductDetailScreen(
            dependencies: d,
            productId: customerId,
          ),
          'account' => ShoppingPage(
            body: AccountHomeScreen(session: h.session),
          ),
          'profile' => ProfileScreen(dependencies: d),
          'photo' => PhotoScreen(dependencies: d),
          'review composer' => ReviewComposerScreen(
            dependencies: d,
            controller: state.review(customerId, otherId),
          ),
          'batch' => BatchResultScreen(dependencies: d, id: customerId),
          'password' => PasswordScreen(dependencies: d),
          'preferences' => PreferencesScreen(dependencies: d),
          'addresses' => AddressBookScreen(dependencies: d),
          'address form' => AddressFormScreen(dependencies: d),
          'cart' => ShoppingPage(body: CartScreen(dependencies: d)),
          'checkout' => CheckoutScreen(dependencies: d),
          'orders' => OrdersScreen(dependencies: d),
          'order' => OrderDetailScreen(dependencies: d, id: customerId),
          'wishlist' || 'history' => SavedProductsScreen(
            dependencies: d,
            collection: feature == 'history'
                ? SavedCollection.recentlyViewed
                : SavedCollection.wishlist,
          ),
          'questions' => QuestionsScreen(dependencies: d, product: customerId),
          'reviews' => ReviewsScreen(dependencies: d, product: customerId),
          'notifications' => NotificationInboxScreen(dependencies: d),
          'message' => ShopThreadScreen(
            dependencies: d,
            controller: state.shopThread(id: customerId),
          ),
          'support' => TicketInboxScreen(dependencies: d),
          'ticket composer' => TicketComposerScreen(
            dependencies: d,
            controller: state.ticket(),
          ),
          _ => TicketDetailScreen(
            dependencies: d,
            controller: state.ticket(customerId),
          ),
        };
        var scale = 1.0;
        Widget app() => MaterialApp(
          theme: buyerTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        );
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phoneTabletSizes.first;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        TextField? input;
        FocusNode? inputFocus;
        if (find.byType(TextFormField).evaluate().isNotEmpty) {
          final field = find.byType(TextFormField).first;
          await tester.ensureVisible(field);
          await tester.enterText(field, 'Safe synthetic draft');
          await tester.pumpAndSettle();
          inputFocus = tester
              .widget<EditableText>(
                find
                    .descendant(of: field, matching: find.byType(EditableText))
                    .first,
              )
              .focusNode;
          input = tester.widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)).first,
          );
        }
        final requests = h.adapter.requests.length;
        for (final size in phoneTabletSizes) {
          for (final actual in [size, Size(size.height, size.width)]) {
            for (final textScale in [1.0, 1.5, 2.0]) {
              scale = textScale;
              tester.view.physicalSize = actual;
              tester.view.viewInsets = FakeViewPadding(
                bottom: actual.height > 500 ? 240 : 100,
              );
              await tester.pumpWidget(app());
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$feature $actual text $scale',
              );
            }
          }
        }
        // Cross both breakpoints repeatedly while retaining the mounted screen.
        for (final width in [599.0, 600.0, 839.0, 840.0, 900.0, 400.0]) {
          tester.view.physicalSize = Size(width, 700);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (input != null) {
          expect(input.controller!.text, 'Safe synthetic draft');
          expect(inputFocus!.hasFocus, isTrue);
        }
        expect(
          h.adapter.requests.length,
          requests,
          reason: 'Resizing must not refetch or write.',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
