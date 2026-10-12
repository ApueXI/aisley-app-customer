// Actual Checkout screens with synthetic transport and public media.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/commerce_state.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_repository.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/checkout_repository.dart';
import 'package:aisley_mobile_buyer/features/checkout/domain/checkout_intent.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/batch_result_screen.dart';
import 'package:aisley_mobile_buyer/features/checkout/presentation/checkout_screen.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';

import '../support/fakes.dart';
import '../support/image_samples.dart';

late SemanticsHandle semantics;
late AppDependencies dependencies;
final delayedImage = Completer<ResponseBody>();
final scenario = Uri.base.queryParameters['scenario'] ?? 'normal';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  final auth = FakeAuth(), policies = FakePolicies();
  final session = SessionController(
    auth,
    policies,
    MemoryTokenStore()..token = 'synthetic-only',
  );
  await session.bootstrap();
  final values = jsonDecode(wireFixtures) as Map<String, dynamic>;
  final quote = values['op-029']['data'];
  quote['expiresAt'] = DateTime.now()
      .add(const Duration(minutes: 15))
      .toUtc()
      .toIso8601String();
  quote['mode'] = 'buy_now';
  quote['groups'][0]['availableVouchers'] = [];
  final batch = values['op-030']['data'];
  final name = scenario == 'long'
      ? List.filled(6, 'Long reviewed Product name').join(' ')
      : 'Reviewed Product';
  for (final item in [
    quote['groups'][0]['items'][0],
    batch['orders'][0]['items'][0],
  ]) {
    item['productName'] = name;
    item['imageUrl'] = switch (scenario) {
      'missing' => null,
      'foreign' => 'https://untrusted.example/api/v1/product-media/$otherId',
      _ => '/api/v1/product-media/$otherId',
    };
    item['variantId'] = null;
  }
  final adapter = FakeAdapter((r) {
    final path = r.uri.path;
    if (path.startsWith('/api/v1/product-media/')) {
      if (r.headers.keys.any(
        (k) => ['authorization', 'cookie'].contains(k.toLowerCase()),
      )) {
        throw StateError('Public media received credentials');
      }
      if (scenario == 'loading') return delayedImage.future;
      if (scenario == 'broken') return jsonReply({}, status: 404);
      if (scenario == 'corrupt') return ResponseBody.fromBytes([1, 2, 3], 200);
      return imageReply();
    }
    if (path.endsWith('/cart')) return jsonReply(values['op-025']);
    if (path.endsWith('/addresses')) return jsonReply(values['op-015']);
    if (path.endsWith('/checkout/logistics-options')) {
      return jsonReply(values['op-096']);
    }
    if (path.endsWith('/checkout/quote')) return jsonReply(values['op-029']);
    if (path.contains('/checkout/')) return jsonReply(values['op-030']);
    return jsonReply({}, status: 404);
  });
  final api = ApiClient(
    testConfig,
    publicClient: Dio()..httpClientAdapter = adapter,
    privateClient: Dio()..httpClientAdapter = adapter,
    deadline: const Duration(minutes: 2),
    readBackoff: Duration.zero,
  );
  final addresses = AddressRepository(api);
  final commerce = CommerceState(
    session: session,
    carts: CartRepository(api),
    checkoutRepository: CheckoutRepository(api),
    addresses: addresses,
    orders: OrderRepository(api),
  );
  dependencies = AppDependencies(
    config: testConfig,
    auth: auth,
    policies: policies,
    session: session,
    launcher: TrustedLauncher(testConfig),
    client: api,
    commerce: commerce,
    addresses: addresses,
    discovery: DiscoveryRepository(api: api, session: session),
  );
  commerce.checkout.begin(
    CheckoutIntent.buyNow(BuyNowItem(customerId, null, 1)),
  );
  runApp(const Fixture());
}

ResponseBody imageReply() => ResponseBody.fromBytes(
  base64Decode(buyerImageSamples.first['bytes']!),
  200,
  headers: {
    Headers.contentTypeHeader: ['image/jpeg'],
  },
);

