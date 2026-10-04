import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/checkout/data/checkout_repository.dart';
import '../features/orders/data/order_repository.dart';
import 'commerce_state.dart';
import 'communication_state.dart';
import '../core/networking/api_client.dart';
import '../core/platform/http_adapter.dart';
import '../core/platform/trusted_launcher.dart';
import '../core/security/session_controller.dart';
import '../core/security/token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/account/data/account_repository.dart';
import '../features/account/data/photo_picker_adapter.dart';
import '../features/addresses/data/address_repository.dart';
import '../features/addresses/data/map_location_service.dart';
import '../features/discovery/data/discovery_repository.dart';
import '../features/policies/data/policy_repository.dart';
import '../features/saved/data/saved_repository.dart';
import '../features/saved/presentation/recent_merge_coordinator.dart';
import '../features/saved/presentation/saved_status_controller.dart';

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.auth,
    required this.policies,
    required this.session,
    required this.launcher,
    this.discovery,
    this.accounts,
    this.addresses,
    this.wishlist,
    this.recentlyViewed,
    this.guestRecent,
    this.savedStatus,
    this.recentMerge,
    this.mapLocations,
    this.photoPicker,
    this.providerClient,
    DateTime Function()? clock,
    this.client,
    this.commerce,
    this.communication,
  }) : clock = clock ?? DateTime.now;
  factory AppDependencies.production(AppConfig config) {
    final client = ApiClient(config);
    configureHttpAdapter(client.publicClient);
    configureHttpAdapter(client.privateClient);
    final auth = ApiAuthRepository(
      client,
      deviceName: kIsWeb ? 'buyer-local-web' : 'buyer-android',
    );
    final policies = ApiPolicyRepository(client);
    final session = SessionController(
      auth,
      policies,
      SecureTokenStore(apiOrigin: config.apiBase.origin),
    );
    final discovery = DiscoveryRepository(api: client, session: session);
    final accounts = ApiAccountRepository(client);
    final addresses = AddressRepository(client);
    final wishlist = WishlistRepository(client);
    final recentlyViewed = RecentlyViewedRepository(client);
    final guestRecent = GuestRecentStore();
    final savedStatus = SavedStatusController(session, wishlist);
    final recentMerge = RecentMergeCoordinator(
      session: session,
      repository: recentlyViewed,
      guestStore: guestRecent,
    );
    final mapDio = Dio();
    configureHttpAdapter(mapDio, publicMapProvider: true);
    final mapLocations = MapLocationService(config, client: mapDio);
    return AppDependencies(
      config: config,
      client: client,
      auth: auth,
      policies: policies,
      session: session,
      launcher: TrustedLauncher(config),
      discovery: discovery,
      accounts: accounts,
      addresses: addresses,
      wishlist: wishlist,
      recentlyViewed: recentlyViewed,
      guestRecent: guestRecent,
      savedStatus: savedStatus,
      recentMerge: recentMerge,
      mapLocations: mapLocations,
      photoPicker: PhotoPickerAdapter(),
      providerClient: mapDio,
      communication: CommunicationState(session, client),
      commerce: CommerceState(
        session: session,
        carts: CartRepository(client),
        checkoutRepository: CheckoutRepository(client),
        addresses: addresses,
        orders: OrderRepository(client),
      ),
    );
  }
  final CommerceState? commerce;
  final CommunicationState? communication;
  final AppConfig config;
  final AuthRepository auth;
  final PolicyRepository policies;
  final SessionController session;
  final TrustedLauncher launcher;
  final DiscoveryRepository? discovery;
  final AccountRepository? accounts;
  final AddressRepository? addresses;
  final WishlistRepository? wishlist;
  final RecentlyViewedRepository? recentlyViewed;
  final GuestRecentStore? guestRecent;
  final SavedStatusController? savedStatus;
  final RecentMergeCoordinator? recentMerge;
  final MapLocationService? mapLocations;
  final PhotoPickerAdapter? photoPicker;
  final Dio? providerClient;
  final DateTime Function() clock;
  final ApiClient? client;
  void dispose() {
    communication?.dispose();
    commerce?.dispose();
    recentMerge?.dispose();
    savedStatus?.dispose();
    providerClient?.close(force: true);
    discovery?.dispose();
    session.dispose();
    client?.close();
  }
}
