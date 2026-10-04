import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../data/photo_picker_adapter.dart';
import 'account_controllers.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late final PhotoController _controller = PhotoController(
    widget.dependencies.session,
    widget.dependencies.accounts!,
  );
  PickedBuyerImage? _selected;
  String? _pickerNotice;
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = widget.dependencies.session.generation;
    widget.dependencies.session.addListener(_sessionChanged);
    widget.dependencies.session.registerPrivateCleanup(_clearDraft);
    _controller.load(widget.dependencies.session.customer?.avatarUrl);
    _checkInterruptedSelection();
  }

  @override
  void dispose() {
    widget.dependencies.session.removeListener(_sessionChanged);
    widget.dependencies.session.unregisterPrivateCleanup(_clearDraft);
    _selected = null;
    _controller.dispose();
    super.dispose();
  }

  void _clearDraft() {
    _selected = null;
    _pickerNotice = null;
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    final current = widget.dependencies.session.generation;
    if (current != _generation) {
      _generation = current;
      _selected = null;
      if (mounted) setState(() => _pickerNotice = null);
    }
  }

  Future<void> _checkInterruptedSelection() async {
    final lost = await widget.dependencies.photoPicker!
        .hasInterruptedSelection();
    if (lost && mounted) {
      setState(() {
        _pickerNotice =
            'A photo selection was interrupted. Pick it again to continue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => FormPage(
      title: 'Profile photo',
      dirty: _selected != null,
      busy: _controller.uploading || _controller.removing,
      children: [
        const Text('Photos must be JPEG, PNG or WebP and smaller than 10 MiB.'),
        if (_pickerNotice != null)
          Semantics(liveRegion: true, child: Text(_pickerNotice!)),
        if (_controller.error != null)
          Semantics(liveRegion: true, child: Text(_controller.error!)),
        if (_controller.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading private profile photo',
          ),
        if (_controller.requiresReconciliation)
          OutlinedButton(
            onPressed: _controller.load,
            child: const Text('Refresh current photo'),
          ),
        if (_controller.fieldErrors['photo'] != null)
          Text(_controller.fieldErrors['photo']!),
        Center(
          child: ClipOval(
            child: SizedBox.square(
              dimension: 168,
              child: _selected != null
                  ? Image.memory(
                      _selected!.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Photo preview unavailable'),
                      ),
                    )
                  : _controller.bytes != null
                  ? Image.memory(
                      _controller.bytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
        ),
        if (_selected != null)
          Text(
            '${_selected!.filename} · ${_selected!.bytes.lengthInBytes} bytes',
          ),
        if (_controller.uploading)
          Column(
            children: [
              LinearProgressIndicator(value: _controller.progress),
              Text(
                _controller.progress == null
                    ? 'Uploading…'
                    : _controller.progress! >= 1
                    ? 'Upload sent. Waiting for confirmation…'
                    : 'Uploading ${(_controller.progress! * 100).round()}%',
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed:
              _controller.uploading ||
                  _controller.coolingDown ||
                  _controller.requiresReconciliation
              ? null
              : _pick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose a photo'),
        ),
        if (_selected != null)
          FilledButton.icon(
            onPressed:
                _controller.uploading ||
                    _controller.coolingDown ||
                    _controller.requiresReconciliation
                ? null
                : _upload,
            icon: const Icon(Icons.upload_outlined),
            label: Text(
              _controller.uploading ? 'Uploading…' : 'Upload selected photo',
            ),
          ),
        if (_controller.bytes != null || _controller.photoUrl != null)
          OutlinedButton.icon(
            onPressed:
                _controller.removing ||
                    _controller.coolingDown ||
                    _controller.requiresReconciliation
                ? null
                : _remove,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              _controller.removing ? 'Removing…' : 'Remove profile photo',
            ),
          ),
      ],
    ),
  );

  Widget _placeholder() => const ColoredBox(
    color: Color(0xFFF4F0F3),
    child: Icon(
      Icons.person_outline,
      size: 76,
      semanticLabel: 'No profile photo',
    ),
  );

  Future<void> _pick() async {
    final generation = _controller.featureGeneration;
    try {
      final image = await widget.dependencies.photoPicker!.pick();
      if (!mounted ||
          image == null ||
          generation != _controller.featureGeneration ||
          !widget.dependencies.session.active) {
        return;
      }
      if (image.bytes.isEmpty || image.bytes.lengthInBytes >= 10485760) {
        setState(() => _pickerNotice = 'Choose a photo smaller than 10 MiB.');
        return;
      }
      setState(() {
        _selected = image;
        _pickerNotice = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _pickerNotice =
              'The photo picker is unavailable. You can try again.',
        );
      }
    }
  }

  Future<void> _upload() async {
    final image = _selected;
    if (image == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload this photo?'),
        content: const Text(
          'The new image will replace your current profile photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _controller.upload(
      data: image.bytes,
      filename: image.filename,
      mimeType: image.mimeType,
    );
    if (!mounted) return;
    if (ok) {
      _selected = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      setState(() {});
    }
  }

  Future<void> _remove() async {
    if (!await confirmAction(
          context,
          title: 'Remove profile photo?',
          message: 'Remove your current profile photo?',
          action: 'Remove',
        ) ||
        !mounted) {
      return;
    }
    final ok = await _controller.remove();
    if (!mounted || !ok) return;
    setState(() => _selected = null);
  }
}
