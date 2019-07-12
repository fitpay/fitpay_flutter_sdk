import 'package:rx_ble/rx_ble.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:convert/convert.dart';
import 'package:fitpay_flutter_sdk/fitpay_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'hndx_images.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hndx_models.g.dart';

class HendricksBleDeviceDiscovered {
  ScanResult scanResult;

  HendricksBleDeviceDiscovered({this.scanResult});

  int get strength {
    int strength;
    int rssi = scanResult.rssi;
    if (rssi <= -100) {
      strength = 0;
    } else if (rssi >= -50) {
      strength = 100;
    } else {
      strength = 2 * (rssi + 100);
    }

    return strength;
  }
}

class HndxResult {}

enum HndxCmdState { sending, waiting, receiving, complete, failed }

class HndxBle {
  static const HNDX_SERVICE = "7DB2E9EA-ADF6-4F18-A110-61055D64B287";
  static const STATUS_CHAR = "7DB2134A-ADF6-4F18-A110-61055D64B287";
  static const COMMAND_CHAR = "7DB20256-ADF6-4F18-A110-61055D64B287";
  static const DATA_CHAR = "7DB2E528-ADF6-4F18-A110-61055D64B287";
}

class HndxStatus {
  static const STATUS_START = 0x01;
  static const STATUS_END = 0x02;
  static const STATUS_ABORT = 0x03;
  static const SUCCESS = 0x01;
}

class HndxStatusAck {
  static const SUCCESS = 0x01;
  static const FAILURE = 0x02;
  static const READY = 0x03;

  final int status;
  final int length;
  final int command;
  final int errorCode;

  bool get successful => status == SUCCESS;
  bool get nack => status == FAILURE;
  bool get ready => status == READY;

  HndxStatusAck({this.status, this.length, this.command, this.errorCode});

  factory HndxStatusAck.fromData(Uint8List data) {
    if (data.length != 7) {
      print('status ack/nack response was not 7 bytes [${hex.encode(data)}], length: ${data.length}');
      throw 'invalid ack/nack message, unexpected length';
    }

    return HndxStatusAck(
      status: data[0],
      errorCode: data[1],
      command: data[2],
      length: (data[6] << 24) | (data[5] << 16) | (data[4] << 8) | (data[3] & 0xFF),
    );
  }
}

class HndxCmd {
  static const PING = 0x01;
  static const BOOTLOADER = 0x03;
  static const GET_CATEGORIES = 0x1C;
  static const APDU_PACKAGE = 0x20;
  static const GET_OBJECT = 0x1D;
  static const DELETE_OBJECT = 0x15;
  static const ADD_CARD = 0x13;
  static const ACTIVATE_CARD = 0x16;
  static const DEACTIVATE_CARD = 0x18;
  static const FACTORY_RESET = 0x07;
  static const CLEAR_FACTORY_RESET = 0x21;
  static const ADD_FAV_CAT = 0x1E;
  static const REMOVE_FAV_CAT = 0x1F;
}

class HndxResultState {
  final HndxCmdState state;
  final HndxResult result;
  HndxResultState({this.state, this.result});
}

enum DeviceMode { application, selfTest, bootloader, unknown }

class HndxAddCardData {
  final Uint8List command;
  final Uint8List data;

  HndxAddCardData(this.command, this.data);
}

class HndxAddCardDataResult extends HndxResult {
  final Uint8List cardOid;

  HndxAddCardDataResult(this.cardOid);
}

class HndxCategory {
  final Uint8List categoryId;
  final String title;
  final List<HndxObject> objects = [];

  HndxCategory(this.categoryId, this.title);
}

class HndxObject extends HndxResult {
  final Uint8List categoryId;
  final Uint8List oid;
  final bool isFavorite;

  HndxObject(this.categoryId, this.oid, this.isFavorite);

  factory HndxObject.fromData(Uint8List data) {
    int idx = 0;

    Uint8List categoryId = data.sublist(idx, idx + 2);
    idx += 2;
    Uint8List oid = data.sublist(idx, idx + 2);
    idx += 2;
    bool isFavorite = data.elementAt(idx++) == 1;

    HndxObject obj;
    switch (categoryId[0]) {
      case 1:
        obj = HndxObjectIdentity(categoryId, oid, isFavorite);
        break;
      case 2:
        obj = HndxObjectCard(categoryId, oid, isFavorite, data.sublist(idx));
        break;
      case 3:
        obj = HndxObjectMisc(categoryId, oid, isFavorite);
        break;
      default:
        print('unrecognized category ${categoryId.toString()} for oid ${oid.toString()}');
    }

    return obj;
  }
}

