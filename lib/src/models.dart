import 'package:json_annotation/json_annotation.dart';
import 'package:corsac_jwt/corsac_jwt.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

part 'models.g.dart';

class ApiConfiguration {
  final String apiUrl;
  final String authUrl;

  /*
   * In the payment_device_connector.dart during a sync, the FitPay platform will typically exclude commits that
   * have already been acknowledged by a client.  This is designed to protect against clients not gracefully
   * handling replays of commits during a sync.  By setting this value to false, commits that have already been
   * acknowleged either as successful or failed will never be replayed during a sync workflow as the platform
   * will not return them when getting a list of commits.
   * 
   * By default this is set to true in this SDK, so clients listening for commits in their payment device connectors
   * should be aware that commits maybe duplicated and that condition should be handled gracefully.  If replay
   * isn't desired, set this value to false.
   * 
   * An example scenario:
   * 
   * Your payment device connector overrides the syncOnCreditCardActivated() method because you want to transmit some
   * data to your remote wallet running on your wearable.  During the sync your device isn't connected so you report
   * a failed commit back in your syncOnCreditCardActivated() method.  During the next sync this activated event will
   * again be delivered to your implementation as a retry.  If this property is set to false, then you would never see
   * the retry of the activated event.
   */
  final bool syncIncludeAcknowledgedCommits;

  const ApiConfiguration({
    this.apiUrl = 'https://api.fit-pay.com',
    this.authUrl = 'https://auth.fit-pay.com',
    this.syncIncludeAcknowledgedCommits = true,
  });
}

@JsonSerializable(nullable: false)
class AccessToken {
  @JsonKey(name: 'access_token')
  final String token;
  final claims;

  AccessToken({this.token}) : claims = new JWT.parse(token);

  String getUserId() {
    return claims.getClaim('user_id');
  }

  String get clientId => claims.getClaim('client_id');

  factory AccessToken.fromJson(Map<String, dynamic> json) => _$AccessTokenFromJson(json);
}

abstract class BaseResource {
  @JsonKey(name: '_links')
  final Map<String, Link> links;

  BaseResource({links}) : this.links = links != null ? links : {};

  String get self => links.containsKey('self') ? links['self'].href : null;
}

@JsonSerializable(nullable: false)
class SyncRequest extends BaseResource {
  final String syncId;
  final String userId;
  final String deviceId;
  final String clientId;

  SyncRequest({
    this.syncId,
    this.userId,
    this.deviceId,
    this.clientId,
    Map<String, Link> links,
  }) : super(links: links);

  factory SyncRequest.fromJson(Map<String, dynamic> json) => _$SyncRequestFromJson(json);
}

@JsonSerializable(nullable: true)
class Link {
  final String href;
  final bool templated;

  Link({this.href, templated}) : this.templated = templated != null ? templated : false;

  Uri toUri() => Uri.parse(href);

  factory Link.fromJson(Map<String, dynamic> json) => _$LinkFromJson(json);

  Map<String, dynamic> toJson() => _$LinkToJson(this);
}

@JsonSerializable(nullable: true)
class EncryptionKey extends BaseResource {
  final String serverPublicKey;
  final String keyId;
  String clientPrivateKey;
  String clientPublicKey;

  EncryptionKey({Map<String, Link> links, this.keyId, this.serverPublicKey}) : super(links: links);

  factory EncryptionKey.fromJson(Map<String, dynamic> json) => _$EncryptionKeyFromJson(json);
}

@JsonSerializable(nullable: true)
class User extends BaseResource {
  final String userId;

  User({this.userId, Map<String, Link> links}) : super(links: links);

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@JsonSerializable(nullable: true)
class Page<T> extends BaseResource {
  final int limit;
  final int offset;
  final int totalResults;

  @_Converter()
  final List<T> results;

  Page({this.limit, this.offset, this.totalResults, this.results, Map<String, Link> links}) : super(links: links);

  factory Page.fromJson(Map<String, dynamic> json) => _$PageFromJson<T>(json);

  Map<String, dynamic> toJson() => _$PageToJson(this);
}

class _Converter<T> implements JsonConverter<T, Object> {
  const _Converter();

