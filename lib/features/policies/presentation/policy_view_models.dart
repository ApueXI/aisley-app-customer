import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../data/policy_models.dart';
import '../data/policy_repository.dart';

export 'consent_view_model.dart';

class PolicyReaderViewModel extends ChangeNotifier {
  PolicyReaderViewModel(this.repository, this.type, this.version);
  final PolicyRepository repository;
  final PolicyType type;
  final int? version;
  PublicPolicy? policy;
  PolicyHistory? history;
  ApiFailure? failure, historyFailure;
  bool loading = false, historyLoading = false, _disposed = false;
  int _query = 0;

  Future<void> load() async {
    final query = ++_query;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = version == null
          ? await repository.current(type, refresh: true)
          : await repository.version(type, version!);
      if (!_disposed && query == _query) policy = result;
    } on ApiFailure catch (error) {
      if (!_disposed && query == _query) failure = error;
    } finally {
      if (!_disposed && query == _query) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadHistory() async {
    if (historyLoading) return;
    historyLoading = true;
    historyFailure = null;
    notifyListeners();
    try {
      final result = await repository.history(type);
      if (!_disposed) history = result;
    } on ApiFailure catch (error) {
      if (!_disposed) historyFailure = error;
    } finally {
      if (!_disposed) {
        historyLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _query++;
    super.dispose();
  }
}
