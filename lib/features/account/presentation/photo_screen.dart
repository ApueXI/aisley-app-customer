import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../data/photo_picker_adapter.dart';
import '../data/photo_validation.dart';
import 'account_controllers.dart';

class PhotoScreen extends StatelessWidget {
  const PhotoScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Profile photo',
    children: [ProfilePhotoSection(dependencies: dependencies)],
  );
}

/// Profile photo state is independent of the editable profile form.
class ProfilePhotoSection extends StatefulWidget {
  const ProfilePhotoSection({
    super.key,
    required this.dependencies,
    this.onStateChanged,
  });
  final AppDependencies dependencies;
  final void Function({required bool dirty, required bool busy})?
  onStateChanged;

  @override
  State<ProfilePhotoSection> createState() => _ProfilePhotoSectionState();
}

class _ProfilePhotoSectionState extends State<ProfilePhotoSection> {
  late final PhotoController _controller = widget.dependencies.profilePhoto;
  PickedBuyerImage? _selected;
  String? _pickerNotice;
  late int _generation;
  bool _reportedDirty = false, _reportedBusy = false;
  bool _selecting = false, _confirming = false;
  int _selectionOperation = 0;
  bool get _busy => _controller.busy || _selecting || _confirming;
  bool get _exitBusy =>
      _controller.uploading ||
      _controller.removing ||
      _selecting ||
      _confirming;

