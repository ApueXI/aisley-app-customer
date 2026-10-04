import '../../../core/commerce/commerce_controller.dart';
import '../../../core/networking/api_failure.dart';
import '../../addresses/data/address_models.dart';
import '../../addresses/data/address_repository.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';
import '../data/tracking_models.dart';
import 'order_mutation_controller.dart';

class OrderDetailController extends CommerceController {
  OrderDetailController(
    super.session,
    this.repository,
    this.mutations,
    this.addressRepository,
    this.id,
  );
  final OrderRepository repository;
  final OrderMutationController mutations;
  final AddressRepository addressRepository;
  final String id;
  BuyerOrder? order;
  List<TrackingEvent> timeline = const [];
  List<BuyerAddress> addresses = const [];
  bool loading = false,
      paging = false,
      stale = true,
      hasMore = false,
      loadingAddresses = false,
      addressesFresh = false;
  int _page = 0, _query = 0;
  String? pageError, addressError;
  bool get mutable => !stale && !loading && mutations.canStart(id);
  bool get canCorrect => mutable && order?.canCorrect == true;
  bool get canCancel => mutable && order?.canCancel == true;

  Future<void> load() async {
    final credential = lease;
    if (credential == null || loading || mutations.busy(id) || coolingDown) {
      return;
    }
    final generation = epoch, query = ++_query;
    loading = true;
    paging = false;
    stale = true;
    error = null;
    pageError = null;
    addresses = const [];
    addressesFresh = false;
    loadingAddresses = false;
    notifyListeners();
    try {
      final value = await repository.detail(credential, id);
      if (!current(generation, credential) || query != _query) return;
      order = value;
      // Start tracking pagination at page 1: the embedded preview may be shorter than 25.
      timeline = _merge(const [], value.timeline);
      _page = 0;
      hasMore = value.timelineHasMore;
      stale = false;
      mutations.refreshed(id);
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        if (value.status == 403 || value.status == 404) {
          order = null;
          timeline = const [];
          hasMore = false;
        }
        failure(value);
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> moreTracking() async {
    final credential = lease;
    if (credential == null ||
        loading ||
        paging ||
        stale ||
        !hasMore ||
        coolingDown) {
      return;
    }
    final generation = epoch, query = _query, next = _page + 1;
    paging = true;
    pageError = null;
    notifyListeners();
    try {
      final value = await repository.tracking(credential, id, next);
      if (!current(generation, credential) || query != _query) return;
      if (value.page != next) throw const ApiFailure(FailureKind.decode);
      timeline = _merge(timeline, value.items);
      _page = next;
      hasMore = value.hasMore;
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        pageError = describeFailure(value);
        if (value.status == 403 || value.status == 404) {
          order = null;
          timeline = const [];
          hasMore = false;
          stale = true;
        }
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        paging = false;
        notifyListeners();
      }
    }
  }

  List<TrackingEvent> _merge(
    List<TrackingEvent> before,
    List<TrackingEvent> after,
  ) {
    final map = {for (final event in before) event.id: event};
    for (final event in after) {
      map[event.id] = event;
    }
    return List.unmodifiable(
      map.values.toList()..sort((a, b) => a.occurredAt.compareTo(b.occurredAt)),
    );
  }

  Future<void> loadAddresses() async {
    final credential = lease;
    if (credential == null || !canCorrect || loadingAddresses) return;
    final generation = epoch, query = _query;
    loadingAddresses = true;
    addressesFresh = false;
    addressError = null;
    notifyListeners();
    try {
      final rows = await addressRepository.list(credential);
      if (!current(generation, credential) || query != _query) return;
      addresses = List.unmodifiable(
        rows.where((a) => order!.address.permitsContactCorrection(a)),
      );
      addressesFresh = true;
    } on ApiFailure catch (value) {
      if (current(generation, credential) && query == _query) {
        addressError = describeFailure(value);
        addresses = const [];
      }
    } finally {
      if (current(generation, credential) && query == _query) {
        loadingAddresses = false;
        notifyListeners();
      }
    }
  }

  Future<void> cancel(String? reason) async {
    final value = order;
    if (value == null || !canCancel) return;
    await _after(mutations.cancel(value, reason, fresh: !stale));
  }

  Future<void> correct(BuyerAddress address) async {
    final value = order;
    if (value == null || !canCorrect || !addressesFresh) return;
    await _after(
      mutations.correct(
        value,
        address,
        fresh: !stale,
        owned: addresses.any((a) => identical(a, address)),
      ),
    );
  }

  Future<void> retryMutation() => _after(mutations.retry(id));
  Future<void> _after(Future<BuyerOrder?> operation) async {
    final generation = epoch;
    await operation;
    if (disposed || generation != epoch) return;
    stale = true;
    notifyListeners();
    await load();
  }

  @override
  void reset({required bool preserveUnresolved}) {
    order = null;
    timeline = const [];
    addresses = const [];
    stale = true;
    loading = paging = hasMore = loadingAddresses = addressesFresh = false;
    _page = 0;
    _query++;
    pageError = addressError = null;
  }
}
