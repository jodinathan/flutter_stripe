import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

import '../bridge/rpc_messages.dart';
import '../bridge/stripe_js_bridge.dart';
import '../card_element_style.dart';
import '../config.dart';
import '../page/page_source.dart';
import '../stripe_desktop_platform.dart';

const double kDesktopCardFieldDefaultHeight = 48;
const double _kHeaderHeight = 56;
const double _kExpandedMargin = 24;
const Duration _kAnimationDuration = Duration(milliseconds: 200);

/// The desktop `CardField`: a Stripe.js Card Element hosted in a resident
/// webview.
///
/// The webview lives in a permanent [OverlayEntry] anchored to the widget's
/// slot through a [LayerLink]/[CompositedTransformFollower] pair, so the
/// native platform view is **never re-parented** (re-parenting would recreate
/// the WKWebView and kill the page). During `confirm*` calls the overlay
/// expands to (almost) fullscreen so the 3DS challenge — rendered by
/// Stripe.js inside the very same page — has room to breathe, then collapses
/// back to the anchored slot.
class DesktopCardField extends StatefulWidget {
  const DesktopCardField({
    super.key,
    required this.controller,
    this.onCardChanged,
    this.onFocus,
    this.onValidationError,
    this.onReady,
    this.style,
    this.fonts = const <Map<String, String>>[],
    this.placeholder,
    this.enablePostalCode = false,
    this.width,
    this.height = kDesktopCardFieldDefaultHeight,
    this.constraints,
    this.focusNode,
    this.autofocus = false,
    this.dangerouslyUpdateFullCardDetails = false,
    this.challengeTitle = 'Bank verification',
    this.cancelLabel = 'Cancel',
  });

  final CardEditController controller;
  final CardChangedCallback? onCardChanged;

  /// Fired on focus / blur of the Card Element. The Element is a single input
  /// on the web, so the field name is always [CardFieldName.cardNumber] on
  /// focus and `null` on blur.
  final CardFocusCallback? onFocus;

  /// The Stripe.js validation message for what is currently typed (`null` when
  /// valid or empty) — Stripe localises it with the `locale` given to `init`.
  final ValueChanged<String?>? onValidationError;

  /// Fired once the Card Element is mounted on the page: the webview booted,
  /// Stripe.js loaded and the Element is in place. Hosts that keep a loading
  /// state over the field wait for this instead of guessing a delay. Fired
  /// again after every re-mount (style, fonts or publishable key change).
  final VoidCallback? onReady;

  final CardStyle? style;

  /// Stripe.js `elements({fonts})` entries, e.g.
  /// `[{'cssSrc': 'https://…/exo2.css'}]`. Stripe loads them inside its own
  /// iframes, which is the only way an app-bundled face can reach the card
  /// inputs.
  final List<Map<String, String>> fonts;
  final CardPlaceholder? placeholder;
  final bool enablePostalCode;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool dangerouslyUpdateFullCardDetails;

  /// Title shown in the header of the expanded (3DS challenge) overlay.
  final String challengeTitle;

  /// Label of the button that cancels an in-flight confirmation from the
  /// expanded overlay.
  final String cancelLabel;

  @override
  DesktopCardFieldState createState() => DesktopCardFieldState();
}

