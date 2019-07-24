import 'payment_device_connector.dart';
import 'models.dart';
import 'utils.dart';
import 'dart:math';

// TODO: This really should respond to the boarding script intead of having a statically
// declared secure element
class MockPaymentDeviceConnector extends PaymentDeviceConnector {
  SecureElement secureElement;

  MockPaymentDeviceConnector()
      : secureElement = SecureElement(
            secureElementId: MockUtils.createRandomCplc(),
            manufacturer: SecureElementManufacturer.st,
            casdCert: MockUtils.VALID_ST_CASD);

  @override
  Future<void> connect(String deviceId) async {
    super.connect(deviceId);
    // simulate a scan
    dispatch(PaymentDeviceState.scanning);

    // simulate a connection
    await Future.delayed(Duration(seconds: 1));
    dispatch(PaymentDeviceState.connecting);

    await Future.delayed(Duration(seconds: 1));
    dispatch(PaymentDeviceState.connected);
  }

  @override
  Future<void> disconnect() async {
    await super.disconnect();

    dispatch(PaymentDeviceState.disconnecting);

    await Future.delayed(Duration(seconds: 2));
    dispatch(PaymentDeviceState.disconnected);
  }

  @override
  Future<PaymentDeviceInformation> get deviceInformation async => PaymentDeviceInformation(
      countryCode: 'US',
      deviceType: DeviceType.MOCK,
      deviceName: 'Mock Device',
      firmwareRevision: '1.0.0',
      softwareRevision: '1.0.0',
      hardwareRevision: '1.0.0',
      manufacturerName: 'Mocker Mocking',
      modelNumber: '2',
      osName: 'ANDROID',
      systemId: '123456',
      serialNumber: '111222333',
      secureElement: secureElement);

  @override
  Stream<APDUExecutionStatus> executeApduPackage(APDUPackage apduPackage) async* {
    int startTime = DateTime.now().millisecondsSinceEpoch;

    yield APDUExecutionStatus(state: APDUExecutionState.starting);
    await Future.delayed(Duration(seconds: 2));

    yield APDUExecutionStatus(state: APDUExecutionState.sending);
    await Future.delayed(Duration(seconds: 5));

    yield APDUExecutionStatus(state: APDUExecutionState.executing);
    await Future.delayed(Duration(seconds: 10));

    yield APDUExecutionStatus(
        result: ApduExecutionResult(
            packageId: apduPackage.packageId,
            state: ApduExecutionResultState.processed,
            executedDuration: DateTime.now().millisecondsSinceEpoch - startTime,
            executedTsEpoch: startTime,
            apduResponses: await Stream.fromIterable(apduPackage.commandApdus ?? [])
                .map((cmd) => ApduCommandResult(
                      commandId: cmd.commandId,
                      responseCode: '9000',
                    ))
                .toList()),
        state: APDUExecutionState.success);
  }
}

class MockUtils {
  static Random random = Random.secure();
  static final String VALID_ST_CASD = "7F218202A4" +
      "7F218201B393102016072916110000000000001122334442038949325F200C434552542E434153442E43549501825F2504201607015F240420210701450CA000000151535043415344005314F8E1CB407F2233139DC304E40B81C21C52BFB3B35F37820100D27D99221AB06EAD71B6BC3D6008661953EBC3BD5A32C49212EFE95BDE0846632D211100AD9C67C0C8904D65823DF4AF76E73360B83943DC16A45471FBFC44E4FB254433BFE678A2E364712C3FFFF86EEB718F927DB12E8E78B3C33F980BF2CE5E333F4CFA9E9A5A3AF09CD779BEB6173D2142013B45357E6B785399C80D2C283A82EDFE8E06A72DEF4E28617700EA7CBAC02197798DA3E7E2F5C84D0F23857846DEC069553E0BCF4DB86E68B3F80C8B95053F588E47910C2BEA34D95136BA4BB4F5C41D7461062EDCD9BAF43249AA2DD005888820F5174AFC626A17C0AB326F39A095E97D99509F6DACAA61C5A31E6D1027504CC31091060111E03A8F4297E15F3850B4D8B6F9282431E1009282C23133D8025A44CC2F8CCE402B79E2A51B4EFA38E9C8A378596181B6410C5A8F7E0BB354332A93DEB40B1CACBFF1FC23B5804B52EBA1811B30E40F77CAC891F42CDCB902BF" +
      "7F2181E893100000000000000000000017021300000142038949325F200C434552542E434153442E4354950200805F2504201702135F240420370213450CA000000151535043415344005314136B48BC5EDAD14857960BE3D8F33867C5DEFBEE7F4946B04104217D6B238C79086A27B0452788845CD7CFB0371A1C314864B9F1F98F7F947FC14E2827C8713F62662D7FDA958834F17CDC8EF23C3435B5A71E9B72D805853B83F001005F3740B8235129450DFAE6B8CD4134EDF3914325D891178E06A6F617FE401F6537BCABD3334BCB29DC35220AC0EC16DCB3885CAC9364A649C316BE6BACE18B4E15FA0C";

  // NXP returns one cert at a time, each wrapped in a 7F21 tag
  static final String VALID_NXP_CASD_CERT = "7F2181E1" +
      "7F2181DD931004143013B73E800163400043959401984207999900019000045F2001009501825F240421161125450100530841E2CF9D3D62AEB05F3781801FCFC2B35116111F5CAB779CAE65D0CB0898E4A0D1DA66228C2D908D29C7A98F1FF5AEC4B3959578D622E7B1EF950ECCB17B2AB5B624BEAFC4DB615A60CF11279C03603D2ECD3D3FD7496BB04E09E3496A3985A0FC918265238819D6610E003A7778A577B848E62F5B452C7FBECDEA129D471C1741C7DE20EF5EE2759A92305D5F3820B628D7D6F68FD4006035F7D18BAA6C9F51BA49DDDFD5125F9AB681B0C9F5F2CF";

  static String createRandomCplc() {
    var cplc = 'BADC0FFEE000';
    cplc += '000B';
    cplc += randomHex(2);
    cplc += '5287';
    cplc += randomHex(8);
    cplc += '60A4';
    cplc += '0823';
    cplc += '4272';
    cplc += randomHex(2);
    cplc += '6250';
    cplc += randomHex(6);
    cplc += '6250';
    cplc += randomHex(4);
    cplc = cplc.toUpperCase();

    return cplc;
  }

  static String randomHex(int byteCount) {
    List<int> l = [];

    for (var i = 0; i < byteCount; i++) {
      l.add(random.nextInt(255));
    }

    return Utils.hexEncode(l);
  }
}
