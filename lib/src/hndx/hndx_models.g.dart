// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hndx_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HendricksDeviceInfo _$HendricksDeviceInfoFromJson(Map<String, dynamic> json) {
  return HendricksDeviceInfo()
    ..deviceMode = _$enumDecode(_$DeviceModeEnumMap, json['deviceMode'])
    ..firmwareVersion = json['firmwareVersion'] as String
    ..bootloaderVersion = json['bootloaderVersion'] as String
    ..d21AppVersion = json['d21AppVersion'] as String
    ..d21BootloaderVersion = json['d21BootloaderVersion'] as String
    ..hardwareVersion = json['hardwareVersion'] as String
    ..deviceId = json['deviceId'] as int
    ..serialNumber = json['serialNumber'] as String
    ..mac = json['mac'] as String
    ..buildHash = json['buildHash'] as String
    ..buildNumber = json['buildNumber'] as String
    ..buildBranch = json['buildBranch'] as String
    ..factoryResetIndicator = json['factoryResetIndicator'] as bool
    ..softDeviceVersion = json['softDeviceVersion'] as String;
}

Map<String, dynamic> _$HendricksDeviceInfoToJson(
        HendricksDeviceInfo instance) =>
    <String, dynamic>{
      'deviceMode': _$DeviceModeEnumMap[instance.deviceMode],
      'firmwareVersion': instance.firmwareVersion,
      'bootloaderVersion': instance.bootloaderVersion,
      'd21AppVersion': instance.d21AppVersion,
      'd21BootloaderVersion': instance.d21BootloaderVersion,
      'hardwareVersion': instance.hardwareVersion,
      'deviceId': instance.deviceId,
      'serialNumber': instance.serialNumber,
      'mac': instance.mac,
      'buildHash': instance.buildHash,
      'buildNumber': instance.buildNumber,
      'buildBranch': instance.buildBranch,
      'factoryResetIndicator': instance.factoryResetIndicator,
      'softDeviceVersion': instance.softDeviceVersion
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

const _$DeviceModeEnumMap = <DeviceMode, dynamic>{
  DeviceMode.application: 'application',
  DeviceMode.selfTest: 'selfTest',
  DeviceMode.bootloader: 'bootloader',
  DeviceMode.unknown: 'unknown'
};
