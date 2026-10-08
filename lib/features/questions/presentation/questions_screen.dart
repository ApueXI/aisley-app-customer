import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/ui/marketplace_widgets.dart';
import '../../../core/communication/text_rules.dart';
import 'question_controllers.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({
    super.key,
    required this.dependencies,
    required this.product,
  });
  final AppDependencies dependencies;
  final String product;
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  late final list = QuestionListController(
    widget.dependencies.communication!.questions,
    widget.product,
  );
  final text = TextEditingController(), focus = FocusNode();
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    list.load();
    widget.dependencies.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.dependencies.session.removeListener(_sessionChanged);
    list.dispose();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.dependencies.session;
    final ask = session.active
        ? widget.dependencies.communication!.ask(widget.product)
        : null;
    return ListenableBuilder(
      listenable: Listenable.merge([list, session, ?ask]),
      builder: (context, _) {
        final draft = ask?.pending?.text ?? ask?.draft ?? '';
        if (text.text != draft) {
          text.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
        return FormPage(
          title: 'Product questions',
          dirty: text.text.isNotEmpty,
          busy: ask?.busy ?? false,
          onCancel: () {
            if (ask?.pending == null) ask?.draft = '';
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products/${widget.product}');
            }
          },
          children: [
            if (list.loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Loading questions',
              ),
            if (list.error != null)
              Semantics(liveRegion: true, child: Text(list.error!)),
            TextButton(
              onPressed: list.loading || list.coolingDown ? null : list.load,
              child: const Text('Refresh questions'),
            ),
            if (list.loaded && list.items.isEmpty)
              const Text('No questions yet.'),
            for (final item in list.items)
              MarketSection(
                title: 'Question',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      item.question,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (item.askedAt != null)
                      Text(item.askedAt!.toLocal().toString()),
                    if (item.answer != null) ...[
                      Text('Official answer · ${item.sellerLabel ?? 'Seller'}'),
                      SelectableText(item.answer!),
                    ] else
                      const Text('Awaiting an official Seller answer.'),
                  ],
                ),
              ),
            if (list.pageError != null) Text(list.pageError!),
            if (list.hasMore)
              TextButton(
                onPressed: list.loading || list.paging || list.coolingDown
                    ? null
                    : () => list.load(more: true),
                child: Text(list.paging ? 'Loading…' : 'Load more questions'),
              ),
            if (list.loaded) ...[
              if (!session.active)
                FilledButton(
                  onPressed: () => context.push(
                    '/login?returnTo=${Uri.encodeComponent('/products/${widget.product}/questions')}',
                  ),
                  child: const Text('Sign in to ask a question'),
                )
              else ...[
                const Text(
                  'Ask a public Product question. Do not include private contact information.',
                ),
                if (ask?.error != null)
                  Semantics(liveRegion: true, child: Text(ask!.error!)),
                if (ask?.committed != null) const Text('Question submitted.'),
                Form(
                  key: form,
                  child: TextFormField(
                    controller: text,
                    focusNode: focus,
                    enabled: ask?.pending == null && ask?.busy != true,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Question',
                      helperText: 'Plain text, up to 1,000 characters',
                      errorText: ask?.fieldErrors['question'],
                    ),
                    validator: (v) => plainTextError(v, 1000),
                    onChanged: (v) {
                      ask!.draft = v;
                      setState(() {});
                    },
                  ),
                ),
                FilledButton(
                  onPressed:
                      ask!.busy ||
                          ask.coolingDown ||
                          ask.pending != null ||
                          ask.conflict
                      ? null
                      : () async {
                          if (validateForm(form.currentState!)) {
                            await ask.submit();
                            if (ask.committed != null) await list.load();
                          }
                        },
                  child: Text(ask.busy ? 'Submitting…' : 'Ask question'),
                ),
                if (ask.pending != null) ...[
                  const Text('The original question is kept for exact retry.'),
                  TextButton(
                    onPressed: ask.busy || ask.coolingDown || ask.conflict
                        ? null
                        : () async {
                            await ask.submit(retry: true);
                            if (ask.committed != null) await list.load();
                          },
                    child: const Text('Retry exact question'),
                  ),
                ],
                if (ask.conflict)
                  const Text(
                    'The question conflicts with the saved request. Refresh and review existing questions before continuing.',
                  ),
              ],
            ],
          ],
        );
      },
    );
  }
}