class HndxObjectIdentity extends HndxObject {
  HndxObjectIdentity(categoryId, oid, isFavorite) : super(categoryId, oid, isFavorite);
}

class HndxObjectCard extends HndxObject {
  String lastFour;
  String expDate;
  String cardType;
  String _creditCardId;
  int cardStatus;

  String get creditCardId => _creditCardId != null ? _creditCardId.trim() : null;

  HndxObjectCard(categoryId, oid, isFavorite, data) : super(categoryId, oid, isFavorite) {
    int idx = 0;

    lastFour = RxBle.charToString(data.sublist(idx, idx + HndxCardUtils.HNDX_CARD_LASTFOUR_LEN));
    idx += HndxCardUtils.HNDX_CARD_LASTFOUR_LEN;

    expDate = RxBle.charToString(data.sublist(idx, idx + HndxCardUtils.HNDX_CARD_EXP_LEN));
    idx += HndxCardUtils.HNDX_CARD_EXP_LEN;

    cardType = RxBle.charToString(data.sublist(idx, idx + HndxCardUtils.HNDX_CARD_TYPE_LEN));
    idx += HndxCardUtils.HNDX_CARD_TYPE_LEN;

    _creditCardId = RxBle.charToString(data.sublist(idx, idx + HndxCardUtils.HNDX_CARD_CARDID_LEN));
    idx += HndxCardUtils.HNDX_CARD_CARDID_LEN;

    cardStatus = data.elementAt(idx++);
  }

  @override
  String toString() {
    return 'HndxObjectCard - lastFour: $lastFour, expDate $expDate, cardType: $cardType, creditCardId: $creditCardId, status: $cardStatus';
  }
}

class HndxObjectMisc extends HndxObject {
  HndxObjectMisc(categoryId, oid, isFavorite) : super(categoryId, oid, isFavorite);
}

class HndxGetCategoriesResult extends HndxResult {
  final List<HndxCategory> categories;

  HndxGetCategoriesResult(this.categories);

  factory HndxGetCategoriesResult.fromData(Uint8List data) {
    List<HndxCategory> categories = [];

    int idx = 0;
    int numberOfCategories = data.elementAt(idx++);
    for (var i = 0; i < numberOfCategories; i++) {
      Uint8List categoryId = data.sublist(idx, idx + 2);
      idx += 2;

      HndxCategory category = HndxCategory(
        categoryId,
        RxBle.charToString(data.sublist(idx, idx + 8)),
      );
      idx += 8;
      int numberOfObjects = data.elementAt(idx++);
      for (var j = 0; j < numberOfObjects; j++) {
        category.objects.add(HndxObject(category.categoryId, data.sublist(idx, idx + 2), null));
        idx += 2;
      }

      categories.add(category);
    }

    return HndxGetCategoriesResult(categories);
  }
}

class HndxCategoryUtils {
  static Uint8List getObjectCommand(Uint8List categoryId, Uint8List oid) {
    BytesBuilder buf = BytesBuilder();
    buf.addByte(HndxCmd.GET_OBJECT);
    buf.add(categoryId);
    buf.add(oid);

    return Uint8List.fromList(buf.toBytes());
  }

  static Uint8List getDeleteCommand(Uint8List oid) {
    BytesBuilder buf = BytesBuilder();
    buf.addByte(HndxCmd.DELETE_OBJECT);
    buf.add(oid);

    return Uint8List.fromList(buf.toBytes());
  }

  static Uint8List getActivateCommand(Uint8List oid) {
    BytesBuilder buf = BytesBuilder();
    buf.addByte(HndxCmd.ACTIVATE_CARD);
    buf.add(oid);

    return Uint8List.fromList(buf.toBytes());
  }

  static Uint8List getDeactivateCommand(Uint8List oid) {
    BytesBuilder buf = BytesBuilder();
    buf.addByte(HndxCmd.DEACTIVATE_CARD);
    buf.add(oid);

    return Uint8List.fromList(buf.toBytes());
  }
}

