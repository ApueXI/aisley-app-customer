import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/chat_media/draft_controller.dart';
import 'package:aisley_mobile_buyer/features/messaging/presentation/message_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chat_media_fake.dart';

void main() {
  late MediaFake repository;
  late ChatMediaDraftController media;
  var sends = 0;
  setUp(() {
    repository = MediaFake();
    media = ChatMediaDraftController(repository);
    sends = 0;
  });
  tearDown(() => media.dispose());

  Widget app({
    double scale = 1,
    bool pending = false,
    String? fieldError,
    Widget? contextAction,
  }) => MaterialApp(
    theme: buyerTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: MessageThreadView(
      title: 'Synthetic Shop',
      rows: const [],
      draft: '',
      changed: (_) {},
      clearDraft: () {},
      send: () => sends++,
      retry: () {},
      refresh: () {},
      loadMore: () {},
      displayed: (_) {},
      loading: false,
      paging: false,
      sending: false,
      allowed: true,
      pending: pending,
      conflict: false,
      more: false,
      reviewConflict: () {},
      arrivals: 0,
      acknowledge: () {},
      media: media,
      mediaContext: const {'channel': 'shop'},
      compactComposer: true,
      fieldError: fieldError,
      contextAction: contextAction,
    ),
  );

  testWidgets(
    'long context leaves room for history and composer above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        app(
          scale: 2,
          contextAction: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                List.filled(
                  6,
                  'Long synthetic Product context label',
                ).join(' '),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final send = find.widgetWithText(FilledButton, 'Send');
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(360));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'compact chat composer fits $width at text scale $scale and sends image-only',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(app(scale: scale));
          await tester.pumpAndSettle();
          final send = find.widgetWithText(FilledButton, 'Send');
          final addImage = find.byTooltip(
            'Add image · JPEG or PNG, up to 8 MB each, up to 5 images',
          );
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(addImage).height, greaterThanOrEqualTo(48));
          if (width == 390 && scale == 1) {
            expect(
              (tester.getBottomRight(send).dy -
                      tester.getBottomRight(find.byType(TextFormField)).dy)
                  .abs(),
              lessThan(2),
            );
          } else {
            expect(
              tester.getTopLeft(send).dy,
              greaterThanOrEqualTo(
                tester.getBottomRight(find.byType(TextFormField)).dy,
              ),
            );
          }
          await tester.tap(addImage);
          await tester.pumpAndSettle();
          expect(repository.uploads, 1);
          expect(media.ready, isTrue);
          await tester.ensureVisible(send);
          await tester.tap(send);
          await tester.pumpAndSettle();
          expect(sends, 1);
          expect(find.text('Enter a value.'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'unconfirmed sends disable editing and expose exact retry without upload',
    (tester) async {
      await tester.pumpWidget(app(pending: true));
      await tester.pumpAndSettle();
      expect(find.text('Retry exact message'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
            .onPressed,
        isNull,
      );
      final image = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip(
                'Add image · JPEG or PNG, up to 8 MB each, up to 5 images',
              ),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(image.onPressed, isNull);
      expect(repository.uploads, 0);
      expect(sends, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'compact input keeps server field feedback and blocks empty text sends',
    (tester) async {
      await tester.pumpWidget(app(fieldError: 'Review this message.'));
      await tester.pumpAndSettle();
      expect(find.text('Review this message.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      expect(sends, 0);
      expect(repository.uploads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
