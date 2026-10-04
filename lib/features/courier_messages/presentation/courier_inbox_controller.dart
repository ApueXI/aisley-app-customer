import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/networking/cursor_page.dart';
import '../data/courier_models.dart';
import '../data/courier_repository.dart';

class CourierInboxController extends CommerceController {
  CourierInboxController(super.session, this.repository);
  final CourierChatRepository repository;
  List<CourierConversation> items = const [];
  final trail = CursorTrail();
  bool loading = false, paging = false, offline = false, loaded = false;
  int unread = 0;
  String? pageError;
  Future<void> load({bool more = false}) async {
    final credential = lease;
    final cursor = more ? trail.next : null;
    if (credential == null ||
        loading ||
        paging ||
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
      final page = await repository.inbox(credential, cursor);
      if (!current(stamp, credential)) return;
      final prior = items.map((e) => e.id).toSet();
      if (!more) {
        items = page.items;
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
  }
}