  @override
  T fromJson(Object json) {
    if (T == CreditCard) {
      return json == null ? null : CreditCard.fromJson(json) as T;
    } else if (T == Device) {
      return json == null ? null : Device.fromJson(json) as T;
    } else if (T == GPRAccount) {
      return json == null ? null : GPRAccount.fromJson(json) as T;
    } else if (T == FundingSource) {
      return json == null ? null : FundingSource.fromJson(json) as T;
    } else if (T == Commit) {
      return json == null ? null : Commit.fromJson(json) as T;
    } else if (T == GPRTransaction) {
      return json == null ? null : GPRTransaction.fromJson(json) as T;
    } else if (T == Transaction) {
      return json == null ? null : Transaction.fromJson(json) as T;
    }

    return json as T;
  }

  Object toJson(T object) {
    return object;
  }
}

@JsonSerializable(nullable: true)
class APDUPackage extends BaseResource {
  final String packageId;
  final List<APDUCommand> commandApdus; // apdu packages
  final List<APDUCommand> apduCommands; // offline se actions

  APDUPackage({this.packageId, this.commandApdus, this.apduCommands});

  factory APDUPackage.fromJson(Map<String, dynamic> json) => _$APDUPackageFromJson(json);
}

@JsonSerializable(nullable: true)
class APDUCommand extends BaseResource {
  final String commandId;
  final int groupId;
  final int sequence;
  final String command;
  final String type;
  final bool injected;
  bool continueOnFailure;

  APDUCommand({
    this.commandId,
    groupId,
    this.sequence,
    this.command,
    this.type,
    this.injected,
    continueOnFailure,
  })  : this.groupId = groupId != null ? groupId : 0,
        this.continueOnFailure = continueOnFailure != null ? continueOnFailure : false;

  factory APDUCommand.fromJson(Map<String, dynamic> json) => _$APDUCommandFromJson(json);
}

@JsonSerializable(nullable: true)
class ApduCommandResult {
  final String commandId;
  final String responseCode;
  final String responseData;

  ApduCommandResult({this.commandId, this.responseCode, this.responseData});

  factory ApduCommandResult.fromJson(Map<String, dynamic> json) => _$ApduCommandResultFromJson(json);

  Map<String, dynamic> toJson() => _$ApduCommandResultToJson(this);
}

enum ApduExecutionResultState {
  @JsonValue('PROCESSED')
  processed,
  @JsonValue('FAILED')
  failed,
  @JsonValue('NOT_PROCESSED')
  notProcessed
}

@JsonSerializable(nullable: true)
class ApduExecutionResult {
  final String packageId;
  final ApduExecutionResultState state;
  final int executedTsEpoch;
  final int executedDuration; //in seconds
  final List<ApduCommandResult> apduResponses;
  final String errorReason;
  final String errorCode;

  ApduExecutionResult({
    this.packageId,
    this.state,
    this.executedTsEpoch,
    this.executedDuration,
    this.apduResponses,
    this.errorReason,
    this.errorCode,
  });

  Map<String, dynamic> toJson() => _$ApduExecutionResultToJson(this);
}

enum APDUExecutionState { starting, sending, executing, receiving, success, error }

class APDUExecutionStatus {
  final APDUExecutionState state;
  final ApduExecutionResult result;

  APDUExecutionStatus({this.state, this.result});
}

enum CausedBy {
  @JsonValue('CARDHOLDER')
  cardHolder,
  @JsonValue('ISSUER')
  issuer
}

@JsonSerializable(nullable: true)
class VerificationMethods extends BaseResource {
  final String creditCardId;
  final List<VerificationMethod> verificationMethods;

  VerificationMethods({this.creditCardId, this.verificationMethods});

  factory VerificationMethods.fromJson(Map<String, dynamic> json) => _$VerificationMethodsFromJson(json);
}

@JsonSerializable(nullable: true)
class CreditCard extends BaseResource {
  final String userId;
  final String creditCardId;
  final String state;
  final String reason;
  final String cardType;
  final CausedBy causedBy;
  final dynamic encryptedData;
  final String tokenLastFour;
  final CardMetaData cardMetaData;
  final List<Asset> termsAssetReferences;
  final List<VerificationMethod> verificationMethods;
  final Map<String, APDUPackage> offlineSeActions;

  CreditCard(
      {this.userId,
      this.creditCardId,
      this.cardType,
      this.state,
      this.reason,
      this.encryptedData,
      this.tokenLastFour,
      this.cardMetaData,
      this.causedBy,
      this.termsAssetReferences,
      verificationMethods,
      Map<String, APDUPackage> offlineSeActions,
      Map<String, Link> links})
      : this.offlineSeActions = offlineSeActions ?? {},
        this.verificationMethods = verificationMethods ?? [],
        super(links: links);

