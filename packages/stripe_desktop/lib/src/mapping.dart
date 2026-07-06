/// Pure-Dart mapping from raw Stripe.js JSON (snake_case, as returned by the
/// host page over the RPC bridge) into the freezed models of
/// `stripe_platform_interface`.
///
/// These functions mirror the conversions done by the `flutter_stripe_web`
/// parsers (`packages/stripe_web/lib/src/parser/*.dart`), which build the
/// models directly instead of going through `fromJson` — the platform
/// interface `fromJson`s expect the mobile SDK shapes, not the Stripe API
/// shapes. Fields Stripe.js does not return are left at the model defaults.
library;

import 'package:stripe_platform_interface/stripe_platform_interface.dart';

import 'bridge/rpc_messages.dart' show asStringKeyedMap;

/// Maps a raw Stripe.js `paymentIntent` object into a [PaymentIntent].
PaymentIntent mapPaymentIntentFromJs(Map<String, dynamic> json) {
  return PaymentIntent(
    id: json['id'] as String? ?? '',
    amount: json['amount'] as num? ?? 0,
    created: _epochToString(json['created']),
    currency: json['currency'] as String? ?? '',
    status: _parsePaymentIntentsStatus(json['status'] as String?),
    clientSecret: json['client_secret'] as String? ?? '',
    livemode: json['livemode'] as bool? ?? false,
    captureMethod: _parseCaptureMethod(json['capture_method'] as String?),
    confirmationMethod: _parseConfirmationMethod(
      json['confirmation_method'] as String?,
    ),
    paymentMethodId: _objectId(json['payment_method']),
    description: json['description'] as String?,
    receiptEmail: json['receipt_email'] as String?,
    canceledAt: json['canceled_at']?.toString(),
    latestCharge: _objectId(json['latest_charge']),
  );
}

/// Maps a raw Stripe.js `setupIntent` object into a [SetupIntent].
SetupIntent mapSetupIntentFromJs(Map<String, dynamic> json) {
  return SetupIntent(
    id: json['id'] as String? ?? '',
    status: json['status'] as String? ?? '',
    livemode: json['livemode'] as bool? ?? false,
    clientSecret: json['client_secret'] as String? ?? '',
    paymentMethodId: _objectId(json['payment_method']) ?? '',
    usage: json['usage'] as String? ?? '',
    paymentMethodTypes: _parsePaymentMethodTypes(json['payment_method_types']),
    description: json['description'] as String?,
    created: json['created'] == null ? null : _epochToString(json['created']),
  );
}

/// Maps a raw Stripe.js `paymentMethod` object into a [PaymentMethod].
PaymentMethod mapPaymentMethodFromJs(Map<String, dynamic> json) {
  final billingDetails = asStringKeyedMap(json['billing_details']);
  final card = asStringKeyedMap(json['card']);
  return PaymentMethod(
    id: json['id'] as String? ?? '',
    livemode: json['livemode'] as bool? ?? false,
    paymentMethodType: json['type'] as String? ?? 'card',
    billingDetails: _mapBillingDetailsFromJs(billingDetails),
    card: Card(
      brand: card['brand'] as String?,
      country: card['country'] as String?,
      expMonth: (card['exp_month'] as num?)?.toInt(),
      expYear: (card['exp_year'] as num?)?.toInt(),
      funding: card['funding'] as String?,
      last4: card['last4'] as String?,
    ),
    sepaDebit: const SepaDebit(),
    bacsDebit: const BacsDebit(),
    auBecsDebit: const AuBecsDebit(),
    ideal: const Ideal(),
    fpx: const Fpx(),
    usBankAccount: const UsBankAccount(
      accountHolderType: BankAccountHolderType.Unknown,
      accountType: UsBankAccountType.Unknown,
    ),
    customerId: _objectId(json['customer']),
  );
}

/// Maps a raw Stripe.js `token` object into a [TokenData].
TokenData mapTokenFromJs(Map<String, dynamic> json) {
  final card = json['card'] == null ? null : asStringKeyedMap(json['card']);
  final bankAccount = json['bank_account'] == null
      ? null
      : asStringKeyedMap(json['bank_account']);
  return TokenData(
    id: json['id'] as String? ?? '',
    created: _epochToString(json['created']),
    livemode: json['livemode'] as bool? ?? false,
    type: _parseTokenType(json['type'] as String?),
    card: card == null ? null : _mapCardDataFromJs(card),
    bankAccount: bankAccount == null
        ? null
        : _mapBankAccountFromJs(bankAccount),
  );
}