class DesktopCardFieldState extends State<DesktopCardField>
    with CardFieldContext {
  /// The RPC bridge to the Stripe.js page of this field.
  final StripeJsBridge bridge = StripeJsBridge();

  final LayerLink _link = LayerLink();
  final GlobalKey _slotKey = GlobalKey();
  OverlayEntry? _entry;
  StreamSubscription<PageEvent>? _eventsSubscription;
  late final Widget _webView;
  bool _expanded = false;
  bool _cardMounted = false;
  Future<void> _configQueue = Future<void>.value();

  double get _effectiveHeight =>
      widget.height ?? kDesktopCardFieldDefaultHeight;

  @override
  void initState() {
    super.initState();
    StripeDesktop.instance.attachField(this);
    attachController(widget.controller);
    _webView = _createWebView();
    _eventsSubscription = bridge.events.listen(_onPageEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertOverlay());
    // Configuration is applied by `onWebViewCreated` once the webview exists
    // (the overlay — and therefore the webview — is only inserted after the
    // first frame); `StripeDesktop.initialise` re-applies it if the
    // publishable key changes while the field is mounted.
  }

  @override
  void didUpdateWidget(covariant DesktopCardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      detachController(oldWidget.controller);
      attachController(widget.controller);
    }
    if (widget.style != oldWidget.style ||
        widget.enablePostalCode != oldWidget.enablePostalCode ||
        !_sameFonts(widget.fonts, oldWidget.fonts)) {
      _scheduleReinit();
    }
    _requestOverlayRebuild();
  }

  @override
  void dispose() {
    detachController(widget.controller);
    StripeDesktop.instance.detachField(this);
    _eventsSubscription?.cancel();
    bridge.dispose();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  /// Compares the font lists BY VALUE. `listEquals` would compare the maps by
  /// identity, so a caller that builds the list inside `build` would remount
  /// the Card Element on every frame — losing focus on every keystroke.
  static bool _sameFonts(
    List<Map<String, String>> a,
    List<Map<String, String>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!mapEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// (Re)applies the Stripe.js configuration: re-creates the `Stripe`
  /// instance on the page with the current publishable key and (re)mounts the
  /// Card Element. Called after `Stripe.publishableKey` changes while the
  /// field is mounted.
  Future<void> reinit() {
    _configQueue = _configQueue
        // Keep the queue alive after a failed configuration attempt.
        .catchError((Object _) {})
        .then((_) => _applyConfiguration());
    return _configQueue;
  }

  /// Fire-and-forget [reinit] for call sites that cannot await (lifecycle
  /// hooks): configuration failures are logged instead of becoming unhandled
  /// async errors — the next explicit Stripe call surfaces the real problem.
  void _scheduleReinit() {
    unawaited(
      reinit().catchError((Object error) {
        debugPrint('stripe_desktop: card configuration failed: $error');
      }),
    );
  }

  /// Rebuilds the overlay entry, deferring to the end of the frame when the
  /// framework is mid-build/layout ([didUpdateWidget] runs during build, and
  /// an [OverlayEntry] is not a descendant of this widget).
  void _requestOverlayRebuild() {
    final entry = _entry;
    if (entry == null) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_entry, entry)) entry.markNeedsBuild();
      });
    } else {
      entry.markNeedsBuild();
    }
  }

  /// Expands the overlay to (almost) fullscreen so the 3DS challenge iframe
  /// has room. Called by `confirm*`/`handleNextAction` on [StripeDesktop].
  Future<void> expandForChallenge() async {
    if (_expanded) return;
    _expanded = true;
    _entry?.markNeedsBuild();
    await Future<void>.delayed(_kAnimationDuration);
  }

  /// Collapses the overlay back to the anchored slot.
  Future<void> collapse() async {
    if (!_expanded) return;
    _expanded = false;
    _entry?.markNeedsBuild();
    await Future<void>.delayed(_kAnimationDuration);
  }

  // CardFieldContext -------------------------------------------------------
  // The Card Element lives inside the Stripe iframe; programmatic focus
  // control is not part of the desktop v1 host page protocol.

  @override
  void focus() {}

  @override
  void blur() {}

  @override
  void clear() {}

  @override
  void dangerouslyUpdateCardDetails(CardFieldInputDetails details) {
    throw UnsupportedError(
      'dangerouslyUpdateCardDetails is not supported on desktop: the card '
      'details live inside the Stripe.js iframe.',
    );
  }

  // Internals ---------------------------------------------------------------

  Widget _createWebView() {
    final pageUrl = StripeDesktopConfig.paymentPageUrl;
    return InAppWebView(
      // Mode B: the page hosted by the app backend wins when configured.
      initialUrlRequest: pageUrl == null
          ? null
          : URLRequest(url: WebUri.uri(pageUrl)),
      // Mode A: bundled page loaded on a virtual origin.
      initialData: pageUrl != null
          ? null
          : InAppWebViewInitialData(
              data: stripeDesktopPageHtml,
              baseUrl: WebUri.uri(StripeDesktopConfig.virtualOrigin),
              historyUrl: WebUri.uri(StripeDesktopConfig.virtualOrigin),
            ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        javaScriptEnabled: true,
        supportZoom: false,
        disableContextMenu: false,
        isInspectable: kDebugMode,
      ),
      onWebViewCreated: (controller) {
        bridge.attach(controller);
        // First configuration pass: `call` awaits the page's `ready` signal,
        // so this is safe to schedule right away.
        _scheduleReinit();
      },
    );
  }

  Future<void> _applyConfiguration() async {
    final publishableKey = StripeDesktop.instance.publishableKey;
    if (publishableKey == null || !mounted) return;
    // Too early: the webview has not been created yet. `onWebViewCreated`
    // schedules a fresh pass once the bridge is attached.
    if (!bridge.isAttached) return;
    if (_cardMounted) {
      await bridge.call('unmountCard', const {});
      _cardMounted = false;
    }
    await bridge.call('init', {
      'publishableKey': publishableKey,
      'stripeAccountId': StripeDesktop.instance.stripeAccountId,
      'locale': WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
    });
    final background = widget.style?.backgroundColor;
    await bridge.call('mountCard', {
      'style': cardElementStyleFrom(widget.style),
      'postalCodeEnabled': widget.enablePostalCode,
      'fonts': widget.fonts,
      if (background != null) 'background': cssRgbColor(background),
    });
    _cardMounted = true;
    if (mounted) widget.onReady?.call();
  }

  void _onPageEvent(PageEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case PageEvent.kindCardFocus:
        widget.onFocus?.call(CardFieldName.cardNumber);
      case PageEvent.kindCardBlur:
        widget.onFocus?.call(null);
      case PageEvent.kindCardChange:
        final details = CardFieldInputDetails(
          complete: event.complete ?? false,
          brand: event.brand,
        );
        widget.onValidationError?.call(event.error);
        widget.onCardChanged?.call(details);
        updateCardDetails(details, widget.controller);
    }
  }

  void _cancelChallenge() {
    bridge.cancelPendingCalls('The 3D Secure challenge was canceled.');
    // `confirm*` collapses in its `finally`, but collapse defensively in case
    // the overlay was expanded without an in-flight call.
    unawaited(collapse());
  }

  void _insertOverlay() {
    if (!mounted || _entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    // The visible widget is only the slot the overlay-resident webview is
    // anchored to.
    Widget slot = SizedBox(
      key: _slotKey,
      width: widget.width,
      height: _effectiveHeight,
    );
    if (widget.constraints != null) {
      slot = ConstrainedBox(constraints: widget.constraints!, child: slot);
    }
    return CompositedTransformTarget(link: _link, child: slot);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final slotBox = _slotKey.currentContext?.findRenderObject() as RenderBox?;
    final slotAttached = slotBox != null && slotBox.attached && slotBox.hasSize;
    final slotSize = slotAttached
        ? slotBox.size
        : Size(widget.width ?? 300, _effectiveHeight);
    final screenSize = MediaQuery.sizeOf(overlayContext);
    final expandedSize = Size(
      (screenSize.width - _kExpandedMargin * 2).clamp(0, double.infinity),
      (screenSize.height - _kExpandedMargin * 2).clamp(0, double.infinity),
    );
    final slotOrigin = slotAttached
        ? slotBox.localToGlobal(Offset.zero)
        : Offset.zero;
    final expandedOffset =
        const Offset(_kExpandedMargin, _kExpandedMargin) - slotOrigin;
    final size = _expanded ? expandedSize : slotSize;

    // NOTE: both children stay in the tree in both visual states so that the
    // webview element (a native platform view) is never re-created.
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_expanded,
            child: AnimatedOpacity(
              opacity: _expanded ? 1 : 0,
              duration: _kAnimationDuration,
              child: const ModalBarrier(
                dismissible: false,
                color: Color(0x99000000),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: _expanded ? expandedOffset : Offset.zero,
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedContainer(
                duration: _kAnimationDuration,
                width: size.width,
                height: size.height,
                decoration: _containerDecoration(overlayContext),
                child: Column(
                  children: [
                    _buildHeader(overlayContext),
                    Expanded(child: ClipRect(child: _webView)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext overlayContext) {
    final theme = Theme.of(overlayContext);
    return ClipRect(
      child: AnimatedContainer(
        duration: _kAnimationDuration,
        height: _expanded ? _kHeaderHeight : 0,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: _kHeaderHeight,
          maxHeight: _kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.challengeTitle,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _cancelChallenge,
                  child: Text(widget.cancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _containerDecoration(BuildContext overlayContext) {
    if (_expanded) {
      return BoxDecoration(
        color: Theme.of(overlayContext).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      );
    }
    final style = widget.style;
    final borderColor = style?.borderColor;
    return BoxDecoration(
      color: style?.backgroundColor,
      border: borderColor == null
          ? null
          : Border.all(
              color: borderColor,
              width: (style?.borderWidth ?? 1).toDouble(),
            ),
      borderRadius: style?.borderRadius == null
          ? null
          : BorderRadius.circular(style!.borderRadius!.toDouble()),
    );
  }
}
