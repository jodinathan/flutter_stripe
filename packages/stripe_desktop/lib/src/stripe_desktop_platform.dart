import 'package:flutter/widgets.dart';
import 'package:stripe_platform_interface/stripe_platform_interface.dart';

import 'bridge/rpc_messages.dart';
import 'bridge/stripe_js_bridge.dart';
import 'errors.dart';
import 'mapping.dart';
import 'widgets/desktop_card_field.dart';

/// The macOS implementation of [StripePlatform], running Stripe.js in a
/// WKWebView.
///
/// Feature matrix (web parity): card payments through the Card Element —
/// `initialise`, `buildCard`, `createPaymentMethod`, `createToken`,
/// `confirmPayment`, `confirmSetupIntent`, `handleNextAction`,
/// `handleNextActionForSetupIntent`, `retrievePaymentIntent` and
/// `retrieveSetupIntent`. Every other method throws
/// [StripeDesktopUnsupportedError].
class StripeDesktop extends StripePlatform {
  StripeDesktop._();

  /// The singleton instance registered as [StripePlatform.instance].
  static final StripeDesktop instance = StripeDesktop._();

  String? _publishableKey;
  String? _stripeAccountId;
  DesktopCardFieldState? _activeField;

  /// The publishable key passed to [initialise]. Internal — read by
  /// [DesktopCardField] to configure the Stripe.js page.
  String? get publishableKey => _publishableKey;

  /// The connected account id passed to [initialise]. Internal — read by
  /// [DesktopCardField] to configure the Stripe.js page.
  String? get stripeAccountId => _stripeAccountId;

  /// Registers [field] as the active card field. Internal — called by
  /// [DesktopCardField] in `initState` (the last mounted field wins).
  void attachField(DesktopCardFieldState field) {
    _activeField = field;
  }

  /// Deregisters [field]. Internal — called by [DesktopCardField] in
  /// `dispose`.
  void detachField(DesktopCardFieldState field) {
    if (_activeField == field) {
      _activeField = null;
    }
  }

  /// Settings are applied eagerly on [initialise], exactly like on web.
  @override
  bool get updateSettingsLazily => false;

  @override
  Future<void> initialise({
    required String publishableKey,
    String? stripeAccountId,
    ThreeDSecureConfigurationParams? threeDSecureParams,
    String? merchantIdentifier,
    String? urlScheme,
    bool? setReturnUrlSchemeOnAndroid,
  }) async {
    // threeDSecureParams / merchantIdentifier / urlScheme /
    // setReturnUrlSchemeOnAndroid are mobile-only concepts: accepted and
    // ignored here.
    _publishableKey = publishableKey;
    _stripeAccountId = stripeAccountId;
    // Publishable key changed with a mounted field: re-init the page.
    await _activeField?.reinit();
  }

  @override
  Widget buildCard({
    Key? key,
    required CardEditController controller,
    CardChangedCallback? onCardChanged,
    CardFocusCallback? onFocus,
    CardStyle? style,
    CardPlaceholder? placeholder,
    bool enablePostalCode = false,
    double? width,
    double? height,
    BoxConstraints? constraints,
    FocusNode? focusNode,
    bool autofocus = false,
    bool dangerouslyUpdateFullCardDetails = false,
  }) {
    return DesktopCardField(
      key: key,
      controller: controller,
      onCardChanged: onCardChanged,
      onFocus: onFocus,
      style: style,
      placeholder: placeholder,
      enablePostalCode: enablePostalCode,
      width: width,
      height: height,
      constraints: constraints,
      focusNode: focusNode,
      autofocus: autofocus,
      dangerouslyUpdateFullCardDetails: dangerouslyUpdateFullCardDetails,
    );
  }

  @override
  Future<PaymentMethod> createPaymentMethod(
    PaymentMethodParams data, [
    PaymentMethodOptions? options,
  ]) async {
    final params = data.maybeWhen<Map<String, dynamic>>(
      card: (data) => <String, dynamic>{
        if (data.billingDetails != null)
          'billingDetails': billingDetailsToJs(data.billingDetails!),
      },
      orElse: () => throw StripeDesktopUnsupportedError(
        'createPaymentMethod with ${data.runtimeType}',
      ),
    );
    final result = await _bridge.call('createPaymentMethod', params);
    return mapPaymentMethodFromJs(asStringKeyedMap(result['paymentMethod']));
  }

