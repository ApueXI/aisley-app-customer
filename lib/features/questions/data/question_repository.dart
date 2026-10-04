import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_page.dart';
import '../../../core/networking/wire.dart';
import '../../../core/commerce/commerce_value.dart';
import '../../../core/communication/text_rules.dart';
import 'question_models.dart';

class QuestionRepository {
  QuestionRepository(this.api);
  final ApiClient api;
  Future<ApiPage<ProductQuestion>> list(String product, [int page = 1]) async =>
      ApiPage.parse(
        await api.request(
          'GET',
          'products/${requireUuid(product)}/questions',
          queryParameters: {'page': page, 'limit': 10},
        ),
        ProductQuestion.parse,
      );
  Future<ProductQuestion> ask(
    SessionLease lease,
    String product,
    String question,
    String key,
  ) async => ProductQuestion.parse(
    Wire(
      await api.request(
        'POST',
        'products/${requireUuid(product)}/questions',
        lease: lease,
        body: {'question': checkedText(question, 1000)},
        idempotencyKey: key,
      ),
    ).object('data'),
  );
}
