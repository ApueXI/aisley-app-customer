import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/form_page.dart';
import '../../../core/communication/text_rules.dart';

export 'inbox_view.dart';

class MessageRow {
  const MessageRow(
    this.id,
    this.sequence,
    this.body,
    this.mine,
    this.label,
    this.at, {
    this.context,
  });
  final String id, body, label;
  final int sequence;
  final bool mine;
  final DateTime? at;
  final String? context;
}

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
  });
  final String title, draft;
  final List<MessageRow> rows;
  final bool loading,
      paging,
      sending,
      allowed,
      pending,
      conflict,
      more,
      coolingDown;
  final int arrivals;
  final Widget? contextAction;
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
  late final _text = TextEditingController(text: widget.draft);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _rows = <String, GlobalKey>{};
  final _form = GlobalKey<FormState>();
  bool _allowPop = false, _confirming = false;
  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (addedOlder && _scroll.hasClients) {
        _scroll.jumpTo(
          (_scroll.offset + _scroll.position.maxScrollExtent - oldHeight).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
      _displayed();
    });
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
    final height =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    for (final row in widget.rows) {
      final box = _rows[row.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final y = box.localToGlobal(Offset.zero).dy;
        if (y >= 80 &&
            y + box.size.height <= height &&
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
    if (_text.text.isNotEmpty || widget.sending) {
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
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || _text.text.isEmpty && !widget.sending,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.subtitle != null) Text(widget.subtitle!),
            if (widget.contextAction != null) widget.contextAction!,
            if (widget.loading || widget.sending)
              const LinearProgressIndicator(
                semanticsLabel: 'Updating conversation',
              ),
            if (widget.error != null)
              Semantics(liveRegion: true, child: Text(widget.error!)),
            if (widget.arrivals > 0)
              TextButton(
                onPressed: _viewArrivals,
                child: Text('${widget.arrivals} new messages · View'),
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
                child: Text(widget.paging ? 'Loading…' : 'Load older messages'),
              ),
            if (widget.pageError != null) Text(widget.pageError!),
            if (widget.rows.isEmpty && !widget.loading && widget.error == null)
              const Text('Your first sent message starts the conversation.'),
            for (final row in widget.rows)
              Padding(
                key: _rows.putIfAbsent(row.id, () => GlobalKey()),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.mine ? 'You' : row.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SelectableText(row.body),
                    if (row.context != null) Text(row.context!),
                    if (row.at != null)
                      Text(
                        row.at!.toLocal().toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            if (widget.readError != null) ...[
              Text(widget.readError!),
              TextButton(
                onPressed: widget.coolingDown || widget.rows.isEmpty
                    ? null
                    : () => _displayed(retry: true),
                child: const Text('Retry read marker'),
              ),
            ],
            if (!widget.allowed)
              Text(
                'Read only. ${widget.reason ?? 'Sending is currently unavailable.'}',
              ),
            if (widget.pending) ...[
              const Text(
                'A send is unresolved. The original text and key are kept for exact retry.',
              ),
              TextButton(
                onPressed:
                    widget.sending ||
                        widget.loading ||
                        widget.coolingDown ||
                        widget.conflict
                    ? null
                    : widget.retry,
                child: const Text('Retry exact message'),
              ),
            ],
            if (widget.conflict)
              TextButton(
                onPressed: widget.loading || widget.sending || !widget.allowed
                    ? null
                    : () async {
                        if (await confirmAction(
                          context,
                          title: 'Review changed conversation',
                          message: 'The previous request was rejected. Review current permissions and send the draft as a new attempt?',
                          action: 'Review draft',
                        )) {
                          widget.reviewConflict();
                        }
                      },
                child: const Text('Review conflict'),
              ),
            Form(
              key: _form,
              child: TextFormField(
                controller: _text,
                focusNode: _focus,
                enabled: widget.allowed && !widget.pending && !widget.sending,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  helperText: 'Plain text, up to 2,000 characters',
                  errorText: widget.fieldError,
                ),
                validator: (v) => plainTextError(v, 2000),
                onChanged: (v) {
                  widget.changed(v);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  !widget.allowed ||
                      widget.pending ||
                      widget.conflict ||
                      widget.sending ||
                      widget.loading ||
                      widget.coolingDown
                  ? null
                  : () {
                      if (validateForm(_form.currentState!)) widget.send();
                    },
              child: Text(widget.sending ? 'Sending…' : 'Send message'),
            ),
            TextButton(
              onPressed: widget.loading || widget.sending || widget.coolingDown
                  ? null
                  : widget.refresh,
              child: const Text('Retry / refresh'),
            ),
          ],
        ),
      ),
    ),
  );
}