/// Translates [BillingDetails] into the snake_case `billing_details` object
/// Stripe.js expects.
Map<String, dynamic> billingDetailsToJs(BillingDetails details) {
  final address = details.address;
  return <String, dynamic>{
    if (details.name != null) 'name': details.name,
    if (details.email != null) 'email': details.email,
    if (details.phone != null) 'phone': details.phone,
    if (address != null)
      'address': <String, dynamic>{
        if (address.city != null) 'city': address.city,
        if (address.country != null) 'country': address.country,
        if (address.line1 != null) 'line1': address.line1,
        if (address.line2 != null) 'line2': address.line2,
        if (address.postalCode != null) 'postal_code': address.postalCode,
        if (address.state != null) 'state': address.state,
      },
  };
}

/// Translates card token parameters into the `stripe.createToken(card, data)`
/// data object (snake_case).
Map<String, dynamic> cardTokenParamsToJs({
  String? name,
  Address? address,
  String? currency,
}) {
  return <String, dynamic>{
    'name': ?name,
    'address_line1': ?address?.line1,
    'address_line2': ?address?.line2,
    'address_city': ?address?.city,
    'address_state': ?address?.state,
    'address_country': ?address?.country,
    'address_zip': ?address?.postalCode,
    'currency': ?currency,
  };
}

/// Translates [PaymentIntentsFutureUsage] into the Stripe.js
/// `setup_future_usage` string.
String? futureUsageToJs(PaymentIntentsFutureUsage? usage) {
  switch (usage) {
    case PaymentIntentsFutureUsage.OffSession:
      return 'off_session';
    case PaymentIntentsFutureUsage.OnSession:
      return 'on_session';
    case null:
      return null;
  }
}

BillingDetails _mapBillingDetailsFromJs(Map<String, dynamic> json) {
  final address = json['address'] == null
      ? null
      : asStringKeyedMap(json['address']);
  return BillingDetails(
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    name: json['name'] as String?,
    address: address == null
        ? null
        : Address(
            city: address['city'] as String?,
            country: address['country'] as String?,
            line1: address['line1'] as String?,
            line2: address['line2'] as String?,
            postalCode: address['postal_code'] as String?,
            state: address['state'] as String?,
          ),
  );
}

CardData _mapCardDataFromJs(Map<String, dynamic> json) {
  return CardData(
    id: json['id'] as String?,
    brand: json['brand'] as String? ?? 'Unknown',
    country: json['country'] as String?,
    currency: json['currency'] as String?,
    expYear: (json['exp_year'] as num?)?.toInt(),
    expMonth: (json['exp_month'] as num?)?.toInt(),
    name: json['name'] as String?,
    funding: json['funding'] as String?,
    last4: json['last4'] as String?,
    address: Address(
      line1: json['address_line1'] as String?,
      line2: json['address_line2'] as String?,
      city: json['address_city'] as String?,
      state: json['address_state'] as String?,
      country: json['address_country'] as String?,
      postalCode: json['address_zip'] as String?,
    ),
  );
}

BankAccount _mapBankAccountFromJs(Map<String, dynamic> json) {
  return BankAccount(
    id: json['id'] as String? ?? '',
    accountHolderName: json['account_holder_name'] as String?,
    accountHolderType: _parseBankAccountHolderType(
      json['account_holder_type'] as String?,
    ),
    bankName: json['bank_name'] as String?,
    country: json['country'] as String?,
    currency: json['currency'] as String?,
    last4: json['last4'] as String?,
    routingNumber: json['routing_number'] as String?,
    status: _parseBankAccountStatus(json['status'] as String?),
    fingerprint: json['fingerprint'] as String?,
  );
}

String _epochToString(Object? value) => value == null ? '0' : '$value';

/// Stripe.js expandable fields may be either an id string or a full object.
String? _objectId(Object? value) {
  if (value is String) return value;
  if (value is Map) return value['id'] as String?;
  return null;
}

