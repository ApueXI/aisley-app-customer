import 'package:flutter/material.dart';

import '../../../core/platform/trusted_launcher.dart';
import '../data/discovery_repository.dart';
import '../data/home_models.dart';
import 'catalog_image.dart';

class HomeCampaignBanner extends StatelessWidget {
  const HomeCampaignBanner({
    super.key,
    required this.campaign,
    required this.discovery,
    required this.launcher,
  });

  final HomeCampaign campaign;
  final DiscoveryRepository discovery;
  final TrustedLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final title = campaign.title?.trim();
    final destination = campaign.destinationUrl?.trim();
    final label = [campaign.altText, campaign.title]
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Promotion');
    final image = MediaQuery.sizeOf(context).width >= 600
        ? campaign.imageDesktopUrl ?? campaign.imageMobileUrl
        : campaign.imageMobileUrl ?? campaign.imageDesktopUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      child: InkWell(
        onTap: destination == null || destination.isEmpty
            ? null
            : () => launcher.open(destination),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              AspectRatio(
                aspectRatio: 2.4,
                child: CatalogImage(
                  url: image,
                  discovery: discovery,
                  label: label,
                ),
              ),
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  semanticsLabel: label,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
