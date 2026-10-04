import '../../../core/commerce/commerce_controller.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/communication/text_rules.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
import '../data/support_repository.dart';
import '../data/support_models.dart';

class PendingTicketWrite {
  PendingTicketWrite(this.id, Map<String, dynamic> body, this.key)
    : body = Map.unmodifiable(body);
  final String? id;
  final Map<String, dynamic> body;
  final String key;
  bool uncertain = false;
}

class TicketController extends CommerceController {
  TicketController(
    super.session,
    this.repository, {
    this.id,
    String Function()? uuid,
  }) : uuid = uuid ?? secureUuid;
  final SupportRepository repository;
  final String Function() uuid;
  String? id;
  SupportTicket? ticket;
  List<TicketEvent> events = const [];
  final trail = CursorTrail();
  String subject = '', category = 'general', draft = '';
  PendingTicketWrite? pending;
  bool loading = false,
      paging = false,
      busy = false,
      offline = false,
      conflict = false,
      _reading = false;
  int _readWanted = 0, _readSent = 0, arrivals = 0;
  String? pageError, readError;
  Future<void> load({bool more = false}) async {
    final credential = lease, cursor = more ? trail.next : null;
    if (credential == null ||
        id == null ||
        loading ||
        paging ||
        busy ||
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
      final value = await repository.detail(credential, id!, cursor);
      if (!current(stamp, credential)) return;
      ticket = value.$1;
      final page = value.$2, old = events.map((e) => e.id).toSet();
      final oldMax = events.isEmpty ? 0 : events.last.sequence;
      final gap =
          events.isNotEmpty &&
          page.items.isNotEmpty &&
          page.items.first.sequence > oldMax + 1;
      _merge(page.items);
      if (more) {
        trail.advance(
          cursor!,
          page.next,
          progressed: page.items.any((e) => !old.contains(e.id)),
        );
      } else {
        trail.seed(page.next, gap: gap);
        arrivals += page.items
            .where(
              (e) =>
                  !e.mine &&
                  !old.contains(e.id) &&
                  e.sequence > oldMax &&
                  oldMax > 0,
            )
            .length;
      }
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      offline = e.kind == FailureKind.offline || e.kind == FailureKind.timeout;
      if (more) {
        pageError = describeFailure(e);
      } else {
        failure(e);
      }
      if (e.status == 403 || e.status == 404) reset(preserveUnresolved: false);
    } finally {
      if (current(stamp, credential)) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  void _merge(List<TicketEvent> incoming) {
    final values = {
      for (final e in events) e.id: e,
      for (final e in incoming) e.id: e,
    }.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
    events = List.unmodifiable(values);
  }

  Future<void> submit() async {
    if (lease == null ||
        loading ||
        paging ||
        busy ||
        _reading ||
        coolingDown ||
        pending != null ||
        conflict ||
        id != null && ticket?.canReply != true) {
      return;
    }
    final invalid = plainTextError(draft, 2000);
    if (invalid != null) {
      error = invalid;
      notifyListeners();
      return;
    }
    if (id == null &&
        (normalizedText(subject).isEmpty ||
            normalizedText(subject).runes.length > 150 ||
            !ticketCategories.contains(category))) {
      error = 'Enter a subject up to 150 characters and choose a category.';
      notifyListeners();
      return;
    }
    pending = PendingTicketWrite(id, {
      'body': normalizedText(draft),
      if (id == null) ...{
        'subject': normalizedText(subject),
        'category': category,
      } else
        'expected_revision': ticket!.revision,
    }, uuid());
    await retry();
  }

  Future<void> retry() async {
    final credential = lease, record = pending;
    if (credential == null ||
        record == null ||
        loading ||
        paging ||
        busy ||
        _reading ||
        coolingDown ||
        conflict) {
      return;
    }
    final stamp = epoch;
    busy = true;
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
      if (record.id != null && record.id != value.$1.id) {
        throw const ApiFailure(FailureKind.decode);
      }
      ticket = value.$1;
      id = value.$1.id;
      _merge([value.$2]);
      pending = null;
      draft = subject = '';
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
      if (e.status == 403 || e.status == 404) reset(preserveUnresolved: false);
    } finally {
      if (current(stamp, credential)) {
        busy = false;
        notifyListeners();
      }
    }
    if (conflict) await load();
  }

  void reviewConflict() {
    if (!conflict ||
        pending?.uncertain == true ||
        loading ||
        ticket == null ||
        !ticket!.canReply) {
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
        sequence < 0 ||
        !events.any((e) => e.sequence == sequence) ||
        coolingDown) {
      return;
    }
    if (sequence > _readWanted) _readWanted = sequence;
    if (sequence <= _readSent || _reading || loading || paging || busy) return;
    _reading = true;
    final stamp = epoch;
    try {
      while (current(stamp, credential) && _readWanted > _readSent) {
        final target = _readWanted;
        final value = await repository.read(credential, id!, target);
        if (!current(stamp, credential)) return;
        _readSent = target;
        readError = null;
        if (ticket == null || value.revision >= ticket!.revision) {
          ticket = value;
        }
      }
    } on ApiFailure catch (e) {
      if (current(stamp, credential)) {
        readError = describeFailure(e);
        if (e.status == 403 || e.status == 404) {
          reset(preserveUnresolved: false);
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
    if (preserveUnresolved && busy && pending != null) {
      pending!.uncertain = true;
    }
    ticket = null;
    events = const [];
    trail.clear();
    subject = draft = '';
    category = 'general';
    loading = paging = busy = offline = _reading = false;
    _readWanted = _readSent = arrivals = 0;
    pageError = readError = null;
    if (!preserveUnresolved) {
      pending = null;
      conflict = false;
    }
  }
}
