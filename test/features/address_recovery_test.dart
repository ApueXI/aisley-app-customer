import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/features/addresses/data/psgc_loader.dart';

import 'package:aisley_mobile_buyer/features/addresses/presentation/psgc_fields.dart';

import 'phase_2_location_test.dart' show SelectorAssets;

// Exercise the real AssetBundle string cache, including successful reads whose
// bytes fail JSON/hierarchy validation in PsgcLoader.
class RecoveringAssets extends CachingAssetBundle {
  final source = SelectorAssets();
  bool corruptIndex = false, corruptRegion = false;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    reads++;
    final corrupt = key.endsWith('list-of-all-regions.json')
        ? corruptIndex
        : corruptRegion;
    final text = corrupt ? '{broken' : await source.loadString(key);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

class DelayedAssets extends SelectorAssets {
  final pending = Completer<String>();
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      key.contains('0100000000-')
      ? pending.future
      : super.loadString(key, cache: cache);
}

Finder menu(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownMenu<String> && (widget.label as Text).data == label,
);
Finder field(String label) =>
    find.descendant(of: menu(label), matching: find.byType(TextField));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Retry reloads a corrupt cached PSGC index and caches validated data',
    () async {
      final assets = RecoveringAssets()..corruptIndex = true;
      final loader = PsgcLoader(bundle: assets);
      await expectLater(loader.regions(), throwsFormatException);
      assets.corruptIndex = false;
      expect(await loader.regions(), hasLength(18));
      final reads = assets.reads;
      await loader.regions();
      expect(assets.reads, reads);
    },
  );

  test(
    'Retry reloads a corrupt cached region without invalidating the index',
    () async {
      final assets = RecoveringAssets()..corruptRegion = true;
      final loader = PsgcLoader(bundle: assets);
      final region = (await loader.regions()).first;
      await expectLater(loader.dataset(region), throwsFormatException);
      assets.corruptRegion = false;
      expect((await loader.dataset(region)).children, isNotEmpty);
      final reads = assets.reads;
      await loader.regions();
      await loader.dataset(region);
      expect(assets.reads, reads);
    },
  );
  testWidgets(
    'changing Region during an offline load rejects its late failure',
    (tester) async {
      final assets = DelayedAssets();
      final changes = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PsgcFields(
                loader: PsgcLoader(bundle: assets),
                onChange: changes.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(field('Region'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Region'), 'Region I (Ilocos Region)');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Region I (Ilocos Region)').last);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<DropdownMenu<String>>(menu('Region')).enabled,
        isTrue,
      );
      await tester.tap(field('Region'));
      await tester.pump();
      await tester.enterText(field('Region'), 'National Capital');
      await tester.pumpAndSettle();
      await tester.tap(find.text('National Capital Region (NCR)').last);
      await tester.pumpAndSettle();
      assets.pending.completeError(const FormatException('Old dataset failed'));
      await tester.pumpAndSettle();
      expect(find.text('Retry address choices'), findsNothing);
      expect(
        tester.widget<DropdownMenu<String>>(menu('Province')).enabled,
        isTrue,
      );
      expect(changes.last['region'], 'National Capital Region (NCR)');
      expect(changes.last['barangay'], isEmpty);
    },
  );

  testWidgets('saved NCR hierarchy recovers after corrupt asset Retry', (
    tester,
  ) async {
    final assets = RecoveringAssets()..corruptRegion = true;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: form,
              child: PsgcFields(
                loader: PsgcLoader(bundle: assets),
                onChange: (_) {},
                initialValues: const {
                  'region': 'National Capital Region (NCR)',
                  'province': 'National Capital Region (NCR)',
                  'city_municipality': 'City',
                  'barangay': 'Barangay',
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    assets.corruptRegion = false;
    await tester.tap(find.text('Retry address choices'));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isTrue);
    expect(find.text('Retry address choices'), findsNothing);
    // Editing a selected parent, even to an exact searchable name, invalidates
    // every dependent selection and cannot silently restore them.
    await tester.ensureVisible(field('Province'));
    await tester.tap(field('Province'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Province'), 'National Capital');
    await tester.pumpAndSettle();
    await tester.enterText(field('Province'), 'National Capital Region (NCR)');
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    expect(
      tester
          .widget<DropdownMenu<String>>(menu('City / Municipality'))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester.widget<DropdownMenu<String>>(menu('Barangay')).controller!.text,
      isEmpty,
    );
  });
}
