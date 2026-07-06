/// macOS implementation of flutter_stripe, running Stripe.js in a WKWebView.
library;

import 'package:stripe_platform_interface/stripe_platform_interface.dart';

import 'src/stripe_desktop_platform.dart';

export 'src/bridge/rpc_messages.dart';
export 'src/bridge/stripe_js_bridge.dart';
export 'src/card_element_style.dart';
export 'src/config.dart';
export 'src/errors.dart';
export 'src/mapping.dart';
export 'src/page/page_source.dart';
export 'src/stripe_desktop_platform.dart';
export 'src/widgets/desktop_card_field.dart';

/// Registration entry point of the plugin.
class StripeDesktopPlugin {
  /// Registers [StripeDesktop] as the [StripePlatform] implementation.
  ///
  /// Called automatically by the Flutter tooling through the
  /// `dartPluginClass` declaration. Apps are advised to also call this
  /// manually in `main()` before using `Stripe` (belt and suspenders — the
  /// call is idempotent and does not depend on the tooling's plugin
  /// resolution).
  static void registerWith() {
    StripePlatform.instance = StripeDesktop.instance;
  }
}
