import '../../../core/networking/wire.dart';
import 'catalog_models.dart';

class BuyerHome {
  const BuyerHome({
    required this.viewer,
    required this.advertisementLayer,
    required this.campaigns,
    required this.quickActions,
    required this.categories,
    required this.flashDeals,
    required this.topProducts,
    required this.recentlyViewed,
    required this.recommendations,
  });
  final HomeViewer viewer;
  final HomeAdvertisement? advertisementLayer;
  final CampaignGroups campaigns;
  final List<QuickAction> quickActions;
  final List<HomeCategory> categories;
  final HomeFlashDeals? flashDeals;
  final List<ProductCard> topProducts, recentlyViewed;
  final HomeRecommendations recommendations;

  factory BuyerHome.parse(Object? json) {
    final wire = Wire(json);
    final advertisement = wire.field('advertisementLayer');
    final deals = wire.field('flashDeals');
    return BuyerHome(
      viewer: HomeViewer.parse(wire.object('viewer')),
      advertisementLayer: advertisement == null
          ? null
          : HomeAdvertisement.parse(advertisement),
      campaigns: CampaignGroups.parse(wire.object('campaigns')),
      quickActions: wire.list('quickActions', QuickAction.parse),
      categories: wire.list('categories', HomeCategory.parse),
      flashDeals: deals == null ? null : HomeFlashDeals.parse(deals),
      topProducts: wire.list(
        'topProducts',
        (value) => ProductCard.parse(value),
      ),
      recentlyViewed: wire.list(
        'recentlyViewed',
        (value) => ProductCard.parse(value),
      ),
      recommendations: HomeRecommendations.parse(
        wire.object('recommendations'),
      ),
    );
  }
}

class HomeViewer {
  const HomeViewer({
    required this.isAuthenticated,
    required this.displayName,
    required this.email,
    required this.deliveryLocation,
    required this.cartItemCount,
  });
  final bool isAuthenticated;
  final String? displayName, email;
  final DeliveryLocation? deliveryLocation;
  final int cartItemCount;

  factory HomeViewer.parse(Object? json) {
    final wire = Wire(json);
    final location = wire.field('deliveryLocation');
    return HomeViewer(
      isAuthenticated: wire.boolean('isAuthenticated'),
      displayName: wire.nullableString('displayName'),
      email: wire.nullableString('email'),
      deliveryLocation: location == null
          ? null
          : DeliveryLocation.parse(location),
      cartItemCount: wire.integer('cartItemCount'),
    );
  }
}

class DeliveryLocation {
  const DeliveryLocation({
    required this.id,
    required this.label,
    required this.cityMunicipality,
    required this.province,
  });
  final String id, cityMunicipality, province;
  final String? label;

  factory DeliveryLocation.parse(Object? json) {
    final wire = Wire(json);
    return DeliveryLocation(
      id: wire.uuid('id'),
      label: wire.nullableString('label'),
      cityMunicipality: wire.string('cityMunicipality'),
      province: wire.string('province'),
    );
  }
}

class HomeAdvertisement {
  const HomeAdvertisement({
    required this.layout,
    required this.rotationIntervalSeconds,
    required this.primary,
    required this.secondaryTop,
    required this.secondaryBottom,
  });
  final String layout;
  final int rotationIntervalSeconds;
  final List<HomeCampaign> primary;
  final HomeCampaign? secondaryTop, secondaryBottom;

  factory HomeAdvertisement.parse(Object? json) {
    final wire = Wire(json);
    final top = wire.field('secondaryTop'),
        bottom = wire.field('secondaryBottom');
    return HomeAdvertisement(
      layout: wire.string('layout'),
      rotationIntervalSeconds: wire.integer('rotationIntervalSeconds'),
      primary: wire.list('primary', HomeCampaign.parse),
      secondaryTop: top == null ? null : HomeCampaign.parse(top),
      secondaryBottom: bottom == null ? null : HomeCampaign.parse(bottom),
    );
  }
}

