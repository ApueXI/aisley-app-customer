import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';
import '../data/tracking_models.dart';

class OrdersController extends CommerceController {
  OrdersController(super.session, this.repository);
  final OrderRepository repository;
  List<OrderSummary> items = const [];
  List<OrderTab> tabs = const [];
  String? group, pageError;
  bool loading = false, paging = false, stale = true, hasMore = false;
  int _page = 0, _query = 0;
  Future<void> filter(String? value) async {
    if (value != null && !orderGroups.contains(value)) return;
    group = value;
    _query++;
    items = const [];
    loading = paging = false;
    await load();
  }

  Future<void> load({bool more = false}) async {
    final credential = lease;
    if (credential == null ||
        loading ||
        paging ||
        coolingDown ||
        more && (!hasMore || stale)) {
      return;
    }
    final generation = epoch, query = more ? _query : ++_query;
    final page = more ? _page + 1 : 1;
    if (more) {
      paging = true;
      pageError = null;
    } else {
      loading = true;
      stale = true;
      error = null;
      pageError = null;
    }
    notifyListeners();
    try {
      final result = await repository.list(
        credential,
        group: group,
        page: page,
      );
      if (!current(generation, credential) || query != _query) return;
      if (result.page.page != page || result.selected != group) {
        throw const ApiFailure(FailureKind.decode);
      }
      final deduplicated = <String, OrderSummary>{
        for (final item in more ? items : <OrderSummary>[]) item.id: item,
      };
      for (final item in result.page.items) {
        deduplicated[item.id] = item;
      }
      items = List.unmodifiable(deduplicated.values);
      tabs = result.tabs;
      hasMore = result.page.hasMore;
      _page = page;
      stale = false;
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        if (value.status == 403 || value.status == 404) {
          items = const [];
          tabs = const [];
          hasMore = false;
        }
        if (more) {
          pageError = describeFailure(value);
        } else {
          failure(value);
        }
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        loading = paging = false;
        notifyListeners();
      }
    }
  }

  @override
  void reset({required bool preserveUnresolved}) {
    items = const [];
    tabs = const [];
    group = pageError = null;
    loading = paging = hasMore = false;
    stale = true;
    _page = 0;
    _query++;
  }
}
