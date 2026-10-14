import 'dart:async';

import 'attachment.dart';

class MediaCooldown {
  MediaCooldown(this.onReady);
  final void Function() onReady;
  DateTime? _until;
  Timer? _timer;
  bool get active => _until?.isAfter(DateTime.now()) == true;
  void failure(ChatMediaFailure failure) {
    if (failure.status != 429) return;
    final delay = failure.retryAfter ?? const Duration(seconds: 30);
    _until = DateTime.now().add(delay);
    _timer?.cancel();
    _timer = Timer(delay.isNegative ? Duration.zero : delay, onReady);
  }

  void dispose() {
    _timer?.cancel();
  }
}