class CampaignGroups {
  const CampaignGroups({required this.hero, required this.side});
  final List<HomeCampaign> hero, side;

  factory CampaignGroups.parse(Object? json) {
    final wire = Wire(json);
    return CampaignGroups(
      hero: wire.list('hero', HomeCampaign.parse),
      side: wire.list('side', HomeCampaign.parse),
    );
  }
}

class HomeCampaign {
  const HomeCampaign({
    required this.id,
    required this.placement,
    required this.title,
    required this.description,
    required this.slot,
    required this.position,
    required this.imageDesktopUrl,
    required this.imageMobileUrl,
    required this.altText,
    required this.destinationUrl,
    required this.startsAt,
    required this.endsAt,
    required this.priority,
    required this.isActive,
  });
  final String id, title, altText, destinationUrl;
  final String? placement, description, slot, imageDesktopUrl, imageMobileUrl;
  final int position;
  final int? priority;
  final DateTime? startsAt, endsAt;
  final bool isActive;

  factory HomeCampaign.parse(Object? json) {
    final wire = Wire(json);
    return HomeCampaign(
      id: wire.string('id'),
      placement: wire.optionalString('placement'),
      title: wire.string('title'),
      description: wire.nullableString('description'),
      slot: wire.nullableString('slot'),
      position: wire.integer('position'),
      imageDesktopUrl: wire.nullableString('imageDesktopUrl'),
      imageMobileUrl: wire.nullableString('imageMobileUrl'),
      altText: wire.string('altText'),
      destinationUrl: wire.string('destinationUrl'),
      startsAt: _optionalTimestamp(wire, 'startsAt'),
      endsAt: _optionalTimestamp(wire, 'endsAt'),
      priority: wire.data.containsKey('priority')
          ? wire.nullableInt('priority')
          : null,
      isActive: wire.boolean('isActive'),
    );
  }
}

class QuickAction {
  const QuickAction({
    required this.key,
    required this.label,
    required this.destinationUrl,
  });
  final String key, label, destinationUrl;

  factory QuickAction.parse(Object? json) {
    final wire = Wire(json);
    return QuickAction(
      key: wire.string('key'),
      label: wire.string('label'),
      destinationUrl: wire.string('destinationUrl'),
    );
  }
}

class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.imageUrl,
  });
  final String id, slug, name;
  final String? imageUrl;

  factory HomeCategory.parse(Object? json) {
    final wire = Wire(json);
    return HomeCategory(
      id: wire.uuid('id'),
      slug: wire.string('slug'),
      name: wire.string('name'),
      imageUrl: wire.nullableString('imageUrl'),
    );
  }
}

class HomeRecommendations {
  const HomeRecommendations({
    required this.items,
    required this.nextCursor,
    required this.pageSize,
  });
  final List<ProductCard> items;
  final String? nextCursor;
  final int pageSize;

  factory HomeRecommendations.parse(Object? json) {
    final wire = Wire(json);
    return HomeRecommendations(
      items: wire.list('items', (value) => ProductCard.parse(value)),
      nextCursor: wire.nullableString('nextCursor'),
      pageSize: wire.positiveInt('pageSize'),
    );
  }
}

class HomeFlashDeals {
  const HomeFlashDeals({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.products,
  });
  final String id, title;
  final DateTime startsAt, endsAt;
  final List<ProductCard> products;

  factory HomeFlashDeals.parse(Object? json) {
    final wire = Wire(json);
    return HomeFlashDeals(
      id: wire.uuid('id'),
      title: wire.string('title'),
      startsAt: wire.timestamp('startsAt')!,
      endsAt: wire.timestamp('endsAt')!,
      products: wire.list('products', (value) => ProductCard.parse(value)),
    );
  }
}

DateTime? _optionalTimestamp(Wire wire, String key) {
  if (!wire.data.containsKey(key)) return null;
  return wire.timestamp(key);
}
