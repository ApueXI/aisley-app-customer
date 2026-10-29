import 'package:flutter/material.dart';

import 'message_row.dart';
import '../../../core/chat_media/draft_controller.dart';
import '../../../core/chat_media/image_widgets.dart';
import 'message_bubble.dart';
export 'message_row.dart';

import 'package:go_router/go_router.dart';

import '../../../core/ui/responsive_layout.dart';

import '../../../core/ui/form_page.dart';
import '../../../core/communication/text_rules.dart';

export 'inbox_view.dart';
part 'message_composer.dart';
part 'message_thread_header.dart';

class MessageThreadView extends StatefulWidget {
  const MessageThreadView({
    super.key,
    required this.title,
    required this.rows,
    required this.draft,
    required this.changed,
    required this.clearDraft,
    required this.send,
    required this.retry,
    required this.refresh,
    required this.loadMore,
    required this.displayed,
    required this.loading,
    required this.paging,
    required this.sending,
    required this.allowed,
    required this.pending,
    required this.conflict,
    required this.more,
    required this.reviewConflict,
    required this.arrivals,
    required this.acknowledge,
    this.reason,
    this.subtitle,
    this.contextAction,
    this.error,
    this.pageError,
    this.readError,
    this.fieldError,
    this.coolingDown = false,
    this.inbox,
    this.media,
    this.mediaContext = const {},
    this.compactComposer = false,
  });
  final String title, draft;
  final ChatMediaDraftController? media;
  final Map<String, Object?> mediaContext;
  final List<MessageRow> rows;
  final bool compactComposer;
  final bool loading,
      paging,
      sending,
      allowed,
      pending,
      conflict,
      more,
      coolingDown;
  final int arrivals;
  final Widget? contextAction, inbox;
  final String? subtitle;
  final String? reason, error, pageError, readError, fieldError;
  final void Function(String) changed;
  final VoidCallback clearDraft,
      send,
      retry,
      refresh,
      loadMore,
      reviewConflict,
      acknowledge;
  final void Function(int) displayed;
  @override
  State<MessageThreadView> createState() => _MessageThreadViewState();
}

class _MessageThreadViewState extends State<MessageThreadView> {
  bool _inboxMounted = false;

