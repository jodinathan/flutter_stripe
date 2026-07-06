# stripe_desktop

macOS implementation of [flutter_stripe](https://pub.dev/packages/flutter_stripe),
running the real Stripe.js inside the system WKWebView. Use the same
`flutter_stripe` API (`CardField`, `Stripe.instance.confirmPayment`, ...) in
your macOS app.

> **Status: experimental.** This package targets feature parity with the
> official web implementation (`flutter_stripe_web`) — the same Stripe.js
> foundation, the same card-payments subset — not with the mobile SDKs.

## How it works

- The Stripe.js **Card Element** is hosted by a tiny HTML page inside a
  resident `WKWebView` (via `flutter_inappwebview`, `AppKitView`).
- A JSON-RPC bridge connects Dart to the page: `CardField` renders the
  Element, `Stripe.instance.confirmPayment(...)` calls
  `stripe.confirmCardPayment(...)` on the page.
- 3D Secure challenges are rendered by Stripe.js inside the very same page;
  the field's overlay expands to fullscreen for the challenge and collapses
  afterwards. The webview is never re-parented (re-parenting would recreate
  the platform view and kill the page).

## Installation

Add both packages to your app:

```yaml
dependencies:
  flutter_stripe: ^13.0.0
  stripe_desktop: ^0.1.0
```

Then register the desktop implementation manually in `main()` before using
`Stripe`. When the package is resolved as a macOS plugin the Flutter tooling
registers it automatically through `dartPluginClass`; the manual call is
idempotent belt-and-braces that works regardless of the tooling's plugin
resolution (e.g. when consuming the package as a non-endorsed
implementation):

```dart
import 'package:stripe_desktop/stripe_desktop.dart';

void main() {
  StripeDesktopPlugin.registerWith();
  Stripe.publishableKey = 'pk_test_...';
  runApp(const MyApp());
}
```

### macOS entitlements

Since the plugin loads Stripe.js from `https://js.stripe.com`, the macOS app
sandbox needs the outgoing-network entitlement in **both**
`macos/Runner/DebugProfile.entitlements` and
`macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Page modes

The Card Element is hosted by a small HTML page. There are two ways to load
it:

### Mode A (default) — bundled page + virtual origin

The page bundled with this package (`stripeDesktopPageHtml`) is loaded with
`loadData`, using `StripeDesktopConfig.virtualOrigin` as `baseUrl`/
`historyUrl`. Zero setup for the app developer.

> **Live-mode verdict pending.** Test keys (`pk_test_...`) work with the
> virtual origin. Whether Stripe.js accepts a virtual (non-served) origin
> with **live** keys has not been verified end-to-end yet — until it is,
> production apps should use Mode B.

### Mode B — self-hosted page (recommended for production)

Serve the exact same HTML (`stripeDesktopPageHtml`, byte-for-byte — the RPC
protocol must be identical in both modes) from your backend over HTTPS and
point the plugin at it:

```dart
StripeDesktopConfig.paymentPageUrl =
    Uri.parse('https://your.app/pay/stripe-desktop');
```

When set, `paymentPageUrl` always wins over the bundled page.

Recommended Content-Security-Policy for the hosted page (serving it with the
right CSP is the integrator's responsibility):

```
Content-Security-Policy: default-src 'none';
  script-src https://js.stripe.com 'unsafe-inline';
  frame-src https://js.stripe.com https://hooks.stripe.com;
  connect-src https://api.stripe.com https://js.stripe.com https://m.stripe.network https://r.stripe.com;
  style-src 'unsafe-inline'; img-src data: https://*.stripe.com
```

(`hooks.stripe.com` hosts the 3DS challenge iframe; `m.stripe.network` and
`r.stripe.com` are Stripe.js telemetry/Radar endpoints.)

## Feature matrix (v1 — web parity)

| `StripePlatform` method | v1 | Stripe.js foundation |
|---|---|---|
| `initialise` | ✅ | `Stripe(pk, {stripeAccount, locale})` |
| `buildCard` (→ `CardField`) | ✅ | Card Element mounted in the webview |
| `createPaymentMethod` | ✅ | `stripe.createPaymentMethod({card: element})` |
| `createToken` | ✅ | `stripe.createToken(element, params)` |
| `confirmPayment` | ✅ | `stripe.confirmCardPayment(...)` (automatic 3DS) |
| `confirmSetupIntent` | ✅ | `stripe.confirmCardSetup(...)` |
| `handleNextAction` / `handleNextActionForSetupIntent` | ✅ | `stripe.handleNextAction({clientSecret})` |
| `retrievePaymentIntent` / `retrieveSetupIntent` | ✅ | `stripe.retrievePaymentIntent(...)` / `stripe.retrieveSetupIntent(...)` |
| Everything else (PaymentSheet, CustomerSheet, Apple/Google/PlatformPay, wallets, Financial Connections, ACH, Radar, `dangerouslyUpdateCardDetails`, `createTokenForCVCUpdate`, aubecs, AddressSheet, EmbeddedPaymentElement, ...) | ❌ throws `StripeDesktopUnsupportedError` | same pattern as `WebUnsupportedError` in `flutter_stripe_web` |

## Known limitations

- **No PaymentSheet, no wallets.** Apple Pay / Google Pay / PlatformPay are
  not available on desktop; filter them out of your payment method selector.
- **`confirm*` requires a mounted `CardField`.** The confirmation runs inside
  the page that hosts the Card Element, so
  `confirmPayment`/`confirmSetupIntent`/`handleNextAction` throw a
  `StripeError` when no card field is mounted.
- **macOS platform-view gesture caveats.** Platform views on macOS have
  documented gesture/focus limitations; typing and scrolling inside the
  webview work with the pinned `flutter_inappwebview` version, but exotic
  gesture combinations (e.g. nested scrollables over the field) may behave
  differently than native Flutter widgets.
- **Mode A live-mode verdict pending** (see above): use
  `StripeDesktopConfig.paymentPageUrl` in production until the virtual-origin
  spike is verified with live keys.
- **One active card field.** The last mounted `CardField` wins; multiple
  simultaneously mounted fields are not supported.

## PCI note

The card number never touches your Dart code or your backend: the Card
Element input lives in an iframe served from the `js.stripe.com` origin,
exactly like the official web implementation (this keeps integrations in
SAQ A-EP territory). Only the publishable key, client secrets and billing
details travel over the RPC bridge. When self-hosting the page (Mode B),
serving it over HTTPS with the recommended CSP is the integrator's
responsibility.

## Troubleshooting

- **The field stays blank / `stripe_desktop_timeout` errors**: the webview
  could not reach `https://js.stripe.com`. In a sandboxed app this is almost
  always the missing `com.apple.security.network.client` entitlement (see
  Installation). Check both the Debug and Release entitlement files.
- **`stripe_desktop requires a mounted CardField`**: `confirmPayment` &
  friends need the card field to be on screen; keep it mounted until the
  confirmation completes.
- **Inspecting the page**: in debug builds the webview is inspectable via
  Safari → Develop.