  Future<Map<String, dynamic>> get acceptTermsState async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('acceptTermsState-$creditCardId')) {
      return jsonDecode(prefs.getString('acceptTermsState-$creditCardId'));
    }

    return Map<String, dynamic>();
  }

  static void removeAcceptTermsState(String creditCardId) {
    SharedPreferences.getInstance().then((prefs) => prefs.remove('acceptTermsState-$creditCardId'));
  }

  factory CreditCard.fromJson(Map<String, dynamic> json) {
    CreditCard card = _$CreditCardFromJson(json);

    // if this is the first time seeing a non-templated acceptTerms links, we need to save state because
    // the FitPay platform will never send them again
    if (card.links.containsKey('acceptTerms') && !card.links['acceptTerms'].templated) {
      SharedPreferences.getInstance().then((prefs) {
        if (!prefs.containsKey('acceptTermsState-${card.creditCardId}')) {
          Uri acceptTermsUri = card.links['acceptTerms'].toUri();
          print('saving acceptTerms link state: ${acceptTermsUri.toString()}');

          prefs.setString('acceptTermsState-${card.creditCardId}', jsonEncode(acceptTermsUri.queryParametersAll));
        }
      });
    }
    return card;
  }
}

@JsonSerializable(nullable: true)
class AppToAppContext {
  final String applicationId;
  final String action;
  final String payload;

  AppToAppContext({this.applicationId, this.action, this.payload});

  factory AppToAppContext.fromJson(Map<String, dynamic> json) => _$AppToAppContextFromJson(json);
}

@JsonSerializable(nullable: true)
class VerificationMethod extends BaseResource {
  final String methodType;
  final String state;
  final String value;
  final String verificationId;
  final AppToAppContext appToAppContext;

  VerificationMethod({
    this.methodType,
    this.state,
    this.value,
    this.verificationId,
    this.appToAppContext,
    Map<String, Link> links,
  }) : super(links: links);

  factory VerificationMethod.fromJson(Map<String, dynamic> json) => _$VerificationMethodFromJson(json);
}

enum VerificationMethodReason {
  @JsonValue('INCORRECT_CODE')
  incorrectCode,
  @JsonValue('INCORRECT_CODE_RETRIES_EXCEEDED')
  incorrectCodeRetriesExceed,
  @JsonValue('EXPIRED_CODE')
  expiredCode,
  @JsonValue('INCORRECT_TAV')
  incorrectTav,
  @JsonValue('EXPIRED_SESSION')
  expiredSession,
  @JsonValue('GENERIC_ERROR')
  genericError,
  @JsonValue('NOT_AVAILABLE')
  notAvailable
}

@JsonSerializable(nullable: true)
class VerificationMethodSubmitError {
  final String summary;
  final String description;
  final String requestId;
  @JsonKey(name: 'details', defaultValue: VerificationMethodReason.genericError)
  final VerificationMethodReason reason;

  VerificationMethodSubmitError({
    this.summary,
    this.description,
    this.requestId,
    this.reason,
  });

  factory VerificationMethodSubmitError.fromJson(Map<String, dynamic> json) =>
      _$VerificationMethodSubmitErrorFromJson(json);
}

@JsonSerializable(nullable: true)
class CardMetaData {
  final String contactEmail;
  final String contactPhone;
  final Uri contactUrl;
  final String issuerName;
  final List<Asset> issuerLogo;
  final List<Asset> icon;
  final String shortDescription;
  final String longDescription;
  final String foregroundColor;
  final List<Asset> cardBackgroundCombined;
  final List<Asset> cardBackgroundCombinedEmbossed;
  final Uri termsAndConditionsUrl;
  final Uri privacyPolicyUrl;

  CardMetaData(
      {this.foregroundColor,
      this.cardBackgroundCombined,
      this.cardBackgroundCombinedEmbossed,
      this.contactEmail,
      this.contactPhone,
      this.contactUrl,
      this.issuerLogo,
      this.issuerName,
      this.icon,
      this.shortDescription,
      this.longDescription,
      this.termsAndConditionsUrl,
      this.privacyPolicyUrl});

  factory CardMetaData.fromJson(Map<String, dynamic> json) => _$CardMetaDataFromJson(json);
}

@JsonSerializable(nullable: true)
class Asset extends BaseResource {
  Asset({Map<String, Link> links}) : super(links: links);

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
}

enum CreditCardCreationState { creating, pending_eligibility_check, created, error }

