// Actual Order screens and media transport with entirely synthetic data.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/commerce_state.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_client.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/core/security/session_controller.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/address_repository.dart';
import 'package:aisley_mobile_buyer/features/cart/data/cart_repository.dart';
import 'package:aisley_mobile_buyer/features/checkout/data/checkout_repository.dart';
import 'package:aisley_mobile_buyer/features/discovery/data/discovery_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/data/order_repository.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/order_detail_screen.dart';
import 'package:aisley_mobile_buyer/features/orders/presentation/orders_screen.dart';

import '../support/fakes.dart';
import '../support/image_samples.dart';

late SemanticsHandle semantics;
late AppDependencies dependencies;
final delayedImage = Completer<ResponseBody>();
int imageReads = 0;
String scenario = 'normal';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  semantics = SemanticsBinding.instance.ensureSemantics();
  scenario = Uri.base.queryParameters['scenario'] ?? 'normal';
  final auth = FakeAuth(), policies = FakePolicies();
  final session = SessionController(
    auth,
    policies,
    MemoryTokenStore()..token = 'synthetic-only',
  );
  await session.bootstrap();
  final values = jsonDecode(wireFixtures) as Map<String, dynamic>;
  final preview = values['op-032']['data'][0] as Map<String, dynamic>;
  final item = values['op-033']['data']['items'][0] as Map<String, dynamic>;
  final name = scenario == 'long'
      ? List.filled(6, 'Long purchased Product name').join(' ')
      : 'Purchased Product';
  final imageUrl = switch (scenario) {
    'missing' => null,
    'foreign' => 'https://untrusted.example/api/v1/product-media/$otherId',
    _ => '/api/v1/product-media/$otherId',
  };
  preview['itemPreview'] = {
    'productId': customerId,
    'productName': name,
    'variantName': 'Color: Purple',
    'quantity': 1,
    'imageUrl': imageUrl,
  };
  item['productName'] = name;
  item['imageUrl'] = imageUrl;
  final adapter = FakeAdapter((r) {
    final path = r.uri.path;
    if (path.startsWith('/api/v1/product-media/')) {
      imageReads++;
      if (r.headers.keys.any(
        (k) => ['authorization', 'cookie'].contains(k.toLowerCase()),
      )) {
        throw StateError('Public image received credentials');
      }
      if (scenario == 'loading') return delayedImage.future;
      if (scenario == 'broken') return jsonReply({}, status: 404);
      if (scenario == 'corrupt') return ResponseBody.fromBytes([1, 2, 3], 200);
      return imageReply();
    }
    if (path.endsWith('/orders')) return jsonReply(values['op-032']);
    if (path.endsWith('/tracking')) return jsonReply(values['op-034']);
    if (path.contains('/orders/')) return jsonReply(values['op-033']);
    if (path.endsWith('/cart')) return jsonReply(values['op-025']);
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
  State<Fixture> createState() => FixtureState();
}

class FixtureState extends State<Fixture> {
  bool detail = Uri.base.queryParameters['page'] == 'detail';
  final large = Uri.base.queryParameters['text'] == 'large';
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buyerTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
      child: child!,
    ),
    home: ListenableBuilder(
      listenable: dependencies.session,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => setState(() => detail = false),
                    child: const Text('Show Orders'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => detail = true),
                    child: const Text('Show detail'),
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
                        setState(() {});
                      },
                      child: const Text('Release image'),
                    ),
                ],
              ),
              Expanded(
                child: !dependencies.session.active
                    ? const Center(child: Text('Session cleared'))
                    : detail
                    ? OrderDetailScreen(
                        dependencies: dependencies,
                        id: customerId,
                      )
                    : OrdersScreen(dependencies: dependencies),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const wireFixtures =
    r'''{"op-032":{"data":[{"id":"11111111-1111-4111-8111-111111111111","reference":"ASL-SYNTHETIC","shop":{"id":"11111111-1111-4111-8111-111111111111","slug":"Synthetic example","name":"Synthetic example","logoUrl":null},"itemPreview":null,"lineCount":1,"itemCount":1,"status":"placed","statusLabel":"Order placed","group":"to_prepare","groupLabel":"To Prepare","latestTrackingAt":"2026-10-03T00:00:00.000000Z","totals":{"merchandiseSubtotal":"100.00","shippingFee":"100.00","discount":"0.00","shippingDiscount":"0.00","payable":"200.00","currency":"PHP"},"actions":{"canCancel":true,"canModify":true,"canReview":false,"modifiableFields":["delivery_address"]},"detailUrl":"/synthetic-placeholder","shippingProvider":{"id":"22222222-2222-4222-8222-222222222222","businessName":"Synthetic Logistics"}}],"links":{"first":"/synthetic-placeholder","last":"/synthetic-placeholder","prev":null,"next":null},"meta":{"current_page":1,"from":null,"last_page":1,"links":[{"url":null,"label":"Synthetic example","active":false}],"path":"/synthetic-placeholder","per_page":1,"to":null,"total":1},"filters":{"selected":null,"tabs":[{"value":null,"label":"Synthetic example"}]}},"op-033":{"data":{"id":"11111111-1111-4111-8111-111111111111","reference":"ASL-SYNTHETIC","checkoutBatchId":"11111111-1111-4111-8111-111111111111","placedAt":"2026-10-03T00:00:00.000000Z","latestTrackingAt":"2026-10-03T00:00:00.000000Z","status":"placed","statusLabel":"Order placed","group":"to_prepare","groupLabel":"To Prepare","shop":{"id":"11111111-1111-4111-8111-111111111111","slug":"Synthetic example","name":"Synthetic example","logoUrl":null},"items":[{"id":"11111111-1111-4111-8111-111111111111","productId":null,"variantId":null,"productName":"Synthetic example","variantName":null,"sku":null,"selectedOptions":[{"group":"Synthetic example","value":"Synthetic example"}],"unitPrice":"100.00","quantity":1,"lineSubtotal":"100.00","currency":"PHP","canReview":false,"reviewId":null}],"deliveryAddress":{"version":1,"recipientName":"Synthetic example","contactNumber":"Synthetic example","addressLine1":"Synthetic example","addressLine2":null,"barangay":"Synthetic example","cityMunicipality":"Synthetic example","province":"Synthetic example","region":"Synthetic example","postalCode":"Synthetic example","country":"Synthetic example"},"payment":{"method":"cod","status":"pending"},"vouchers":[],"totals":{"merchandiseSubtotal":"100.00","shippingFee":"100.00","discount":"0.00","shippingDiscount":"0.00","payable":"200.00","currency":"PHP"},"timeline":[{"id":"11111111-1111-4111-8111-111111111111","status":"placed","label":"Synthetic example","eventType":null,"location":{},"occurredAt":"2026-10-03T00:00:00.000000Z"}],"timelineCount":1,"timelineHasMore":false,"trackingUrl":"/synthetic-placeholder","delivery":null,"map":{"available":false,"state":"unavailable","message":"Location is not available yet","currentPosition":null,"route":null,"capturedAt":null},"actions":{"canCancel":true,"canModify":true,"canReview":false,"modifiableFields":["delivery_address"]},"shippingProvider":{"id":"22222222-2222-4222-8222-222222222222","businessName":"Synthetic Logistics"}}},"op-034":{"data":[{"id":"11111111-1111-4111-8111-111111111111","status":"placed","label":"Synthetic example","eventType":null,"location":{},"occurredAt":"2026-10-03T00:00:00.000000Z"}],"links":{"first":"/synthetic-placeholder","last":"/synthetic-placeholder","prev":null,"next":null},"meta":{"current_page":1,"from":null,"last_page":1,"links":[{"url":null,"label":"Synthetic example","active":false}],"path":"/synthetic-placeholder","per_page":1,"to":null,"total":1}},"op-025":{"data":{"id":"11111111-1111-4111-8111-111111111111","itemCount":1,"distinctItemCount":1,"subtotal":100,"availableSubtotal":100,"items":[{"id":"11111111-1111-4111-8111-111111111111","quantity":1,"unitPrice":100,"lineSubtotal":100,"product":{"id":"11111111-1111-4111-8111-111111111111","slug":"Synthetic example","name":"Synthetic example","url":"/synthetic-placeholder"},"variant":null,"selectedOptions":[{"group":"Synthetic example","value":"Synthetic example"}],"media":{"url":"/api/v1/product-media/11111111-1111-4111-8111-111111111111","altText":"Synthetic example"},"availability":{"isAvailable":true,"reason":null,"availableQuantity":1}}]}}}''';
