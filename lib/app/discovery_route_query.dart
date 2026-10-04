class DiscoveryRouteQuery {
  const DiscoveryRouteQuery({
    required this.valid,
    this.query = '',
    this.mode = 'products',
    this.category,
    this.page = 1,
    this.limit = 20,
  });
  final bool valid;
  final String query, mode;
  final String? category;
  final int page, limit;

  factory DiscoveryRouteQuery.parse(Uri uri, {required String kind}) {
    final allowed = switch (kind) {
      'search' => const {'q', 'mode', 'page', 'limit'},
      'directory' => const {'category', 'page', 'limit'},
      _ => const {'q', 'category', 'page', 'limit'},
    };
    if (uri.queryParametersAll.entries.any(
      (entry) => !allowed.contains(entry.key) || entry.value.length != 1,
    )) {
      return const DiscoveryRouteQuery(valid: false);
    }
    final params = uri.queryParameters;
    final query = (params['q'] ?? '').trim();
    final mode = params['mode'] ?? 'products';
    final category = params['category'];
    final page = int.tryParse(params['page'] ?? '1');
    final limit = int.tryParse(params['limit'] ?? '20');
    final valid =
        query.length <= 100 &&
        const {'products', 'shops'}.contains(mode) &&
        page != null &&
        page >= 1 &&
        page <= 10000 &&
        limit != null &&
        limit >= 8 &&
        limit <= 50 &&
        (category == null ||
            RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$').hasMatch(category));
    return DiscoveryRouteQuery(
      valid: valid,
      query: query,
      mode: mode,
      category: category,
      page: page ?? 1,
      limit: limit ?? 20,
    );
  }
}
