import '../commerce/commerce_value.dart';
import 'api_failure.dart';
import 'wire.dart';

class ApiPage<T> {
  ApiPage.parse(Object? json, T Function(Object?) parse) {
    final w = Wire(json);
    items = w.list('data', parse);
    final links = Wire(w.object('links'));
    links.string('first');
    links.string('last');
    links.nullableString('prev');
    links.nullableString('next');
    final m = Wire(w.object('meta'));
    page = m.positiveInt('current_page');
    lastPage = m.positiveInt('last_page');
    final size = m.positiveInt('per_page');
    total = nonnegative(m, 'total');
    m.nullableInt('from');
    m.nullableInt('to');
    m.string('path');
    m.list('links', (raw) {
      final link = Wire(raw);
      link.nullableString('url');
      link.string('label');
      link.boolean('active');
      return true;
    });
    if (page > 10000 || lastPage < page || size > 50) {
      throw const ApiFailure(FailureKind.decode);
    }
  }
  late final List<T> items;
  late final int page, lastPage, total;
  bool get hasMore => page < lastPage && page < 10000;
}