class CreditCardCreationStatus {
  final CreditCardCreationState state;
  final CreditCard creditCard;
  final ApiError error;
  final int statusCode;
  CreditCardCreationStatus({this.state, this.creditCard, this.statusCode, this.error});
}

enum CreditCardAcceptTermsState {
  accepting,
  active,
  pendingActive,
  pendingVerification,
  declined,
  notEligible,
  provisioningLimitExceeded,
  provisioningFailed,
  error,
}

class CreditCardAcceptTermsStatus {
  final CreditCardAcceptTermsState state;
  final CreditCard creditCard;
  final ApiError error;
  final int statusCode;
  CreditCardAcceptTermsStatus({this.state, this.creditCard, this.statusCode, this.error});
}

enum SecureElementManufacturer {
  @JsonValue('ST')
  st,
  @JsonValue('NXP')
  nxp,
  @JsonValue('INFINEON')
  infineon
}

@JsonSerializable(nullable: true)
class SecureElement {
  final String secureElementId;
  final String casdCert;
  final SecureElementManufacturer manufacturer;

  SecureElement({this.secureElementId, this.casdCert, this.manufacturer});

  factory SecureElement.fromJson(Map<String, dynamic> json) => _$SecureElementFromJson(json);

  Map<String, dynamic> toJson() => _$SecureElementToJson(this);
}

enum DeviceType {
  @JsonValue('ACTIVITY_TRACKER')
  ACTIVITY_TRACKER,
  @JsonValue('WATCH')
  WATCH,
  @JsonValue('MOCK')
  MOCK,
  @JsonValue('PHONE')
  PHONE
}

enum DeviceState { INITIALIZING, INITIALIZED, FAILED_INITIALIZATION }

@JsonSerializable(nullable: true)
class Device extends BaseResource {
  final String userId;
  final DeviceState state;
  final String deviceIdentifier;
  final String manufacturerName;
  final String softwareRevision;
  final String firmwareRevision;
  final String hardwareRevision;
  final String modelNumber;
  final String systemId;
  final String deviceName;
  final String osName;
  final String countryCode;
  final String serialNumber;
  final DeviceType deviceType;
  final String notificationToken;

  final SecureElement secureElement;

  Device(
      {this.userId,
      this.deviceIdentifier,
      this.deviceType,
      this.manufacturerName,
      this.softwareRevision,
      this.firmwareRevision,
      this.hardwareRevision,
      this.modelNumber,
      this.systemId,
      this.deviceName,
      this.osName,
      this.countryCode,
      this.serialNumber,
      this.state,
      this.secureElement,
      this.notificationToken,
      Map<String, Link> links})
      : super(links: links);

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

@JsonSerializable(nullable: true)
class DecryptedTransaction {
  final String merchantName;
  final String merchantType;
  final String amount;
  final String dateTime;
  final String currencyCode;
  final String transactionType;
  final String authorizationStatus;

  DecryptedTransaction(
      {this.merchantName,
      this.merchantType,
      this.amount,
      this.dateTime,
      this.currencyCode,
      this.transactionType,
      this.authorizationStatus});

  factory DecryptedTransaction.fromJson(Map<String, dynamic> json) => _$DecryptedTransactionFromJson(json);
}

@JsonSerializable(nullable: true)
class Transaction extends BaseResource {
  final String transactionId;
  final String encryptedData;
  final int transactionTimeEpoch;
  DecryptedTransaction decryptedTransaction;

  Transaction({this.transactionId, this.encryptedData, this.transactionTimeEpoch});

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
}

@JsonSerializable(nullable: true)
class Commit extends BaseResource {
  final String commitId;
  final String commitType;
  final String encryptedData;

  Commit({
    this.commitId,
    this.commitType,
    this.encryptedData,
    Map<String, Link> links,
  }) : super(links: links);

  factory Commit.fromJson(Map<String, dynamic> json) => _$CommitFromJson(json);
}

enum CommitResult { SUCCESS, FAILED, SKIPPED }

@JsonSerializable(nullable: true)
class CommitResponse {
  final CommitResult result;

  CommitResponse({this.result});

  Map<String, dynamic> toJson() => _$CommitResponseToJson(this);
}

@JsonSerializable(nullable: true)
class ApiError {
  final String message;
  final String description;

  ApiError({this.message, this.description});

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);
}

String _dateTimeToJson(DateTime d) => d.toIso8601String();

@JsonSerializable(nullable: true)
class IdvVerificationData {
  String locale;
  bool nfcCapable;
  String deviceCountry;
  String oemAccountUserName;
  String deviceTimeZone;
  String deviceBluetoothMac;
  @JsonKey(toJson: _dateTimeToJson)
  DateTime oemAccountCreatedDate;

