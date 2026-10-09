import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../account/data/photo_picker_adapter.dart';
import '../../../core/ui/form_page.dart';
import '../../../core/communication/text_rules.dart';
import 'review_composer_controller.dart';
import 'reviews_screen.dart';

class ReviewComposerScreen extends StatefulWidget {
  const ReviewComposerScreen({
    super.key,
    required this.dependencies,
    required this.controller,
  });
  final AppDependencies dependencies;
  final ReviewComposerController controller;
  @override
  State<ReviewComposerScreen> createState() => _ReviewComposerScreenState();
}

class _ReviewComposerScreenState extends State<ReviewComposerScreen> {
  final text = TextEditingController(), focus = FocusNode();
  final form = GlobalKey<FormState>();
  String? pickerNotice;
  @override
  void initState() {
    super.initState();
    _recover();
    if (widget.controller.reviewId != null) widget.controller.reconcilePhotos();
  }

  Future<void> _recover() async {
    final stamp = widget.controller.epoch;
    final recovery = await widget.dependencies.photoPicker
        ?.recoverInterruptedSelection();
    if (mounted &&
        stamp == widget.controller.epoch &&
        widget.dependencies.session.active &&
        (recovery == PickerRecovery.interrupted ||
            recovery == PickerRecovery.failed)) {
      setState(
        () => pickerNotice = recovery == PickerRecovery.interrupted
            ? 'An interrupted image selection needs to be selected again for this Review.'
            : 'The interrupted selection could not be recovered. Choose your photo again.',
      );
    }
  }

  @override
  void dispose() {
    widget.controller.clearSelection(notify: false);
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([c, widget.dependencies.session]),
      builder: (context, _) {
        if (!widget.dependencies.session.active) return const SizedBox.shrink();
        final draft = c.pending?.body ?? c.draft;
        if (text.text != draft) {
          text.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
        return FormPage(
          title: 'Verified purchase review',
          dirty: text.text.isNotEmpty || c.selected != null,
          busy: c.locked,
          onCancel: () {
            if (c.pending == null && !c.busy) c.draft = '';
            if (!c.uploading) c.clearSelection();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/orders');
            }
          },
          children: [
            if (c.busy || c.reconciling)
              const LinearProgressIndicator(semanticsLabel: 'Updating Review'),
            if (c.error != null)
              Semantics(liveRegion: true, child: Text(c.error!)),
            if (c.reviewId == null) ...[
              DropdownButtonFormField<int>(
                isExpanded: true,
                itemHeight: null,
                initialValue: c.pending?.rating ?? c.rating,
                decoration: InputDecoration(
                  labelText: 'Rating',
                  errorText: c.fieldErrors['rating'],
                ),
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i of 5 stars')),
                ],
                onChanged: c.locked || c.pending != null
                    ? null
                    : (v) {
                        if (v != null) c.rating = v;
                      },
              ),
              Form(
                key: form,
                child: TextFormField(
                  controller: text,
                  focusNode: focus,
                  enabled: !c.locked && c.pending == null,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: 'Review',
                    helperText: 'Plain text, up to 2,000 characters',
                    errorText: c.fieldErrors['body'],
                  ),
                  validator: (v) => plainTextError(v, 2000),
                  onChanged: (v) {
                    c.draft = v;
                    setState(() {});
                  },
                ),
              ),
              FilledButton(
                onPressed:
                    c.locked || c.coolingDown || c.pending != null || c.conflict
                    ? null
                    : () {
                        if (validateForm(form.currentState!)) c.submit();
                      },
                child: const Text('Submit Review'),
              ),
              if (c.pending != null) ...[
                const Text(
                  'Review outcome is unresolved. Retry the identical rating and text.',
                ),
                TextButton(
                  onPressed: c.locked || c.coolingDown || c.conflict
                      ? null
                      : () => c.submit(retry: true),
                  child: const Text('Retry identical Review'),
                ),
              ],
              if (c.conflict)
                const Text(
                  'The server rejected this Review. Return to the Order to review current eligibility or the existing Review.',
                ),
            ] else ...[
              const Text(
                'Review text is confirmed. Photos are uploaded separately.',
              ),
              if (c.review != null)
                ReviewView(
                  review: c.review!,
                  photos: c.photos,
                  dependencies: widget.dependencies,
                ),
              Text('${c.photos.length} of 5 committed photos'),
              const Text(
                'JPEG, PNG or WebP under 10 MiB. Up to 8,000 pixels per edge and 40 million pixels.',
              ),
              if (pickerNotice != null) Text(pickerNotice!),
              if (c.fieldErrors['image'] != null) Text(c.fieldErrors['image']!),
              if (c.photoError != null)
                Semantics(liveRegion: true, child: Text(c.photoError!)),
              if (c.uncertainPhoto)
                const Text(
                  'Check the canonical Review before another deliberate upload. Uploads are never replayed automatically.',
                ),
              TextButton(
                onPressed: c.locked || c.coolingDown ? null : c.reconcilePhotos,
                child: const Text('Check published Review / photos'),
              ),
              if (c.selected != null) ...[
                Image.memory(
                  c.selected!.bytes,
                  height: 180,
                  semanticLabel: 'Selected Review photo',
                ),
                Text(c.selected!.filename),
                TextButton(
                  onPressed: c.uploading ? null : c.clearSelection,
                  child: const Text('Remove selection'),
                ),
              ],
              if (c.selecting)
                const LinearProgressIndicator(
                  semanticsLabel: 'Reading selected photo',
                ),
              if (c.uploading) ...[
                LinearProgressIndicator(
                  value: c.progress,
                  semanticsLabel: 'Uploading Review photo',
                ),
                Text(
                  c.progress != null && c.progress! >= 1
                      ? 'Upload sent. Waiting for confirmation…'
                      : 'Uploading photo…',
                ),
                TextButton(
                  onPressed: c.cancelUpload,
                  child: const Text('Cancel upload'),
                ),
              ],
              OutlinedButton(
                onPressed:
                    widget.dependencies.photoPicker == null ||
                        c.locked ||
                        c.coolingDown ||
                        c.uncertainPhoto ||
                        c.photos.length >= 5
                    ? null
                    : () => c.select(widget.dependencies.photoPicker!),
                child: const Text('Choose photo'),
              ),
              FilledButton(
                onPressed:
                    c.selected == null ||
                        c.locked ||
                        c.coolingDown ||
                        c.uncertainPhoto ||
                        c.photos.length >= 5
                    ? null
                    : c.upload,
                child: const Text('Upload selected photo'),
              ),
              TextButton(
                onPressed: () => context.push('/products/${c.product}/reviews'),
                child: const Text('View Product reviews'),
              ),
            ],
          ],
        );
      },
    );
  }
}
