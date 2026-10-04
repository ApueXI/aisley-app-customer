import 'package:flutter/foundation.dart';

import '../../../core/networking/api_failure.dart';
import '../../../core/networking/request_cooldown.dart';
import '../../../core/commerce/commerce_controller.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/communication/text_rules.dart';
import '../data/question_repository.dart';
import '../data/question_models.dart';

class QuestionListController extends ChangeNotifier with RequestCooldown {
  QuestionListController(this.repository, this.product);
  final QuestionRepository repository;
  final String product;
  List<ProductQuestion> items = const [];
  bool loading = false, paging = false, loaded = false, hasMore = false;
  String? error, pageError;
  int page = 0, generation = 0;
  bool disposed = false;
  Future<void> load({bool more = false}) async {
    if (loading || paging || coolingDown || more && !hasMore) return;
    final stamp = generation;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      error = null;
    }
    notifyListeners();
    try {
      final value = await repository.list(product, more ? page + 1 : 1);
      if (disposed || generation != stamp) return;
      if (value.page != (more ? page + 1 : 1)) {
        throw const ApiFailure(FailureKind.decode);
      }
      final old = items.map((e) => e.id).toSet();
      items = List.unmodifiable(
        {
          if (more)
            for (final e in items) e.id: e,
          for (final e in value.items) e.id: e,
        }.values,
      );
      hasMore =
          value.hasMore &&
          (!more || value.items.any((e) => !old.contains(e.id)));
      page = value.page;
      loaded = true;
    } on ApiFailure catch (e) {
      if (disposed || generation != stamp) return;
      if (more) {
        pageError = describeFailure(e);
      } else {
        error = describeFailure(e);
      }
      if (e.status == 403 || e.status == 404) {
        items = const [];
        hasMore = loaded = false;
      }
    } finally {
      if (!disposed && generation == stamp) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    super.dispose();
  }
}

class AskQuestionController extends CommerceController {
  AskQuestionController(
    super.session,
    this.repository,
    this.product, {
    String Function()? uuid,
  }) : uuid = uuid ?? secureUuid;
  final QuestionRepository repository;
  final String product;
  final String Function() uuid;
  String draft = '';
  ({String text, String key})? pending;
  ProductQuestion? committed;
  bool busy = false, conflict = false, uncertain = false;
  Future<void> submit({bool retry = false}) async {
    final credential = lease;
    if (credential == null ||
        busy ||
        coolingDown ||
        conflict ||
        pending != null && !retry) {
      return;
    }
    final invalid = plainTextError(draft, 1000);
    if (pending == null && invalid != null) {
      error = invalid;
      notifyListeners();
      return;
    }
    committed = null;
    pending ??= (text: normalizedText(draft), key: uuid());
    final record = pending!, stamp = epoch;
    busy = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.ask(
        credential,
        product,
        record.text,
        record.key,
      );
      if (!current(stamp, credential)) return;
      committed = value;
      uncertain = false;
      pending = null;
      draft = '';
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      failure(e);
      if (e.status == 409) conflict = true;
      if (e.uncertain) uncertain = true;
      if (e.status == 422 &&
          !uncertain &&
          !e.fields.containsKey('idempotency_key')) {
        pending = null;
      }
      if (e.status == 403 || e.status == 404) reset(preserveUnresolved: false);
    } finally {
      if (current(stamp, credential)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    if (preserveUnresolved && busy && pending != null) uncertain = true;
    draft = '';
    committed = null;
    busy = false;
    if (!preserveUnresolved) {
      pending = null;
      conflict = uncertain = false;
    }
  }
}
