import '../../../core/networking/api_client.dart';
import '../../../core/networking/cursor_page.dart';
import '../../messaging/presentation/conversation_inbox_controller.dart';
import '../data/shop_models.dart';
import '../data/shop_repository.dart';

class ShopInboxController
    extends ConversationInboxController<ShopConversation> {
  ShopInboxController(super.session, this.repository);
  final ShopChatRepository repository;

  @override
  Future<CursorPage<ShopConversation>> fetch(
    SessionLease credential,
    String? cursor,
  ) => repository.inbox(credential, cursor);

  @override
  String idOf(ShopConversation item) => item.id;
}
