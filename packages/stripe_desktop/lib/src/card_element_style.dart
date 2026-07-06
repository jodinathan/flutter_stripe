/// Pure-Dart translation of the platform interface [CardStyle] into the
/// Stripe.js Card Element `style` object, kept free of widget/webview
/// dependencies so it can be unit tested.
library;

import 'dart:ui' show Color;

import 'package:stripe_platform_interface/stripe_platform_interface.dart';

/// Translates [CardStyle] into the Stripe.js Card Element `style` object
/// (https://docs.stripe.com/js/appendix/style).
///
/// Only the text-level properties are forwarded to the Element: background
/// and border are painted by the Flutter container around the webview — the
/// Element itself does not paint a background.
Map<String, dynamic> cardElementStyleFrom(CardStyle? style) {
  final base = <String, dynamic>{};
  final invalid = <String, dynamic>{};
  if (style != null) {
    final textColor = style.textColor;
    if (textColor != null) base['color'] = cssRgbColor(textColor);
    final fontSize = style.fontSize;
    if (fontSize != null) base['fontSize'] = '${fontSize}px';
    final placeholderColor = style.placeholderColor;
    if (placeholderColor != null) {
      base['::placeholder'] = {'color': cssRgbColor(placeholderColor)};
    }
    final textErrorColor = style.textErrorColor;
    if (textErrorColor != null) invalid['color'] = cssRgbColor(textErrorColor);
  }
  return {'base': base, 'invalid': invalid};
}

/// Formats [color] as a CSS `rgb(r, g, b)` string. The alpha channel is
/// intentionally dropped: the Card Element text is always fully opaque.
String cssRgbColor(Color color) {
  final argb = color.toARGB32();
  final red = (argb >> 16) & 0xFF;
  final green = (argb >> 8) & 0xFF;
  final blue = argb & 0xFF;
  return 'rgb($red, $green, $blue)';
}