class HndxCardUtils {
  static const int HNDX_CARD_STATUS_CREATED = 0x01;
  static const int HNDX_CARD_STATUS_ACTIVATED = 0x02;
  static const int TOW_AID_LENGTH_OFFSET = 0x06;
  static const int HNDX_IMAGE_WIDTH = 200;
  static const int HNDX_IMAGE_HEIGHT = 126;

  static const int HNDX_CARD_LASTFOUR_LEN = 5;
  static const int HNDX_CARD_EXP_LEN = 6;
  static const int HNDX_CARD_TYPE_LEN = 21;
  static const int HNDX_CARD_CARDID_LEN = 37;
  static const int HNDX_CARD_STATUS_LEN = 1;
  static const int HNDX_ADD_CARD_DATA_LEN =
      (HNDX_CARD_LASTFOUR_LEN + HNDX_CARD_EXP_LEN + HNDX_CARD_TYPE_LEN + HNDX_CARD_CARDID_LEN + HNDX_CARD_STATUS_LEN);

  static Future<HndxAddCardData> addCardCmd(API api, CreditCard card, Uint8List oid,
      {addToFavorites = false, cardStatus = HNDX_CARD_STATUS_CREATED}) async {
    BytesBuilder command = BytesBuilder();
    BytesBuilder data = BytesBuilder();

    command.addByte(HndxCmd.ADD_CARD);

    Uint8List towBytes = towData(card);
    Uint8List imgBytes = await cardImgData(api, card);

    int metadataSize = HNDX_ADD_CARD_DATA_LEN;
    int towSize = towBytes.length;
    int imgSize = imgBytes.length;

    command.addByte(metadataSize & 0xFF);
    command.addByte((metadataSize >> 8) & 0xFF);
    command.addByte((metadataSize >> 16) & 0xFF);
    command.addByte((metadataSize >> 24) & 0xFF);

    //TOW size
    command.addByte(towSize & 0xFF);
    command.addByte((towSize >> 8) & 0xFF);
    command.addByte((towSize >> 16) & 0xFF);
    command.addByte((towSize >> 24) & 0xFF);

    //Art size
    command.addByte(imgSize & 0xFF);
    command.addByte((imgSize >> 8) & 0xFF);
    command.addByte((imgSize >> 16) & 0xFF);
    command.addByte((imgSize >> 24) & 0xFF);

    // add to favorites
    command.addByte(addToFavorites ? 1 : 0); // 1 or 0

    // upsert if we can!
    command.add(oid != null ? oid : Uint8List.fromList([0x00, 0x00]));

    String pan = '';
    int expMo = 0;
    int expYr = 0;
    if (card.encryptedData != null) {
      Map<String, dynamic> ed = await api.encryptor.decrypt(card.encryptedData);
      pan = ed['pan'];
      expMo = ed['expMonth'];
      expYr = ed['expYear'];
    }

    if (pan.length >= 4) {
      pan = pan.substring(pan.length - 4, pan.length);
    }
    var exp = '$expMo/$expYr';

    data.add(encodeString(pan, HNDX_CARD_LASTFOUR_LEN));
    data.add(encodeString(exp, HNDX_CARD_EXP_LEN));
    data.add(encodeString(card.cardType, HNDX_CARD_TYPE_LEN));
    data.add(encodeString(card.creditCardId, HNDX_CARD_CARDID_LEN));

    // card status
    data.addByte(cardStatus & 0xFF);

    // tow data
    data.add(towBytes);

    // img data
    data.add(imgBytes);

    return HndxAddCardData(Uint8List.fromList(command.toBytes()), Uint8List.fromList(data.toBytes()));
  }

  // right pad strings with 0x00, gawd my brain isn't working there has to be a cleaner way to do this
  // brute force until the fog clears!
  static Uint8List encodeString(String str, int maxLength) {
    var s = str != null ? str : '';
    if (s.length > maxLength) s = s.substring(0, maxLength);

    BytesBuilder buf = BytesBuilder();
    Uint8List b = RxBle.stringToChar(s);
    for (var i = 0; i < (maxLength - b.length); i++) {
      buf.addByte(0x00);
    }

    buf.add(b);
    return Uint8List.fromList(buf.toBytes());
  }

