import '../../../core/networking/wire.dart';

class ProductQuestion {
  ProductQuestion.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    question = w.string('question');
    askedAt = w.timestamp('askedAt');
    answer = w.nullableString('answer');
    answeredAt = w.timestamp('answeredAt');
    sellerLabel = w.nullableString('sellerLabel');
  }
  late final String id, question;
  late final String? answer, sellerLabel;
  late final DateTime? askedAt, answeredAt;
}
