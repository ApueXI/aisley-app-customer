import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';

/// Shared paging mechanics; each channel keeps its own repository and state.
abstract class ConversationInboxController<T> extends CommerceController {
  ConversationInboxController(super.session);

  Future<CursorPage<T>> fetch(SessionLease credential, String? cursor);
  String idOf(T item);

  List<T> items = const [];
  final trail = CursorTrail();
  bool loading = false, paging = false, offline = false, loaded = false;
  int unread = 0;
  String? pageError;
  bool stale = true, unreadFresh = false, needsRefresh = true;
  int _unreadRevision = 0;
  bool get busy => loading || paging;

  void invalidate() {
    needsRefresh = true;
    markUnreadStale();
  }

  void markUnreadStale() {
    _unreadRevision++;
    unreadFresh = false;
    if (!disposed) notifyListeners();
  }

  Future<void> load({
    bool more = false,
    bool retain = false,
    bool automatic = false,
  }) async {
    final credential = lease;
    final cursor = more ? trail.next : null;
    if (credential == null ||
        busy ||
        coolingDown ||
        automatic && offline ||
        more && (cursor == null || stale)) {
      return;
    }
    final stamp = more ? epoch : ++epoch;
    final unreadRevision = _unreadRevision;
    needsRefresh = false;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      if (!retain) stale = true;
      pageError = null;
      error = null;
      offline = false;
    }
    notifyListeners();
    try {
      final page = await fetch(credential, cursor);
      if (!current(stamp, credential)) return;
      final prior = items.map(idOf).toSet();
      if (!more && (!retain || !loaded || page.items.isEmpty)) {
        items = List.unmodifiable(
          {for (final item in page.items) idOf(item): item}.values,
        );
        trail.clear();
        trail.seed(page.next);
      } else {
        items = List.unmodifiable(
          {
            for (final item in items) idOf(item): item,
            for (final item in page.items) idOf(item): item,
          }.values,
        );
        if (more) {
          trail.advance(
            cursor!,
            page.next,
            progressed: page.items.any((item) => !prior.contains(idOf(item))),
          );
        } else {
          // Keep both the new first-page bridge and the older paging frontier.
          trail.seed(page.next, gap: true);
        }
      }
      unread = page.unread;
      unreadFresh = !needsRefresh && unreadRevision == _unreadRevision;
      loaded = true;
      stale = false;
      offline = false;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      unreadFresh = false;
      offline = e.kind == FailureKind.offline || e.kind == FailureKind.timeout;
      if (more) {
        pageError = describeFailure(e);
      } else {
        stale = true;
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

  void discard(String id) {
    epoch++;
    loading = paging = false;
    items = List.unmodifiable(items.where((item) => idOf(item) != id));
    invalidate();
  }

  @override
  void reset({required bool preserveUnresolved}) {
    items = const [];
    trail.clear();
    unread = 0;
    loading = paging = loaded = offline = unreadFresh = false;
    pageError = null;
    stale = needsRefresh = true;
  }
}
