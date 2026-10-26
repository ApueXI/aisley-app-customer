import '../../../core/networking/api_client.dart';
import '../../../core/networking/cursor_page.dart';
import '../../messaging/presentation/conversation_inbox_controller.dart';
import '../data/logistics_models.dart';
import '../data/logistics_repository.dart';

class LogisticsInboxController
    extends ConversationInboxController<LogisticsConversation> {
  LogisticsInboxController(super.session, this.repository);
  final LogisticsChatRepository repository;

  @override
  Future<CursorPage<LogisticsConversation>> fetch(
    SessionLease credential,
    String? cursor,
  ) => repository.inbox(credential, cursor);

  @override
  String idOf(LogisticsConversation item) => item.id;
}