  static Future<Uint8List> cardImgData(API api, CreditCard card) async {
    const defaultImageUrl =
        'https://proxy.duckduckgo.com/iu/?u=http%3A%2F%2Fwww.pngpix.com%2Fwp-content%2Fuploads%2F2016%2F11%2FPNGPIX-COM-Credit-Card-Vector-PNG-Transparent-Image.png&f=1';
    String imgUrl;

    if (card.cardMetaData == null ||
        card.cardMetaData.cardBackgroundCombined == null ||
        card.cardMetaData.cardBackgroundCombined.length == 0 ||
        card.cardMetaData.cardBackgroundCombined[0].self == null) {
      print('return stock image, no card card found on ${card.creditCardId}');
      imgUrl = defaultImageUrl;
    } else {
      Uri uri = Uri.parse(card.cardMetaData.cardBackgroundCombined[0].self);

      Map<String, String> queryParameters = Map.from(uri.queryParameters);

      String pan = '';
      if (card.encryptedData != null) {
        pan = (await api.encryptor.decrypt(card.encryptedData))['pan'];
      }

      if (pan.length >= 4) {
        pan = pan.substring(pan.length - 4, pan.length);
      }

      String text = '•••• $pan';
      var foregroundColor = card.cardMetaData.foregroundColor ?? 'ffffff';

      queryParameters['embossedText'] = text;
      queryParameters['embossedForegroundColor'] = foregroundColor;
      queryParameters['w'] = '$HNDX_IMAGE_WIDTH';
      queryParameters['h'] = '$HNDX_IMAGE_HEIGHT';
      queryParameters['fs'] = '30';
      queryParameters['txs'] = '0.9';
      queryParameters['tys'] = '.125';
      queryParameters['fn'] = 'Arial';
      queryParameters['fb'] = 'true';
      queryParameters['rc'] = 'true';

      imgUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryParameters: queryParameters,
      ).toString();
    }

    var response = await http.get(imgUrl, headers: {'Accept': 'image/png'});
    if (response.statusCode != 200) {
      print('no card art from: $imgUrl, using default');
      response = await http.get(defaultImageUrl, headers: {'Accept': 'image/png'});
    }

    return HndxImgUtils.convert(response.bodyBytes);
  }

  static Uint8List towData(CreditCard card) {
    List<APDUCommand> towCommands;

    bool requireFixingAid = false;
    if (card.offlineSeActions.containsKey('activate')) {
      towCommands = card.offlineSeActions['activate'].apduCommands;
    } else if (card.offlineSeActions.containsKey('topOfWallet')) {
      requireFixingAid = true;
      towCommands = card.offlineSeActions['topOfWallet'].apduCommands;
    } else {
      towCommands = [
        APDUCommand(
          commandId: 'ad56010a-3199-410b-a7e7-c9318752f5b6',
          command: '00A4040009A00000015143525300',
          groupId: 0,
          sequence: 0,
          type: 'SELECT_CRS',
          injected: true,
          continueOnFailure: false,
        )
      ];
    }

    // NXP manipulation of TOW commands, hopefully not needed anymore with the new 'activate' commands
    if (requireFixingAid) {
      // find the apdu command with the AID
      int aidIndex = -1;
      for (int i = 0; i < towCommands.length; i++) {
        List<int> cmd = hex.decode(towCommands[i].command);
        if (cmd[0] == 0x80 && cmd[1] == 0xF0 && cmd[2] == 0x02 && cmd[3] == 0x02) {
          aidIndex = i;
          break;
        }
      }

      if (aidIndex != -1) {
        // extract aid bytes from the full apdu command
        List<int> cmdWithAid = hex.decode(towCommands[aidIndex].command);
        int aidLength = cmdWithAid[TOW_AID_LENGTH_OFFSET];
        List<int> aidBytes = cmdWithAid.sublist(TOW_AID_LENGTH_OFFSET, aidLength + 1);

        towCommands = [];
        int sequence = 0;
        towCommands.add(APDUCommand(
          commandId: 'f008a024-b597-4a23-94cd-50b15175cec7',
          command: '00A4040009A00000015143525300',
          groupId: 0,
          sequence: sequence++,
          type: 'SELECT_CRS',
          injected: false,
          continueOnFailure: false,
        ));
        towCommands.add(APDUCommand(
          commandId: '2f8dc2fb-b2fa-47a9-b55f-9df0e2dfa5da',
          command: '80C3010000',
          groupId: 0,
          sequence: sequence++,
          type: 'DEACTIVATE_DEFAULT_CARD',
          injected: false,
          continueOnFailure: true,
        ));
        towCommands.add(APDUCommand(
          commandId: 'c09104c8-1d86-4cfd-97d5-5a232204d725',
          command: '80C10000${hex.encode(aidBytes).toUpperCase()}',
          groupId: 0,
          sequence: sequence++,
          type: 'SET_DEFAULT_CARD',
          injected: false,
          continueOnFailure: false,
        ));

        towCommands.add(APDUCommand(
          commandId: '042376e8-0214-421e-8c90-c7a41ac8b4f3',
          command: '80C3010100',
          groupId: 0,
          sequence: sequence++,
          type: 'ACTIVATE_DEFAULT_CARD',
          injected: false,
          continueOnFailure: false,
        ));
      }
    }

    BytesBuilder towBytes = BytesBuilder();
    towCommands.forEach((cmd) {
      towBytes.add(HndxApduUtils.transformApduCommand(cmd));
    });

    return Uint8List.fromList(towBytes.toBytes());
  }
}

