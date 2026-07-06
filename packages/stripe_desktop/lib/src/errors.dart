import 'package:stripe_platform_interface/stripe_platform_interface.dart';

/// Error thrown by every [StripePlatform] method that is not part of the
/// desktop v1 feature matrix (web parity: card payments only).
///
/// Mirrors the `WebUnsupportedError` pattern of `flutter_stripe_web`.
class StripeDesktopUnsupportedError extends Error implements UnsupportedError {
  StripeDesktopUnsupportedError(String method)
    : message =
          '$method is not available on the desktop implementation '
          'of flutter_stripe';

  @override
  final String message;

  @override
  String toString() => 'StripeDesktopUnsupportedError: $message';
}

/// Maps the normalized Stripe.js `error` object (see the host page dispatcher
/// in `page_source.dart`) into the exception types of
/// `stripe_platform_interface`, matching how `flutter_stripe_web` surfaces
/// Stripe.js errors:
///
/// - `card_error` / `validation_error` -> [StripeException] with a
///   [LocalizedErrorMessage] carrying the decline code.
/// - `invalid_request_error` / `api_error` (and anything else) ->
///   [StripeError].
Exception stripeExceptionFrom(Map<String, dynamic> error) {
  final type = error['type'] as String?;
  final message = error['message'] as String? ?? 'Unknown error';
  final code = error['code'] as String?;
  switch (type) {
    case 'card_error':
    case 'validation_error':
      return StripeException(
        error: LocalizedErrorMessage(
          code: FailureCode.Failed,
          message: message,
          localizedMessage: message,
          stripeErrorCode: code,
          declineCode: error['declineCode'] as String?,
          type: type,
        ),
      );
    default:
      return StripeError<String?>(message: message, code: code);
  }
}
