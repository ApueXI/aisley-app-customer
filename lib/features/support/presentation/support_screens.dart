import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/responsive_layout.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/foreground_poll.dart';
import '../../../core/communication/text_rules.dart';
import '../../messaging/presentation/message_views.dart';
import '../data/support_models.dart';
import 'ticket_controller.dart';

class TicketInboxScreen extends StatefulWidget {
  const TicketInboxScreen({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<TicketInboxScreen> createState() => _TicketInboxScreenState();
}

class _TicketInboxScreenState extends State<TicketInboxScreen> {
  late final controller = widget.dependencies.communication!.ticketInbox;
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  Widget build(BuildContext context) => ForegroundPoll(
    refresh: controller.load,
    paused: () => controller.offline || !widget.dependencies.session.active,
    child: ListenableBuilder(
      listenable: Listenable.merge([controller, widget.dependencies.session]),
      builder: (context, _) => !widget.dependencies.session.active
          ? const SizedBox.shrink()
          : ShoppingPage(
              appBar: AppBar(
                title: const Text('Support tickets'),
                actions: [
                  IconButton(
                    tooltip: 'Refresh tickets',
                    onPressed: controller.loading || controller.coolingDown
                        ? null
                        : controller.load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              body: ListView(
                padding: pagePadding(context),
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push('/support-tickets/new');
                      if (mounted) controller.load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create support ticket'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('status/${controller.status}'),
                    initialValue: controller.status,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      for (final s in ticketStatuses)
                        DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ')),
                        ),
                    ],
                    onChanged: (v) => controller.filter(
                      status: v,
                      category: controller.category,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('category/${controller.category}'),
                    initialValue: controller.category,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final s in ticketCategories)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => controller.filter(
                      status: controller.status,
                      category: v,
                    ),
                  ),
                  if (controller.loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading tickets',
                    ),
                  if (controller.error != null) ...[
                    Text(controller.error!),
                    TextButton(
                      onPressed: controller.coolingDown
                          ? null
                          : controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                  if (controller.loaded && controller.items.isEmpty)
                    const Text('No tickets in these filters.'),
                  for (final item in controller.items)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.support_agent),
                        trailing: const Icon(Icons.chevron_right),
                        minTileHeight: 72,
                        title: Text(item.subject),
                        subtitle: Text(
                          '${item.reference} · ${item.status.replaceAll('_', ' ')}\n${item.unread} unread',
                        ),
                        onTap: () async {
                          await context.push('/support-tickets/${item.id}');
                          if (mounted) controller.load();
                        },
                      ),
                    ),
                  if (controller.pageError != null) Text(controller.pageError!),
                  if (controller.trail.next != null)
                    TextButton(
                      onPressed:
                          controller.loading ||
                              controller.paging ||
                              controller.coolingDown
                          ? null
                          : () => controller.load(more: true),
                      child: const Text('Load more tickets'),
                    ),
                ],
              ),
            ),
    ),
  );
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.dependencies,
    required this.controller,
  });
  final AppDependencies dependencies;
  final TicketController controller;
  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ForegroundPoll(
      refresh: c.load,
      paused: () => c.offline || !widget.dependencies.session.active,
      child: ListenableBuilder(
        listenable: Listenable.merge([c, widget.dependencies.session]),
        builder: (context, _) => !widget.dependencies.session.active
            ? const SizedBox.shrink()
            : MessageThreadView(
                title: c.ticket?.subject ?? 'Support ticket',
                rows: [
                  for (final e in c.events)
                    MessageRow(
                      e.id,
                      e.sequence,
                      _eventText(e),
                      e.mine,
                      _eventLabel(e),
                      e.at,
                    ),
                ],
                draft: c.pending?.body['body'] as String? ?? c.draft,
                changed: (v) => c.draft = v,
                clearDraft: () => c.draft = '',
                send: c.submit,
                retry: c.retry,
                refresh: c.load,
                loadMore: () => c.load(more: true),
                displayed: c.displayed,
                loading: c.loading,
                paging: c.paging,
                sending: c.busy,
                allowed: c.ticket?.canReply == true,
                pending: c.pending != null,
                conflict: c.conflict,
                more: c.trail.next != null,
                reviewConflict: c.reviewConflict,
                arrivals: c.arrivals,
                acknowledge: c.acknowledgeArrivals,
                subtitle: c.ticket == null
                    ? null
                    : '${c.ticket!.reference} · ${c.ticket!.status.replaceAll('_', ' ')} · Revision ${c.ticket!.revision}${c.ticket!.assignee == null ? '' : '\nSupport: ${c.ticket!.assignee}'}',
                reason: c.ticket == null
                    ? 'Ticket unavailable.'
                    : '${c.ticket!.reference} · ${c.ticket!.status}',
                error: c.error,
                pageError: c.pageError,
                readError: c.readError,
                fieldError: c.fieldErrors['body'],
                coolingDown: c.coolingDown,
              ),
      ),
    );
  }

  String _eventLabel(TicketEvent e) => e.assignmentChanged
      ? 'Support assignment'
      : e.toStatus != null
      ? 'Status change'
      : '${e.role} reply';
  String _eventText(TicketEvent e) => [
    if (e.body != null) e.body!,
    if (e.toStatus != null)
      '${e.fromStatus ?? 'Initial status'} → ${e.toStatus}',
    if (e.assignmentChanged) 'Support assignment changed.',
    if (e.body == null && e.toStatus == null && !e.assignmentChanged)
      'Ticket event: ${e.type}',
  ].join('\n');
}