  IdvVerificationData({
    this.locale,
    this.nfcCapable,
    this.deviceCountry,
    this.oemAccountUserName,
    this.deviceTimeZone,
    this.deviceBluetoothMac,
    this.oemAccountCreatedDate,
  });

  factory IdvVerificationData.fromJson(Map<String, dynamic> json) => _$IdvVerificationDataFromJson(json);
  Map<String, dynamic> toJson() => _$IdvVerificationDataToJson(this);
}

@JsonSerializable(nullable: true)
class CreateCreditCardRequest {
  String _cardNumber;
  int expMonth;
  int expYear;
  String _securityCode;
  String _name;
  String _street;
  String _city;
  String _country;
  String _state;
  String _postalCode;
  String _deviceId;
  IdvVerificationData riskData;

  CreateCreditCardRequest({
    cardNumber,
    this.expMonth,
    this.expYear,
    securityCode,
    name,
    street,
    city,
    country,
    state,
    postalCode,
    deviceId,
  })  : this._cardNumber = cardNumber,
        this._name = name,
        this._securityCode = securityCode,
        this._street = street,
        this._city = city,
        this._country = country,
        this._state = state,
        this._postalCode = postalCode,
        this._deviceId = deviceId;

  set cardNumber(String cardNumber) {
    this._cardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
  }

  String get cardNumber {
    if (this._cardNumber == null) return null;

    return _cardNumber.replaceAll(RegExp(r'\D'), '');
  }

  String get name => _name != null && _name.isNotEmpty ? _name : null;
  set name(String v) => _name = v;
  String get securityCode => _securityCode != null && _securityCode.isNotEmpty ? _securityCode : null;
  set securityCode(String v) => _securityCode = v;
  String get street => _street != null && _street.isNotEmpty ? _street : null;
  set street(String v) => _street = v;
  String get city => _city != null && _city.isNotEmpty ? _city : null;
  set city(String v) => _city = v;
  String get country => _country != null && _country.isNotEmpty ? _country : null;
  set country(String v) => _country = v;
  String get state => _state != null && _state.isNotEmpty ? _state : null;
  set state(String v) => _state = v;
  String get postalCode => _postalCode != null && _postalCode.isNotEmpty ? _postalCode : null;
  set postalCode(String v) => _postalCode = v;
  String get deviceId => _deviceId != null && _deviceId.isNotEmpty ? _deviceId : null;
  set deviceId(String v) => _deviceId = v;

  Map<String, dynamic> toJson() => _$CreateCreditCardRequestToJson(this);
}

enum GprAccountType { GPR, PREPAID, HYBRID }

@JsonSerializable(nullable: true)
class GPRAccount extends BaseResource {
  final String accountId;
  final String cardReferenceId;
  final String deviceSerialNumber;
  final String state;
  final String lastTransferId;
  final String programUserId;
  final String programAccountReferenceId;
  final String i2cCardProgramId;
  final List<String> programCardReferenceIds;
  final double transferLimit;
  final double currentBalance;
  final List<String> errors;
  final String createdTsEpoch;
  final String lastModifiedTsEpoch;
  final GprAccountType accountType;

  GPRAccount(
      {this.accountId,
      this.cardReferenceId,
      this.deviceSerialNumber,
      this.state,
      this.lastTransferId,
      this.programUserId,
      this.programAccountReferenceId,
      this.i2cCardProgramId,
      this.programCardReferenceIds,
      this.transferLimit,
      this.currentBalance,
      this.errors,
      this.createdTsEpoch,
      this.lastModifiedTsEpoch,
      this.accountType,
      Map<String, Link> links})
      : super(links: links);

  factory GPRAccount.fromJson(Map<String, dynamic> json) => _$GPRAccountFromJson(json);

  Map<String, dynamic> toJson() => _$GPRAccountToJson(this);
}

@JsonSerializable(nullable: true)
class FCMEvent {
  final String type;
  final int version;
  final Map<String, dynamic> metadata;
  final String payload;

  FCMEvent({this.type, this.version, this.metadata, this.payload});

  factory FCMEvent.fromJson(Map<String, dynamic> json) => _$FCMEventFromJson(json);
}

@JsonSerializable(nullable: true)
class FitPayEvent {
  final String type;
  final int version;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> payload;

