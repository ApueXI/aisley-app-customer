import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
import '../data/support_repository.dart';
import '../data/support_models.dart';

class TicketInboxController extends CommerceController {
  TicketInboxController(super.session, this.repository);
  final SupportRepository repository;
  String? status, category, pageError;
  List<SupportTicket> items = const [];
  final trail = CursorTrail();
  bool loading = false, paging = false, loaded = false, offline = false;
  bool stale = true;
  Future<void> filter({String? status, String? category}) async {
    if (status != null && !ticketStatuses.contains(status) ||
        category != null && !ticketCategories.contains(category)) {
      return;
    }
    epoch++;
    this.status = status;
    this.category = category;
    items = const [];
    error = coolingDown ? 'Please wait before retrying this list.' : null;
    pageError = null;
    stale = true;
    trail.clear();
    loading = paging = loaded = false;
    notifyListeners();
    await load();
  }

  Future<void> load({bool more = false}) async {
    final credential = lease, cursor = more ? trail.next : null;
    if (credential == null ||
        loading ||
        more && paging ||
        coolingDown ||
        more && (cursor == null || stale)) {
      return;
    }
    final stamp = more ? epoch : ++epoch;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      paging = false;
      stale = true;
      pageError = null;
      error = null;
      offline = false;
    }
    notifyListeners();
    try {
      final value = await repository.list(
        credential,
        cursor: cursor,
        status: status,
        category: category,
      );
      if (!current(stamp, credential)) return;
      final old = items.map((e) => e.id).toSet();
      items = List.unmodifiable(
        {
          if (more)
            for (final e in items) e.id: e,
          for (final e in value.items) e.id: e,
        }.values,
      );
      if (more) {
        trail.advance(
          cursor!,
          value.next,
          progressed: value.items.any((e) => !old.contains(e.id)),
        );
      } else {
        trail.clear();
        trail.seed(value.next);
      }
      loaded = true;
      stale = false;
      offline = false;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      offline = e.kind == FailureKind.offline || e.kind == FailureKind.timeout;
      if (more) {
        pageError = describeFailure(e);
      } else {
        failure(e);
      }
      if (e.status == 403 || e.status == 404) {
        items = const [];
        trail.clear();
        loaded = false;
        stale = true;
      }
    } finally {
      if (current(stamp, credential)) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    items = const [];
    status = category = pageError = null;
    trail.clear();
    loading = paging = loaded = offline = false;
    stale = true;
  }
}