class HndxApduUtils {
  static List<int> transformApduCommand(APDUCommand cmd) {
    BytesBuilder buf = BytesBuilder();

    buf.addByte(cmd.groupId);
    buf.add([cmd.sequence & 0xFF, (cmd.sequence >> 8) & 0xFF]);
    buf.addByte(cmd.continueOnFailure ? 0x01 : 0x00);

    List<int> apduCommand = hex.decode(cmd.command);
    buf.add([apduCommand.length & 0xFF, (apduCommand.length >> 8) & 0xFF]);
    buf.add(apduCommand);

    return buf.toBytes();
  }

  static Uint8List apduPackageData(APDUPackage package) {
    BytesBuilder buf = BytesBuilder();

    package.commandApdus.forEach((cmd) {
      buf.add(transformApduCommand(cmd));
    });

    return Uint8List.fromList(buf.toBytes());
  }

  static Uint8List apduPackageCommand(APDUPackage package, Uint8List data) {
    BytesBuilder buf = BytesBuilder();

    buf.addByte(0x20); // apdu package command
    buf.add([package.commandApdus.length & 0xFF, (package.commandApdus.length >> 8) & 0xFF]);
    buf.add([
      data.length & 0xFF,
      (data.length >> 8) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 24) & 0xFF,
    ]);

    return Uint8List.fromList(buf.toBytes());
  }

  static Future<List<ApduCommandResult>> parseApduCommandResults(APDUPackage apduPackage, Uint8List data) async {
    int idx = 0;
    List<ApduCommandResult> results = [];

    for (var i = 0; i < apduPackage.commandApdus.length; i++) {
      APDUCommand cmd = apduPackage.commandApdus[i];

      int groupId = data[idx++] & 0xFF;
      int sequence = (data[idx++] & 0xFF) | (data[idx++] << 8 & 0xFF);
      bool continueOnFailure = data[idx++] == 1;
      int len = (data[idx++] & 0xFF) | (data[idx++] << 8 & 0xFF);
      List<int> responseData = data.sublist(idx, idx + len);
      List<int> responseCode = responseData.sublist(responseData.length - 2, responseData.length);
      idx += len;

      if (cmd.groupId != groupId && sequence != cmd.sequence) {
        print(
            'APDU command from groupId: $groupId sequence: $sequence returned does not match expect groupId: ${cmd.groupId} sequence: ${cmd.sequence}');
        break;
      }

      results.add(ApduCommandResult(
        commandId: cmd.commandId,
        responseCode: hex.encode(responseCode),
        responseData: hex.encode(responseData),
      ));

      if (idx >= data.length) {
        print('Number of APDU command returned from hndx device was not long enough for the package sent!');
        break;
      } else if (responseCode[0] != 0x90 && responseCode[1] != 0x00 && !continueOnFailure) {
        break;
      }
    }
    return results;
  }
}

class HendricksApduResponse extends HndxResult {
  final Uint8List data;
  HendricksApduResponse(this.data);
}

