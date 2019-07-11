# fitpay_flutter_sdk

# Description

This Flutter PlugIn is a wrapper to the FitPay REST API. The included example Flutter application illustrates a complete native wallet experience.

# The Ugly

At this point this SDK is mostly illustrative and not ready for a production use case, the following are the areas that need to be addressed:

-   Data Modeling
    ..- The [models.dart|../blob/master/lib/src/models.dart] only models attributes necessary for a basic wallet experience vs. a full blown integration to FitPay.
-   Payload Encryption
    ..- The decryption of payload data works, but is not entirely abstracted away from the consumer of the SDK like other mobile SDKs from FitPay. The problem has been around `json_serializable` supporting `Future` from the `DataEncryptor` service in a seemless way. I'm sure there is an easy solution, it does need to be addressed.
-   Happy Path Execution
    ..- The API only manages happy path response codes from the FitPay API, negative cases need to be addressed raising exceptions the UX consumer can present.

# SDK Use Cases

## Creating a Credit Card

Creating a credit card can be a complex process due to it's asyncrounous nature along with the required state changes for a typical wallet. The SDK abstracts this complexity away in [createCreditCard()|../blob/master/lib/src/api.dart]. As the creation of the credit card progresses as `Stream` of `CreditCardCreationStatus` instances are emitted to allow for UX progress to be displayed.

## Accepting Issuer Terms & Conditions

Accepting issuer terms & conditions is another complex potentially asyncrounous process that includes the following challenges:

-   Card state changes can be delayed while device requirements are met
-   Accept terms link template management for state managed by the client and not the FitPay platform

See [acceptCreditCardTerms()|../blob/master/lib/src/api.dart] where similar to `createCreditCard()` a `Stream` of `CreditCardAcceptTermsStatus` is emitted to allow for UX progress to be displayed.
