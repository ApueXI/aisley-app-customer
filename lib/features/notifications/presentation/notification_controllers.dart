import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

class NotificationInboxController extends CommerceController {
  NotificationInboxController(super.session, this.repository);
  final NotificationRepository repository;
  String status = 'all';
  List<BuyerNotification> items = const [];
  bool loading = false, paging = false, loaded = false, hasMore = false;
  int page = 0;
  String? pageError;
  bool stale = true;
  Future<void> filter(String value) async {
    if (!const ['all', 'read', 'unread'].contains(value) || value == status) {
      return;
    }
    epoch++;
    status = value;
    items = const [];
    error = coolingDown ? 'Please wait before retrying this list.' : null;
    pageError = null;
    stale = true;
    page = 0;
    hasMore = loaded = loading = paging = false;
    notifyListeners();
    await load();
  }

  Future<void> load({bool more = false}) async {
    final credential = lease;
    if (credential == null ||
        loading ||
        more && paging ||
        coolingDown ||
        more && (!hasMore || stale)) {
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
    }
    notifyListeners();
    try {
      final value = await repository.list(
        credential,
        status,
        more ? page + 1 : 1,
      );
      if (!current(stamp, credential)) return;
      if (value.page != (more ? page + 1 : 1)) {
        throw const ApiFailure(FailureKind.decode);
      }
      items = List.unmodifiable(
        {
          if (more)
            for (final e in items) e.id: e,
          for (final e in value.items) e.id: e,
        }.values,
      );
      page = value.page;
      hasMore = value.hasMore;
      loaded = true;
      stale = false;
    } on ApiFailure catch (e) {
      if (!current(stamp, credential)) return;
      if (more) {
        pageError = describeFailure(e);
      } else {
        failure(e);
      }
      if (e.status == 403 || e.status == 404) {
        stale = true;
        items = const [];
        hasMore = loaded = false;
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
    status = 'all';
    page = 0;
    loading = paging = loaded = hasMore = false;
    pageError = null;
    stale = true;
  }
}

class NotificationDetailController extends CommerceController {
  NotificationDetailController(super.session, this.repository, this.id);
  final NotificationRepository repository;
  final String id;
  BuyerNotification? value;
  bool loading = false, reading = false;
  String? readError;
  Future<void> load() async {
    final credential = lease;
    if (credential == null || loading || reading || coolingDown) return;
    final stamp = epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final item = await repository.detail(credential, id);
      if (current(stamp, credential)) value = item;
    } on ApiFailure catch (e) {
      if (current(stamp, credential)) {
        failure(e);
        if (e.status == 403 || e.status == 404) value = null;
      }
    } finally {
      if (current(stamp, credential)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> displayed() async {
    final credential = lease;
    if (credential == null ||
        value == null ||
        value!.readAt != null ||
        loading ||
        reading ||
        coolingDown) {
      return;
    }
    final stamp = epoch;
    reading = true;
    try {
      final item = await repository.read(credential, id);
      if (current(stamp, credential)) {
        value = item;
        readError = null;
      }
    } on ApiFailure catch (e) {
      if (current(stamp, credential)) {
        readError = describeFailure(e);
        if (e.status == 403 || e.status == 404) value = null;
      }
    } finally {
      if (current(stamp, credential)) {
        reading = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    value = null;
    loading = reading = false;
    readError = null;
  }
}
