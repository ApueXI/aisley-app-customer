import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/theme.dart';

void main() {
  test(
    'Buyer retains its light palette and supplies readable dark theme pairs',
    () {
      final light = buyerTheme();
      expect(light.colorScheme.primary, buyerPink);
      expect(light.colorScheme.secondary, buyerPurple);
      expect(light.colorScheme.surface, Colors.white);
      expect(light.scaffoldBackgroundColor, buyerCanvas);
      for (final brightness in Brightness.values) {
        final theme = buyerTheme(brightness);
        final scheme = theme.colorScheme;
        expect(theme.brightness, brightness);
        for (final (foreground, background) in [
          (scheme.onSurface, scheme.surface),
          (scheme.onSurfaceVariant, scheme.surface),
          (scheme.onPrimary, scheme.primary),
          (scheme.onSecondary, scheme.secondary),
          (scheme.onPrimaryContainer, scheme.primaryContainer),
          (scheme.onSecondaryContainer, scheme.secondaryContainer),
          (scheme.error, scheme.surface),
        ]) {
          final a = foreground.computeLuminance(),
              b = background.computeLuminance();
          final ratio = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$brightness $foreground on $background',
          );
        }
        expect(theme.cardTheme.color, scheme.surface);
        expect(theme.dialogTheme.backgroundColor, scheme.surface);
        expect(theme.bottomSheetTheme.backgroundColor, scheme.surface);
        expect(theme.inputDecorationTheme.fillColor, scheme.surface);
      }
    },
  );
}
