/// Plain Dart envelopes for the JSON-RPC protocol between the Dart side and
/// the Stripe.js host page. No code generation involved.
library;

/// Converts a loosely typed map coming from the webview JavaScript handler
/// (which may be a `Map<dynamic, dynamic>`) into a `Map<String, dynamic>`.
Map<String, dynamic> asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

/// A single Dart -> page call of a Stripe.js method.
class RpcRequest {
  const RpcRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  factory RpcRequest.fromJson(Map<String, dynamic> json) => RpcRequest(
    id: (json['id'] as num).toInt(),
    method: json['method'] as String,
    params: asStringKeyedMap(json['params']),
  );

  /// Correlates request and response (monotonic counter).
  final int id;

  /// One of: `init`, `mountCard`, `createPaymentMethod`, `createToken`,
  /// `confirmPayment`, `confirmSetup`, `handleNextAction`,
  /// `retrievePaymentIntent`, `retrieveSetupIntent`, `unmountCard`.
  final String method;

  /// Method arguments. Never contains secrets; only the publishable key,
  /// client secrets and billing details travel through the bridge.
  final Map<String, dynamic> params;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'method': method,
    'params': params,
  };
}

/// A page -> Dart response with the result or error of a call.
class RpcResponse {
  const RpcResponse({
    required this.id,
    required this.ok,
    this.result,
    this.error,
  });

  factory RpcResponse.fromJson(Map<String, dynamic> json) => RpcResponse(
    id: (json['id'] as num).toInt(),
    ok: json['ok'] == true,
    result: json['result'] == null ? null : asStringKeyedMap(json['result']),
    error: json['error'] == null
        ? null
        : StripeJsError.fromJson(asStringKeyedMap(json['error'])),
  );

  /// Echo of the request id.
  final int id;

  /// Whether the Stripe.js promise resolved without an error.
  final bool ok;

  /// Raw object returned by Stripe.js (`paymentMethod`, `paymentIntent`,
  /// `token`, `setupIntent`).
  final Map<String, dynamic>? result;

  /// Present when [ok] is false.
  final StripeJsError? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'ok': ok,
    if (result != null) 'result': result,
    if (error != null) 'error': error!.toJson(),
  };
}

/// The Stripe.js `error` object, normalized by the host page.
class StripeJsError {
  const StripeJsError({
    required this.type,
    required this.message,
    this.code,
    this.declineCode,
    this.paymentIntent,
  });

  factory StripeJsError.fromJson(Map<String, dynamic> json) => StripeJsError(
    type: json['type'] as String? ?? 'api_error',
    message: json['message'] as String? ?? 'Unknown error',
    code: json['code'] as String?,
    declineCode: json['declineCode'] as String?,
    paymentIntent: json['paymentIntent'] == null
        ? null
        : asStringKeyedMap(json['paymentIntent']),
  );

  /// `card_error`, `validation_error`, `invalid_request_error`, `api_error`.
  final String type;

  /// e.g. `card_declined`, `incomplete_number`.
  final String? code;

  /// e.g. `insufficient_funds`.
  final String? declineCode;

  /// Human readable message from Stripe.js.
  final String message;

  /// The payment intent in its error state, when Stripe.js returns it
  /// alongside the error.
  final Map<String, dynamic>? paymentIntent;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'message': message,
    if (code != null) 'code': code,
    if (declineCode != null) 'declineCode': declineCode,
    if (paymentIntent != null) 'paymentIntent': paymentIntent,
  };
}

/// Spontaneous events emitted by the page (not responses to RPC calls).
class PageEvent {
  const PageEvent({
    required this.type,
    this.complete,
    this.empty,
    this.brand,
    this.error,
  });

  /// The page finished loading Stripe.js and the RPC dispatcher.
  const PageEvent.ready() : this(type: PageEvent.kindReady);

  factory PageEvent.fromJson(Map<String, dynamic> json) => PageEvent(
    type: json['event'] as String? ?? json['kind'] as String? ?? '',
    complete: json['complete'] as bool?,
    empty: json['empty'] as bool?,
    brand: json['brand'] as String?,
    error: json['error'] as String?,
  );

  static const kindReady = 'ready';
  static const kindCardChange = 'cardChange';
  static const kindCardFocus = 'cardFocus';
  static const kindCardBlur = 'cardBlur';

  /// One of [kindReady], [kindCardChange], [kindCardFocus], [kindCardBlur].
  final String type;

  /// Card Element `change` event payload (only for [kindCardChange]).
  final bool? complete;
  final bool? empty;
  final String? brand;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'event',
    'event': type,
    if (complete != null) 'complete': complete,
    if (empty != null) 'empty': empty,
    if (brand != null) 'brand': brand,
    if (error != null) 'error': error,
  };
}
