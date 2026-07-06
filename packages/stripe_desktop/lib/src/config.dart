/// Global configuration for the `stripe_desktop` plugin.
///
/// The plugin can load the Stripe.js host page in two modes:
///
/// - **Mode A (default)**: the HTML page bundled with this package is loaded
///   with `loadData` using [virtualOrigin] as `baseUrl`/`historyUrl`. This
///   requires zero setup from the app developer.
/// - **Mode B**: the app serves the very same page over HTTPS from its own
///   backend and points [paymentPageUrl] at it. When set, it always wins.
abstract final class StripeDesktopConfig {
  /// Mode B: HTTPS URL of the payment page served by the app backend.
  ///
  /// When set, the desktop card field loads this URL instead of the bundled
  /// page. The remote page must serve the exact same HTML this package
  /// bundles (see `stripeDesktopPageHtml`) so the RPC protocol is identical
  /// in both modes.
  static Uri? paymentPageUrl;

  /// Mode A: virtual origin used as `baseUrl`/`historyUrl` when loading the
  /// bundled page with `loadData`.
  static Uri virtualOrigin = Uri.parse('https://stripe-desktop.invalid/pay');
}