  String get creditCardId => payload['creditCardId'] ?? null;
  String get userId => payload['userId'] ?? null;
  String get deviceId => payload['deviceId'] ?? payload['deviceIdentifier'] ?? null;

  FitPayEvent({this.type, this.version, this.payload, this.metadata});

  factory FitPayEvent.fromJson(Map<String, dynamic> json) => _$FitPayEventFromJson(json);
}

@JsonSerializable(nullable: true)
class GPRTransaction extends BaseResource {
  final String transactionId;
  final String transactionType;
  final double amount;
  final String currencyCode;
  final String authorizationStatus;
  final String transactionTime;
  final int transactionTimeEpoch;
  final String merchantName;
  final String merchantCode;
  final String merchantType;

  GPRTransaction(
      {this.transactionId,
      this.transactionType,
      this.amount,
      this.currencyCode,
      this.authorizationStatus,
      this.transactionTime,
      this.transactionTimeEpoch,
      this.merchantName,
      this.merchantCode,
      this.merchantType,
      Map<String, Link> links})
      : super(links: links);

  factory GPRTransaction.fromJson(Map<String, dynamic> json) => _$GPRTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$GPRTransactionToJson(this);
}

enum FundingType { ACH, TOPUP }

@JsonSerializable(nullable: true)
class FundingSource extends BaseResource {
  final String accountNumber;
  final String routingNumber;
  final String nameOnAccount;
  final String userId;
  final FundingType fundingType;
  final String displayName;
  final String accountId;

  FundingSource(
    {this.accountNumber, 
    this.routingNumber, 
    this.nameOnAccount, 
    this.userId, 
    this.fundingType, 
    this.displayName, 
    this.accountId,
    Map<String, Link> links})
    : super(links: links);

  factory FundingSource.fromJson(Map<String, dynamic> json) => _$FundingSourceFromJson(json);

  Map<String, dynamic> toJson() => _$FundingSourceToJson(this);
}

enum FundingType {
  @JsonValue('TOPUP')
  topUp,
  @JsonValue('ACH')
  scheduled,
}

enum FundingState {
  @JsonValue("ACTIVE")
  ACTIVE,
  @JsonValue("STOPPED")
  STOPPED,
  @JsonValue("ERROR")
  ERROR
}

@JsonSerializable(nullable: true)
class Funding extends BaseResource {
  FundingState fundingState;
  String fundingId;
  String accountId;
  String fundingSourceId;
  String description;
  double fundingAmount;

  static String dateToJson(DateTime date) => date.toUtc().toIso8601String();
  @JsonKey(
    fromJson: DateTime.parse,
    toJson: dateToJson
  )
  DateTime nextFundingTs;
  bool isRecurring;
  double lowAmountTopUp;
  double topAmountTopUp;
  String displayName;
  FundingType fundingType;

  Funding({this.fundingState,
    this.fundingId,
    this.accountId,
    this.fundingSourceId,
    this.description,
    this.fundingAmount,
    this.nextFundingTs,
    this.isRecurring = false,
    this.lowAmountTopUp,
    this.topAmountTopUp,
    this.displayName,
    this.fundingType});

  factory Funding.fromJson(Map<String, dynamic> json) => _$FundingFromJson(json);

  Map<String, dynamic> toJson() => _$FundingToJson(this);

}

enum JsonPatchOp {
  @JsonValue('add')
  add,
  @JsonValue('remove')
  remove,
  @JsonValue('replace')
  replace
}

@JsonSerializable(nullable: true)
class JsonPatch {
  final JsonPatchOp op;
  final String path;
  final String value;

  JsonPatch({this.op, this.path, this.value});

  Map<String, dynamic> toJson() => _$JsonPatchToJson(this);
}

@JsonSerializable(nullable: true)
class PaymentDeviceInformation {
  final String manufacturerName;
  final String softwareRevision;
  final String firmwareRevision;
  final String hardwareRevision;
  final String modelNumber;
  final String systemId;
  final String deviceName;
  final String osName;
  final String countryCode;
  final String serialNumber;
  final DeviceType deviceType;

  final SecureElement secureElement;

  PaymentDeviceInformation(
      {this.manufacturerName,
      this.softwareRevision,
      this.firmwareRevision,
      this.hardwareRevision,
      this.modelNumber,
      this.systemId,
      this.deviceName,
      this.osName,
      this.countryCode,
      this.serialNumber,
      this.deviceType,
      this.secureElement});

  Map<String, dynamic> toJson() => _$PaymentDeviceInformationToJson(this);
}