  @override
  Future<TokenData> createToken(CreateTokenParams params) async {
    final jsParams = params.maybeWhen<Map<String, dynamic>>(
      (type, name, address) =>
          cardTokenParamsToJs(name: name, address: address),
      card: (params) => cardTokenParamsToJs(
        name: params.name,
        address: params.address,
        currency: params.currency,
      ),
      orElse: () => throw StripeDesktopUnsupportedError(
        'createToken with ${params.runtimeType}',
      ),
    );
    final result = await _bridge.call('createToken', jsParams);
    return mapTokenFromJs(asStringKeyedMap(result['token']));
  }

  @override
  Future<PaymentIntent> confirmPayment(
    String paymentIntentClientSecret,
    PaymentMethodParams? params, [
    PaymentMethodOptions? options,
  ]) async {
    final field = _requireField();
    final jsParams = <String, dynamic>{
      'clientSecret': paymentIntentClientSecret,
      ..._confirmParamsToJs(params, options),
    };
    await field.expandForChallenge();
    try {
      final result = await field.bridge.call('confirmPayment', jsParams);
      return mapPaymentIntentFromJs(asStringKeyedMap(result['paymentIntent']));
    } finally {
      await field.collapse();
    }
  }

  @override
  Future<SetupIntent> confirmSetupIntent(
    String setupIntentClientSecret,
    PaymentMethodParams data,
    PaymentMethodOptions? options,
  ) async {
    final field = _requireField();
    final jsParams = data.maybeWhen<Map<String, dynamic>>(
      card: (data) => <String, dynamic>{
        if (data.billingDetails != null)
          'billingDetails': billingDetailsToJs(data.billingDetails!),
      },
      orElse: () => throw StripeDesktopUnsupportedError(
        'confirmSetupIntent with ${data.runtimeType}',
      ),
    );
    await field.expandForChallenge();
    try {
      final result = await field.bridge.call('confirmSetup', {
        'clientSecret': setupIntentClientSecret,
        ...jsParams,
      });
      return mapSetupIntentFromJs(asStringKeyedMap(result['setupIntent']));
    } finally {
      await field.collapse();
    }
  }

  @override
  Future<PaymentIntent> handleNextAction(
    String paymentIntentClientSecret, {
    String? returnURL,
  }) async {
    final field = _requireField();
    await field.expandForChallenge();
    try {
      final result = await field.bridge.call('handleNextAction', {
        'clientSecret': paymentIntentClientSecret,
      });
      return mapPaymentIntentFromJs(asStringKeyedMap(result['paymentIntent']));
    } finally {
      await field.collapse();
    }
  }

  @override
  Future<SetupIntent> handleNextActionForSetupIntent(
    String setupIntentClientSecret, {
    String? returnURL,
  }) async {
    final field = _requireField();
    await field.expandForChallenge();
    try {
      // Stripe.js `handleNextAction` accepts both payment and setup intent
      // client secrets and resolves with the matching intent.
      final result = await field.bridge.call('handleNextAction', {
        'clientSecret': setupIntentClientSecret,
      });
      return mapSetupIntentFromJs(asStringKeyedMap(result['setupIntent']));
    } finally {
      await field.collapse();
    }
  }

  @override
  Future<PaymentIntent> retrievePaymentIntent(String clientSecret) async {
    final result = await _bridge.call('retrievePaymentIntent', {
      'clientSecret': clientSecret,
    });
    return mapPaymentIntentFromJs(asStringKeyedMap(result['paymentIntent']));
  }

  @override
  Future<SetupIntent> retrieveSetupIntent(String clientSecret) async {
    final result = await _bridge.call('retrieveSetupIntent', {
      'clientSecret': clientSecret,
    });
    return mapSetupIntentFromJs(asStringKeyedMap(result['setupIntent']));
  }

  // Helpers -----------------------------------------------------------------

  StripeJsBridge get _bridge => _requireField().bridge;

  DesktopCardFieldState _requireField() {
    final field = _activeField;
    if (field == null) {
      throw const StripeError<FailureCode>(
        code: FailureCode.Failed,
        message:
            'stripe_desktop requires a mounted CardField for this operation',
      );
    }
    return field;
  }

