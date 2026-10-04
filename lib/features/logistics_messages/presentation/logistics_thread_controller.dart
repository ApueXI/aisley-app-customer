import '../../../core/commerce/commerce_controller.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/communication/text_rules.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
import '../data/logistics_models.dart';
import '../data/logistics_repository.dart';

class LogisticsPendingMessage {
  LogisticsPendingMessage(this.id, Map<String, dynamic> body, this.key)
    : body = Map.unmodifiable(body);
  final String? id;
  final Map<String, dynamic> body;
  final String key;
  bool uncertain = false;
}

class LogisticsThreadController extends CommerceController {
  LogisticsThreadController(
    super.session,
    this.repository, {
    this.id,
    this.entry = const {},
    String Function()? uuid,
  }) : uuid = uuid ?? secureUuid;
  final LogisticsChatRepository repository;
  final String Function() uuid;
  String? id;
  final Map<String, dynamic> entry;
  LogisticsConversation? conversation;
  List<LogisticsMessage> messages = const [];
  final trail = CursorTrail();
  LogisticsPendingMessage? pending;
  String draft = '';
  bool unavailable = false;
  String? pageError, readError;
  bool loading = false,
      paging = false,
      sending = false,
      offline = false,
      conflict = false;
  int arrivals = 0, _readWanted = 0, _readSent = 0;
  bool _reading = false;
  bool get canSend =>
      !unavailable && (conversation?.sendAllowed ?? entry.isNotEmpty);
  bool get canCheckNewHandler =>
      entry.isNotEmpty && pending == null && conversation?.sendAllowed == false;
  void checkNewHandler() {
    if (!canCheckNewHandler || loading || sending) return;
    id = null;
    reset(preserveUnresolved: false);
    notifyListeners();
  }

  Future<void> load({bool more = false}) async {
    final credential = lease;
    final cursor = more ? trail.next : null;
    if (credential == null ||
        loading ||
        paging ||
        sending ||
        _reading ||
        coolingDown ||
        more && cursor == null) {
      return;
    }
    final stamp = epoch;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      error = null;
      offline = false;
    }
    notifyListeners();
    try {
      final target = id;
      if (target == null) return;
      final summary = await repository.detail(credential, target);
      if (!current(stamp, credential)) return;
      final page = await repository.history(credential, target, cursor);
      if (!current(stamp, credential)) return;
      unavailable = false;
      conversation = summary;
      final prior = messages.map((e) => e.id).toSet();
      final oldMax = messages.isEmpty ? 0 : messages.last.sequence;
      final gap =
          messages.isNotEmpty &&
          page.items.isNotEmpty &&
          page.items.first.sequence > oldMax + 1;
      _merge(page.items);
      if (more) {
        trail.advance(
          cursor!,
          page.next,
          progressed: page.items.any((e) => !prior.contains(e.id)),
        );
      } else {
        trail.seed(page.next, gap: gap);
        arrivals += page.items
            .where(
              (e) =>
                  !e.mine &&
                  !prior.contains(e.id) &&
                  e.sequence > oldMax &&
                  oldMax > 0,
            )
            .length;
      }
      if (summary.lastRead > _readSent) _readSent = summary.lastRead;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      offline = e.kind == FailureKind.offline || e.kind == FailureKind.timeout;
      if (more) {
        pageError = describeFailure(e);
      } else {
        failure(e);
      }
      if (e.status == 403 || e.status == 404) {
        reset(preserveUnresolved: false);
        unavailable = true;
      }
    } finally {
      if (current(stamp, credential)) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  void _merge(List<LogisticsMessage> incoming) {
    final merged = {
      for (final e in messages) e.id: e,
      for (final e in incoming) e.id: e,
    };
    final bySequence = {
      for (final e in merged.values) e.sequence: e,
      for (final e in incoming) e.sequence: e,
    }.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
    messages = List.unmodifiable(bySequence);
  }

  Future<void> send() async {
    if (pending != null ||
        !canSend ||
        conflict ||
        sending ||
        loading ||
        paging ||
        _reading ||
        coolingDown ||
        lease == null) {
      return;
    }
    final value = normalizedText(draft);
    final invalid = plainTextError(value, 2000);
    if (invalid != null) {
      error = invalid;
      notifyListeners();
      return;
    }
    pending = LogisticsPendingMessage(id, {
      if (id == null) ...entry,
      'body': value,
    }, uuid());
    await retry();
  }

  Future<void> retry() async {
    final credential = lease, record = pending;
    if (credential == null ||
        record == null ||
        sending ||
        loading ||
        paging ||
        _reading ||
        coolingDown ||
        conflict) {
      return;
    }
    final stamp = epoch;
    sending = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      final value = await repository.write(
        credential,
        record.id,
        record.body,
        record.key,
      );
      if (!current(stamp, credential)) return;
      if (record.id != null && value.$1.id != record.id ||
          value.$2.conversationId != value.$1.id) {
        throw const ApiFailure(FailureKind.decode);
      }
      id = value.$1.id;
      conversation = value.$1;
      _merge([value.$2]);
      pending = null;
      draft = '';
      conflict = false;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      failure(e);
      if (e.uncertain) record.uncertain = true;
      if (e.status == 409) conflict = true;
      if (e.status == 422 &&
          !record.uncertain &&
          !e.fields.containsKey('idempotency_key')) {
        pending = null;
      }
      if (e.status == 403 || e.status == 404) {
        reset(preserveUnresolved: false);
        unavailable = true;
      }
    } finally {
      if (current(stamp, credential)) {
        sending = false;
        notifyListeners();
      }
    }
    if (conflict) await load();
  }

