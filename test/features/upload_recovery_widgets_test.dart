import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/app_dependencies.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';
import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:aisley_mobile_buyer/core/platform/trusted_launcher.dart';
import 'package:aisley_mobile_buyer/features/account/data/photo_picker_adapter.dart';
import 'package:aisley_mobile_buyer/features/account/presentation/photo_screen.dart';
import 'package:aisley_mobile_buyer/features/reviews/presentation/review_composer_screen.dart';

import '../support/account_fake.dart';
import '../support/communication_harness.dart';
import '../support/fakes.dart';

class SelectionPicker extends PhotoPickerAdapter {
  SelectionPicker(this.image);
  PickedBuyerImage? image;
  @override
  Future<PickedBuyerImage?> pick({bool review = false}) async => image;
  @override
  Future<PickerRecovery> recoverInterruptedSelection() async =>
      PickerRecovery.none;
}

void main() {
  late CommunicationHarness h;
  late FakeAccountRepository repo;
  late SelectionPicker picker;
  late AppDependencies deps;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
  );
  setUp(() async {
    h = CommunicationHarness();
    await h.initialize();
    repo = FakeAccountRepository()..onPhoto = () async => png;
    picker = SelectionPicker(
      PickedBuyerImage(
        bytes: png,
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
    );
    deps = AppDependencies(
      config: testConfig,
      auth: h.auth,
      policies: h.policies,
      session: h.session,
      launcher: TrustedLauncher(testConfig),
      accounts: repo,
      photoPicker: picker,
    );
  });
  tearDown(() {
    deps.profilePhoto.dispose();
    h.dispose();
  });
  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }

  Future<void> show(
    WidgetTester tester,
    Widget child,
    Size size, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: buyerTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets(
      'profile selection/cancel/uncertainty survives remount at $size',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(
          tester,
          PhotoScreen(dependencies: deps),
          size,
          scale: size.width == 320 ? 2 : 1,
        );
        await tap(tester, 'Choose a photo');
        await tester.pumpAndSettle();
        expect(find.text('Upload selected photo'), findsOneWidget);
        await tap(tester, 'Upload selected photo');
        await tester.pumpAndSettle();
        await tap(tester, 'Cancel');
        await tester.pumpAndSettle();
        expect(repo.uploads, 0);
        expect(find.text('Upload selected photo'), findsOneWidget);
        picker.image = null;
        await tap(tester, 'Choose a photo');
        await tester.pumpAndSettle();
        expect(find.text('Upload selected photo'), findsOneWidget);
        await tap(tester, 'Remove selection');
        expect(find.text('Upload selected photo'), findsNothing);
        picker.image = PickedBuyerImage(
          bytes: png,
          filename: 'photo.png',
          mimeType: 'image/png',
        );
        await tap(tester, 'Choose a photo');
        repo.onUpload = () async {
          await repo.uploadCancellation!.whenCancel;
          throw const ApiFailure(FailureKind.cancelled);
        };
        await tap(tester, 'Upload selected photo');
        await tester.pumpAndSettle();
        await tap(tester, 'Upload');
        await tester.pump();
        final button = find.widgetWithText(TextButton, 'Cancel upload');
        await tester.ensureVisible(button);
        final rect = tester.getRect(button);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.uploads, 1);
        expect(find.text('Upload selected photo'), findsNothing);
        expect(deps.profilePhoto.requiresReconciliation, isTrue);
        expect(find.text('Refresh current photo'), findsOneWidget);
        repo.onAccount = () async =>
            throw const ApiFailure(FailureKind.offline);
        await show(
          tester,
          PhotoScreen(key: const ValueKey('reopened'), dependencies: deps),
          size,
        );
        expect(deps.profilePhoto.requiresReconciliation, isTrue);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Choose a photo'),
              )
              .onPressed,
          isNull,
        );
        repo.onAccount = null;
        await tap(tester, 'Refresh current photo');
        await tester.pumpAndSettle();
        expect(deps.profilePhoto.requiresReconciliation, isFalse);
        expect(repo.uploads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'profile confirmation after account loss cannot submit the captured file',
    (tester) async {
      await show(tester, PhotoScreen(dependencies: deps), const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tap(tester, 'Choose a photo');
      await tester.pumpAndSettle();
      await tap(tester, 'Upload selected photo');
      await tester.pumpAndSettle();
      await h.session.signOut();
      await tester.pump();
      await tap(tester, 'Upload');
      await tester.pumpAndSettle();
      expect(repo.uploads, 0);
      expect(find.text('Upload selected photo'), findsNothing);
    },
  );
  testWidgets(
    'Review cancel retains text and committed photos; failed read keeps upload disabled',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = h.state.review(customerId, otherId);
      c.draft = 'Confirmed Review';
      await tester.runAsync(c.submit);
      await show(
        tester,
        ReviewComposerScreen(
          dependencies: h.dependencies(picker: picker),
          controller: c,
        ),
        const Size(320, 640),
        scale: 2,
      );
      await tester.runAsync(() => c.select(picker));
      await tester.pumpAndSettle();
      expect(find.text('photo.png'), findsOneWidget);
      final response = Completer<ResponseBody>();
      h.reply = (_) => response.future;
      final uploadButton = find.widgetWithText(
        FilledButton,
        'Upload selected photo',
      );
      await tester.ensureVisible(uploadButton);
      await tester.runAsync(() async {
        await tester.tap(uploadButton);
        for (
          var i = 0;
          i < 100 &&
              h.adapter.requests
                  .where((r) => r.uri.path.endsWith('/images'))
                  .isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.pump();
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/images')).length,
        1,
      );
      await tap(tester, 'Cancel upload');
      await tester.runAsync(() async {
        response.complete(
          jsonReply(fixture('product-review-ratings', 'op-053'), status: 201),
        );
        for (var i = 0; i < 100 && c.uploading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      expect(c.uploading, isFalse);
      await tester.pumpAndSettle();
      expect(c.selected, isNull);
      expect(c.uncertainPhoto, isTrue);
      expect(find.textContaining('Review text is confirmed'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Choose photo'),
            )
            .onPressed,
        isNull,
      );
      h.reply = (_) => jsonReply({}, status: 422);
      final checkButton = find.text('Check published Review / photos');
      await tester.ensureVisible(checkButton);
      await tester.runAsync(() async {
        await tester.tap(checkButton);
        for (var i = 0; i < 100 && c.reconciling; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.pumpAndSettle();
      expect(c.uncertainPhoto, isTrue);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/images')).length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
