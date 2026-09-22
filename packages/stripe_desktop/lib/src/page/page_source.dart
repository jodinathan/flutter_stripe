/// The Stripe.js host page bundled with the package (Mode A).
///
/// The very same HTML can be served by the app backend over HTTPS (Mode B,
/// see `StripeDesktopConfig.paymentPageUrl`); the RPC protocol is identical
/// in both modes. Backend tooling may extract this constant verbatim, so keep
/// it byte-stable.
///
/// Rules: a single inline script with no external dependency other than
/// https://js.stripe.com; the page never receives secrets — only the
/// publishable key, client secrets and billing details, always via RPC after
/// load (never in the query string).
///
/// `mountCard` accepts an optional `fonts` list (Stripe.js `elements({fonts})`
/// entries, e.g. `{cssSrc: 'https://…/exo2.css'}`): the stylesheet is fetched
/// by Stripe INSIDE its own iframes, so a custom face reaches the card inputs
/// without this page ever loading it. It also accepts a `background` CSS
/// color, painted on the page itself: a macOS WKWebView stays OPAQUE WHITE no
/// matter what the host puts behind it, so the field colour has to be applied
/// in here.
const String stripeDesktopPageHtml =
    r'''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://js.stripe.com/v3"></script>
<style>
  html,body{margin:0;background:transparent}
  /* The Element is vertically centred in the slot: the host paints the field
     chrome (fill, border, padding) around the webview, so the page must not
     assume the slot is exactly as tall as the Element. */
  #card{position:absolute;inset:0;display:flex;flex-direction:column;
        justify-content:center;padding:var(--pad,0)}
  #card>*{width:100%}
  /* 3DS challenge: Stripe.js injects its own fullscreen iframe — nothing to style */
</style></head><body><div id="card"></div>
<script>
'use strict';
let stripe, elements, card;
const send = (m) => window.flutter_inappwebview.callHandler('stripeDesktop', m);
const handlers = {
  init: (p) => { stripe = Stripe(p.publishableKey,
      {stripeAccount: p.stripeAccountId || undefined, locale: p.locale || 'auto'}); },
  mountCard: (p) => {
    if (p.background) document.documentElement.style.background = p.background;
    elements = stripe.elements(p.fonts && p.fonts.length ? {fonts: p.fonts} : undefined);
    card = elements.create('card', {style: p.style, hidePostalCode: !p.postalCodeEnabled});
    card.on('change', (e) => send({kind: 'event', event: 'cardChange',
        complete: e.complete, empty: e.empty, brand: e.brand,
        error: e.error ? e.error.message : null}));
    card.on('focus', () => send({kind: 'event', event: 'cardFocus'}));
    card.on('blur', () => send({kind: 'event', event: 'cardBlur'}));
    card.mount('#card');
  },
  createPaymentMethod: (p) => stripe.createPaymentMethod(
      {type: 'card', card, billing_details: p.billingDetails}),
  createToken:      (p) => stripe.createToken(card, p),
  confirmPayment:   (p) => stripe.confirmCardPayment(p.clientSecret,
      p.paymentMethodId ? {payment_method: p.paymentMethodId}
                        : {payment_method: {card, billing_details: p.billingDetails},
                           setup_future_usage: p.setupFutureUsage}),
  confirmSetup:     (p) => stripe.confirmCardSetup(p.clientSecret,
      {payment_method: {card, billing_details: p.billingDetails}}),
  handleNextAction: (p) => stripe.handleNextAction({clientSecret: p.clientSecret}),
  retrievePaymentIntent: (p) => stripe.retrievePaymentIntent(p.clientSecret),
  retrieveSetupIntent:   (p) => stripe.retrieveSetupIntent(p.clientSecret),
  unmountCard: () => { card && card.unmount(); },
};
window.__stripeDesktop = { dispatch: async (req) => {
  try {
    const out = await handlers[req.method](req.params);
    if (out && out.error) send({kind:'response', id: req.id, ok: false, error: {
        type: out.error.type, code: out.error.code, declineCode: out.error.decline_code,
        message: out.error.message, paymentIntent: out.error.payment_intent}});
    else send({kind:'response', id: req.id, ok: true, result: out || {}});
  } catch (e) {
    send({kind:'response', id: req.id, ok: false,
          error: {type: 'api_error', message: String(e)}});
  }
}};
send({kind: 'ready'});
</script></body></html>
''';
