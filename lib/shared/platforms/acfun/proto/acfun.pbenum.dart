// This is a generated file - do not edit.
//
// Generated from acfun.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class RegisterRequest_PresenceStatus extends $pb.ProtobufEnum {
  static const RegisterRequest_PresenceStatus kPresenceOffline =
      RegisterRequest_PresenceStatus._(0, _omitEnumNames ? '' : 'kPresenceOffline');
  static const RegisterRequest_PresenceStatus kPresenceOnline =
      RegisterRequest_PresenceStatus._(1, _omitEnumNames ? '' : 'kPresenceOnline');

  static const $core.List<RegisterRequest_PresenceStatus> values = <RegisterRequest_PresenceStatus>[
    kPresenceOffline,
    kPresenceOnline,
  ];

  static final $core.List<RegisterRequest_PresenceStatus?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static RegisterRequest_PresenceStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RegisterRequest_PresenceStatus._(super.value, super.name);
}

class RegisterRequest_ActiveStatus extends $pb.ProtobufEnum {
  static const RegisterRequest_ActiveStatus kInvalid =
      RegisterRequest_ActiveStatus._(0, _omitEnumNames ? '' : 'kInvalid');
  static const RegisterRequest_ActiveStatus kAppInForeground =
      RegisterRequest_ActiveStatus._(1, _omitEnumNames ? '' : 'kAppInForeground');
  static const RegisterRequest_ActiveStatus kAppInBackground =
      RegisterRequest_ActiveStatus._(2, _omitEnumNames ? '' : 'kAppInBackground');

  static const $core.List<RegisterRequest_ActiveStatus> values = <RegisterRequest_ActiveStatus>[
    kInvalid,
    kAppInForeground,
    kAppInBackground,
  ];

  static final $core.List<RegisterRequest_ActiveStatus?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RegisterRequest_ActiveStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RegisterRequest_ActiveStatus._(super.value, super.name);
}

class AccessPoint_AddressType extends $pb.ProtobufEnum {
  static const AccessPoint_AddressType kIPV4 = AccessPoint_AddressType._(0, _omitEnumNames ? '' : 'kIPV4');
  static const AccessPoint_AddressType kIPV6 = AccessPoint_AddressType._(1, _omitEnumNames ? '' : 'kIPV6');
  static const AccessPoint_AddressType kDomain = AccessPoint_AddressType._(2, _omitEnumNames ? '' : 'kDomain');

  static const $core.List<AccessPoint_AddressType> values = <AccessPoint_AddressType>[
    kIPV4,
    kIPV6,
    kDomain,
  ];

  static final $core.List<AccessPoint_AddressType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AccessPoint_AddressType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AccessPoint_AddressType._(super.value, super.name);
}

class DeviceInfo_PlatformType extends $pb.ProtobufEnum {
  static const DeviceInfo_PlatformType kInvalid = DeviceInfo_PlatformType._(0, _omitEnumNames ? '' : 'kInvalid');
  static const DeviceInfo_PlatformType kAndroid = DeviceInfo_PlatformType._(1, _omitEnumNames ? '' : 'kAndroid');
  static const DeviceInfo_PlatformType kiOS = DeviceInfo_PlatformType._(2, _omitEnumNames ? '' : 'kiOS');
  static const DeviceInfo_PlatformType kWindows = DeviceInfo_PlatformType._(3, _omitEnumNames ? '' : 'kWindows');
  static const DeviceInfo_PlatformType WECHAT_ANDROID =
      DeviceInfo_PlatformType._(4, _omitEnumNames ? '' : 'WECHAT_ANDROID');
  static const DeviceInfo_PlatformType WECHAT_IOS = DeviceInfo_PlatformType._(5, _omitEnumNames ? '' : 'WECHAT_IOS');
  static const DeviceInfo_PlatformType H5 = DeviceInfo_PlatformType._(6, _omitEnumNames ? '' : 'H5');
  static const DeviceInfo_PlatformType H5_ANDROID = DeviceInfo_PlatformType._(7, _omitEnumNames ? '' : 'H5_ANDROID');
  static const DeviceInfo_PlatformType H5_IOS = DeviceInfo_PlatformType._(8, _omitEnumNames ? '' : 'H5_IOS');
  static const DeviceInfo_PlatformType H5_WINDOWS = DeviceInfo_PlatformType._(9, _omitEnumNames ? '' : 'H5_WINDOWS');
  static const DeviceInfo_PlatformType H5_MAC = DeviceInfo_PlatformType._(10, _omitEnumNames ? '' : 'H5_MAC');
  static const DeviceInfo_PlatformType kPlatformNum =
      DeviceInfo_PlatformType._(11, _omitEnumNames ? '' : 'kPlatformNum');