PaymentIntentsStatus _parsePaymentIntentsStatus(String? value) {
  switch (value) {
    case 'succeeded':
      return PaymentIntentsStatus.Succeeded;
    case 'requires_payment_method':
      return PaymentIntentsStatus.RequiresPaymentMethod;
    case 'requires_confirmation':
      return PaymentIntentsStatus.RequiresConfirmation;
    case 'canceled':
      return PaymentIntentsStatus.Canceled;
    case 'processing':
      return PaymentIntentsStatus.Processing;
    case 'requires_action':
      return PaymentIntentsStatus.RequiresAction;
    case 'requires_capture':
      return PaymentIntentsStatus.RequiresCapture;
    default:
      return PaymentIntentsStatus.Unknown;
  }
}

CaptureMethod _parseCaptureMethod(String? value) {
  switch (value) {
    case 'automatic':
      return CaptureMethod.Automatic;
    case 'automatic_async':
      return CaptureMethod.AutomaticAsync;
    case 'manual':
      return CaptureMethod.Manual;
    default:
      return CaptureMethod.Unknown;
  }
}

ConfirmationMethod _parseConfirmationMethod(String? value) {
  switch (value) {
    case 'automatic':
      return ConfirmationMethod.Automatic;
    case 'manual':
      return ConfirmationMethod.Manual;
    default:
      return ConfirmationMethod.Unknown;
  }
}

TokenType _parseTokenType(String? value) {
  switch (value) {
    case 'bank_account':
      return TokenType.BankAccount;
    case 'pii':
      return TokenType.Pii;
    case 'card':
    default:
      return TokenType.Card;
  }
}

BankAccountHolderType _parseBankAccountHolderType(String? value) {
  switch (value) {
    case 'company':
      return BankAccountHolderType.Company;
    case 'individual':
      return BankAccountHolderType.Individual;
    default:
      return BankAccountHolderType.Unknown;
  }
}

BankAccountStatus? _parseBankAccountStatus(String? value) {
  switch (value) {
    case 'new':
      return BankAccountStatus.New;
    case 'validated':
      return BankAccountStatus.Validated;
    case 'verified':
      return BankAccountStatus.Verified;
    case 'verification_failed':
      return BankAccountStatus.VerificationFailed;
    case 'errored':
      return BankAccountStatus.Errored;
    default:
      return null;
  }
}

List<PaymentMethodType> _parsePaymentMethodTypes(Object? value) {
  if (value is! List) return const [];
  return value
      .map((dynamic type) => _parsePaymentMethodType('$type'))
      .toList(growable: false);
}

PaymentMethodType _parsePaymentMethodType(String value) {
  switch (value) {
    case 'card':
      return PaymentMethodType.Card;
    case 'cashapp':
      return PaymentMethodType.CashApp;
    case 'alipay':
      return PaymentMethodType.Alipay;
    case 'grabpay':
      return PaymentMethodType.Grabpay;
    case 'ideal':
      return PaymentMethodType.Ideal;
    case 'fpx':
      return PaymentMethodType.Fpx;
    case 'card_present':
      return PaymentMethodType.CardPresent;
    case 'sepa_debit':
      return PaymentMethodType.SepaDebit;
    case 'au_becs_debit':
      return PaymentMethodType.AuBecsDebit;
    case 'bacs_debit':
      return PaymentMethodType.BacsDebit;
    case 'p24':
      return PaymentMethodType.P24;
    case 'eps':
      return PaymentMethodType.Eps;
    case 'bancontact':
      return PaymentMethodType.Bancontact;
    case 'oxxo':
      return PaymentMethodType.Oxxo;
    case 'paypal':
      return PaymentMethodType.PayPal;
    case 'us_bank_account':
      return PaymentMethodType.USBankAccount;
    case 'revolut_pay':
      return PaymentMethodType.RevolutPay;
    case 'klarna':
      return PaymentMethodType.Klarna;
    case 'link':
      return PaymentMethodType.Link;
    case 'multibanco':
      return PaymentMethodType.Multibanco;
    case 'afterpay_clearpay':
      return PaymentMethodType.AfterpayClearpay;
    default:
      return PaymentMethodType.Unknown;
  }
}
