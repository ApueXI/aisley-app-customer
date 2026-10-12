import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'draft_controller.dart';
export 'private_image.dart';

class ChatImageComposer extends StatefulWidget {
  const ChatImageComposer({
    super.key,
    required this.controller,
    required this.contextValue,
    required this.enabled,
  });
  final ChatMediaDraftController controller;
  final Map<String, Object?> contextValue;
  final bool enabled;
  @override
  State<ChatImageComposer> createState() => _ChatImageComposerState();
}

class _ChatImageComposerState extends State<ChatImageComposer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.setForeground(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.controller.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed:
                widget.enabled &&
                    !c.locked &&
                    !c.selecting &&
                    c.items.length < 5
                ? () => c.add(widget.contextValue)
                : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(c.selecting ? 'Selecting image…' : 'Add image'),
          ),
          const Text(
            'JPEG, PNG or WebP at most 8 MB (8,000,000 bytes) each · Up to 5 images',
          ),
          if (c.error != null)
            Semantics(liveRegion: true, child: Text(c.error!)),
          for (final item in c.items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LocalChatImage(bytes: item.image.bytes),
                    Text(item.image.filename),
                    Text(switch (item.state) {
                      'pending' => 'Checking image…',
                      'ready' => 'Ready to send',
                      'uploading' => 'Uploading image…',
                      'uncertain' => 'Upload unconfirmed',
                      _ => item.state,
                    }),
                    if (item.busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Uploading or checking image',
                      ),
                    if (item.error != null)
                      Semantics(liveRegion: true, child: Text(item.error!)),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (item.state != 'ready' &&
                            item.state != 'rejected' &&
                            item.state != 'deleted')
                          TextButton(
                            onPressed: c.locked || item.busy
                                ? null
                                : () => c.retry(item),
                            child: const Text('Retry / check image'),
                          ),
                        TextButton(
                          onPressed: c.locked ? null : () => c.remove(item),
                          child: const Text('Remove image'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _LocalChatImage extends StatefulWidget {
  const _LocalChatImage({required this.bytes});
  final Uint8List bytes;
  @override
  State<_LocalChatImage> createState() => _LocalChatImageState();
}

class _LocalChatImageState extends State<_LocalChatImage> {
  late MemoryImage image = MemoryImage(widget.bytes);
  @override
  void didUpdateWidget(_LocalChatImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) {
      image.evict();
      image = MemoryImage(widget.bytes);
    }
  }

  @override
  void dispose() {
    image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: image,
    width: 72,
    height: 72,
    fit: BoxFit.contain,
    semanticLabel: 'Selected chat image',
    errorBuilder: (_, e, s) => const SizedBox(
      width: 72,
      height: 72,
      child: Icon(Icons.image_not_supported_outlined),
    ),
  );
}
