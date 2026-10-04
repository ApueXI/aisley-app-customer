import '../../../core/networking/wire.dart';
import '../../../core/networking/api_failure.dart';
import '../../../core/commerce/commerce_value.dart';

const ticketCategories = ['general', 'account', 'order', 'delivery'];
const ticketStatuses = [
  'open',
  'in_progress',
  'waiting_for_requester',
  'resolved',
];

class SupportTicket {
  SupportTicket.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    reference = w.string('reference');
    subject = w.string('subject');
    category = w.string('category');
    status = w.string('status');
    revision = w.positiveInt('revision');
    role = w.string('requester_role');
    if (w.field('requester_name') != null || w.field('assignee_id') != null) {
      throw const ApiFailure(FailureKind.decode);
    }
    assignee = w.nullableString('assignee_name');
    unread = nonnegative(w, 'unread_count');
    activityAt = w.timestamp('last_activity_at');
    createdAt = w.timestamp('created_at');
    resolvedAt = w.timestamp('resolved_at');
  }
  late final String id, reference, subject, category, status, role;
  late final int revision, unread;
  late final String? assignee;
  late final DateTime? activityAt, createdAt, resolvedAt;
  bool get canReply => role == 'customer' && ticketStatuses.contains(status);
}

class TicketEvent {
  TicketEvent.parse(Object? json) {
    final w = Wire(json);
    id = w.uuid('id');
    sequence = w.positiveInt('sequence');
    type = w.string('type');
    role = w.string('actor_role');
    mine = w.boolean('is_mine');
    body = w.nullableString('body');
    fromStatus = w.nullableString('from_status');
    toStatus = w.nullableString('to_status');
    assignmentChanged = w.boolean('assignment_changed');
    at = w.timestamp('created_at');
  }
  late final String id, type, role;
  late final int sequence;
  late final bool mine, assignmentChanged;
  late final String? body, fromStatus, toStatus;
  late final DateTime? at;
}
