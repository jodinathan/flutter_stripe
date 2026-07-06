import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_desktop/src/errors.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

void main() {
  group('stripeExceptionFrom', () {
    test('card_error maps to StripeException with the decline code', () {
      final exception = stripeExceptionFrom(const {
        'type': 'card_error',
        'code': 'card_declined',
        'declineCode': 'insufficient_funds',
        'message': 'Your card has insufficient funds.',
      });

      expect(exception, isA<StripeException>());
      final error = (exception as StripeException).error;
      expect(error.code, FailureCode.Failed);
      expect(error.message, 'Your card has insufficient funds.');
      expect(error.localizedMessage, 'Your card has insufficient funds.');
      expect(error.stripeErrorCode, 'card_declined');
      expect(error.declineCode, 'insufficient_funds');
      expect(error.type, 'card_error');
    });

    test('validation_error maps to StripeException without a decline code', () {
      final exception = stripeExceptionFrom(const {
        'type': 'validation_error',
        'code': 'incomplete_number',
        'message': 'Your card number is incomplete.',
      });

      expect(exception, isA<StripeException>());
      final error = (exception as StripeException).error;
      expect(error.code, FailureCode.Failed);
      expect(error.message, 'Your card number is incomplete.');
      expect(error.localizedMessage, 'Your card number is incomplete.');
      expect(error.stripeErrorCode, 'incomplete_number');
      expect(error.declineCode, isNull);
      expect(error.type, 'validation_error');
    });

    test('invalid_request_error maps to StripeError', () {
      final exception = stripeExceptionFrom(const {
        'type': 'invalid_request_error',
        'code': 'payment_intent_unexpected_state',
        'message':
            'This PaymentIntent could not be captured because it has '
            'already been captured.',
      });

      expect(exception, isA<StripeError<String?>>());
      final error = exception as StripeError<String?>;
      expect(error.code, 'payment_intent_unexpected_state');
      expect(
        error.message,
        'This PaymentIntent could not be captured because it has '
        'already been captured.',
      );
    });

    test('api_error maps to StripeError', () {
      final exception = stripeExceptionFrom(const {
        'type': 'api_error',
        'message': 'An error occurred while processing your card.',
      });

      expect(exception, isA<StripeError<String?>>());
      final error = exception as StripeError<String?>;
      expect(error.code, isNull);
      expect(error.message, 'An error occurred while processing your card.');
    });

    test('unknown types and missing messages fall back to StripeError', () {
      final exception = stripeExceptionFrom(const {'type': 'something_new'});

      expect(exception, isA<StripeError<String?>>());
      final error = exception as StripeError<String?>;
      expect(error.message, 'Unknown error');
      expect(error.code, isNull);
    });
  });

  group('StripeDesktopUnsupportedError', () {
    test('is an UnsupportedError naming the method', () {
      final error = StripeDesktopUnsupportedError('presentPaymentSheet');
      expect(error, isA<UnsupportedError>());
      expect(error.message, contains('presentPaymentSheet'));
      expect(error.toString(), contains('StripeDesktopUnsupportedError'));
    });
  });
}
