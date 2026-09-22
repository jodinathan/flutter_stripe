import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_desktop/src/card_element_style.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

void main() {
  group('cardElementStyleFrom', () {
    test('a null style produces empty base/invalid variants', () {
      expect(cardElementStyleFrom(null), {
        'base': <String, dynamic>{},
        'invalid': <String, dynamic>{},
      });
    });

    test('translates the text-level CardStyle properties', () {
      final style = CardStyle(
        textColor: const Color(0xFF112233),
        fontSize: 14,
        placeholderColor: const Color(0xFF9E9E9E),
        textErrorColor: const Color(0xFFB00020),
      );

      expect(cardElementStyleFrom(style), {
        'base': {
          'color': 'rgb(17, 34, 51)',
          'fontSize': '14px',
          '::placeholder': {'color': 'rgb(158, 158, 158)'},
        },
        'invalid': {'color': 'rgb(176, 0, 32)'},
      });
    });

    test('omits unset properties instead of sending nulls', () {
      final style = CardStyle(fontSize: 16);
      expect(cardElementStyleFrom(style), {
        'base': {'fontSize': '16px'},
        'invalid': <String, dynamic>{},
      });
    });

    test('container-level properties (background/border) are not forwarded '
        'to the Element', () {
      final style = CardStyle(
        backgroundColor: const Color(0xFFFFFFFF),
        borderColor: const Color(0xFF000000),
        borderWidth: 2,
        borderRadius: 8,
        cursorColor: const Color(0xFF0000FF),
      );
      expect(cardElementStyleFrom(style), {
        'base': <String, dynamic>{},
        'invalid': <String, dynamic>{},
      });
    });
  });

  group('fontFamily', () {
    test('forwards a CSS family list to the base style', () {
      final style = CardStyle(fontFamily: "'Exo 2', sans-serif");
      expect(
        cardElementStyleFrom(style),
        {
          'base': {'fontFamily': "'Exo 2', sans-serif"},
          'invalid': <String, dynamic>{},
        },
      );
    });

    test('an empty family is dropped rather than sent as ""', () {
      expect(cardElementStyleFrom(CardStyle(fontFamily: '')), {
        'base': <String, dynamic>{},
        'invalid': <String, dynamic>{},
      });
    });
  });

  group('cssRgbColor', () {
    test('formats an opaque color as rgb()', () {
      expect(cssRgbColor(const Color(0xFF336699)), 'rgb(51, 102, 153)');
    });

    test('drops the alpha channel', () {
      expect(cssRgbColor(const Color(0x80336699)), 'rgb(51, 102, 153)');
    });

    test('handles the channel extremes', () {
      expect(cssRgbColor(const Color(0xFF000000)), 'rgb(0, 0, 0)');
      expect(cssRgbColor(const Color(0xFFFFFFFF)), 'rgb(255, 255, 255)');
    });
  });
}
