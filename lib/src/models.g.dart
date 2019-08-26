// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccessToken _$AccessTokenFromJson(Map<String, dynamic> json) {
  return AccessToken(
    token: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    scope: json['scope'] as String,
    expiresIn: json['expires_in'] as String,
    jti: json['jti'] as String,
  );
}

Map<String, dynamic> _$AccessTokenToJson(AccessToken instance) =>
    <String, dynamic>{
      'access_token': instance.token,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'scope': instance.scope,
      'jti': instance.jti,
    };

SyncRequest _$SyncRequestFromJson(Map<String, dynamic> json) {
  return SyncRequest(
    syncId: json['syncId'] as String,
    userId: json['userId'] as String,
    deviceId: json['deviceId'] as String,
    clientId: json['clientId'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$SyncRequestToJson(SyncRequest instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'syncId': instance.syncId,
      'userId': instance.userId,
      'deviceId': instance.deviceId,
      'clientId': instance.clientId,
    };

Link _$LinkFromJson(Map<String, dynamic> json) {
  return Link(
    href: json['href'] as String,
    templated: json['templated'],
  );
}

Map<String, dynamic> _$LinkToJson(Link instance) => <String, dynamic>{
      'href': instance.href,
      'templated': instance.templated,
    };

EncryptionKey _$EncryptionKeyFromJson(Map<String, dynamic> json) {
  return EncryptionKey(
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
    keyId: json['keyId'] as String,
    serverPublicKey: json['serverPublicKey'] as String,
  )
    ..clientPrivateKey = json['clientPrivateKey'] as String
    ..clientPublicKey = json['clientPublicKey'] as String;
}

Map<String, dynamic> _$EncryptionKeyToJson(EncryptionKey instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'serverPublicKey': instance.serverPublicKey,
      'keyId': instance.keyId,
      'clientPrivateKey': instance.clientPrivateKey,
      'clientPublicKey': instance.clientPublicKey,
    };

User _$UserFromJson(Map<String, dynamic> json) {
  return User(
    userId: json['userId'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      '_links': instance.links,
      'userId': instance.userId,
    };

Page<T> _$PageFromJson<T>(Map<String, dynamic> json) {
  return Page<T>(
    limit: json['limit'] as int,
    offset: json['offset'] as int,
    totalResults: json['totalResults'] as int,
    results: (json['results'] as List)?.map(_Converter<T>().fromJson)?.toList(),
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$PageToJson<T>(Page<T> instance) => <String, dynamic>{
      '_links': instance.links,
      'limit': instance.limit,
      'offset': instance.offset,
      'totalResults': instance.totalResults,
      'results': instance.results?.map(_Converter<T>().toJson)?.toList(),
    };

APDUPackage _$APDUPackageFromJson(Map<String, dynamic> json) {
  return APDUPackage(
    packageId: json['packageId'] as String,
    commandApdus: (json['commandApdus'] as List)
        ?.map((e) =>
            e == null ? null : APDUCommand.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    apduCommands: (json['apduCommands'] as List)
        ?.map((e) =>
            e == null ? null : APDUCommand.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$APDUPackageToJson(APDUPackage instance) =>
    <String, dynamic>{
      'packageId': instance.packageId,
      'commandApdus': instance.commandApdus,
      'apduCommands': instance.apduCommands,
    };

APDUCommand _$APDUCommandFromJson(Map<String, dynamic> json) {
  return APDUCommand(
    commandId: json['commandId'] as String,
    groupId: json['groupId'],
    sequence: json['sequence'] as int,
    command: json['command'] as String,
    type: json['type'] as String,
    injected: json['injected'] as bool,
    continueOnFailure: json['continueOnFailure'],
  );
}

Map<String, dynamic> _$APDUCommandToJson(APDUCommand instance) =>
    <String, dynamic>{
      'commandId': instance.commandId,
      'groupId': instance.groupId,
      'sequence': instance.sequence,
      'command': instance.command,
      'type': instance.type,
      'injected': instance.injected,
      'continueOnFailure': instance.continueOnFailure,
    };

ApduCommandResult _$ApduCommandResultFromJson(Map<String, dynamic> json) {
  return ApduCommandResult(
    commandId: json['commandId'] as String,
    responseCode: json['responseCode'] as String,
    responseData: json['responseData'] as String,
  );
}

Map<String, dynamic> _$ApduCommandResultToJson(ApduCommandResult instance) =>
    <String, dynamic>{
      'commandId': instance.commandId,
      'responseCode': instance.responseCode,
      'responseData': instance.responseData,
    };

ApduExecutionResult _$ApduExecutionResultFromJson(Map<String, dynamic> json) {
  return ApduExecutionResult(
    packageId: json['packageId'] as String,
    state:
        _$enumDecodeNullable(_$ApduExecutionResultStateEnumMap, json['state']),
    executedTsEpoch: json['executedTsEpoch'] as int,
    executedDuration: json['executedDuration'] as int,
    apduResponses: (json['apduResponses'] as List)
        ?.map((e) => e == null
            ? null
            : ApduCommandResult.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    errorReason: json['errorReason'] as String,
    errorCode: json['errorCode'] as String,
  );
}

Map<String, dynamic> _$ApduExecutionResultToJson(
        ApduExecutionResult instance) =>
    <String, dynamic>{
      'packageId': instance.packageId,
      'state': _$ApduExecutionResultStateEnumMap[instance.state],
      'executedTsEpoch': instance.executedTsEpoch,
      'executedDuration': instance.executedDuration,
      'apduResponses': instance.apduResponses,
      'errorReason': instance.errorReason,
      'errorCode': instance.errorCode,
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$ApduExecutionResultStateEnumMap = <ApduExecutionResultState, dynamic>{
  ApduExecutionResultState.processed: 'PROCESSED',
  ApduExecutionResultState.failed: 'FAILED',
  ApduExecutionResultState.notProcessed: 'NOT_PROCESSED'
};

VerificationMethods _$VerificationMethodsFromJson(Map<String, dynamic> json) {
  return VerificationMethods(
    creditCardId: json['creditCardId'] as String,
    verificationMethods: (json['verificationMethods'] as List)
        ?.map((e) => e == null
            ? null
            : VerificationMethod.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$VerificationMethodsToJson(
        VerificationMethods instance) =>
    <String, dynamic>{
      'creditCardId': instance.creditCardId,
      'verificationMethods': instance.verificationMethods,
    };

CreditCard _$CreditCardFromJson(Map<String, dynamic> json) {
  return CreditCard(
    userId: json['userId'] as String,
    creditCardId: json['creditCardId'] as String,
    cardType: json['cardType'] as String,
    state: json['state'] as String,
    reason: json['reason'] as String,
    encryptedData: json['encryptedData'],
    tokenLastFour: json['tokenLastFour'] as String,
    cardMetaData: json['cardMetaData'] == null
        ? null
        : CardMetaData.fromJson(json['cardMetaData'] as Map<String, dynamic>),
    causedBy: _$enumDecodeNullable(_$CausedByEnumMap, json['causedBy']),
    termsAssetReferences: (json['termsAssetReferences'] as List)
        ?.map(
            (e) => e == null ? null : Asset.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    verificationMethods: (json['verificationMethods'] as List)
        ?.map((e) => e == null
            ? null
            : VerificationMethod.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    offlineSeActions: (json['offlineSeActions'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k,
          e == null ? null : APDUPackage.fromJson(e as Map<String, dynamic>)),
    ),
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$CreditCardToJson(CreditCard instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'userId': instance.userId,
      'creditCardId': instance.creditCardId,
      'state': instance.state,
      'reason': instance.reason,
      'cardType': instance.cardType,
      'causedBy': _$CausedByEnumMap[instance.causedBy],
      'encryptedData': instance.encryptedData,
      'tokenLastFour': instance.tokenLastFour,
      'cardMetaData': instance.cardMetaData,
      'termsAssetReferences': instance.termsAssetReferences,
      'verificationMethods': instance.verificationMethods,
      'offlineSeActions': instance.offlineSeActions,
    };

const _$CausedByEnumMap = <CausedBy, dynamic>{
  CausedBy.cardHolder: 'CARDHOLDER',
  CausedBy.issuer: 'ISSUER'
};

AppToAppContext _$AppToAppContextFromJson(Map<String, dynamic> json) {
  return AppToAppContext(
    applicationId: json['applicationId'] as String,
    action: json['action'] as String,
    payload: json['payload'] as String,
  );
}

Map<String, dynamic> _$AppToAppContextToJson(AppToAppContext instance) =>
    <String, dynamic>{
      'applicationId': instance.applicationId,
      'action': instance.action,
      'payload': instance.payload,
    };

VerificationMethod _$VerificationMethodFromJson(Map<String, dynamic> json) {
  return VerificationMethod(
    methodType: json['methodType'] as String,
    state: json['state'] as String,
    value: json['value'] as String,
    verificationId: json['verificationId'] as String,
    appToAppContext: json['appToAppContext'] == null
        ? null
        : AppToAppContext.fromJson(
            json['appToAppContext'] as Map<String, dynamic>),
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$VerificationMethodToJson(VerificationMethod instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'methodType': instance.methodType,
      'state': instance.state,
      'value': instance.value,
      'verificationId': instance.verificationId,
      'appToAppContext': instance.appToAppContext,
    };

VerificationMethodSubmitError _$VerificationMethodSubmitErrorFromJson(
    Map<String, dynamic> json) {
  return VerificationMethodSubmitError(
    summary: json['summary'] as String,
    description: json['description'] as String,
    requestId: json['requestId'] as String,
    reason: _$enumDecodeNullable(
            _$VerificationMethodReasonEnumMap, json['details']) ??
        VerificationMethodReason.genericError,
  );
}

Map<String, dynamic> _$VerificationMethodSubmitErrorToJson(
        VerificationMethodSubmitError instance) =>
    <String, dynamic>{
      'summary': instance.summary,
      'description': instance.description,
      'requestId': instance.requestId,
      'details': _$VerificationMethodReasonEnumMap[instance.reason],
    };

const _$VerificationMethodReasonEnumMap = <VerificationMethodReason, dynamic>{
  VerificationMethodReason.incorrectCode: 'INCORRECT_CODE',
  VerificationMethodReason.incorrectCodeRetriesExceed:
      'INCORRECT_CODE_RETRIES_EXCEEDED',
  VerificationMethodReason.expiredCode: 'EXPIRED_CODE',
  VerificationMethodReason.incorrectTav: 'INCORRECT_TAV',
  VerificationMethodReason.expiredSession: 'EXPIRED_SESSION',
  VerificationMethodReason.genericError: 'GENERIC_ERROR',
  VerificationMethodReason.notAvailable: 'NOT_AVAILABLE'
};

CardMetaData _$CardMetaDataFromJson(Map<String, dynamic> json) {
  return CardMetaData(
    foregroundColor: json['foregroundColor'] as String,
    cardBackgroundCombined: (json['cardBackgroundCombined'] as List)
        ?.map(
            (e) => e == null ? null : Asset.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    cardBackgroundCombinedEmbossed: (json['cardBackgroundCombinedEmbossed']
            as List)
        ?.map(
            (e) => e == null ? null : Asset.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    contactEmail: json['contactEmail'] as String,
    contactPhone: json['contactPhone'] as String,
    contactUrl: json['contactUrl'] == null
        ? null
        : Uri.parse(json['contactUrl'] as String),
    issuerLogo: (json['issuerLogo'] as List)
        ?.map(
            (e) => e == null ? null : Asset.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    issuerName: json['issuerName'] as String,
    icon: (json['icon'] as List)
        ?.map(
            (e) => e == null ? null : Asset.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    shortDescription: json['shortDescription'] as String,
    longDescription: json['longDescription'] as String,
    termsAndConditionsUrl: json['termsAndConditionsUrl'] == null
        ? null
        : Uri.parse(json['termsAndConditionsUrl'] as String),
    privacyPolicyUrl: json['privacyPolicyUrl'] == null
        ? null
        : Uri.parse(json['privacyPolicyUrl'] as String),
  );
}

Map<String, dynamic> _$CardMetaDataToJson(CardMetaData instance) =>
    <String, dynamic>{
      'contactEmail': instance.contactEmail,
      'contactPhone': instance.contactPhone,
      'contactUrl': instance.contactUrl?.toString(),
      'issuerName': instance.issuerName,
      'issuerLogo': instance.issuerLogo,
      'icon': instance.icon,
      'shortDescription': instance.shortDescription,
      'longDescription': instance.longDescription,
      'foregroundColor': instance.foregroundColor,
      'cardBackgroundCombined': instance.cardBackgroundCombined,
      'cardBackgroundCombinedEmbossed': instance.cardBackgroundCombinedEmbossed,
      'termsAndConditionsUrl': instance.termsAndConditionsUrl?.toString(),
      'privacyPolicyUrl': instance.privacyPolicyUrl?.toString(),
    };

Asset _$AssetFromJson(Map<String, dynamic> json) {
  return Asset(
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
      '_links': instance.links,
    };

SecureElement _$SecureElementFromJson(Map<String, dynamic> json) {
  return SecureElement(
    secureElementId: json['secureElementId'] as String,
    casdCert: json['casdCert'] as String,
    manufacturer: _$enumDecodeNullable(
        _$SecureElementManufacturerEnumMap, json['manufacturer']),
  );
}

Map<String, dynamic> _$SecureElementToJson(SecureElement instance) =>
    <String, dynamic>{
      'secureElementId': instance.secureElementId,
      'casdCert': instance.casdCert,
      'manufacturer': _$SecureElementManufacturerEnumMap[instance.manufacturer],
    };

const _$SecureElementManufacturerEnumMap = <SecureElementManufacturer, dynamic>{
  SecureElementManufacturer.st: 'ST',
  SecureElementManufacturer.nxp: 'NXP',
  SecureElementManufacturer.infineon: 'INFINEON'
};

Device _$DeviceFromJson(Map<String, dynamic> json) {
  return Device(
    userId: json['userId'] as String,
    deviceIdentifier: json['deviceIdentifier'] as String,
    deviceType: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['deviceType']),
    manufacturerName: json['manufacturerName'] as String,
    softwareRevision: json['softwareRevision'] as String,
    firmwareRevision: json['firmwareRevision'] as String,
    hardwareRevision: json['hardwareRevision'] as String,
    modelNumber: json['modelNumber'] as String,
    systemId: json['systemId'] as String,
    deviceName: json['deviceName'] as String,
    osName: json['osName'] as String,
    countryCode: json['countryCode'] as String,
    serialNumber: json['serialNumber'] as String,
    state: _$enumDecodeNullable(_$DeviceStateEnumMap, json['state']),
    secureElement: json['secureElement'] == null
        ? null
        : SecureElement.fromJson(json['secureElement'] as Map<String, dynamic>),
    notificationToken: json['notificationToken'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      '_links': instance.links,
      'userId': instance.userId,
      'state': _$DeviceStateEnumMap[instance.state],
      'deviceIdentifier': instance.deviceIdentifier,
      'manufacturerName': instance.manufacturerName,
      'softwareRevision': instance.softwareRevision,
      'firmwareRevision': instance.firmwareRevision,
      'hardwareRevision': instance.hardwareRevision,
      'modelNumber': instance.modelNumber,
      'systemId': instance.systemId,
      'deviceName': instance.deviceName,
      'osName': instance.osName,
      'countryCode': instance.countryCode,
      'serialNumber': instance.serialNumber,
      'deviceType': _$DeviceTypeEnumMap[instance.deviceType],
      'notificationToken': instance.notificationToken,
      'secureElement': instance.secureElement,
    };

const _$DeviceTypeEnumMap = <DeviceType, dynamic>{
  DeviceType.ACTIVITY_TRACKER: 'ACTIVITY_TRACKER',
  DeviceType.WATCH: 'WATCH',
  DeviceType.MOCK: 'MOCK',
  DeviceType.PHONE: 'PHONE'
};

const _$DeviceStateEnumMap = <DeviceState, dynamic>{
  DeviceState.INITIALIZING: 'INITIALIZING',
  DeviceState.INITIALIZED: 'INITIALIZED',
  DeviceState.FAILED_INITIALIZATION: 'FAILED_INITIALIZATION'
};

DecryptedTransaction _$DecryptedTransactionFromJson(Map<String, dynamic> json) {
  return DecryptedTransaction(
    merchantName: json['merchantName'] as String,
    merchantType: json['merchantType'] as String,
    amount: json['amount'] as String,
    dateTime: json['dateTime'] as String,
    currencyCode: json['currencyCode'] as String,
    transactionType: json['transactionType'] as String,
    authorizationStatus: json['authorizationStatus'] as String,
  );
}

Map<String, dynamic> _$DecryptedTransactionToJson(
        DecryptedTransaction instance) =>
    <String, dynamic>{
      'merchantName': instance.merchantName,
      'merchantType': instance.merchantType,
      'amount': instance.amount,
      'dateTime': instance.dateTime,
      'currencyCode': instance.currencyCode,
      'transactionType': instance.transactionType,
      'authorizationStatus': instance.authorizationStatus,
    };

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return Transaction(
    transactionId: json['transactionId'] as String,
    encryptedData: json['encryptedData'] as String,
    transactionTimeEpoch: json['transactionTimeEpoch'] as int,
  )..decryptedTransaction = json['decryptedTransaction'] == null
      ? null
      : DecryptedTransaction.fromJson(
          json['decryptedTransaction'] as Map<String, dynamic>);
}

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'transactionId': instance.transactionId,
      'encryptedData': instance.encryptedData,
      'transactionTimeEpoch': instance.transactionTimeEpoch,
      'decryptedTransaction': instance.decryptedTransaction,
    };

Commit _$CommitFromJson(Map<String, dynamic> json) {
  return Commit(
    commitId: json['commitId'] as String,
    commitType: json['commitType'] as String,
    encryptedData: json['encryptedData'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$CommitToJson(Commit instance) => <String, dynamic>{
      '_links': instance.links,
      'commitId': instance.commitId,
      'commitType': instance.commitType,
      'encryptedData': instance.encryptedData,
    };

CommitResponse _$CommitResponseFromJson(Map<String, dynamic> json) {
  return CommitResponse(
    result: _$enumDecodeNullable(_$CommitResultEnumMap, json['result']),
  );
}

Map<String, dynamic> _$CommitResponseToJson(CommitResponse instance) =>
    <String, dynamic>{
      'result': _$CommitResultEnumMap[instance.result],
    };

const _$CommitResultEnumMap = <CommitResult, dynamic>{
  CommitResult.SUCCESS: 'SUCCESS',
  CommitResult.FAILED: 'FAILED',
  CommitResult.SKIPPED: 'SKIPPED'
};

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) {
  return ApiError(
    message: json['message'] as String,
    description: json['description'] as String,
  );
}

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
      'message': instance.message,
      'description': instance.description,
    };

IdvVerificationData _$IdvVerificationDataFromJson(Map<String, dynamic> json) {
  return IdvVerificationData(
    locale: json['locale'] as String,
    nfcCapable: json['nfcCapable'] as bool,
    deviceCountry: json['deviceCountry'] as String,
    oemAccountUserName: json['oemAccountUserName'] as String,
    deviceTimeZone: json['deviceTimeZone'] as String,
    deviceBluetoothMac: json['deviceBluetoothMac'] as String,
    oemAccountCreatedDate: json['oemAccountCreatedDate'] == null
        ? null
        : DateTime.parse(json['oemAccountCreatedDate'] as String),
  );
}

Map<String, dynamic> _$IdvVerificationDataToJson(
        IdvVerificationData instance) =>
    <String, dynamic>{
      'locale': instance.locale,
      'nfcCapable': instance.nfcCapable,
      'deviceCountry': instance.deviceCountry,
      'oemAccountUserName': instance.oemAccountUserName,
      'deviceTimeZone': instance.deviceTimeZone,
      'deviceBluetoothMac': instance.deviceBluetoothMac,
      'oemAccountCreatedDate': _dateTimeToJson(instance.oemAccountCreatedDate),
    };

CreateCreditCardRequest _$CreateCreditCardRequestFromJson(
    Map<String, dynamic> json) {
  return CreateCreditCardRequest(
    cardNumber: json['cardNumber'],
    expMonth: json['expMonth'] as int,
    expYear: json['expYear'] as int,
    securityCode: json['securityCode'],
    name: json['name'],
    street: json['street'],
    city: json['city'],
    country: json['country'],
    state: json['state'],
    postalCode: json['postalCode'],
    deviceId: json['deviceId'],
  )..riskData = json['riskData'] == null
      ? null
      : IdvVerificationData.fromJson(json['riskData'] as Map<String, dynamic>);
}

Map<String, dynamic> _$CreateCreditCardRequestToJson(
        CreateCreditCardRequest instance) =>
    <String, dynamic>{
      'expMonth': instance.expMonth,
      'expYear': instance.expYear,
      'riskData': instance.riskData,
      'cardNumber': instance.cardNumber,
      'name': instance.name,
      'securityCode': instance.securityCode,
      'street': instance.street,
      'city': instance.city,
      'country': instance.country,
      'state': instance.state,
      'postalCode': instance.postalCode,
      'deviceId': instance.deviceId,
    };

GPRAccount _$GPRAccountFromJson(Map<String, dynamic> json) {
  return GPRAccount(
    accountId: json['accountId'] as String,
    cardReferenceId: json['cardReferenceId'] as String,
    deviceSerialNumber: json['deviceSerialNumber'] as String,
    state: json['state'] as String,
    lastTransferId: json['lastTransferId'] as String,
    programUserId: json['programUserId'] as String,
    programAccountReferenceId: json['programAccountReferenceId'] as String,
    i2cCardProgramId: json['i2cCardProgramId'] as String,
    programCardReferenceIds: (json['programCardReferenceIds'] as List)
        ?.map((e) => e as String)
        ?.toList(),
    transferLimit: (json['transferLimit'] as num)?.toDouble(),
    currentBalance: (json['currentBalance'] as num)?.toDouble(),
    errors: (json['errors'] as List)?.map((e) => e as String)?.toList(),
    createdTsEpoch: json['createdTsEpoch'] as String,
    lastModifiedTsEpoch: json['lastModifiedTsEpoch'] as String,
    accountType:
        _$enumDecodeNullable(_$GprAccountTypeEnumMap, json['accountType']),
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$GPRAccountToJson(GPRAccount instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'accountId': instance.accountId,
      'cardReferenceId': instance.cardReferenceId,
      'deviceSerialNumber': instance.deviceSerialNumber,
      'state': instance.state,
      'lastTransferId': instance.lastTransferId,
      'programUserId': instance.programUserId,
      'programAccountReferenceId': instance.programAccountReferenceId,
      'i2cCardProgramId': instance.i2cCardProgramId,
      'programCardReferenceIds': instance.programCardReferenceIds,
      'transferLimit': instance.transferLimit,
      'currentBalance': instance.currentBalance,
      'errors': instance.errors,
      'createdTsEpoch': instance.createdTsEpoch,
      'lastModifiedTsEpoch': instance.lastModifiedTsEpoch,
      'accountType': _$GprAccountTypeEnumMap[instance.accountType],
    };

const _$GprAccountTypeEnumMap = <GprAccountType, dynamic>{
  GprAccountType.GPR: 'GPR',
  GprAccountType.PREPAID: 'PREPAID',
  GprAccountType.HYBRID: 'HYBRID'
};

FCMEvent _$FCMEventFromJson(Map<String, dynamic> json) {
  return FCMEvent(
    type: json['type'] as String,
    version: json['version'] as int,
    metadata: json['metadata'] as Map<String, dynamic>,
    payload: json['payload'] as String,
  );
}

Map<String, dynamic> _$FCMEventToJson(FCMEvent instance) => <String, dynamic>{
      'type': instance.type,
      'version': instance.version,
      'metadata': instance.metadata,
      'payload': instance.payload,
    };

FitPayEvent _$FitPayEventFromJson(Map<String, dynamic> json) {
  return FitPayEvent(
    type: json['type'] as String,
    version: json['version'] as int,
    payload: json['payload'] as Map<String, dynamic>,
    metadata: json['metadata'] as Map<String, dynamic>,
  );
}

Map<String, dynamic> _$FitPayEventToJson(FitPayEvent instance) =>
    <String, dynamic>{
      'type': instance.type,
      'version': instance.version,
      'metadata': instance.metadata,
      'payload': instance.payload,
    };

GPRTransaction _$GPRTransactionFromJson(Map<String, dynamic> json) {
  return GPRTransaction(
    transactionId: json['transactionId'] as String,
    transactionType: json['transactionType'] as String,
    amount: (json['amount'] as num)?.toDouble(),
    currencyCode: json['currencyCode'] as String,
    authorizationStatus: json['authorizationStatus'] as String,
    transactionTime: json['transactionTime'] as String,
    transactionTimeEpoch: json['transactionTimeEpoch'] as int,
    merchantName: json['merchantName'] as String,
    merchantCode: json['merchantCode'] as String,
    merchantType: json['merchantType'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$GPRTransactionToJson(GPRTransaction instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'transactionId': instance.transactionId,
      'transactionType': instance.transactionType,
      'amount': instance.amount,
      'currencyCode': instance.currencyCode,
      'authorizationStatus': instance.authorizationStatus,
      'transactionTime': instance.transactionTime,
      'transactionTimeEpoch': instance.transactionTimeEpoch,
      'merchantName': instance.merchantName,
      'merchantCode': instance.merchantCode,
      'merchantType': instance.merchantType,
    };

FundingSource _$FundingSourceFromJson(Map<String, dynamic> json) {
  return FundingSource(
    accountNumber: json['accountNumber'] as String,
    routingNumber: json['routingNumber'] as String,
    nameOnAccount: json['nameOnAccount'] as String,
    userId: json['userId'] as String,
    fundingType:
        _$enumDecodeNullable(_$FundingTypeEnumMap, json['fundingType']),
    displayName: json['displayName'] as String,
    accountId: json['accountId'] as String,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$FundingSourceToJson(FundingSource instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'accountNumber': instance.accountNumber,
      'routingNumber': instance.routingNumber,
      'nameOnAccount': instance.nameOnAccount,
      'userId': instance.userId,
      'fundingType': _$FundingTypeEnumMap[instance.fundingType],
      'displayName': instance.displayName,
      'accountId': instance.accountId,
    };

const _$FundingTypeEnumMap = <FundingType, dynamic>{
  FundingType.topUp: 'TOPUP',
  FundingType.ach: 'ACH'
};

Funding _$FundingFromJson(Map<String, dynamic> json) {
  return Funding(
    fundingState:
        _$enumDecodeNullable(_$FundingStateEnumMap, json['fundingState']),
    fundingId: json['fundingId'] as String,
    accountId: json['accountId'] as String,
    fundingSourceId: json['fundingSourceId'] as String,
    description: json['description'] as String,
    fundingAmount: (json['fundingAmount'] as num)?.toDouble(),
    nextFundingTs: _dateTimeFromJson(json['nextFundingTs'] as String),
    isRecurring: json['isRecurring'] as bool,
    lowAmountTopUp: (json['lowAmountTopUp'] as num)?.toDouble(),
    topAmountTopUp: (json['topAmountTopUp'] as num)?.toDouble(),
    displayName: json['displayName'] as String,
    fundingType:
        _$enumDecodeNullable(_$FundingTypeEnumMap, json['fundingType']),
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$FundingToJson(Funding instance) => <String, dynamic>{
      '_links': instance.links,
      'fundingState': _$FundingStateEnumMap[instance.fundingState],
      'fundingId': instance.fundingId,
      'accountId': instance.accountId,
      'fundingSourceId': instance.fundingSourceId,
      'description': instance.description,
      'fundingAmount': instance.fundingAmount,
      'nextFundingTs': _dateTimeToJson(instance.nextFundingTs),
      'isRecurring': instance.isRecurring,
      'lowAmountTopUp': instance.lowAmountTopUp,
      'topAmountTopUp': instance.topAmountTopUp,
      'displayName': instance.displayName,
      'fundingType': _$FundingTypeEnumMap[instance.fundingType],
    };

const _$FundingStateEnumMap = <FundingState, dynamic>{
  FundingState.ACTIVE: 'ACTIVE',
  FundingState.STOPPED: 'STOPPED',
  FundingState.ERROR: 'ERROR'
};

JsonPatch _$JsonPatchFromJson(Map<String, dynamic> json) {
  return JsonPatch(
    op: _$enumDecodeNullable(_$JsonPatchOpEnumMap, json['op']),
    path: json['path'] as String,
    value: json['value'],
  );
}

Map<String, dynamic> _$JsonPatchToJson(JsonPatch instance) => <String, dynamic>{
      'op': _$JsonPatchOpEnumMap[instance.op],
      'path': instance.path,
      'value': instance.value,
    };

const _$JsonPatchOpEnumMap = <JsonPatchOp, dynamic>{
  JsonPatchOp.add: 'add',
  JsonPatchOp.remove: 'remove',
  JsonPatchOp.replace: 'replace'
};

PaymentDeviceInformation _$PaymentDeviceInformationFromJson(
    Map<String, dynamic> json) {
  return PaymentDeviceInformation(
    manufacturerName: json['manufacturerName'] as String,
    softwareRevision: json['softwareRevision'] as String,
    firmwareRevision: json['firmwareRevision'] as String,
    hardwareRevision: json['hardwareRevision'] as String,
    modelNumber: json['modelNumber'] as String,
    systemId: json['systemId'] as String,
    deviceName: json['deviceName'] as String,
    osName: json['osName'] as String,
    countryCode: json['countryCode'] as String,
    serialNumber: json['serialNumber'] as String,
    deviceType: _$enumDecodeNullable(_$DeviceTypeEnumMap, json['deviceType']),
    secureElement: json['secureElement'] == null
        ? null
        : SecureElement.fromJson(json['secureElement'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$PaymentDeviceInformationToJson(
        PaymentDeviceInformation instance) =>
    <String, dynamic>{
      'manufacturerName': instance.manufacturerName,
      'softwareRevision': instance.softwareRevision,
      'firmwareRevision': instance.firmwareRevision,
      'hardwareRevision': instance.hardwareRevision,
      'modelNumber': instance.modelNumber,
      'systemId': instance.systemId,
      'deviceName': instance.deviceName,
      'osName': instance.osName,
      'countryCode': instance.countryCode,
      'serialNumber': instance.serialNumber,
      'deviceType': _$DeviceTypeEnumMap[instance.deviceType],
      'secureElement': instance.secureElement,
    };

Application _$ApplicationFromJson(Map<String, dynamic> json) {
  return Application(
    applicationId: json['applicationId'] as String,
    applicationState: _$enumDecodeNullable(
        _$ApplicationStateEnumMap, json['applicationState']),
    accountId: json['accountId'] as String,
    cardId: json['cardId'] as String,
    userId: json['userId'] as String,
    programId: json['programId'] as String,
    dateSubmitedTs: json['dateSubmitedTs'] as String,
    dateCreatedTs: json['dateCreatedTs'] as String,
    lastModifiedTs: json['lastModifiedTs'] as String,
    kycSteps: (json['kycSteps'] as List)
        ?.map((e) => e == null
            ? null
            : ApplicationPage.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    dateSubmitedTsEpoch: json['dateSubmitedTsEpoch'] as int,
    dateCreatedTsEpoch: json['dateCreatedTsEpoch'] as int,
    lastModifiedTsEpoch: json['lastModifiedTsEpoch'] as int,
    links: (json['_links'] as Map<String, dynamic>).map(
      (k, e) => MapEntry(k, Link.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$ApplicationToJson(Application instance) =>
    <String, dynamic>{
      '_links': instance.links,
      'applicationId': instance.applicationId,
      'applicationState': _$ApplicationStateEnumMap[instance.applicationState],
      'accountId': instance.accountId,
      'cardId': instance.cardId,
      'userId': instance.userId,
      'programId': instance.programId,
      'dateSubmitedTs': instance.dateSubmitedTs,
      'dateCreatedTs': instance.dateCreatedTs,
      'lastModifiedTs': instance.lastModifiedTs,
      'kycSteps': instance.kycSteps,
      'dateSubmitedTsEpoch': instance.dateSubmitedTsEpoch,
      'dateCreatedTsEpoch': instance.dateCreatedTsEpoch,
      'lastModifiedTsEpoch': instance.lastModifiedTsEpoch,
    };

const _$ApplicationStateEnumMap = <ApplicationState, dynamic>{
  ApplicationState.NEW: 'NEW',
  ApplicationState.APPROVED: 'APPROVED',
  ApplicationState.DECLINED: 'DECLINED'
};

ApplicationPage _$ApplicationPageFromJson(Map<String, dynamic> json) {
  return ApplicationPage(
    pageId: json['pageId'] as String,
    name: json['name'] as String,
    length: json['length'] as int,
    index: json['index'] as int,
    fields: (json['fields'] as List)
        ?.map((e) => e == null
            ? null
            : ApplicationField.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$ApplicationPageToJson(ApplicationPage instance) =>
    <String, dynamic>{
      'pageId': instance.pageId,
      'name': instance.name,
      'length': instance.length,
      'index': instance.index,
      'fields': instance.fields,
    };

ApplicationField _$ApplicationFieldFromJson(Map<String, dynamic> json) {
  return ApplicationField(
    fieldId: json['fieldId'] as String,
    name: json['name'] as String,
    value: json['value'],
    regex: json['regex'] as String,
    index: json['index'] as int,
    optional: json['optional'] as bool,
    type: _$enumDecodeNullable(_$FieldTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$ApplicationFieldToJson(ApplicationField instance) =>
    <String, dynamic>{
      'fieldId': instance.fieldId,
      'name': instance.name,
      'regex': instance.regex,
      'optional': instance.optional,
      'type': _$FieldTypeEnumMap[instance.type],
      'index': instance.index,
      'value': instance.value,
    };

const _$FieldTypeEnumMap = <FieldType, dynamic>{
  FieldType.text: 'TEXT',
  FieldType.decimal: 'DECIMAL',
  FieldType.float: 'FLOAT',
  FieldType.date: 'DATE'
};