  static const $core.List<DeviceInfo_PlatformType> values = <DeviceInfo_PlatformType>[
    kInvalid,
    kAndroid,
    kiOS,
    kWindows,
    WECHAT_ANDROID,
    WECHAT_IOS,
    H5,
    H5_ANDROID,
    H5_IOS,
    H5_WINDOWS,
    H5_MAC,
    kPlatformNum,
  ];

  static final $core.List<DeviceInfo_PlatformType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 11);
  static DeviceInfo_PlatformType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceInfo_PlatformType._(super.value, super.name);
}

class EnvInfo_NetworkType extends $pb.ProtobufEnum {
  static const EnvInfo_NetworkType kInvalid = EnvInfo_NetworkType._(0, _omitEnumNames ? '' : 'kInvalid');
  static const EnvInfo_NetworkType kWIFI = EnvInfo_NetworkType._(1, _omitEnumNames ? '' : 'kWIFI');
  static const EnvInfo_NetworkType kCellular = EnvInfo_NetworkType._(2, _omitEnumNames ? '' : 'kCellular');

  static const $core.List<EnvInfo_NetworkType> values = <EnvInfo_NetworkType>[
    kInvalid,
    kWIFI,
    kCellular,
  ];

  static final $core.List<EnvInfo_NetworkType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 2);
  static EnvInfo_NetworkType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EnvInfo_NetworkType._(super.value, super.name);
}

class PushServiceToken_PushType extends $pb.ProtobufEnum {
  static const PushServiceToken_PushType kPushTypeInvalid =
      PushServiceToken_PushType._(0, _omitEnumNames ? '' : 'kPushTypeInvalid');
  static const PushServiceToken_PushType kPushTypeAPNS =
      PushServiceToken_PushType._(1, _omitEnumNames ? '' : 'kPushTypeAPNS');
  static const PushServiceToken_PushType kPushTypeXmPush =
      PushServiceToken_PushType._(2, _omitEnumNames ? '' : 'kPushTypeXmPush');
  static const PushServiceToken_PushType kPushTypeJgPush =
      PushServiceToken_PushType._(3, _omitEnumNames ? '' : 'kPushTypeJgPush');
  static const PushServiceToken_PushType kPushTypeGtPush =
      PushServiceToken_PushType._(4, _omitEnumNames ? '' : 'kPushTypeGtPush');
  static const PushServiceToken_PushType kPushTypeOpPush =
      PushServiceToken_PushType._(5, _omitEnumNames ? '' : 'kPushTypeOpPush');
  static const PushServiceToken_PushType kPushTypeVvPush =
      PushServiceToken_PushType._(6, _omitEnumNames ? '' : 'kPushTypeVvPush');
  static const PushServiceToken_PushType kPushTypeHwPush =
      PushServiceToken_PushType._(7, _omitEnumNames ? '' : 'kPushTypeHwPush');
  static const PushServiceToken_PushType kPushTypeFcm =
      PushServiceToken_PushType._(8, _omitEnumNames ? '' : 'kPushTypeFcm');

  static const $core.List<PushServiceToken_PushType> values = <PushServiceToken_PushType>[
    kPushTypeInvalid,
    kPushTypeAPNS,
    kPushTypeXmPush,
    kPushTypeJgPush,
    kPushTypeGtPush,
    kPushTypeOpPush,
    kPushTypeVvPush,
    kPushTypeHwPush,
    kPushTypeFcm,
  ];

  static final $core.List<PushServiceToken_PushType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 8);
  static PushServiceToken_PushType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PushServiceToken_PushType._(super.value, super.name);
}

class PingRequest_PingType extends $pb.ProtobufEnum {
  static const PingRequest_PingType kInvalid = PingRequest_PingType._(0, _omitEnumNames ? '' : 'kInvalid');
  static const PingRequest_PingType kPriorRegister = PingRequest_PingType._(1, _omitEnumNames ? '' : 'kPriorRegister');
  static const PingRequest_PingType kPostRegister = PingRequest_PingType._(2, _omitEnumNames ? '' : 'kPostRegister');