  Map<String, dynamic> _confirmParamsToJs(
    PaymentMethodParams? params,
    PaymentMethodOptions? options,
  ) {
    final setupFutureUsage = futureUsageToJs(options?.setupFutureUsage);
    if (params == null) {
      return <String, dynamic>{'setupFutureUsage': ?setupFutureUsage};
    }
    return params.maybeWhen<Map<String, dynamic>>(
      card: (data) => <String, dynamic>{
        if (data.billingDetails != null)
          'billingDetails': billingDetailsToJs(data.billingDetails!),
        'setupFutureUsage': ?setupFutureUsage,
      },
      cardFromMethodId: (data) => <String, dynamic>{
        'paymentMethodId': data.paymentMethodId,
      },
      orElse: () => throw StripeDesktopUnsupportedError(
        'confirmPayment with ${params.runtimeType}',
      ),
    );
  }

  // Methods outside the desktop v1 feature matrix ---------------------------
  // Explicit throws, one per method (no noSuchMethod), so that new abstract
  // methods added to the platform interface surface as analyzer errors here.

  @override
  Future<PaymentSheetPaymentOption?> initPaymentSheet(
    SetupPaymentSheetParameters params,
  ) {
    throw StripeDesktopUnsupportedError('initPaymentSheet');
  }

  @override
  Future<PaymentSheetPaymentOption?> presentPaymentSheet({
    PaymentSheetPresentOptions? options,
  }) {
    throw StripeDesktopUnsupportedError('presentPaymentSheet');
  }

  @override
  Future<void> resetPaymentSheetCustomer() {
    throw StripeDesktopUnsupportedError('resetPaymentSheetCustomer');
  }

  @override
  Future<void> confirmPaymentSheetPayment() {
    throw StripeDesktopUnsupportedError('confirmPaymentSheetPayment');
  }

  @override
  Future<void> initCustomerSheet(CustomerSheetInitParams params) {
    throw StripeDesktopUnsupportedError('initCustomerSheet');
  }

  @override
  Future<CustomerSheetResult?> presentCustomerSheet({
    CustomerSheetPresentParams? options,
  }) {
    throw StripeDesktopUnsupportedError('presentCustomerSheet');
  }

  @override
  Future<CustomerSheetResult?> retrieveCustomerSheetPaymentOptionSelection() {
    throw StripeDesktopUnsupportedError(
      'retrieveCustomerSheetPaymentOptionSelection',
    );
  }

  @override
  Future<void> openApplePaySetup() {
    throw StripeDesktopUnsupportedError('openApplePaySetup');
  }

  @override
  Future<TokenData> createApplePayToken(Map<String, dynamic> payment) {
    throw StripeDesktopUnsupportedError('createApplePayToken');
  }

  @override
  Future<bool> handleURLCallback(String url) {
    throw StripeDesktopUnsupportedError('handleURLCallback');
  }

  @override
  Future<void> initGooglePay(GooglePayInitParams params) {
    throw StripeDesktopUnsupportedError('initGooglePay');
  }

  @override
  Future<void> presentGooglePay(PresentGooglePayParams params) {
    throw StripeDesktopUnsupportedError('presentGooglePay');
  }

  @override
  Future<bool> googlePayIsSupported(IsGooglePaySupportedParams params) {
    throw StripeDesktopUnsupportedError('googlePayIsSupported');
  }

  @override
  Future<PaymentMethod> createGooglePayPaymentMethod(
    CreateGooglePayPaymentParams params,
  ) {
    throw StripeDesktopUnsupportedError('createGooglePayPaymentMethod');
  }

  @override
  Future<AddToWalletResult> canAddToWallet(String last4) {
    throw StripeDesktopUnsupportedError('canAddToWallet');
  }

  @override
  Future<CanAddCardToWalletResult> canAddCardToWallet(
    CanAddCardToWalletParams params,
  ) {
    throw StripeDesktopUnsupportedError('canAddCardToWallet');
  }

  @override
  Future<IsCardInWalletResult> isCardInWallet(String cardLastFour) {
    throw StripeDesktopUnsupportedError('isCardInWallet');
  }

  @override
  Future<bool> isPlatformPaySupported({
    IsGooglePaySupportedParams? params,
    PlatformPayWebPaymentRequestCreateOptions? paymentRequestOptions,
  }) {
    throw StripeDesktopUnsupportedError('isPlatformPaySupported');
  }