class Fixture extends StatefulWidget {
  const Fixture({super.key});
  @override
  State<Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<Fixture> {
  late final router = GoRouter(
    initialLocation: Uri.base.queryParameters['page'] == 'result'
        ? '/checkout/result/$customerId'
        : '/checkout',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _shell(child),
        routes: [
          GoRoute(
            path: '/checkout',
            builder: (_, _) => CheckoutScreen(dependencies: dependencies),
          ),
          GoRoute(
            path: '/checkout/result/:id',
            builder: (_, state) => BatchResultScreen(
              dependencies: dependencies,
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, _) => const Scaffold(body: Text('Orders opened')),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (_, _) =>
                const Scaffold(body: Text('Order detail opened')),
          ),
        ],
      ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  Widget _shell(Widget child) => ListenableBuilder(
    listenable: dependencies.session,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Wrap(
              children: [
                TextButton(
                  onPressed: () => router.go('/checkout'),
                  child: const Text('Show review'),
                ),
                TextButton(
                  onPressed: () => router.go('/checkout/result/$customerId'),
                  child: const Text('Show result'),
                ),
                TextButton(
                  onPressed: dependencies.session.signOut,
                  child: const Text('Clear session'),
                ),
                if (scenario == 'loading')
                  TextButton(
                    onPressed: () {
                      if (!delayedImage.isCompleted) {
                        delayedImage.complete(imageReply());
                      }
                    },
                    child: const Text('Release image'),
                  ),
              ],
            ),
            Expanded(
              child: dependencies.session.active
                  ? child
                  : const Center(child: Text('Session cleared')),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: buyerTheme(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          Uri.base.queryParameters['text'] == 'large' ? 2 : 1,
        ),
      ),
      child: child!,
    ),
  );
}

const wireFixtures =
    r'''{"op-029":{"data":{"quoteId":"00000008-1111-4111-8111-111111111111","expiresAt":"2026-10-03T00:15:00.000000Z","mode":"buy_now","paymentMethod":"cod","address":{"id":"11111111-1111-4111-8111-111111111111","recipientName":"Synthetic example","contactNumber":"Synthetic example","addressLine1":"Synthetic example","addressLine2":null,"barangay":"Synthetic example","cityMunicipality":"Synthetic example","province":"Synthetic example","region":"Synthetic example","postalCode":"Synthetic example","country":"Synthetic example","label":null},"groups":[{"shop":{"id":"11111111-1111-4111-8111-111111111111","name":"Synthetic example"},"items":[{"cartItemId":null,"productId":"11111111-1111-4111-8111-111111111111","variantId":null,"productName":"Synthetic example","sku":null,"selectedOptions":[{"group":"Synthetic example","value":"Synthetic example"}],"unitPrice":"100.00","quantity":1,"lineSubtotal":"100.00","imageUrl":null}],"availableVouchers":[],"appliedVouchers":[],"shippingQuote":{"serviceable":true,"logisticsOrganizationId":"22222222-2222-4222-8222-222222222222","logisticsBusinessName":"Synthetic Logistics","routeStatus":"local","shippingFee":"100.00"},"totals":{"merchandiseSubtotal":"100.00","shippingFee":"100.00","discount":"0.00","shippingDiscount":"0.00","payable":"200.00","currency":"PHP"}}],"summary":{"orderCount":1,"merchandiseSubtotal":"100.00","shippingFee":"100.00","discount":"0.00","shippingDiscount":"0.00","payable":"200.00","currency":"PHP"}}},"op-030":{"data":{"id":"11111111-1111-4111-8111-111111111111","currency":"PHP","placedAt":"2026-10-03T00:00:00.000000Z","orders":[{"id":"11111111-1111-4111-8111-111111111111","reference":"ASL-SYNTHETIC","status":"placed","paymentMethod":"cod","paymentStatus":"pending","shop":{"id":"11111111-1111-4111-8111-111111111111","name":"Synthetic example"},"items":[{"id":"11111111-1111-4111-8111-111111111111","productId":null,"variantId":null,"productName":"Synthetic example","variantName":null,"sku":null,"selectedOptions":[{"group":"Synthetic example","value":"Synthetic example"}],"unitPrice":"100.00","quantity":1,"lineSubtotal":"100.00","currency":"PHP","imageUrl":null}],"address":{"recipientName":"Synthetic example","contactNumber":"Synthetic example","addressLine1":"Synthetic example","addressLine2":null,"barangay":"Synthetic example","cityMunicipality":"Synthetic example","province":"Synthetic example","region":"Synthetic example","postalCode":"Synthetic example","country":"Synthetic example","latitude":null,"longitude":null},"vouchers":[],"shippingQuote":{"logisticsOrganizationId":"22222222-2222-4222-8222-222222222222","logisticsBusinessName":"Synthetic Logistics","routeStatus":"local","shippingFee":"100.00"},"totals":{"merchandiseSubtotal":"100.00","shippingFee":"100.00","discount":"0.00","shippingDiscount":"0.00","payable":"200.00","currency":"PHP"},"detailUrl":"/synthetic-placeholder"}]}},"op-096":{"data":{"address":{"id":"11111111-1111-4111-8111-111111111111","recipientName":"Synthetic example","contactNumber":"Synthetic example","addressLine1":"Synthetic example","addressLine2":null,"barangay":"Synthetic example","cityMunicipality":"Synthetic example","province":"Synthetic example","region":"Synthetic example","postalCode":"Synthetic example","country":"Synthetic example","label":null},"groups":[{"shop":{"id":"11111111-1111-4111-8111-111111111111","name":"Synthetic example"},"options":[{"organizationId":"22222222-2222-4222-8222-222222222222","businessName":"Synthetic Logistics","shippingFee":"100.00","routeStatus":"local"}]}]}},"op-015":{"data":[{"id":"11111111-1111-4111-8111-111111111111","type":"shipping","label":null,"recipientName":"Synthetic example","contactNumber":"Synthetic example","addressLine1":"Synthetic example","addressLine2":null,"barangay":"Synthetic example","cityMunicipality":"Synthetic example","province":"Synthetic example","region":"Synthetic example","postalCode":"Synthetic example","country":"Synthetic example","latitude":null,"longitude":null,"isDefault":false}]},"op-025":{"data":{"id":"11111111-1111-4111-8111-111111111111","itemCount":1,"distinctItemCount":1,"subtotal":100,"availableSubtotal":100,"items":[{"id":"11111111-1111-4111-8111-111111111111","quantity":1,"unitPrice":100,"lineSubtotal":100,"product":{"id":"11111111-1111-4111-8111-111111111111","slug":"Synthetic example","name":"Synthetic example","url":"/synthetic-placeholder"},"variant":null,"selectedOptions":[{"group":"Synthetic example","value":"Synthetic example"}],"media":{"url":"/api/v1/product-media/11111111-1111-4111-8111-111111111111","altText":"Synthetic example"},"availability":{"isAvailable":true,"reason":null,"availableQuantity":1}}]}}}''';
