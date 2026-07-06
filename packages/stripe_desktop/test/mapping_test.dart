import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_desktop/src/mapping.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

/// Fixtures follow the shapes documented in the public Stripe API reference
/// (https://docs.stripe.com/api) as returned by Stripe.js to the browser:
/// snake_case keys, epoch seconds, expandable fields as id strings or nested
/// objects.
void main() {
  group('mapPaymentIntentFromJs', () {
    test('maps a requires_action intent (3DS next_action pending)', () {
      final json = <String, dynamic>{
        'id': 'pi_3MtwBwLkdIwHu7ix28a3tqPa',
        'object': 'payment_intent',
        'amount': 2000,
        'canceled_at': null,
        'cancellation_reason': null,
        'capture_method': 'automatic',
        'client_secret':
            'pi_3MtwBwLkdIwHu7ix28a3tqPa_secret_YrKJUKribcBjcG8HVhfZluoGH',
        'confirmation_method': 'automatic',
        'created': 1680800504,
        'currency': 'usd',
        'description': null,
        'last_payment_error': null,
        'livemode': false,
        'next_action': {
          'type': 'use_stripe_sdk',
          'use_stripe_sdk': {
            'type': 'three_d_secure_redirect',
            'stripe_js': 'https://hooks.stripe.com/redirect/authenticate/src_x',
          },
        },
        'payment_method': 'pm_1MtwBwLkdIwHu7ix3jGKDVey',
        'payment_method_types': ['card'],
        'receipt_email': null,
        'setup_future_usage': null,
        'shipping': null,
        'status': 'requires_action',
      };

      final intent = mapPaymentIntentFromJs(json);

      expect(intent.id, 'pi_3MtwBwLkdIwHu7ix28a3tqPa');
      expect(intent.status, PaymentIntentsStatus.RequiresAction);
      expect(intent.amount, 2000);
      expect(intent.currency, 'usd');
      expect(
        intent.clientSecret,
        'pi_3MtwBwLkdIwHu7ix28a3tqPa_secret_YrKJUKribcBjcG8HVhfZluoGH',
      );
      expect(intent.created, '1680800504');
      expect(intent.livemode, isFalse);
      expect(intent.captureMethod, CaptureMethod.Automatic);
      expect(intent.confirmationMethod, ConfirmationMethod.Automatic);
      expect(intent.paymentMethodId, 'pm_1MtwBwLkdIwHu7ix3jGKDVey');
      expect(intent.canceledAt, isNull);
      expect(intent.description, isNull);
    });

    test('maps a succeeded intent with an expanded payment_method object', () {
      final json = <String, dynamic>{
        'id': 'pi_3MtwBwLkdIwHu7ix28a3tqPa',
        'object': 'payment_intent',
        'amount': 4999,
        'capture_method': 'manual',
        'client_secret': 'pi_3MtwBwLkdIwHu7ix28a3tqPa_secret_abc',
        'confirmation_method': 'manual',
        'created': 1680800504,
        'currency': 'brl',
        'description': 'GymDogs subscription',
        'livemode': true,
        'latest_charge': 'ch_3MtwBwLkdIwHu7ix0Ssdklwq',
        'payment_method': {
          'id': 'pm_1MtwBwLkdIwHu7ix3jGKDVey',
          'object': 'payment_method',
          'type': 'card',
        },
        'receipt_email': 'jenny.rosen@example.com',
        'status': 'succeeded',
      };

      final intent = mapPaymentIntentFromJs(json);

      expect(intent.status, PaymentIntentsStatus.Succeeded);
      expect(intent.amount, 4999);
      expect(intent.currency, 'brl');
      expect(intent.livemode, isTrue);
      expect(intent.captureMethod, CaptureMethod.Manual);
      expect(intent.confirmationMethod, ConfirmationMethod.Manual);
      // Expandable field delivered as a nested object: only the id is kept.
      expect(intent.paymentMethodId, 'pm_1MtwBwLkdIwHu7ix3jGKDVey');
      expect(intent.latestCharge, 'ch_3MtwBwLkdIwHu7ix0Ssdklwq');
      expect(intent.description, 'GymDogs subscription');
      expect(intent.receiptEmail, 'jenny.rosen@example.com');
    });

    test('falls back to safe defaults on unknown values', () {
      final intent = mapPaymentIntentFromJs(const {
        'id': 'pi_123',
        'status': 'brand_new_status',
        'capture_method': 'automatic_async',
      });
      expect(intent.status, PaymentIntentsStatus.Unknown);
      expect(intent.captureMethod, CaptureMethod.AutomaticAsync);
      expect(intent.confirmationMethod, ConfirmationMethod.Unknown);
      expect(intent.amount, 0);
      expect(intent.currency, '');
      expect(intent.created, '0');
    });
  });

  group('mapPaymentMethodFromJs', () {
    test('maps a card payment method with billing details', () {
      final json = <String, dynamic>{
        'id': 'pm_1MqM05LkdIwHu7ixlDxxO6Mc',
        'object': 'payment_method',
        'billing_details': {
          'address': {
            'city': 'San Francisco',
            'country': 'US',
            'line1': '510 Townsend St',
            'line2': null,
            'postal_code': '94103',
            'state': 'CA',
          },
          'email': 'jenny.rosen@example.com',
          'name': 'Jenny Rosen',
          'phone': '+15555555555',
        },
        'card': {
          'brand': 'visa',
          'checks': {
            'address_line1_check': 'pass',
            'address_postal_code_check': 'pass',
            'cvc_check': 'pass',
          },
          'country': 'US',
          'display_brand': 'visa',
          'exp_month': 8,
          'exp_year': 2028,
          'funding': 'credit',
          'last4': '4242',
          'networks': {
            'available': ['visa'],
            'preferred': null,
          },
          'three_d_secure_usage': {'supported': true},
          'wallet': null,
        },
        'created': 1679933301,
        'customer': null,
        'livemode': false,
        'type': 'card',
      };

      final method = mapPaymentMethodFromJs(json);

      expect(method.id, 'pm_1MqM05LkdIwHu7ixlDxxO6Mc');
      expect(method.paymentMethodType, 'card');
      expect(method.livemode, isFalse);
      expect(method.customerId, isNull);
      expect(method.card.brand, 'visa');
      expect(method.card.last4, '4242');
      expect(method.card.expMonth, 8);
      expect(method.card.expYear, 2028);
      expect(method.card.funding, 'credit');
      expect(method.card.country, 'US');
      expect(method.billingDetails.name, 'Jenny Rosen');
      expect(method.billingDetails.email, 'jenny.rosen@example.com');
      expect(method.billingDetails.phone, '+15555555555');
      expect(method.billingDetails.address?.city, 'San Francisco');
      expect(method.billingDetails.address?.line1, '510 Townsend St');
      expect(method.billingDetails.address?.line2, isNull);
      expect(method.billingDetails.address?.postalCode, '94103');
      expect(method.billingDetails.address?.state, 'CA');
      expect(method.billingDetails.address?.country, 'US');
    });

    test('survives loosely typed nested maps from the webview decoder', () {
      final method = mapPaymentMethodFromJs(<String, dynamic>{
        'id': 'pm_123',
        'type': 'card',
        'livemode': false,
        'billing_details': <dynamic, dynamic>{'name': 'Jenny Rosen'},
        'card': <dynamic, dynamic>{'brand': 'mastercard', 'last4': '4444'},
        'customer': 'cus_9s6XKzkNRiz8i3',
      });
      expect(method.billingDetails.name, 'Jenny Rosen');
      expect(method.card.brand, 'mastercard');
      expect(method.card.last4, '4444');
      expect(method.customerId, 'cus_9s6XKzkNRiz8i3');
    });
  });

  group('mapSetupIntentFromJs', () {
    test('maps a succeeded setup intent', () {
      final json = <String, dynamic>{
        'id': 'seti_1Mm8s8LkdIwHu7ix0OXBfTRG',
        'object': 'setup_intent',
        'cancellation_reason': null,
        'client_secret':
            'seti_1Mm8s8LkdIwHu7ix0OXBfTRG_secret_NXDICkPqPeiBTAFqWmkbff09lRmSVXe',
        'created': 1678942624,
        'description': null,
        'last_setup_error': null,
        'livemode': false,
        'next_action': null,
        'payment_method': 'pm_1Mm8s7LkdIwHu7ixRnQZbcYK',
        'payment_method_types': ['card', 'link'],
        'status': 'succeeded',
        'usage': 'off_session',
      };

      final intent = mapSetupIntentFromJs(json);

      expect(intent.id, 'seti_1Mm8s8LkdIwHu7ix0OXBfTRG');
      expect(intent.status, 'succeeded');
      expect(
        intent.clientSecret,
        'seti_1Mm8s8LkdIwHu7ix0OXBfTRG_secret_NXDICkPqPeiBTAFqWmkbff09lRmSVXe',
      );
      expect(intent.paymentMethodId, 'pm_1Mm8s7LkdIwHu7ixRnQZbcYK');
      expect(intent.usage, 'off_session');
      expect(intent.livemode, isFalse);
      expect(intent.created, '1678942624');
      expect(intent.paymentMethodTypes, [
        PaymentMethodType.Card,
        PaymentMethodType.Link,
      ]);
    });

    test('maps unknown payment method types to Unknown', () {
      final intent = mapSetupIntentFromJs(const {
        'id': 'seti_123',
        'status': 'requires_action',
        'payment_method_types': ['card', 'space_credits'],
      });
      expect(intent.paymentMethodTypes, [
        PaymentMethodType.Card,
        PaymentMethodType.Unknown,
      ]);
      expect(intent.created, isNull);
    });
  });

  group('mapTokenFromJs', () {
    test('maps a card token', () {
      final json = <String, dynamic>{
        'id': 'tok_1N3T00LkdIwHu7ix0jpavbG9',
        'object': 'token',
        'card': {
          'id': 'card_1N3T00LkdIwHu7ixRdxpVI1Q',
          'object': 'card',
          'address_city': 'San Francisco',
          'address_country': 'US',
          'address_line1': '510 Townsend St',
          'address_line1_check': 'unchecked',
          'address_line2': null,
          'address_state': 'CA',
          'address_zip': '94103',
          'address_zip_check': 'unchecked',
          'brand': 'Visa',
          'country': 'US',
          'cvc_check': 'unchecked',
          'dynamic_last4': null,
          'exp_month': 5,
          'exp_year': 2027,
          'fingerprint': 'mToisGZ01V71BCos',
          'funding': 'credit',
          'last4': '4242',
          'name': 'Jenny Rosen',
          'tokenization_method': null,
          'wallet': null,
        },
        'client_ip': '8.8.8.8',
        'created': 1683071568,
        'livemode': false,
        'type': 'card',
        'used': false,
      };

      final token = mapTokenFromJs(json);

      expect(token.id, 'tok_1N3T00LkdIwHu7ix0jpavbG9');
      expect(token.type, TokenType.Card);
      expect(token.created, '1683071568');
      expect(token.livemode, isFalse);
      expect(token.bankAccount, isNull);
      final card = token.card;
      expect(card, isNotNull);
      expect(card?.id, 'card_1N3T00LkdIwHu7ixRdxpVI1Q');
      expect(card?.brand, 'Visa');
      expect(card?.last4, '4242');
      expect(card?.expMonth, 5);
      expect(card?.expYear, 2027);
      expect(card?.funding, 'credit');
      expect(card?.name, 'Jenny Rosen');
      expect(card?.address?.line1, '510 Townsend St');
      expect(card?.address?.city, 'San Francisco');
      expect(card?.address?.state, 'CA');
      expect(card?.address?.postalCode, '94103');
      expect(card?.address?.country, 'US');
    });
  });

  group('outbound translations', () {
    test('billingDetailsToJs emits snake_case and omits nulls', () {
      const details = BillingDetails(
        name: 'Jenny Rosen',
        email: 'jenny.rosen@example.com',
        address: Address(
          city: 'San Francisco',
          country: 'US',
          line1: '510 Townsend St',
          line2: null,
          postalCode: '94103',
          state: 'CA',
        ),
      );
      expect(billingDetailsToJs(details), {
        'name': 'Jenny Rosen',
        'email': 'jenny.rosen@example.com',
        'address': {
          'city': 'San Francisco',
          'country': 'US',
          'line1': '510 Townsend St',
          'postal_code': '94103',
          'state': 'CA',
        },
      });
    });

    test('cardTokenParamsToJs emits the legacy address_* keys', () {
      expect(
        cardTokenParamsToJs(
          name: 'Jenny Rosen',
          currency: 'usd',
          address: const Address(
            city: 'San Francisco',
            country: 'US',
            line1: '510 Townsend St',
            line2: null,
            postalCode: '94103',
            state: 'CA',
          ),
        ),
        {
          'name': 'Jenny Rosen',
          'address_line1': '510 Townsend St',
          'address_city': 'San Francisco',
          'address_state': 'CA',
          'address_country': 'US',
          'address_zip': '94103',
          'currency': 'usd',
        },
      );
    });

    test('futureUsageToJs translates the enum', () {
      expect(
        futureUsageToJs(PaymentIntentsFutureUsage.OffSession),
        'off_session',
      );
      expect(
        futureUsageToJs(PaymentIntentsFutureUsage.OnSession),
        'on_session',
      );
      expect(futureUsageToJs(null), isNull);
    });
  });
}