  @override
  Future<SetupIntent> platformPayConfirmSetupIntent({
    required String clientSecret,
    required PlatformPayConfirmParams params,
  }) {
    throw StripeDesktopUnsupportedError('platformPayConfirmSetupIntent');
  }

  @override
  Future<PaymentIntent> platformPayConfirmPaymentIntent({
    required String clientSecret,
    required PlatformPayConfirmParams params,
  }) {
    throw StripeDesktopUnsupportedError('platformPayConfirmPaymentIntent');
  }

  @override
  Future<PlatformPayPaymentMethod> platformPayCreatePaymentMethod({
    required PlatformPayPaymentMethodParams params,
    bool usesDeprecatedTokenFlow = false,
  }) {
    throw StripeDesktopUnsupportedError('platformPayCreatePaymentMethod');
  }

  @override
  Future<void> updatePlatformSheet({
    required PlatformPaySheetUpdateParams params,
  }) {
    throw StripeDesktopUnsupportedError('updatePlatformSheet');
  }

  @override
  Future<void> configurePlatformOrderTracking({
    required PlatformPayOrderDetails orderDetails,
  }) {
    throw StripeDesktopUnsupportedError('configurePlatformOrderTracking');
  }

  @override
  Future<String> createTokenForCVCUpdate(String cvc) {
    throw StripeDesktopUnsupportedError('createTokenForCVCUpdate');
  }

  @override
  Future<RadarSession> createRadarSession() {
    throw StripeDesktopUnsupportedError('createRadarSession');
  }

  @override
  Future<CollectBankAccountResult> collectBankAccount({
    required bool isPaymentIntent,
    required String clientSecret,
    required CollectBankAccountParams params,
  }) {
    throw StripeDesktopUnsupportedError('collectBankAccount');
  }

  @override
  Future<CollectBankAccountResult> verifyPaymentIntentWithMicrodeposits({
    required bool isPaymentIntent,
    required String clientSecret,
    required VerifyMicroDepositsParams params,
  }) {
    throw StripeDesktopUnsupportedError('verifyPaymentIntentWithMicrodeposits');
  }

  @override
  Future<FinancialConnectionTokenResult> collectBankAccountToken({
    required String clientSecret,
    required CollectBankAccountTokenParams params,
  }) {
    throw StripeDesktopUnsupportedError('collectBankAccountToken');
  }

  @override
  Future<FinancialConnectionSessionResult> collectFinancialConnectionsAccounts({
    required String clientSecret,
    CollectFinancialConnectionsAccountsParams? params =
        const CollectFinancialConnectionsAccountsParams(),
  }) {
    throw StripeDesktopUnsupportedError('collectFinancialConnectionsAccounts');
  }

  @override
  Future<void> dangerouslyUpdateCardDetails(CardDetails card) {
    throw StripeDesktopUnsupportedError('dangerouslyUpdateCardDetails');
  }

  @override
  Future<void> intentCreationCallback(IntentCreationCallbackParams params) {
    throw StripeDesktopUnsupportedError('intentCreationCallback');
  }

  @override
  Future<void> confirmationTokenCreationCallback(
    IntentCreationCallbackParams params,
  ) {
    throw StripeDesktopUnsupportedError('confirmationTokenCreationCallback');
  }

  @override
  Future<List<String>> pollAndClearPendingStripeConnectUrls() {
    throw StripeDesktopUnsupportedError('pollAndClearPendingStripeConnectUrls');
  }

  @override
  void setConfirmHandler(ConfirmHandler? handler) {
    throw StripeDesktopUnsupportedError('setConfirmHandler');
  }

  @override
  void setConfirmTokenHandler(ConfirmTokenHandler? handler) {
    throw StripeDesktopUnsupportedError('setConfirmTokenHandler');
  }

  @override
  Widget buildPaymentRequestButton({
    Key? key,
    required VoidCallback onPressed,
    required PlatformPayWebPaymentRequestCreateOptions
    paymentRequestCreateOptions,
    BoxConstraints? constraints,
    PlatformButtonType? type,
    PlatformButtonStyle? style,
  }) {
    throw StripeDesktopUnsupportedError('buildPaymentRequestButton');
  }
}
