part of 'message_views.dart';

extension _MessageComposer on _MessageThreadViewState {
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
    if (widget.media != null)
      ChatImageComposer(
        controller: widget.media!,
        contextValue: widget.mediaContext,
        enabled: widget.allowed && !widget.pending && !widget.sending,
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
        validator: (v) =>
            (v ?? '').trim().isEmpty && widget.media?.hasImages == true
            ? null
            : plainTextError(v, 2000),
        onChanged: _draftChanged,
      ),
    ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed:
          (widget.media != null && !widget.media!.ready) ||
              !widget.allowed ||
              widget.pending ||
              widget.conflict ||
              widget.sending ||
              widget.loading ||
              widget.coolingDown
          ? null
          : () {
              if (validateForm(_form.currentState!)) {
                widget.send();
              }
            },
      child: Text(widget.sending ? 'Sending…' : 'Send message'),
    ),
  ];
}