class TicketComposerScreen extends StatefulWidget {
  const TicketComposerScreen({
    super.key,
    required this.dependencies,
    required this.controller,
  });
  final AppDependencies dependencies;
  final TicketController controller;
  @override
  State<TicketComposerScreen> createState() => _TicketComposerScreenState();
}

class _TicketComposerScreenState extends State<TicketComposerScreen> {
  final subject = TextEditingController(), body = TextEditingController();
  final subjectFocus = FocusNode(), bodyFocus = FocusNode();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    subjectFocus.dispose();
    bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([c, widget.dependencies.session]),
      builder: (context, _) {
        if (!widget.dependencies.session.active) return const SizedBox.shrink();
        final draft = c.pending?.body['body'] as String? ?? c.draft;
        final title = c.pending?.body['subject'] as String? ?? c.subject;
        if (body.text != draft) {
          body.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
        if (subject.text != title) {
          subject.value = TextEditingValue(
            text: title,
            selection: TextSelection.collapsed(offset: title.length),
          );
        }
        return FormPage(
          title: 'New support ticket',
          dirty: subject.text.isNotEmpty || body.text.isNotEmpty,
          busy: c.busy,
          onCancel: () {
            if (c.pending == null && !c.busy) {
              c.draft = c.subject = '';
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/support-tickets');
            }
          },
          children: [
            if (c.busy)
              const LinearProgressIndicator(semanticsLabel: 'Creating ticket'),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            if (c.id != null) ...[
              const Text('Support ticket created.'),
              FilledButton(
                onPressed: () => context.replace('/support-tickets/${c.id}'),
                child: const Text('Open ticket'),
              ),
            ] else ...[
              Form(
                key: form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: subject,
                      focusNode: subjectFocus,
                      enabled: !c.busy && c.pending == null,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        errorText: c.fieldErrors['subject'],
                      ),
                      validator: (v) => requiredText(v, max: 150),
                      onChanged: (v) {
                        c.subject = v;
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          c.pending?.body['category'] as String? ?? c.category,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        errorText: c.fieldErrors['category'],
                      ),
                      items: [
                        for (final s in ticketCategories)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: c.busy || c.pending != null
                          ? null
                          : (v) {
                              if (v != null) c.category = v;
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: body,
                      focusNode: bodyFocus,
                      enabled: !c.busy && c.pending == null,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        helperText: 'Plain text, up to 2,000 characters',
                        errorText: c.fieldErrors['body'],
                      ),
                      validator: (v) => plainTextError(v, 2000),
                      onChanged: (v) {
                        c.draft = v;
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed:
                    c.busy || c.coolingDown || c.pending != null || c.conflict
                    ? null
                    : () {
                        if (validateForm(form.currentState!)) c.submit();
                      },
                child: const Text('Create ticket'),
              ),
              if (c.pending != null) ...[
                const Text(
                  'The original ticket request is kept for exact retry.',
                ),
                TextButton(
                  onPressed: c.busy || c.coolingDown || c.conflict
                      ? null
                      : c.retry,
                  child: const Text('Retry exact ticket'),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