  static const $core.List<PingRequest_PingType> values = <PingRequest_PingType>[
    kInvalid,
    kPriorRegister,
    kPostRegister,
  ];

  static final $core.List<PingRequest_PingType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PingRequest_PingType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PingRequest_PingType._(super.value, super.name);
}

class PacketHeader_Flags extends $pb.ProtobufEnum {
  static const PacketHeader_Flags kDirUpstream = PacketHeader_Flags._(0, _omitEnumNames ? '' : 'kDirUpstream');
  static const PacketHeader_Flags kDirDownstream = PacketHeader_Flags._(1, _omitEnumNames ? '' : 'kDirDownstream');

  static const PacketHeader_Flags kDirMask = kDirDownstream;

  static const $core.List<PacketHeader_Flags> values = <PacketHeader_Flags>[
    kDirUpstream,
    kDirDownstream,
  ];

  static final $core.List<PacketHeader_Flags?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PacketHeader_Flags? valueOf($core.int value) => value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PacketHeader_Flags._(super.value, super.name);
}

class PacketHeader_EncodingType extends $pb.ProtobufEnum {
  static const PacketHeader_EncodingType kEncodingNone =
      PacketHeader_EncodingType._(0, _omitEnumNames ? '' : 'kEncodingNone');
  static const PacketHeader_EncodingType kEncodingLz4 =
      PacketHeader_EncodingType._(1, _omitEnumNames ? '' : 'kEncodingLz4');

  static const $core.List<PacketHeader_EncodingType> values = <PacketHeader_EncodingType>[
    kEncodingNone,
    kEncodingLz4,
  ];

  static final $core.List<PacketHeader_EncodingType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PacketHeader_EncodingType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PacketHeader_EncodingType._(super.value, super.name);
}

class PacketHeader_EncryptionMode extends $pb.ProtobufEnum {
  static const PacketHeader_EncryptionMode kEncryptionNone =
      PacketHeader_EncryptionMode._(0, _omitEnumNames ? '' : 'kEncryptionNone');
  static const PacketHeader_EncryptionMode kEncryptionServiceToken =
      PacketHeader_EncryptionMode._(1, _omitEnumNames ? '' : 'kEncryptionServiceToken');
  static const PacketHeader_EncryptionMode kEncryptionSessionKey =
      PacketHeader_EncryptionMode._(2, _omitEnumNames ? '' : 'kEncryptionSessionKey');

  static const $core.List<PacketHeader_EncryptionMode> values = <PacketHeader_EncryptionMode>[
    kEncryptionNone,
    kEncryptionServiceToken,
    kEncryptionSessionKey,
  ];

  static final $core.List<PacketHeader_EncryptionMode?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 2);
  static PacketHeader_EncryptionMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PacketHeader_EncryptionMode._(super.value, super.name);
}

class PacketHeader_Feature extends $pb.ProtobufEnum {
  static const PacketHeader_Feature kReserve = PacketHeader_Feature._(0, _omitEnumNames ? '' : 'kReserve');
  static const PacketHeader_Feature kCompressLz4 = PacketHeader_Feature._(1, _omitEnumNames ? '' : 'kCompressLz4');

  static const $core.List<PacketHeader_Feature> values = <PacketHeader_Feature>[
    kReserve,
    kCompressLz4,
  ];

  static final $core.List<PacketHeader_Feature?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PacketHeader_Feature? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PacketHeader_Feature._(super.value, super.name);
}

class TokenInfo_TokenType extends $pb.ProtobufEnum {
  static const TokenInfo_TokenType kInvalid = TokenInfo_TokenType._(0, _omitEnumNames ? '' : 'kInvalid');
  static const TokenInfo_TokenType kServiceToken = TokenInfo_TokenType._(1, _omitEnumNames ? '' : 'kServiceToken');

  static const $core.List<TokenInfo_TokenType> values = <TokenInfo_TokenType>[
    kInvalid,
    kServiceToken,
  ];

  static final $core.List<TokenInfo_TokenType?> _byValue = $pb.ProtobufEnum.$_initByValueList(values, 1);
  static TokenInfo_TokenType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TokenInfo_TokenType._(super.value, super.name);
}

const $core.bool _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
