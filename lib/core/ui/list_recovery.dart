import 'package:flutter/material.dart';

/// Feedback for a retained snapshot; never implies an empty successful fetch.
class ListRecovery extends StatelessWidget {
  const ListRecovery({
    super.key,
    required this.retry,
    this.error,
    this.retained = false,
    this.stale = false,
    this.busy = false,
    this.coolingDown = false,
    this.requestedPage,
    this.displayedPage,
  });
  final VoidCallback retry;
  final String? error;
  final bool retained, stale, busy, coolingDown;
  final int? requestedPage, displayedPage;

  @override
  Widget build(BuildContext context) {
    final differentPage =
        displayedPage != null &&
        requestedPage != null &&
        displayedPage != requestedPage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (busy) const LinearProgressIndicator(semanticsLabel: 'Loading list'),
        if (retained && (stale || busy || error != null))
          Semantics(
            liveRegion: true,
            child: Text(
              differentPage
                  ? 'Showing page $displayedPage. ${error == null ? 'Loading' : 'Could not load'} page $requestedPage.'
                  : 'Showing saved results. ${busy ? 'Refreshing…' : 'These results may be out of date.'}',
            ),
          ),
        if (error != null) ...[
          Semantics(liveRegion: true, child: Text(error!)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: busy || coolingDown ? null : retry,
            child: Text(
              requestedPage == null ? 'Retry' : 'Retry page $requestedPage',
            ),
          ),
        ],
      ],
    );
  }
}

class ListPageAction extends StatelessWidget {
  const ListPageAction({
    super.key,
    required this.load,
    required this.hasMore,
    this.error,
    this.busy = false,
    this.disabled = false,
    this.label = 'Load more',
  });
  final VoidCallback load;
  final bool hasMore, busy, disabled;
  final String? error;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null) Semantics(liveRegion: true, child: Text(error!)),
      if (hasMore)
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: busy || disabled ? null : load,
          child: Text(
            busy
                ? 'Loading…'
                : error != null
                ? 'Retry loading more'
                : label,
          ),
        ),
    ],
  );
}
