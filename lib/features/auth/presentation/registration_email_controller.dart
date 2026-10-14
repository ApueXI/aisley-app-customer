import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/registration_email.dart';
import '../../../core/networking/api_failure.dart';

class RegistrationEmailController extends ChangeNotifier {
  RegistrationEmailController(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (proof != null && !proof!.expiresAt.isAfter(this.clock())) {
        proof = null;
        challenge = null;
        message =
            'Email verification expired. Verify again to finish your form.';
      }
      notifyListeners();
    });
  }
  final RegistrationEmailRepository repository;
  final DateTime Function() clock;
  RegistrationEmailChallenge? challenge;
  RegistrationEmailProof? proof;
  String email = '', verifiedEmail = '';
  String? message;
  bool busy = false, failed = false, _disposed = false;
  DateTime? _retryAt;
  int _generation = 0;
  Timer? _timer;
  bool get verified => proof != null && proof!.expiresAt.isAfter(clock());
  bool get expired =>
      challenge != null && !challenge!.expiresAt.isAfter(clock());
  bool get coolingDown => _retryAt?.isAfter(clock()) == true;
  int get resendSeconds {
    var until = challenge?.resendAt ?? clock();
    if (_retryAt != null && _retryAt!.isAfter(until)) until = _retryAt!;
    return (until.difference(clock()).inMilliseconds / 1000).ceil().clamp(
      0,
      3600,
    );
  }

  void reset() {
    _generation++;
    busy = false;
    challenge = null;
    proof = null;
    message = null;
    failed = false;
    notifyListeners();
  }

  Future<bool> send(String value) async {
    if (busy || resendSeconds > 0) return false;
    final normalized = value.trim().toLowerCase();
    return _perform(() async {
      final result = await repository.requestRegistrationCode(normalized);
      return () {
        email = normalized;
        challenge = result;
        message = 'Check your inbox and spam folder for the latest code.';
      };
    });
  }

  Future<bool> verify(String code) async {
    if (busy ||
        coolingDown ||
        expired ||
        challenge == null ||
        !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return false;
    }
    final id = challenge!.id, target = email;
    return _perform(() async {
      final result = await repository.verifyRegistrationEmail(target, id, code);
      return () {
        proof = result;
        verifiedEmail = target;
        message = 'Email verified. Complete your registration.';
      };
    });
  }

  Future<bool> _perform(Future<void Function()> Function() operation) async {
    final generation = ++_generation;
    busy = true;
    failed = false;
    message = null;
    notifyListeners();
    try {
      final apply = await operation().timeout(const Duration(seconds: 20));
      if (_disposed || generation != _generation) return false;
      apply();
      return true;
    } on ApiFailure catch (error) {
      if (!_disposed && generation == _generation) {
        failed = true;
        message = error.fields.containsKey('verification_code')
            ? 'The code is incorrect, expired, or unavailable. Check the latest email or request a new code.'
            : error.description;
        if (error.status == 429) {
          _retryAt = error.retryAt ?? clock().add(const Duration(seconds: 1));
        }
        if (error.uncertain) {
          _retryAt = clock().add(const Duration(seconds: 60));
        }
      }
    } on FormatException {
      if (!_disposed && generation == _generation) {
        failed = true;
        message = 'Unexpected verification response. Wait one minute before retrying.';
        _retryAt = clock().add(const Duration(seconds: 60));
      }
    } on Exception {
      if (!_disposed && generation == _generation) {
        failed = true;
        message = 'The request could not be confirmed. Wait one minute before retrying; a code may have been sent.';
        _retryAt = clock().add(const Duration(seconds: 60));
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    challenge = null;
    proof = null;
    super.dispose();
  }
}