@JsonSerializable(nullable: false)
class HendricksDeviceInfo extends HndxResult {
  static const NRF_RESP_TAG = 0x24;
  static const NRF_SERIAL_TYPE = 0x00;
  static const NRF_VERSION_TYPE = 0x01;
  static const NRF_BOOTLOADER_VERSION_TYPE = 0x17;
  static const D21_APP_VERSION_TYPE = 0x18;
  static const D21_BOOTLOADER_VERSION_TYPE = 0x19;
  static const NRF_HARDWARE_VERSION_TYPE = 0x1A;
  static const NRF_BLE_MAC_TYPE = 0x1B;
  static const BUILD_HASH = 0x80;
  static const BUILD_BRANCH = 0x81;
  static const BUILD_NUM = 0x82;
  static const DEVICE_ID_TYPE = 0x02;
  static const FACTORY_RESET_INDICATOR = 0x1f;
  static const DEVICE_MODE_TYPE = 0x03;
  static const DEVICE_MODE_SELF_TEST = 0x00;
  static const DEVICE_MODE_BOOTLOADER = 0x01;
  static const DEVICE_MODE_APP = 0x02;

  DeviceMode deviceMode;
  String firmwareVersion;
  String bootloaderVersion;
  String d21AppVersion;
  String d21BootloaderVersion;
  String hardwareVersion;
  int deviceId;
  String serialNumber;
  String mac;
  String buildHash;
  String buildNumber;
  String buildBranch;
  bool factoryResetIndicator;

  HendricksDeviceInfo();

  factory HendricksDeviceInfo.fromData(Uint8List data) {
    HendricksDeviceInfo info = HendricksDeviceInfo();

    Map<int, Uint8List> parsedPing = _parseDevicePing(data);

    switch (parsedPing[DEVICE_MODE_TYPE][0]) {
      case DEVICE_MODE_SELF_TEST:
        info.deviceMode = DeviceMode.selfTest;
        break;
      case DEVICE_MODE_APP:
        info.deviceMode = DeviceMode.application;
        break;
      case DEVICE_MODE_BOOTLOADER:
        info.deviceMode = DeviceMode.bootloader;
        break;
      default:
        info.deviceMode = DeviceMode.unknown;
    }

    info.firmwareVersion = _parseVersion(parsedPing[NRF_VERSION_TYPE]);
    info.bootloaderVersion = _parseVersion(parsedPing[NRF_BOOTLOADER_VERSION_TYPE]);
    info.d21AppVersion = _parseVersion(parsedPing[D21_APP_VERSION_TYPE]);
    info.d21BootloaderVersion = _parseVersion(parsedPing[D21_BOOTLOADER_VERSION_TYPE]);
    info.hardwareVersion = _parseVersion(parsedPing[NRF_HARDWARE_VERSION_TYPE]);

    Uint8List deviceIdBytes = parsedPing[DEVICE_ID_TYPE];
    info.deviceId =
        (deviceIdBytes[0] >> 24) | (deviceIdBytes[1] >> 16) | (deviceIdBytes[2] >> 8) | (deviceIdBytes[3] & 0xFF);

    info.serialNumber = hex.encode(parsedPing[NRF_SERIAL_TYPE]);
    info.mac = hex.encode(parsedPing[NRF_BLE_MAC_TYPE]);
    info.buildHash = _str(parsedPing[BUILD_HASH]);
    info.buildBranch = _str(parsedPing[BUILD_BRANCH]);
    info.buildNumber = _str(parsedPing[BUILD_NUM]);
    info.factoryResetIndicator =
        parsedPing.containsKey(FACTORY_RESET_INDICATOR) ? parsedPing[FACTORY_RESET_INDICATOR][0] == 1 : false;

    return info;
  }

  static String _parseVersion(Uint8List data) {
    if (data != null && data.length == 3) {
      return '${data[0]}.${data[1]}.${data[2]}';
    } else {
      return '0.0.0';
    }
  }

  static Map<int, Uint8List> _parseDevicePing(Uint8List data) {
    Map<int, Uint8List> parsed = {};

    for (var i = 0; i < data.length; i++) {
      if (data[i] == NRF_RESP_TAG) {
        int type = data[++i];
        int len = data[++i];
        Uint8List result = data.sublist(++i, i + len);
        parsed[type] = result;

        i += len - 1;
      }
    }

    return parsed;
  }

  static String _str(Uint8List data) {
    if (data != null && data.length > 0) {
      return RxBle.charToString(data);
    } else {
      return null;
    }
  }

  Map<String, dynamic> toJson() => _$HendricksDeviceInfoToJson(this);
}