  // A definitive conflict can be reviewed and abandoned. Uncertain writes remain frozen.
  void reviewConflict() {
    if (!conflict ||
        pending?.uncertain == true ||
        loading ||
        sending ||
        conversation?.sendAllowed != true) {
      return;
    }
    draft = pending?.body['body'] as String? ?? draft;
    pending = null;
    conflict = false;
    error = null;
    notifyListeners();
  }

  Future<void> displayed(int sequence) async {
    final credential = lease;
    if (credential == null ||
        id == null ||
        sequence < 1 ||
        !messages.any((e) => e.sequence == sequence) ||
        coolingDown) {
      return;
    }
    if (sequence > _readWanted) _readWanted = sequence;
    if (sequence <= _readSent || _reading || loading || paging || sending) {
      return;
    }
    _reading = true;
    final stamp = epoch;
    try {
      while (current(stamp, credential) && _readWanted > _readSent) {
        final target = _readWanted;
        final value = await repository.read(credential, id!, target);
        if (!current(stamp, credential)) return;
        _readSent = target;
        readError = null;
        if (conversation == null ||
            value.lastSequence >= conversation!.lastSequence) {
          conversation = value;
        }
      }
    } on ApiFailure catch (e) {
      if (current(stamp, credential)) {
        readError = describeFailure(e);
        if (e.status == 403 || e.status == 404) {
          reset(preserveUnresolved: false);
          unavailable = true;
        }
      }
    } finally {
      if (current(stamp, credential)) {
        _reading = false;
        notifyListeners();
      }
    }
  }

  void acknowledgeArrivals() {
    arrivals = 0;
    notifyListeners();
  }

  @override
  void reset({required bool preserveUnresolved}) {
    if (preserveUnresolved && sending && pending != null) {
      pending!.uncertain = true;
    }
    conversation = null;
    messages = const [];
    trail.clear();
    draft = '';
    unavailable = false;
    pageError = readError = null;
    loading = paging = sending = offline = _reading = false;
    arrivals = _readWanted = _readSent = 0;
    if (!preserveUnresolved) {
      pending = null;
      conflict = false;
    }
  }
}
