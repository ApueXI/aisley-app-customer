part of 'message_views.dart';

extension _MessageThreadHeader on _MessageThreadViewState {
  AppBar _threadHeader() => AppBar(
    toolbarHeight: widget.compactComposer
        ? (56 * catalogTextScale(context)).clamp(56, 112)
        : null,
    title: widget.compactComposer && widget.subtitle != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          )
        : Text(widget.title),
    leading: IconButton(
      tooltip: 'Back',
      onPressed: _leave,
      icon: const Icon(Icons.arrow_back),
    ),
    actions: [
      if (widget.arrivals > 0)
        IconButton(
          tooltip: 'View ${widget.arrivals} new messages',
          onPressed: _viewArrivals,
          icon: const Icon(Icons.mark_chat_unread_outlined),
        ),
      IconButton(
        tooltip: 'Refresh conversation',
        onPressed: widget.loading || widget.sending || widget.coolingDown
            ? null
            : widget.refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}
