import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'attachment.dart';
import 'image_validation.dart';

class ChatImageDraft {
  ChatImageDraft(this.image, this.context, this.key);
  final SelectedChatImage image;
  final Map<String, Object?> context;
  final String key;
  ChatAttachment? attachment;
  String state = 'uploading';
  String? error;
  bool busy = false;
  int checks = 0;
  DateTime? retryAt;
}

/// In-memory uploads belong to one conversation draft, never a disk/offline queue.
class ChatMediaDraftController extends ChangeNotifier {
  ChatMediaDraftController(this.repository);
  final ChatMediaRepository repository;
  final List<ChatImageDraft> items = [];
  String? error;
  bool selecting = false, locked = false, _disposed = false, _foreground = true;
  int generation = 0, privateGeneration = 0;
  Timer? _timer;
  Timer? _cooldownTimer;
  DateTime? retryAt;
  bool get coolingDown => retryAt?.isAfter(DateTime.now()) == true;
  bool get ready =>
      !selecting && items.every((e) => !e.busy && e.state == 'ready');
  List<String> get ids => List.unmodifiable(items.map((e) => e.attachment!.id));
  bool get hasImages => items.isNotEmpty;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int stamp) => !_disposed && stamp == generation;

  Future<void> add(Map<String, Object?> context) async {
    if (locked || selecting || coolingDown || items.length >= 5) return;
    final stamp = generation;
    selecting = true;
    error = null;
    _notify();
    try {
      if (!await repository.capabilities()) {
        if (_current(stamp)) {
          error = 'Image uploads are unavailable. You can still send text.';
        }
        return;
      }
      if (!_current(stamp) || locked) return;
      final image = await repository.pick();
      if (!_current(stamp) || locked || image == null) return;
      if (!validChatImage(image.bytes, image.filename, image.mimeType)) {
        error = 'Choose JPEG or PNG at most 8 MB (8,000,000 bytes), up to 4,096 pixels per edge and 8 megapixels, with one filename extension.';
        return;
      }
      final item = ChatImageDraft(image, Map.unmodifiable(context), _uuid());
      items.add(item);
      await upload(item);
    } on ChatMediaFailure catch (e) {
      if (_current(stamp)) {
        error = e.message;
        if (e.status == 429) {
          retryAt = DateTime.now().add(
            e.retryAfter ?? const Duration(seconds: 30),
          );
          _cooldownTimer?.cancel();
          _cooldownTimer = Timer(
            e.retryAfter ?? const Duration(seconds: 30),
            _notify,
          );
        }
      }
    } catch (_) {
      if (_current(stamp)) {
        error = 'The image could not be selected. Please try again.';
      }
    } finally {
      if (_current(stamp)) {
        selecting = false;
        _notify();
      }
    }
  }

  Future<void> upload(ChatImageDraft item) => _operation(
    item,
    () => repository.upload(item.image, item.context, item.key),
  );
  Future<void> check(ChatImageDraft item) =>
      _operation(item, () => repository.status(item.attachment!.id));
  Future<void> retry(ChatImageDraft item) => item.attachment == null
      ? upload(item)
      : item.state == 'failed'
      ? _operation(item, () => repository.retry(item.attachment!.id))
      : check(item);

  Future<void> _operation(
    ChatImageDraft item,
    Future<ChatAttachment> Function() action,
  ) async {
    if (_disposed ||
        locked ||
        item.busy ||
        item.state == 'rejected' ||
        item.state == 'deleted' ||
        !items.contains(item) ||
        (item.retryAt != null && DateTime.now().isBefore(item.retryAt!))) {
      return;
    }
    final stamp = generation;
    item.busy = true;
    item.error = null;
    _notify();
    try {
      final value = await action();
      if (!_current(stamp) || !items.contains(item)) return;
      if (value.kind != 'image' ||
          (item.attachment != null && value.id != item.attachment!.id)) {
        throw const ChatMediaFailure(
          'The image response was not understood. Retry the original upload.',
        );
      }
      item.attachment = value;
      item.state = value.state;
      item.error = switch (value.state) {
        'rejected' => 'This image was rejected. Remove it and choose another.',
        'failed' => 'Image processing failed. Retry processing or remove it.',
        'deleted' => 'This upload expired. Remove it and choose another.',
        _ => null,
      };
    } on ChatMediaFailure catch (e) {
      if (!_current(stamp)) return;
      item.error = e.message;
      if (e.status == 429) {
        item.retryAt = DateTime.now().add(
          e.retryAfter ?? const Duration(seconds: 30),
        );
      }
      if (e.status == 422) {
        item.state = 'rejected';
        item.error = 'This image was rejected. Remove it and choose another.';
      } else if (item.attachment == null) {
        item.state = 'uncertain';
      }
    } catch (_) {
      if (_current(stamp)) {
        item.error = 'Image upload unconfirmed. Retry the original request.';
        if (item.attachment == null) item.state = 'uncertain';
      }
    } finally {
      if (_current(stamp)) {
        item.busy = false;
        _schedule();
        _notify();
      }
    }
  }

  Future<void> remove(ChatImageDraft item) async {
    if (locked || !items.contains(item)) return;
    items.remove(item);
    _notify();
    // Removal is explicit; an unknown/unbound upload can expire server-side.
    final id = item.attachment?.id;
    if (id != null) {
      try {
        await repository.remove(id);
      } catch (_) {}
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _timer?.cancel();
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_foreground || locked || _disposed) return;
    final pending = items
        .where(
          (e) =>
              e.state == 'pending' &&
              !e.busy &&
              e.error == null &&
              e.checks < 20,
        )
        .toList();
    if (pending.isEmpty) {
      return;
    }
    final checks = pending.map((e) => e.checks).reduce(max);
    _timer = Timer(Duration(seconds: min(30, 2 << min(checks, 4))), () async {
      for (final item in pending) {
        if (!_foreground || locked || _disposed) {
          break;
        }
        item.checks++;
        await check(item);
      }
    });
  }

  void clear({bool preserveHistory = false}) {
    generation++;
    if (!preserveHistory) privateGeneration++;
    _cooldownTimer?.cancel();
    retryAt = null;
    _timer?.cancel();
    items.clear();
    selecting = false;
    locked = false;
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    privateGeneration++;
    _cooldownTimer?.cancel();
    retryAt = null;
    _timer?.cancel();
    items.clear();
    super.dispose();
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
