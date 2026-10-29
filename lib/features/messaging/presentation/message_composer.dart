part of 'message_views.dart';

extension _MessageComposer on _MessageThreadViewState {
  bool get _canEdit => widget.allowed && !widget.pending && !widget.sending;
  bool get _canSend =>
      (widget.media == null || widget.media!.ready) &&
      _canEdit &&
      !widget.conflict &&
      !widget.loading &&
      !widget.coolingDown;

  Widget _composerSurface() => Container(
    padding: EdgeInsets.all(widget.compactComposer ? 8 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _composer(),
    ),
  );

  List<Widget> _composer() => [
    if (widget.pending) ...[
      const Text(
        'Your message is unconfirmed. Retry the original message to check whether it was sent.',
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
    if (widget.compactComposer)
      LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >= 290 * catalogTextScale(context);
          final actions = [
            if (widget.media != null) _imageAction(),
            if (inline) const SizedBox(width: 8),
            if (inline) Expanded(child: _messageInput()),
            if (inline) const SizedBox(width: 8),
            _sendButton(),
          ];
          return inline
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: actions,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _messageInput(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: actions,
                    ),
                  ],
                );
        },
      ),
    if (widget.media != null)
      ChatImageComposer(
        controller: widget.media!,
        contextValue: widget.mediaContext,
        enabled: _canEdit,
        showPicker: !widget.compactComposer,
        showGuidance: !widget.compactComposer || widget.media!.hasImages,
      ),
    if (!widget.compactComposer) ...[
      _messageInput(),
      const SizedBox(height: 12),
      _sendButton(),
    ],
  ];

  Widget _imageAction() {
    final media = widget.media!;
    return IconButton.outlined(
      tooltip: media.selecting
          ? 'Selecting image…'
          : 'Add image · JPEG or PNG, up to 8 MB each, up to 5 images',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed:
          _canEdit &&
              !media.locked &&
              !media.selecting &&
              !media.coolingDown &&
              media.items.length < 5
          ? () => media.add(widget.mediaContext)
          : null,
      icon: const Icon(Icons.add_photo_alternate_outlined),
    );
  }

  Widget _messageInput() => Form(
    key: _form,
    child: TextFormField(
      controller: _text,
      focusNode: _focus,
      enabled: _canEdit,
      minLines: widget.compactComposer ? 1 : 2,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: 'Message',
        hintText: widget.compactComposer ? 'Write a message…' : null,
        helperText: widget.compactComposer
            ? null
            : 'Plain text, up to 2,000 characters',
        errorText: widget.fieldError,
      ),
      validator: (v) =>
          (v ?? '').trim().isEmpty && widget.media?.hasImages == true
          ? null
          : plainTextError(v, 2000),
      onChanged: _draftChanged,
    ),
  );

  Widget _sendButton() => FilledButton(
    style: widget.compactComposer
        ? FilledButton.styleFrom(
            minimumSize: const Size(72, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          )
        : null,
    onPressed: !_canSend
        ? null
        : () {
            if (validateForm(_form.currentState!)) widget.send();
          },
    child: Text(
      widget.sending
          ? 'Sending…'
          : widget.compactComposer
          ? 'Send'
          : 'Send message',
    ),
  );
}