  @override
  void initState() {
    super.initState();
    _generation = widget.dependencies.session.generation;
    widget.dependencies.session.addListener(_sessionChanged);
    widget.dependencies.session.registerPrivateCleanup(_clearDraft);
    _controller.addListener(_controllerChanged);
    _controller.load();
    _checkInterruptedSelection();
    _reportStateAfterFrame();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onStateChanged != widget.onStateChanged) {
      _reportStateAfterFrame();
    }
  }

  @override
  void dispose() {
    widget.dependencies.session.removeListener(_sessionChanged);
    widget.dependencies.session.unregisterPrivateCleanup(_clearDraft);
    _controller.removeListener(_controllerChanged);
    _selected = null;
    _selectionOperation++;
    super.dispose();
  }

  void _clearDraft() {
    _selectionOperation++;
    _selecting = _confirming = false;
    _selected = null;
    _pickerNotice = null;
    if (mounted) setState(() {});
    _reportStateAfterFrame();
  }

  void _sessionChanged() {
    final current = widget.dependencies.session.generation;
    if (current != _generation) {
      _generation = current;
      _selected = null;
      if (mounted) setState(() => _pickerNotice = null);
      _reportStateAfterFrame();
    }
  }

  void _controllerChanged() {
    if (_controller.selectionConsumed &&
        (_controller.uploading || _controller.requiresReconciliation)) {
      _selected = null;
    }
    if (mounted) setState(() {});
    _reportStateAfterFrame();
  }

  void _reportStateAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dirty = _selected != null;
      final busy = _exitBusy;
      if (dirty == _reportedDirty && busy == _reportedBusy) return;
      _reportedDirty = dirty;
      _reportedBusy = busy;
      widget.onStateChanged?.call(dirty: dirty, busy: busy);
    });
  }

  Future<void> _checkInterruptedSelection() async {
    final generation = _controller.featureGeneration;
    final recovery = await widget.dependencies.photoPicker
        ?.recoverInterruptedSelection();
    if (!mounted ||
        generation != _controller.featureGeneration ||
        !widget.dependencies.session.active) {
      return;
    }
    if (recovery == PickerRecovery.interrupted ||
        recovery == PickerRecovery.failed) {
      setState(
        () => _pickerNotice = recovery == PickerRecovery.interrupted
            ? 'A photo selection was interrupted. Pick it again to continue.'
            : 'The interrupted selection could not be recovered. Choose your photo again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Photos must be JPEG, PNG or WebP and smaller than 10 MiB.'),
        if (widget.dependencies.photoPicker == null)
          const Text(
            'Profile photo selection is unavailable on this platform.',
          ),
        if (_pickerNotice != null)
          Semantics(liveRegion: true, child: Text(_pickerNotice!)),
        if (_controller.error != null)
          Semantics(liveRegion: true, child: Text(_controller.error!)),
        if (_controller.loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading private profile photo',
          ),
        if (_controller.error != null || _controller.requiresReconciliation)
          OutlinedButton(
            onPressed: _busy || _controller.coolingDown
                ? null
                : _controller.load,
            child: const Text('Refresh current photo'),
          ),
        if (_controller.fieldErrors['photo'] != null)
          Text(_controller.fieldErrors['photo']!),
        Center(
          child: Semantics(
            button: _controller.bytes != null,
            label: _selected != null
                ? 'Selected profile photo preview'
                : 'Current profile photo',
            child: GestureDetector(
              onTap: _controller.bytes == null && _selected == null
                  ? null
                  : _viewPhoto,
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
        if (_controller.uploading)
          TextButton(
            onPressed: _controller.cancelUpload,
            child: const Text('Cancel upload'),
          ),
        if (_selected != null)
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _selected = null;
                      _pickerNotice = null;
                    });
                    _reportStateAfterFrame();
                  },
            child: const Text('Remove selection'),
          ),
        if (_selecting)
          const LinearProgressIndicator(
            semanticsLabel: 'Reading selected photo',
          ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed:
                widget.dependencies.photoPicker == null ||
                    _busy ||
                    _controller.coolingDown ||
                    _controller.requiresReconciliation
                ? null
                : _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose a photo'),
          ),
        ),
        if (_selected != null)
          FilledButton.icon(
            onPressed:
                _busy ||
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
                _busy ||
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

  Future<void> _viewPhoto() async {
    if (_selected == null && _controller.bytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _controller,
            widget.dependencies.session,
          ]),
          builder: (context, _) {
            final bytes = widget.dependencies.session.active
                ? _selected?.bytes ?? _controller.bytes
                : null;
            return bytes == null
                ? const Text('Photo unavailable')
                : InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  );
          },
        ),
      ),
    );
  }

  Future<void> _pick() async {
    final picker = widget.dependencies.photoPicker;
    if (picker == null || _busy || _controller.requiresReconciliation) return;
    final generation = _controller.featureGeneration,
        operation = ++_selectionOperation;
    setState(() {
      _selecting = true;
      _pickerNotice = null;
    });
    _reportStateAfterFrame();
    bool current() =>
        mounted &&
        operation == _selectionOperation &&
        generation == _controller.featureGeneration &&
        widget.dependencies.session.active;
    try {
      final image = await picker.pick();
      if (!current() || image == null) return;
      setState(() {
        _selected = image;
      });
    } on BuyerImageValidationException catch (e) {
      if (current()) setState(() => _pickerNotice = e.message);
    } catch (_) {
      if (current()) {
        setState(
          () => _pickerNotice = 'The photo could not be read. Check photo access and choose another JPEG, PNG or WebP.',
        );
      }
    } finally {
      if (current()) {
        setState(() => _selecting = false);
        _reportStateAfterFrame();
      }
    }
  }

  Future<void> _upload() async {
    final image = _selected;
    if (image == null || _busy) return;
    final generation = _controller.featureGeneration;
    setState(() => _confirming = true);
    _reportStateAfterFrame();
    final confirmed = await confirmAction(
      context,
      title: 'Upload this photo?',
      message: 'The new image will replace your current profile photo.',
      action: 'Upload',
    );
    if (!mounted || generation != _controller.featureGeneration) return;
    setState(() => _confirming = false);
    _reportStateAfterFrame();
    if (confirmed != true ||
        !identical(image, _selected) ||
        !widget.dependencies.session.active) {
      return;
    }
    final ok = await _controller.upload(
      data: image.bytes,
      filename: image.filename,
      mimeType: image.mimeType,
    );
    if (!mounted || generation != _controller.featureGeneration) return;
    if (ok || _controller.selectionConsumed) {
      setState(() => _selected = null);
      _reportStateAfterFrame();
    }
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    final generation = _controller.featureGeneration;
    setState(() => _confirming = true);
    _reportStateAfterFrame();
    final confirmed = await confirmAction(
      context,
      title: 'Remove profile photo?',
      message: 'Remove your current profile photo?',
      action: 'Remove',
    );
    if (!mounted || generation != _controller.featureGeneration) return;
    setState(() => _confirming = false);
    _reportStateAfterFrame();
    if (!confirmed || !widget.dependencies.session.active) return;
    final ok = await _controller.remove();
    if (!mounted || !ok) return;
    setState(() => _selected = null);
    _reportStateAfterFrame();
  }
}
