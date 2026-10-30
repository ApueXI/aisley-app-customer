import 'dart:convert';

import 'package:aisley_mobile_buyer/core/networking/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/commerce_harness.dart';
import '../support/image_samples.dart';

void main() {
  late CommerceHarness h;
  setUp(() async {
    h = CommerceHarness();
    await h.initialize();
    h.adapter.requests.clear();
  });
  tearDown(() => h.dispose());

  test(
    'approved external product image is public, bounded to host and cached',
    () async {
      final d = h.dependencies();
      addTearDown(d.discovery!.dispose);
      addTearDown(d.savedStatus!.dispose);
      final bytes = base64Decode(buyerImageSamples.first['bytes']!);
      h.reply = (_) => ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
      const url = 'https://images.unsplash.com/photo-synthetic?w=320&fit=crop';
      expect(await d.discovery!.publicMedia(url), bytes);
      expect(await d.discovery!.publicMedia(url), bytes);
      final request = h.adapter.requests.single;
      expect(request.uri.toString(), url);
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(anyOf(contains('authorization'), contains('cookie'))),
      );
      expect(request.followRedirects, isFalse);
      expect(request.headers['Accept'], 'image/*');
    },
  );

  for (final url in [
    'http://images.unsplash.com/photo-synthetic',
    'https://images.unsplash.com:8443/photo-synthetic',
    'https://user@images.unsplash.com/photo-synthetic',
    'https://images.unsplash.com/photo-synthetic#fragment',
    'https://images.unsplash.com.evil.invalid/photo-synthetic',
    'https://arbitrary.invalid/photo-synthetic',
    '//images.unsplash.com/photo-synthetic',
  ]) {
    test('unsupported public image origin is rejected: $url', () async {
      final d = h.dependencies();
      addTearDown(d.discovery!.dispose);
      addTearDown(d.savedStatus!.dispose);
      await expectLater(
        Future.sync(() => d.discovery!.publicMedia(url)),
        throwsA(isA<ApiFailure>()),
      );
      expect(h.adapter.requests, isEmpty);
    });
  }

  for (final type in [null, 'text/html', 'application/json']) {
    test(
      'external product image rejects non-image content type $type',
      () async {
        final d = h.dependencies();
        addTearDown(d.discovery!.dispose);
        addTearDown(d.savedStatus!.dispose);
        h.reply = (_) => ResponseBody.fromBytes(
          [1, 2, 3],
          200,
          headers: {
            if (type != null) Headers.contentTypeHeader: [type],
          },
        );
        await expectLater(
          d.discovery!.publicMedia(
            'https://images.unsplash.com/photo-synthetic',
          ),
          throwsA(isA<ApiFailure>()),
        );
        expect(h.adapter.requests, hasLength(1));
      },
    );
  }

  test('external redirects are not followed and private media cannot use external origin', () async {
    final d = h.dependencies();
    addTearDown(d.discovery!.dispose);
    addTearDown(d.savedStatus!.dispose);
    h.reply = (_) => ResponseBody.fromBytes(
      [],
      302,
      headers: {
        'location': ['https://arbitrary.invalid/private'],
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
    const url = 'https://images.unsplash.com/photo-synthetic';
    await expectLater(
      d.discovery!.publicMedia(url),
      throwsA(isA<ApiFailure>()),
    );
    expect(h.adapter.requests, hasLength(1));
    await expectLater(
      Future.sync(
        () => d.discovery!.privateMedia(url, h.session.verifiedLease!),
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(h.adapter.requests, hasLength(1));
  });
}
