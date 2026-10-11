import '../networking/api_failure.dart';
import 'attachment.dart';

List<ChatAttachment> messageAttachments(Object? value) {
  try {
    return ChatAttachment.list(value);
  } on FormatException {
    throw const ApiFailure(FailureKind.decode);
  }
}
