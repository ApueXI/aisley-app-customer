import '../../../core/networking/api_client.dart';
import '../../../core/networking/cursor_page.dart';
import '../../messaging/presentation/conversation_inbox_controller.dart';
import '../data/courier_models.dart';
import '../data/courier_repository.dart';

class CourierInboxController
    extends ConversationInboxController<CourierConversation> {
  CourierInboxController(super.session, this.repository);
  final CourierChatRepository repository;

  @override
  Future<CursorPage<CourierConversation>> fetch(
    SessionLease credential,
    String? cursor,
  ) => repository.inbox(credential, cursor);

  @override
  String idOf(CourierConversation item) => item.id;
}
