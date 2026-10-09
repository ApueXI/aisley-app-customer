import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
import '../data/logistics_models.dart';
import '../data/logistics_repository.dart';

class LogisticsInboxController extends CommerceController {
  LogisticsInboxController(super.session, this.repository);
  final LogisticsChatRepository repository;
  List<LogisticsConversation> items = const [];
  final trail = CursorTrail();
  bool loading = false, paging = false, offline = false, loaded = false;
  int unread = 0;
  String? pageError;
  bool stale = true;
  Future<void> load({bool more = false}) async {
    final credential = lease;
    final cursor = more ? trail.next : null;
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
      final page = await repository.inbox(credential, cursor);
      if (!current(stamp, credential)) return;
      final prior = items.map((e) => e.id).toSet();
      if (!more) {
        items = List.unmodifiable(
          {for (final item in page.items) item.id: item}.values,
        );
        trail.clear();
        trail.seed(page.next);
      } else {
        items = List.unmodifiable(
          {
            for (final e in items) e.id: e,
            for (final e in page.items) e.id: e,
          }.values,
        );
        trail.advance(
          cursor!,
          page.next,
          progressed: page.items.any((e) => !prior.contains(e.id)),
        );
      }
      unread = page.unread;
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
        unread = 0;
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
    trail.clear();
    unread = 0;
    loading = paging = loaded = offline = false;
    pageError = null;
    stale = true;
  }
}