  late final _text = TextEditingController(text: widget.draft);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _composerScroll = ScrollController();
  final _messageViewport = GlobalKey();
  final _rows = <String, GlobalKey>{};
  final _form = GlobalKey<FormState>();
  bool _allowPop = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    widget.media?.addListener(_mediaChanged);
    _scroll.addListener(_displayed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _displayed());
  }

  @override
  void didUpdateWidget(MessageThreadView old) {
    super.didUpdateWidget(old);
    if (widget.draft != _text.text) {
      _text.value = TextEditingValue(
        text: widget.draft,
        selection: TextSelection.collapsed(offset: widget.draft.length),
      );
    }
    final addedOlder =
        old.rows.isNotEmpty &&
        widget.rows.isNotEmpty &&
        widget.rows.first.sequence < old.rows.first.sequence;
    final oldHeight = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0.0;
    final nearLatest =
        !_scroll.hasClients || _scroll.position.extentAfter <= 80;
    final addedLatest =
        widget.rows.isNotEmpty &&
        (old.rows.isEmpty ||
            widget.rows.last.sequence > old.rows.last.sequence);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (addedOlder && _scroll.hasClients) {
        _scroll.jumpTo(
          (_scroll.offset + _scroll.position.maxScrollExtent - oldHeight).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      } else if (addedLatest && nearLatest && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        if (widget.arrivals > 0) widget.acknowledge();
      }
      _displayed();
    });
  }

  void _draftChanged(String value) {
    widget.changed(value);
    setState(() {});
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  void _displayed({bool retry = false}) {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        widget.loading ||
        widget.paging ||
        widget.readError != null && !retry) {
      return;
    }
    int? highest;
    final viewport = _messageViewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    for (final row in widget.rows) {
      final box = _rows[row.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final y = box.localToGlobal(Offset.zero).dy;
        if (y >= viewportTop &&
            y + box.size.height <= viewportBottom &&
            (highest == null || row.sequence > highest)) {
          highest = row.sequence;
        }
      }
    }
    if (highest != null) widget.displayed(highest);
  }

  Future<void> _viewArrivals() async {
    widget.acknowledge();
    if (!_scroll.hasClients) return;
    await _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!mounted || widget.rows.isEmpty) return;
    final target = _rows[widget.rows.last.id]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target);
    }
  }

  Future<void> _leave() async {
    if (_confirming) return;
    _confirming = true;
    if (_text.text.isNotEmpty ||
        widget.sending ||
        widget.pending ||
        widget.media?.hasImages == true) {
      final leave = await confirmDiscard(
        context,
        widget.pending || widget.sending
            ? 'Leaving keeps an unresolved send in this session. A committed request cannot be cancelled by navigation.'
            : 'Discard this unsent message?',
      );
      if (!mounted) return;
      if (!leave) {
        _confirming = false;
        return;
      }
    }
    if (!widget.pending && !widget.sending) widget.clearDraft();
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/account');
    }
  }

  @override
  void dispose() {
    widget.media?.removeListener(_mediaChanged);
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    _composerScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (marketplaceDesktop(context)) _inboxMounted = true;
    return PopScope(
      canPop:
          _allowPop ||
          _text.text.isEmpty &&
              !widget.sending &&
              !widget.pending &&
              widget.media?.hasImages != true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ShoppingPage(
        appBar: _threadHeader(),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: marketplaceDesktop(context) && widget.inbox != null
                  ? 320
                  : 0,
              child: Visibility(
                visible: marketplaceDesktop(context),
                maintainState: true,
                child: _inboxMounted
                    ? widget.inbox ?? const SizedBox.shrink()
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              key: const ValueKey('message-detail'),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final composerHeight = (constraints.maxHeight * .42).clamp(
                    0.0,
                    320.0,
                  );
                  return Column(
                    children: [
                      if (widget.compactComposer &&
                          widget.contextAction != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .25,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: widget.contextAction!,
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          key: _messageViewport,
                          controller: _scroll,
                          padding: pagePadding(context),
                          children: [
                            if (widget.subtitle != null &&
                                !widget.compactComposer)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(widget.subtitle!),
                              ),
                            if (widget.contextAction != null &&
                                !widget.compactComposer)
                              widget.contextAction!,
                            if (widget.loading || widget.sending)
                              const LinearProgressIndicator(
                                semanticsLabel: 'Updating conversation',
                              ),
                            if (widget.error != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(widget.error!),
                              ),
                            if (widget.arrivals > 0)
                              TextButton(
                                onPressed: _viewArrivals,
                                child: Text(
                                  '${widget.arrivals} new messages · View',
                                ),
                              ),
                            if (widget.more)
                              TextButton(
                                onPressed:
                                    widget.loading ||
                                        widget.paging ||
                                        widget.sending ||
                                        widget.coolingDown
                                    ? null
                                    : widget.loadMore,
                                child: Text(
                                  widget.paging
                                      ? 'Loading…'
                                      : 'Load older messages',
                                ),
                              ),
                            if (widget.pageError != null)
                              Text(widget.pageError!),
                            if (widget.rows.isEmpty &&
                                !widget.loading &&
                                widget.error == null)
                              const Text(
                                'Your first sent message starts the conversation.',
                              ),
                            for (final row in widget.rows)
                              Padding(
                                key: _rows.putIfAbsent(
                                  row.id,
                                  () => GlobalKey(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: MessageBubble(
                                  row: row,
                                  media: widget.media,
                                  conversationStyle: widget.compactComposer,
                                ),
                              ),
                            if (widget.readError != null) ...[
                              Text(widget.readError!),
                              TextButton(
                                onPressed:
                                    widget.coolingDown || widget.rows.isEmpty
                                    ? null
                                    : () => _displayed(retry: true),
                                child: const Text('Retry read marker'),
                              ),
                            ],
                            if (!widget.allowed)
                              Text(
                                'Read only. ${widget.reason ?? 'Sending is currently unavailable.'}',
                              ),
                            if (!widget.compactComposer || widget.error != null)
                              TextButton(
                                onPressed:
                                    widget.loading ||
                                        widget.sending ||
                                        widget.coolingDown
                                    ? null
                                    : widget.refresh,
                                child: const Text('Retry / refresh'),
                              ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: composerHeight),
                        child: SingleChildScrollView(
                          controller: _composerScroll,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _composerSurface(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
