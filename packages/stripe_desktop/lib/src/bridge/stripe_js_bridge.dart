import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

import '../errors.dart';
import 'rpc_messages.dart';

/// JSON-RPC bridge between Dart and the Stripe.js host page running inside
/// an [InAppWebView].
///
/// Dart -> page calls go through `window.__stripeDesktop.dispatch(...)` via
/// `evaluateJavascript`; page -> Dart messages come back through the
/// `stripeDesktop` JavaScript handler.
class StripeJsBridge {
  static const _handlerName = 'stripeDesktop';

  /// How long a single RPC call may take. 3DS challenges are slow, hence the
  /// generous timeout.
  static const callTimeout = Duration(seconds: 90);

  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _events = StreamController<PageEvent>.broadcast();
  var _ready = Completer<void>();
  int _nextId = 0;
  bool _disposed = false;
  InAppWebViewController? _controller;

  /// Spontaneous events emitted by the page (`ready`, `cardChange`).
  Stream<PageEvent> get events => _events.stream;

  /// Completes when the page reported that Stripe.js and the RPC dispatcher
  /// are loaded.
  Future<void> get ready => _ready.future;

  /// Whether the bridge is attached to a live webview controller. Calls made
  /// while detached throw `stripe_desktop_bridge_detached` immediately.
  bool get isAttached => !_disposed && _controller != null;

  /// Attaches the bridge to a freshly created webview controller and
  /// registers the JavaScript handler the page posts messages to.
  void attach(InAppWebViewController controller) {
    _controller = controller;
    // The page reloads from scratch on (re)navigation, so a new attach means
    // waiting for a fresh `ready` signal.
    if (_ready.isCompleted) {
      _ready = Completer<void>();
    }
    controller.addJavaScriptHandler(
      handlerName: _handlerName,
      callback: (args) {
        if (_disposed) return null;
        // callHandler arguments arrive as a List whose first element is the
        // message map; depending on the platform decoder it may come through
        // as Map<dynamic, dynamic>, so cast defensively.
        final msg = args.isNotEmpty
            ? asStringKeyedMap(args.first)
            : const <String, dynamic>{};
        switch (msg['kind']) {
          case 'ready':
            if (!_ready.isCompleted) _ready.complete();
            _events.add(const PageEvent.ready());
          case 'event':
            _events.add(PageEvent.fromJson(msg));
          case 'response':
            final id = (msg['id'] as num?)?.toInt();
            final completer = _pending.remove(id);
            if (completer != null && !completer.isCompleted) {
              completer.complete(msg);
            }
        }
        return null;
      },
    );
  }

  /// Calls [method] on the Stripe.js host page and returns the raw `result`
  /// object of the response.
  ///
  /// Throws the mapped [StripeException]/[StripeError] when the page reports
  /// a Stripe.js error, and a [StripeError] on timeout or when the bridge is
  /// not attached to a webview.
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> params,
  ) async {
    final controller = _controller;
    if (_disposed || controller == null) {
      throw const StripeError<String>(
        code: 'stripe_desktop_bridge_detached',
        message:
            'stripe_desktop: the Stripe.js page is not attached '
            '(is a CardField mounted?)',
      );
    }
    await _ready.future;
    final request = RpcRequest(id: _nextId++, method: method, params: params);
    final completer = Completer<Map<String, dynamic>>();
    _pending[request.id] = completer;
    await controller.evaluateJavascript(
      source:
          'window.__stripeDesktop.dispatch(${jsonEncode(request.toJson())})',
    );
    Map<String, dynamic> response;
    try {
      response = await completer.future.timeout(callTimeout);
    } on TimeoutException {
      _pending.remove(request.id);
      throw StripeError<String>(
        code: 'stripe_desktop_timeout',
        message:
            'stripe_desktop: the Stripe.js page did not answer "$method" '
            'within ${callTimeout.inSeconds}s',
      );
    }
    if (response['ok'] != true) {
      throw stripeExceptionFrom(asStringKeyedMap(response['error']));
    }
    return asStringKeyedMap(response['result']);
  }

  /// Completes every in-flight call with a [StripeException] carrying
  /// [FailureCode.Canceled]. Used when the user dismisses the expanded
  /// challenge overlay.
  void cancelPendingCalls([String? message]) {
    _failAllPending(
      StripeException(
        error: LocalizedErrorMessage(
          code: FailureCode.Canceled,
          message: message ?? 'The operation was canceled by the user.',
        ),
      ),
    );
  }

  /// Detaches from the webview: cancels every in-flight call, removes the
  /// JavaScript handler, closes the event stream and drops the controller.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _failAllPending(
      StripeException(
        error: const LocalizedErrorMessage(
          code: FailureCode.Canceled,
          message:
              'stripe_desktop: the card field was disposed while the '
              'operation was in flight.',
        ),
      ),
    );
    _controller?.removeJavaScriptHandler(handlerName: _handlerName);
    _controller = null;
    _events.close();
  }

  void _failAllPending(Object error) {
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }
}
