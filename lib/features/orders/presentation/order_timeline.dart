import 'package:flutter/material.dart';

import '../../../core/ui/marketplace_widgets.dart';
import '../data/tracking_models.dart';

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({
    super.key,
    required this.events,
    required this.mapAvailable,
    required this.mapMessage,
  });
  final List<TrackingEvent> events;
  final bool mapAvailable;
  final String mapMessage;
  @override
  Widget build(BuildContext context) => MarketSection(
    title: 'Tracking',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mapAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_off_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mapMessage.trim().isEmpty
                        ? 'Live map unavailable.'
                        : mapMessage,
                  ),
                ),
              ],
            ),
          )
        else
          const Text(
            'Map display is unavailable in Buyer. Tracking events show the latest Order updates.',
          ),
        if (events.isEmpty) const Text('No tracking updates yet.'),
        for (var i = 0; i < events.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Update ${i + 1} of ${events.length}',
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text('${i + 1}'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events[i].label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(events[i].occurredAt.toLocal().toString()),
                      if (events[i].hub != null) Text(events[i].hub!),
                      if (events[i].city != null) Text(events[i].city!),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
