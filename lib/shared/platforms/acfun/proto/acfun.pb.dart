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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'acfun.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'acfun.pbenum.dart';

class RegisterRequest extends $pb.GeneratedMessage {
  factory RegisterRequest({
    AppInfo? appInfo,
    DeviceInfo? deviceInfo,
    EnvInfo? envInfo,
    RegisterRequest_PresenceStatus? presenceStatus,
    RegisterRequest_ActiveStatus? appActiveStatus,
    $core.List<$core.int>? appCustomStatus,
    PushServiceToken? pushServiceToken,
    $fixnum.Int64? instanceId,
    $core.Iterable<PushServiceToken>? pushServiceTokenList,
    $core.int? keepaliveIntervalSec,
    ZtCommonInfo? ztCommonInfo,
  }) {
    final result = RegisterRequest._();
    if (appInfo != null) result.appInfo = appInfo;
    if (deviceInfo != null) result.deviceInfo = deviceInfo;
    if (envInfo != null) result.envInfo = envInfo;
    if (presenceStatus != null) result.presenceStatus = presenceStatus;
    if (appActiveStatus != null) result.appActiveStatus = appActiveStatus;
    if (appCustomStatus != null) result.appCustomStatus = appCustomStatus;
    if (pushServiceToken != null) result.pushServiceToken = pushServiceToken;
    if (instanceId != null) result.instanceId = instanceId;
    if (pushServiceTokenList != null) result.pushServiceTokenList.addAll(pushServiceTokenList);
    if (keepaliveIntervalSec != null) result.keepaliveIntervalSec = keepaliveIntervalSec;
    if (ztCommonInfo != null) result.ztCommonInfo = ztCommonInfo;
    return result;
  }

  RegisterRequest._();

  factory RegisterRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterRequest()..mergeFromBuffer(data, registry);
  factory RegisterRequest.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: RegisterRequest.$_createMessage)
    ..aOM<AppInfo>(1, _omitFieldNames ? '' : 'appInfo', protoName: 'appInfo', subBuilder: AppInfo.$_createMessage)
    ..aOM<DeviceInfo>(2, _omitFieldNames ? '' : 'deviceInfo',
        protoName: 'deviceInfo', subBuilder: DeviceInfo.$_createMessage)
    ..aOM<EnvInfo>(3, _omitFieldNames ? '' : 'envInfo', protoName: 'envInfo', subBuilder: EnvInfo.$_createMessage)
    ..aE<RegisterRequest_PresenceStatus>(4, _omitFieldNames ? '' : 'presenceStatus',
        protoName: 'presenceStatus', enumValues: RegisterRequest_PresenceStatus.values)
    ..aE<RegisterRequest_ActiveStatus>(5, _omitFieldNames ? '' : 'appActiveStatus',
        protoName: 'appActiveStatus', enumValues: RegisterRequest_ActiveStatus.values)
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'appCustomStatus', $pb.PbFieldType.OY,
        protoName: 'appCustomStatus')
    ..aOM<PushServiceToken>(7, _omitFieldNames ? '' : 'pushServiceToken',
        protoName: 'pushServiceToken', subBuilder: PushServiceToken.$_createMessage)
    ..aInt64(8, _omitFieldNames ? '' : 'instanceId', protoName: 'instanceId')
    ..pPM<PushServiceToken>(9, _omitFieldNames ? '' : 'pushServiceTokenList',
        protoName: 'pushServiceTokenList', subBuilder: PushServiceToken.$_createMessage)
    ..aI(10, _omitFieldNames ? '' : 'keepaliveIntervalSec', protoName: 'keepaliveIntervalSec')
    ..aOM<ZtCommonInfo>(11, _omitFieldNames ? '' : 'ztCommonInfo',
        protoName: 'ztCommonInfo', subBuilder: ZtCommonInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest copyWith(void Function(RegisterRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterRequest)) as RegisterRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RegisterRequest() / RegisterRequest.new instead')
  static RegisterRequest create() => RegisterRequest._();
  static $pb.GeneratedMessage $_createMessage() => RegisterRequest._();
  @$core.override
  RegisterRequest createEmptyInstance() => RegisterRequest._();
  @$core.pragma('dart2js:noInline')
  static RegisterRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterRequest>(RegisterRequest.$_createMessage);
  static RegisterRequest? _defaultInstance;

  @$pb.TagNumber(1)
  AppInfo get appInfo => $_getN(0);
  @$pb.TagNumber(1)
  set appInfo(AppInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAppInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  AppInfo ensureAppInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  DeviceInfo get deviceInfo => $_getN(1);
  @$pb.TagNumber(2)
  set deviceInfo(DeviceInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceInfo() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceInfo() => $_clearField(2);
  @$pb.TagNumber(2)
  DeviceInfo ensureDeviceInfo() => $_ensure(1);

  @$pb.TagNumber(3)
  EnvInfo get envInfo => $_getN(2);
  @$pb.TagNumber(3)
  set envInfo(EnvInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEnvInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnvInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  EnvInfo ensureEnvInfo() => $_ensure(2);

  @$pb.TagNumber(4)
  RegisterRequest_PresenceStatus get presenceStatus => $_getN(3);
  @$pb.TagNumber(4)
  set presenceStatus(RegisterRequest_PresenceStatus value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPresenceStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearPresenceStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  RegisterRequest_ActiveStatus get appActiveStatus => $_getN(4);
  @$pb.TagNumber(5)
  set appActiveStatus(RegisterRequest_ActiveStatus value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAppActiveStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearAppActiveStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get appCustomStatus => $_getN(5);
  @$pb.TagNumber(6)
  set appCustomStatus($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAppCustomStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppCustomStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  PushServiceToken get pushServiceToken => $_getN(6);
  @$pb.TagNumber(7)
  set pushServiceToken(PushServiceToken value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPushServiceToken() => $_has(6);
  @$pb.TagNumber(7)
  void clearPushServiceToken() => $_clearField(7);
  @$pb.TagNumber(7)
  PushServiceToken ensurePushServiceToken() => $_ensure(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get instanceId => $_getI64(7);
  @$pb.TagNumber(8)
  set instanceId($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInstanceId() => $_has(7);
  @$pb.TagNumber(8)
  void clearInstanceId() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<PushServiceToken> get pushServiceTokenList => $_getList(8);

  @$pb.TagNumber(10)
  $core.int get keepaliveIntervalSec => $_getIZ(9);
  @$pb.TagNumber(10)
  set keepaliveIntervalSec($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasKeepaliveIntervalSec() => $_has(9);
  @$pb.TagNumber(10)
  void clearKeepaliveIntervalSec() => $_clearField(10);

  @$pb.TagNumber(11)
  ZtCommonInfo get ztCommonInfo => $_getN(10);
  @$pb.TagNumber(11)
  set ztCommonInfo(ZtCommonInfo value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasZtCommonInfo() => $_has(10);
  @$pb.TagNumber(11)
  void clearZtCommonInfo() => $_clearField(11);
  @$pb.TagNumber(11)
  ZtCommonInfo ensureZtCommonInfo() => $_ensure(10);
}

class RegisterResponse extends $pb.GeneratedMessage {
  factory RegisterResponse({
    AccessPointsConfig? accessPointsConfig,
    $core.List<$core.int>? sessKey,
    $fixnum.Int64? instanceId,
    SdkOption? sdkOption,
    AccessPointsConfig? accessPointsConfigIpv6,
  }) {
    final result = RegisterResponse._();
    if (accessPointsConfig != null) result.accessPointsConfig = accessPointsConfig;
    if (sessKey != null) result.sessKey = sessKey;
    if (instanceId != null) result.instanceId = instanceId;
    if (sdkOption != null) result.sdkOption = sdkOption;
    if (accessPointsConfigIpv6 != null) result.accessPointsConfigIpv6 = accessPointsConfigIpv6;
    return result;
  }

  RegisterResponse._();

  factory RegisterResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterResponse()..mergeFromBuffer(data, registry);
  factory RegisterResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: RegisterResponse.$_createMessage)
    ..aOM<AccessPointsConfig>(1, _omitFieldNames ? '' : 'accessPointsConfig',
        protoName: 'accessPointsConfig', subBuilder: AccessPointsConfig.$_createMessage)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'sessKey', $pb.PbFieldType.OY, protoName: 'sessKey')
    ..aInt64(3, _omitFieldNames ? '' : 'instanceId', protoName: 'instanceId')
    ..aOM<SdkOption>(4, _omitFieldNames ? '' : 'sdkOption',
        protoName: 'sdkOption', subBuilder: SdkOption.$_createMessage)
    ..aOM<AccessPointsConfig>(5, _omitFieldNames ? '' : 'accessPointsConfigIpv6',
        protoName: 'accessPointsConfigIpv6', subBuilder: AccessPointsConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterResponse copyWith(void Function(RegisterResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterResponse)) as RegisterResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RegisterResponse() / RegisterResponse.new instead')
  static RegisterResponse create() => RegisterResponse._();
  static $pb.GeneratedMessage $_createMessage() => RegisterResponse._();
  @$core.override
  RegisterResponse createEmptyInstance() => RegisterResponse._();
  @$core.pragma('dart2js:noInline')
  static RegisterResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterResponse>(RegisterResponse.$_createMessage);
  static RegisterResponse? _defaultInstance;

  @$pb.TagNumber(1)
  AccessPointsConfig get accessPointsConfig => $_getN(0);
  @$pb.TagNumber(1)
  set accessPointsConfig(AccessPointsConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessPointsConfig() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessPointsConfig() => $_clearField(1);
  @$pb.TagNumber(1)
  AccessPointsConfig ensureAccessPointsConfig() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$core.int> get sessKey => $_getN(1);
  @$pb.TagNumber(2)
  set sessKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get instanceId => $_getI64(2);
  @$pb.TagNumber(3)
  set instanceId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInstanceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInstanceId() => $_clearField(3);

  @$pb.TagNumber(4)
  SdkOption get sdkOption => $_getN(3);
  @$pb.TagNumber(4)
  set sdkOption(SdkOption value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSdkOption() => $_has(3);
  @$pb.TagNumber(4)
  void clearSdkOption() => $_clearField(4);
  @$pb.TagNumber(4)
  SdkOption ensureSdkOption() => $_ensure(3);

  @$pb.TagNumber(5)
  AccessPointsConfig get accessPointsConfigIpv6 => $_getN(4);
  @$pb.TagNumber(5)
  set accessPointsConfigIpv6(AccessPointsConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAccessPointsConfigIpv6() => $_has(4);
  @$pb.TagNumber(5)
  void clearAccessPointsConfigIpv6() => $_clearField(5);
  @$pb.TagNumber(5)
  AccessPointsConfig ensureAccessPointsConfigIpv6() => $_ensure(4);
}

class AccessPointsConfig extends $pb.GeneratedMessage {
  factory AccessPointsConfig({
    $core.Iterable<AccessPoint>? optimalAps,
    $core.Iterable<AccessPoint>? backupAps,
    $core.Iterable<$core.int>? availablePorts,
    AccessPoint? forceLastConnectedAp,
  }) {
    final result = AccessPointsConfig._();
    if (optimalAps != null) result.optimalAps.addAll(optimalAps);
    if (backupAps != null) result.backupAps.addAll(backupAps);
    if (availablePorts != null) result.availablePorts.addAll(availablePorts);
    if (forceLastConnectedAp != null) result.forceLastConnectedAp = forceLastConnectedAp;
    return result;
  }

  AccessPointsConfig._();

  factory AccessPointsConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessPointsConfig()..mergeFromBuffer(data, registry);
  factory AccessPointsConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessPointsConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AccessPointsConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AccessPointsConfig.$_createMessage)
    ..pPM<AccessPoint>(1, _omitFieldNames ? '' : 'optimalAps',
        protoName: 'optimalAps', subBuilder: AccessPoint.$_createMessage)
    ..pPM<AccessPoint>(2, _omitFieldNames ? '' : 'backupAps',
        protoName: 'backupAps', subBuilder: AccessPoint.$_createMessage)
    ..p<$core.int>(3, _omitFieldNames ? '' : 'availablePorts', $pb.PbFieldType.PU3, protoName: 'availablePorts')
    ..aOM<AccessPoint>(4, _omitFieldNames ? '' : 'forceLastConnectedAp',
        protoName: 'forceLastConnectedAp', subBuilder: AccessPoint.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessPointsConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessPointsConfig copyWith(void Function(AccessPointsConfig) updates) =>
      super.copyWith((message) => updates(message as AccessPointsConfig)) as AccessPointsConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccessPointsConfig() / AccessPointsConfig.new instead')
  static AccessPointsConfig create() => AccessPointsConfig._();
  static $pb.GeneratedMessage $_createMessage() => AccessPointsConfig._();
  @$core.override
  AccessPointsConfig createEmptyInstance() => AccessPointsConfig._();
  @$core.pragma('dart2js:noInline')
  static AccessPointsConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccessPointsConfig>(AccessPointsConfig.$_createMessage);
  static AccessPointsConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AccessPoint> get optimalAps => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<AccessPoint> get backupAps => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get availablePorts => $_getList(2);

  @$pb.TagNumber(4)
  AccessPoint get forceLastConnectedAp => $_getN(3);
  @$pb.TagNumber(4)
  set forceLastConnectedAp(AccessPoint value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasForceLastConnectedAp() => $_has(3);
  @$pb.TagNumber(4)
  void clearForceLastConnectedAp() => $_clearField(4);
  @$pb.TagNumber(4)
  AccessPoint ensureForceLastConnectedAp() => $_ensure(3);
}

class AccessPoint extends $pb.GeneratedMessage {
  factory AccessPoint({
    AccessPoint_AddressType? addressType,
    $core.int? port,
    $core.int? ipV4,
    $core.List<$core.int>? ipV6,
    $core.String? domain,
  }) {
    final result = AccessPoint._();
    if (addressType != null) result.addressType = addressType;
    if (port != null) result.port = port;
    if (ipV4 != null) result.ipV4 = ipV4;
    if (ipV6 != null) result.ipV6 = ipV6;
    if (domain != null) result.domain = domain;
    return result;
  }

  AccessPoint._();

  factory AccessPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessPoint()..mergeFromBuffer(data, registry);
  factory AccessPoint.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessPoint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AccessPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AccessPoint.$_createMessage)
    ..aE<AccessPoint_AddressType>(1, _omitFieldNames ? '' : 'addressType',
        protoName: 'addressType', enumValues: AccessPoint_AddressType.values)
    ..aI(2, _omitFieldNames ? '' : 'port', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'ipV4', protoName: 'ipV4', fieldType: $pb.PbFieldType.OF3)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'ipV6', $pb.PbFieldType.OY, protoName: 'ipV6')
    ..aOS(5, _omitFieldNames ? '' : 'domain')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessPoint copyWith(void Function(AccessPoint) updates) =>
      super.copyWith((message) => updates(message as AccessPoint)) as AccessPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccessPoint() / AccessPoint.new instead')
  static AccessPoint create() => AccessPoint._();
  static $pb.GeneratedMessage $_createMessage() => AccessPoint._();
  @$core.override
  AccessPoint createEmptyInstance() => AccessPoint._();
  @$core.pragma('dart2js:noInline')
  static AccessPoint getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccessPoint>(AccessPoint.$_createMessage);
  static AccessPoint? _defaultInstance;

  @$pb.TagNumber(1)
  AccessPoint_AddressType get addressType => $_getN(0);
  @$pb.TagNumber(1)
  set addressType(AccessPoint_AddressType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAddressType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddressType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get ipV4 => $_getIZ(2);
  @$pb.TagNumber(3)
  set ipV4($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIpV4() => $_has(2);
  @$pb.TagNumber(3)
  void clearIpV4() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get ipV6 => $_getN(3);
  @$pb.TagNumber(4)
  set ipV6($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIpV6() => $_has(3);
  @$pb.TagNumber(4)
  void clearIpV6() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get domain => $_getSZ(4);
  @$pb.TagNumber(5)
  set domain($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDomain() => $_has(4);
  @$pb.TagNumber(5)
  void clearDomain() => $_clearField(5);
}

class SdkOption extends $pb.GeneratedMessage {
  factory SdkOption({
    $core.int? reportIntervalSeconds,
    $core.String? reportSecurity,
    $core.int? lz4CompressionThresholdBytes,
    $core.Iterable<$core.String>? netCheckServers,
  }) {
    final result = SdkOption._();
    if (reportIntervalSeconds != null) result.reportIntervalSeconds = reportIntervalSeconds;
    if (reportSecurity != null) result.reportSecurity = reportSecurity;
    if (lz4CompressionThresholdBytes != null) result.lz4CompressionThresholdBytes = lz4CompressionThresholdBytes;
    if (netCheckServers != null) result.netCheckServers.addAll(netCheckServers);
    return result;
  }

  SdkOption._();

  factory SdkOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SdkOption()..mergeFromBuffer(data, registry);
  factory SdkOption.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SdkOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SdkOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: SdkOption.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'reportIntervalSeconds', protoName: 'reportIntervalSeconds')
    ..aOS(2, _omitFieldNames ? '' : 'reportSecurity', protoName: 'reportSecurity')
    ..aI(3, _omitFieldNames ? '' : 'lz4CompressionThresholdBytes', protoName: 'lz4CompressionThresholdBytes')
    ..pPS(4, _omitFieldNames ? '' : 'netCheckServers', protoName: 'netCheckServers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SdkOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SdkOption copyWith(void Function(SdkOption) updates) =>
      super.copyWith((message) => updates(message as SdkOption)) as SdkOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SdkOption() / SdkOption.new instead')
  static SdkOption create() => SdkOption._();
  static $pb.GeneratedMessage $_createMessage() => SdkOption._();
  @$core.override
  SdkOption createEmptyInstance() => SdkOption._();
  @$core.pragma('dart2js:noInline')
  static SdkOption getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SdkOption>(SdkOption.$_createMessage);
  static SdkOption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get reportIntervalSeconds => $_getIZ(0);
  @$pb.TagNumber(1)
  set reportIntervalSeconds($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReportIntervalSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearReportIntervalSeconds() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reportSecurity => $_getSZ(1);
  @$pb.TagNumber(2)
  set reportSecurity($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReportSecurity() => $_has(1);
  @$pb.TagNumber(2)
  void clearReportSecurity() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get lz4CompressionThresholdBytes => $_getIZ(2);
  @$pb.TagNumber(3)
  set lz4CompressionThresholdBytes($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLz4CompressionThresholdBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearLz4CompressionThresholdBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get netCheckServers => $_getList(3);
}

class ZtLiveCsEnterRoom extends $pb.GeneratedMessage {
  factory ZtLiveCsEnterRoom({
    $core.bool? isAuthor,
    $core.int? reconnectCount,
    $core.int? lastErrorCode,
    $core.String? enterRoomAttach,
    $core.String? clientLiveSdkVersion,
  }) {
    final result = ZtLiveCsEnterRoom._();
    if (isAuthor != null) result.isAuthor = isAuthor;
    if (reconnectCount != null) result.reconnectCount = reconnectCount;
    if (lastErrorCode != null) result.lastErrorCode = lastErrorCode;
    if (enterRoomAttach != null) result.enterRoomAttach = enterRoomAttach;
    if (clientLiveSdkVersion != null) result.clientLiveSdkVersion = clientLiveSdkVersion;
    return result;
  }

  ZtLiveCsEnterRoom._();

  factory ZtLiveCsEnterRoom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveCsEnterRoom()..mergeFromBuffer(data, registry);
  factory ZtLiveCsEnterRoom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveCsEnterRoom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveCsEnterRoom',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveCsEnterRoom.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'isAuthor', protoName: 'isAuthor')
    ..aI(2, _omitFieldNames ? '' : 'reconnectCount', protoName: 'reconnectCount', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'lastErrorCode', protoName: 'lastErrorCode', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'enterRoomAttach', protoName: 'enterRoomAttach')
    ..aOS(5, _omitFieldNames ? '' : 'clientLiveSdkVersion', protoName: 'clientLiveSdkVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveCsEnterRoom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveCsEnterRoom copyWith(void Function(ZtLiveCsEnterRoom) updates) =>
      super.copyWith((message) => updates(message as ZtLiveCsEnterRoom)) as ZtLiveCsEnterRoom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveCsEnterRoom() / ZtLiveCsEnterRoom.new instead')
  static ZtLiveCsEnterRoom create() => ZtLiveCsEnterRoom._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveCsEnterRoom._();
  @$core.override
  ZtLiveCsEnterRoom createEmptyInstance() => ZtLiveCsEnterRoom._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveCsEnterRoom getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveCsEnterRoom>(ZtLiveCsEnterRoom.$_createMessage);
  static ZtLiveCsEnterRoom? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isAuthor => $_getBF(0);
  @$pb.TagNumber(1)
  set isAuthor($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsAuthor() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsAuthor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get reconnectCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set reconnectCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReconnectCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearReconnectCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get lastErrorCode => $_getIZ(2);
  @$pb.TagNumber(3)
  set lastErrorCode($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastErrorCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastErrorCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get enterRoomAttach => $_getSZ(3);
  @$pb.TagNumber(4)
  set enterRoomAttach($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnterRoomAttach() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnterRoomAttach() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get clientLiveSdkVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set clientLiveSdkVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientLiveSdkVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientLiveSdkVersion() => $_clearField(5);
}

class ZtLiveCsHeartbeat extends $pb.GeneratedMessage {
  factory ZtLiveCsHeartbeat({
    $fixnum.Int64? clientTimestampMs,
    $core.bool? sequence,
  }) {
    final result = ZtLiveCsHeartbeat._();
    if (clientTimestampMs != null) result.clientTimestampMs = clientTimestampMs;
    if (sequence != null) result.sequence = sequence;
    return result;
  }

  ZtLiveCsHeartbeat._();

  factory ZtLiveCsHeartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveCsHeartbeat()..mergeFromBuffer(data, registry);
  factory ZtLiveCsHeartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveCsHeartbeat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveCsHeartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveCsHeartbeat.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clientTimestampMs', $pb.PbFieldType.OU6,
        protoName: 'clientTimestampMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(2, _omitFieldNames ? '' : 'sequence')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveCsHeartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveCsHeartbeat copyWith(void Function(ZtLiveCsHeartbeat) updates) =>
      super.copyWith((message) => updates(message as ZtLiveCsHeartbeat)) as ZtLiveCsHeartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveCsHeartbeat() / ZtLiveCsHeartbeat.new instead')
  static ZtLiveCsHeartbeat create() => ZtLiveCsHeartbeat._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveCsHeartbeat._();
  @$core.override
  ZtLiveCsHeartbeat createEmptyInstance() => ZtLiveCsHeartbeat._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveCsHeartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveCsHeartbeat>(ZtLiveCsHeartbeat.$_createMessage);
  static ZtLiveCsHeartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clientTimestampMs => $_getI64(0);
  @$pb.TagNumber(1)
  set clientTimestampMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientTimestampMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientTimestampMs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get sequence => $_getBF(1);
  @$pb.TagNumber(2)
  set sequence($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearSequence() => $_clearField(2);
}

class CsCmd extends $pb.GeneratedMessage {
  factory CsCmd({
    $core.String? cmdType,
    $core.List<$core.int>? payload,
    $core.String? ticket,
    $core.String? liveId,
  }) {
    final result = CsCmd._();
    if (cmdType != null) result.cmdType = cmdType;
    if (payload != null) result.payload = payload;
    if (ticket != null) result.ticket = ticket;
    if (liveId != null) result.liveId = liveId;
    return result;
  }

  CsCmd._();

  factory CsCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CsCmd()..mergeFromBuffer(data, registry);
  factory CsCmd.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CsCmd()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CsCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'), createEmptyInstance: CsCmd.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'cmdType', protoName: 'cmdType')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'ticket')
    ..aOS(4, _omitFieldNames ? '' : 'liveId', protoName: 'liveId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CsCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CsCmd copyWith(void Function(CsCmd) updates) => super.copyWith((message) => updates(message as CsCmd)) as CsCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CsCmd() / CsCmd.new instead')
  static CsCmd create() => CsCmd._();
  static $pb.GeneratedMessage $_createMessage() => CsCmd._();
  @$core.override
  CsCmd createEmptyInstance() => CsCmd._();
  @$core.pragma('dart2js:noInline')
  static CsCmd getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CsCmd>(CsCmd.$_createMessage);
  static CsCmd? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cmdType => $_getSZ(0);
  @$pb.TagNumber(1)
  set cmdType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdType() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get ticket => $_getSZ(2);
  @$pb.TagNumber(3)
  set ticket($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTicket() => $_has(2);
  @$pb.TagNumber(3)
  void clearTicket() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get liveId => $_getSZ(3);
  @$pb.TagNumber(4)
  set liveId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLiveId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLiveId() => $_clearField(4);
}

class AppInfo extends $pb.GeneratedMessage {
  factory AppInfo({
    $core.String? appName,
    $core.String? appVersion,
    $core.String? appChannel,
    $core.String? sdkVersion,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? extensionInfo,
  }) {
    final result = AppInfo._();
    if (appName != null) result.appName = appName;
    if (appVersion != null) result.appVersion = appVersion;
    if (appChannel != null) result.appChannel = appChannel;
    if (sdkVersion != null) result.sdkVersion = sdkVersion;
    if (extensionInfo != null) result.extensionInfo.addEntries(extensionInfo);
    return result;
  }

  AppInfo._();

  factory AppInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppInfo()..mergeFromBuffer(data, registry);
  factory AppInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AppInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AppInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'appName', protoName: 'appName')
    ..aOS(2, _omitFieldNames ? '' : 'appVersion', protoName: 'appVersion')
    ..aOS(3, _omitFieldNames ? '' : 'appChannel', protoName: 'appChannel')
    ..aOS(4, _omitFieldNames ? '' : 'sdkVersion', protoName: 'sdkVersion')
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'extensionInfo',
        protoName: 'extensionInfo',
        entryClassName: 'AppInfo.ExtensionInfoEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('AcFunPack'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo copyWith(void Function(AppInfo) updates) =>
      super.copyWith((message) => updates(message as AppInfo)) as AppInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AppInfo() / AppInfo.new instead')
  static AppInfo create() => AppInfo._();
  static $pb.GeneratedMessage $_createMessage() => AppInfo._();
  @$core.override
  AppInfo createEmptyInstance() => AppInfo._();
  @$core.pragma('dart2js:noInline')
  static AppInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AppInfo>(AppInfo.$_createMessage);
  static AppInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get appName => $_getSZ(0);
  @$pb.TagNumber(1)
  set appName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppName() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get appVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set appVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAppVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appChannel => $_getSZ(2);
  @$pb.TagNumber(3)
  set appChannel($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppChannel() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppChannel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sdkVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set sdkVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSdkVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearSdkVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.String> get extensionInfo => $_getMap(4);
}

class DeviceInfo extends $pb.GeneratedMessage {
  factory DeviceInfo({
    DeviceInfo_PlatformType? platformType,
    $core.String? osVersion,
    $core.String? deviceModel,
    $core.List<$core.int>? imeiMd5,
    $core.String? deviceId,
    $core.String? softDid,
    $core.String? kwaiDid,
    $core.String? manufacturer,
    $core.String? deviceName,
  }) {
    final result = DeviceInfo._();
    if (platformType != null) result.platformType = platformType;
    if (osVersion != null) result.osVersion = osVersion;
    if (deviceModel != null) result.deviceModel = deviceModel;
    if (imeiMd5 != null) result.imeiMd5 = imeiMd5;
    if (deviceId != null) result.deviceId = deviceId;
    if (softDid != null) result.softDid = softDid;
    if (kwaiDid != null) result.kwaiDid = kwaiDid;
    if (manufacturer != null) result.manufacturer = manufacturer;
    if (deviceName != null) result.deviceName = deviceName;
    return result;
  }

  DeviceInfo._();

  factory DeviceInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceInfo()..mergeFromBuffer(data, registry);
  factory DeviceInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeviceInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: DeviceInfo.$_createMessage)
    ..aE<DeviceInfo_PlatformType>(1, _omitFieldNames ? '' : 'platformType',
        protoName: 'platformType', enumValues: DeviceInfo_PlatformType.values)
    ..aOS(2, _omitFieldNames ? '' : 'osVersion', protoName: 'osVersion')
    ..aOS(3, _omitFieldNames ? '' : 'deviceModel', protoName: 'deviceModel')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'imeiMd5', $pb.PbFieldType.OY, protoName: 'imeiMd5')
    ..aOS(5, _omitFieldNames ? '' : 'deviceId', protoName: 'deviceId')
    ..aOS(6, _omitFieldNames ? '' : 'softDid', protoName: 'softDid')
    ..aOS(7, _omitFieldNames ? '' : 'kwaiDid', protoName: 'kwaiDid')
    ..aOS(8, _omitFieldNames ? '' : 'manufacturer')
    ..aOS(9, _omitFieldNames ? '' : 'deviceName', protoName: 'deviceName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceInfo copyWith(void Function(DeviceInfo) updates) =>
      super.copyWith((message) => updates(message as DeviceInfo)) as DeviceInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeviceInfo() / DeviceInfo.new instead')
  static DeviceInfo create() => DeviceInfo._();
  static $pb.GeneratedMessage $_createMessage() => DeviceInfo._();
  @$core.override
  DeviceInfo createEmptyInstance() => DeviceInfo._();
  @$core.pragma('dart2js:noInline')
  static DeviceInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceInfo>(DeviceInfo.$_createMessage);
  static DeviceInfo? _defaultInstance;

  @$pb.TagNumber(1)
  DeviceInfo_PlatformType get platformType => $_getN(0);
  @$pb.TagNumber(1)
  set platformType(DeviceInfo_PlatformType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatformType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatformType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get osVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set osVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOsVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearOsVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get deviceModel => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceModel($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceModel() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceModel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get imeiMd5 => $_getN(3);
  @$pb.TagNumber(4)
  set imeiMd5($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasImeiMd5() => $_has(3);
  @$pb.TagNumber(4)
  void clearImeiMd5() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get deviceId => $_getSZ(4);
  @$pb.TagNumber(5)
  set deviceId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeviceId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeviceId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get softDid => $_getSZ(5);
  @$pb.TagNumber(6)
  set softDid($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSoftDid() => $_has(5);
  @$pb.TagNumber(6)
  void clearSoftDid() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get kwaiDid => $_getSZ(6);
  @$pb.TagNumber(7)
  set kwaiDid($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasKwaiDid() => $_has(6);
  @$pb.TagNumber(7)
  void clearKwaiDid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get manufacturer => $_getSZ(7);
  @$pb.TagNumber(8)
  set manufacturer($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasManufacturer() => $_has(7);
  @$pb.TagNumber(8)
  void clearManufacturer() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get deviceName => $_getSZ(8);
  @$pb.TagNumber(9)
  set deviceName($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDeviceName() => $_has(8);
  @$pb.TagNumber(9)
  void clearDeviceName() => $_clearField(9);
}

class EnvInfo extends $pb.GeneratedMessage {
  factory EnvInfo({
    EnvInfo_NetworkType? networkType,
    $core.List<$core.int>? apnName,
  }) {
    final result = EnvInfo._();
    if (networkType != null) result.networkType = networkType;
    if (apnName != null) result.apnName = apnName;
    return result;
  }

  EnvInfo._();

  factory EnvInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvInfo()..mergeFromBuffer(data, registry);
  factory EnvInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EnvInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EnvInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: EnvInfo.$_createMessage)
    ..aE<EnvInfo_NetworkType>(1, _omitFieldNames ? '' : 'networkType',
        protoName: 'networkType', enumValues: EnvInfo_NetworkType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'apnName', $pb.PbFieldType.OY, protoName: 'apnName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EnvInfo copyWith(void Function(EnvInfo) updates) =>
      super.copyWith((message) => updates(message as EnvInfo)) as EnvInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EnvInfo() / EnvInfo.new instead')
  static EnvInfo create() => EnvInfo._();
  static $pb.GeneratedMessage $_createMessage() => EnvInfo._();
  @$core.override
  EnvInfo createEmptyInstance() => EnvInfo._();
  @$core.pragma('dart2js:noInline')
  static EnvInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EnvInfo>(EnvInfo.$_createMessage);
  static EnvInfo? _defaultInstance;

  @$pb.TagNumber(1)
  EnvInfo_NetworkType get networkType => $_getN(0);
  @$pb.TagNumber(1)
  set networkType(EnvInfo_NetworkType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNetworkType() => $_has(0);
  @$pb.TagNumber(1)
  void clearNetworkType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get apnName => $_getN(1);
  @$pb.TagNumber(2)
  set apnName($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasApnName() => $_has(1);
  @$pb.TagNumber(2)
  void clearApnName() => $_clearField(2);
}

class PushServiceToken extends $pb.GeneratedMessage {
  factory PushServiceToken({
    PushServiceToken_PushType? pushType,
    $core.List<$core.int>? token,
    $core.bool? isPassThrough,
  }) {
    final result = PushServiceToken._();
    if (pushType != null) result.pushType = pushType;
    if (token != null) result.token = token;
    if (isPassThrough != null) result.isPassThrough = isPassThrough;
    return result;
  }

  PushServiceToken._();

  factory PushServiceToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushServiceToken()..mergeFromBuffer(data, registry);
  factory PushServiceToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PushServiceToken()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PushServiceToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: PushServiceToken.$_createMessage)
    ..aE<PushServiceToken_PushType>(1, _omitFieldNames ? '' : 'pushType',
        protoName: 'pushType', enumValues: PushServiceToken_PushType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'token', $pb.PbFieldType.OY)
    ..aOB(3, _omitFieldNames ? '' : 'isPassThrough', protoName: 'isPassThrough')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushServiceToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushServiceToken copyWith(void Function(PushServiceToken) updates) =>
      super.copyWith((message) => updates(message as PushServiceToken)) as PushServiceToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PushServiceToken() / PushServiceToken.new instead')
  static PushServiceToken create() => PushServiceToken._();
  static $pb.GeneratedMessage $_createMessage() => PushServiceToken._();
  @$core.override
  PushServiceToken createEmptyInstance() => PushServiceToken._();
  @$core.pragma('dart2js:noInline')
  static PushServiceToken getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushServiceToken>(PushServiceToken.$_createMessage);
  static PushServiceToken? _defaultInstance;

  @$pb.TagNumber(1)
  PushServiceToken_PushType get pushType => $_getN(0);
  @$pb.TagNumber(1)
  set pushType(PushServiceToken_PushType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPushType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPushType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get token => $_getN(1);
  @$pb.TagNumber(2)
  set token($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPassThrough => $_getBF(2);
  @$pb.TagNumber(3)
  set isPassThrough($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsPassThrough() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsPassThrough() => $_clearField(3);
}

class ZtCommonInfo extends $pb.GeneratedMessage {
  factory ZtCommonInfo({
    $core.String? kpn,
    $core.String? kpf,
    $fixnum.Int64? uid,
    $core.String? did,
  }) {
    final result = ZtCommonInfo._();
    if (kpn != null) result.kpn = kpn;
    if (kpf != null) result.kpf = kpf;
    if (uid != null) result.uid = uid;
    if (did != null) result.did = did;
    return result;
  }

  ZtCommonInfo._();

  factory ZtCommonInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtCommonInfo()..mergeFromBuffer(data, registry);
  factory ZtCommonInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtCommonInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtCommonInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtCommonInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'kpn')
    ..aOS(2, _omitFieldNames ? '' : 'kpf')
    ..aInt64(4, _omitFieldNames ? '' : 'uid')
    ..aOS(5, _omitFieldNames ? '' : 'did')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtCommonInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtCommonInfo copyWith(void Function(ZtCommonInfo) updates) =>
      super.copyWith((message) => updates(message as ZtCommonInfo)) as ZtCommonInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtCommonInfo() / ZtCommonInfo.new instead')
  static ZtCommonInfo create() => ZtCommonInfo._();
  static $pb.GeneratedMessage $_createMessage() => ZtCommonInfo._();
  @$core.override
  ZtCommonInfo createEmptyInstance() => ZtCommonInfo._();
  @$core.pragma('dart2js:noInline')
  static ZtCommonInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtCommonInfo>(ZtCommonInfo.$_createMessage);
  static ZtCommonInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kpn => $_getSZ(0);
  @$pb.TagNumber(1)
  set kpn($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKpn() => $_has(0);
  @$pb.TagNumber(1)
  void clearKpn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get kpf => $_getSZ(1);
  @$pb.TagNumber(2)
  set kpf($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKpf() => $_has(1);
  @$pb.TagNumber(2)
  void clearKpf() => $_clearField(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get uid => $_getI64(2);
  @$pb.TagNumber(4)
  set uid($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(4)
  $core.bool hasUid() => $_has(2);
  @$pb.TagNumber(4)
  void clearUid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get did => $_getSZ(3);
  @$pb.TagNumber(5)
  set did($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasDid() => $_has(3);
  @$pb.TagNumber(5)
  void clearDid() => $_clearField(5);
}

class PingResponse extends $pb.GeneratedMessage {
  factory PingResponse({
    $core.int? serverTimestamp,
    $core.int? clientIp,
    $core.int? redirectIp,
    $core.int? redirectPort,
  }) {
    final result = PingResponse._();
    if (serverTimestamp != null) result.serverTimestamp = serverTimestamp;
    if (clientIp != null) result.clientIp = clientIp;
    if (redirectIp != null) result.redirectIp = redirectIp;
    if (redirectPort != null) result.redirectPort = redirectPort;
    return result;
  }

  PingResponse._();

  factory PingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResponse()..mergeFromBuffer(data, registry);
  factory PingResponse.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: PingResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'serverTimestamp', protoName: 'serverTimestamp', fieldType: $pb.PbFieldType.OSF3)
    ..aI(2, _omitFieldNames ? '' : 'clientIp', protoName: 'clientIp', fieldType: $pb.PbFieldType.OF3)
    ..aI(3, _omitFieldNames ? '' : 'redirectIp', protoName: 'redirectIp', fieldType: $pb.PbFieldType.OF3)
    ..aI(4, _omitFieldNames ? '' : 'redirectPort', protoName: 'redirectPort', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse copyWith(void Function(PingResponse) updates) =>
      super.copyWith((message) => updates(message as PingResponse)) as PingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingResponse() / PingResponse.new instead')
  static PingResponse create() => PingResponse._();
  static $pb.GeneratedMessage $_createMessage() => PingResponse._();
  @$core.override
  PingResponse createEmptyInstance() => PingResponse._();
  @$core.pragma('dart2js:noInline')
  static PingResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingResponse>(PingResponse.$_createMessage);
  static PingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get serverTimestamp => $_getIZ(0);
  @$pb.TagNumber(1)
  set serverTimestamp($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTimestamp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get clientIp => $_getIZ(1);
  @$pb.TagNumber(2)
  set clientIp($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientIp() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientIp() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get redirectIp => $_getIZ(2);
  @$pb.TagNumber(3)
  set redirectIp($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRedirectIp() => $_has(2);
  @$pb.TagNumber(3)
  void clearRedirectIp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get redirectPort => $_getIZ(3);
  @$pb.TagNumber(4)
  set redirectPort($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRedirectPort() => $_has(3);
  @$pb.TagNumber(4)
  void clearRedirectPort() => $_clearField(4);
}

class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest({
    PingRequest_PingType? pingType,
    $core.int? pingRound,
  }) {
    final result = PingRequest._();
    if (pingType != null) result.pingType = pingType;
    if (pingRound != null) result.pingRound = pingRound;
    return result;
  }

  PingRequest._();

  factory PingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingRequest()..mergeFromBuffer(data, registry);
  factory PingRequest.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: PingRequest.$_createMessage)
    ..aE<PingRequest_PingType>(1, _omitFieldNames ? '' : 'pingType',
        protoName: 'pingType', enumValues: PingRequest_PingType.values)
    ..aI(2, _omitFieldNames ? '' : 'pingRound', protoName: 'pingRound', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest copyWith(void Function(PingRequest) updates) =>
      super.copyWith((message) => updates(message as PingRequest)) as PingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingRequest() / PingRequest.new instead')
  static PingRequest create() => PingRequest._();
  static $pb.GeneratedMessage $_createMessage() => PingRequest._();
  @$core.override
  PingRequest createEmptyInstance() => PingRequest._();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingRequest>(PingRequest.$_createMessage);
  static PingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  PingRequest_PingType get pingType => $_getN(0);
  @$pb.TagNumber(1)
  set pingType(PingRequest_PingType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPingType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPingType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pingRound => $_getIZ(1);
  @$pb.TagNumber(2)
  set pingRound($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPingRound() => $_has(1);
  @$pb.TagNumber(2)
  void clearPingRound() => $_clearField(2);
}

class UpstreamPayload extends $pb.GeneratedMessage {
  factory UpstreamPayload({
    $core.String? command,
    $fixnum.Int64? seqId,
    $core.int? retryCount,
    $core.List<$core.int>? payloadData,
    UserInstance? userInstance,
    $core.int? errorCode,
    SettingInfo? settingInfo,
    RequsetBasicInfo? requestBasicInfo,
    $core.String? subBiz,
    FrontendInfo? frontendInfo,
    $core.String? kpn,
    $core.bool? anonymouseUser,
  }) {
    final result = UpstreamPayload._();
    if (command != null) result.command = command;
    if (seqId != null) result.seqId = seqId;
    if (retryCount != null) result.retryCount = retryCount;
    if (payloadData != null) result.payloadData = payloadData;
    if (userInstance != null) result.userInstance = userInstance;
    if (errorCode != null) result.errorCode = errorCode;
    if (settingInfo != null) result.settingInfo = settingInfo;
    if (requestBasicInfo != null) result.requestBasicInfo = requestBasicInfo;
    if (subBiz != null) result.subBiz = subBiz;
    if (frontendInfo != null) result.frontendInfo = frontendInfo;
    if (kpn != null) result.kpn = kpn;
    if (anonymouseUser != null) result.anonymouseUser = anonymouseUser;
    return result;
  }

  UpstreamPayload._();

  factory UpstreamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpstreamPayload()..mergeFromBuffer(data, registry);
  factory UpstreamPayload.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpstreamPayload()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpstreamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: UpstreamPayload.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'command')
    ..aInt64(2, _omitFieldNames ? '' : 'seqId', protoName: 'seqId')
    ..aI(3, _omitFieldNames ? '' : 'retryCount', protoName: 'retryCount', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'payloadData', $pb.PbFieldType.OY, protoName: 'payloadData')
    ..aOM<UserInstance>(5, _omitFieldNames ? '' : 'userInstance',
        protoName: 'userInstance', subBuilder: UserInstance.$_createMessage)
    ..aI(6, _omitFieldNames ? '' : 'errorCode', protoName: 'errorCode')
    ..aOM<SettingInfo>(7, _omitFieldNames ? '' : 'settingInfo',
        protoName: 'settingInfo', subBuilder: SettingInfo.$_createMessage)
    ..aOM<RequsetBasicInfo>(8, _omitFieldNames ? '' : 'requestBasicInfo',
        protoName: 'requestBasicInfo', subBuilder: RequsetBasicInfo.$_createMessage)
    ..aOS(9, _omitFieldNames ? '' : 'subBiz', protoName: 'subBiz')
    ..aOM<FrontendInfo>(10, _omitFieldNames ? '' : 'frontendInfo',
        protoName: 'frontendInfo', subBuilder: FrontendInfo.$_createMessage)
    ..aOS(11, _omitFieldNames ? '' : 'kpn')
    ..aOB(12, _omitFieldNames ? '' : 'anonymouseUser', protoName: 'anonymouseUser')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpstreamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpstreamPayload copyWith(void Function(UpstreamPayload) updates) =>
      super.copyWith((message) => updates(message as UpstreamPayload)) as UpstreamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpstreamPayload() / UpstreamPayload.new instead')
  static UpstreamPayload create() => UpstreamPayload._();
  static $pb.GeneratedMessage $_createMessage() => UpstreamPayload._();
  @$core.override
  UpstreamPayload createEmptyInstance() => UpstreamPayload._();
  @$core.pragma('dart2js:noInline')
  static UpstreamPayload getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpstreamPayload>(UpstreamPayload.$_createMessage);
  static UpstreamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get command => $_getSZ(0);
  @$pb.TagNumber(1)
  set command($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seqId => $_getI64(1);
  @$pb.TagNumber(2)
  set seqId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeqId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeqId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get retryCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set retryCount($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRetryCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRetryCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get payloadData => $_getN(3);
  @$pb.TagNumber(4)
  set payloadData($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPayloadData() => $_has(3);
  @$pb.TagNumber(4)
  void clearPayloadData() => $_clearField(4);

  @$pb.TagNumber(5)
  UserInstance get userInstance => $_getN(4);
  @$pb.TagNumber(5)
  set userInstance(UserInstance value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUserInstance() => $_has(4);
  @$pb.TagNumber(5)
  void clearUserInstance() => $_clearField(5);
  @$pb.TagNumber(5)
  UserInstance ensureUserInstance() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.int get errorCode => $_getIZ(5);
  @$pb.TagNumber(6)
  set errorCode($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorCode() => $_clearField(6);

  @$pb.TagNumber(7)
  SettingInfo get settingInfo => $_getN(6);
  @$pb.TagNumber(7)
  set settingInfo(SettingInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSettingInfo() => $_has(6);
  @$pb.TagNumber(7)
  void clearSettingInfo() => $_clearField(7);
  @$pb.TagNumber(7)
  SettingInfo ensureSettingInfo() => $_ensure(6);

  @$pb.TagNumber(8)
  RequsetBasicInfo get requestBasicInfo => $_getN(7);
  @$pb.TagNumber(8)
  set requestBasicInfo(RequsetBasicInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasRequestBasicInfo() => $_has(7);
  @$pb.TagNumber(8)
  void clearRequestBasicInfo() => $_clearField(8);
  @$pb.TagNumber(8)
  RequsetBasicInfo ensureRequestBasicInfo() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get subBiz => $_getSZ(8);
  @$pb.TagNumber(9)
  set subBiz($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSubBiz() => $_has(8);
  @$pb.TagNumber(9)
  void clearSubBiz() => $_clearField(9);

  @$pb.TagNumber(10)
  FrontendInfo get frontendInfo => $_getN(9);
  @$pb.TagNumber(10)
  set frontendInfo(FrontendInfo value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasFrontendInfo() => $_has(9);
  @$pb.TagNumber(10)
  void clearFrontendInfo() => $_clearField(10);
  @$pb.TagNumber(10)
  FrontendInfo ensureFrontendInfo() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get kpn => $_getSZ(10);
  @$pb.TagNumber(11)
  set kpn($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasKpn() => $_has(10);
  @$pb.TagNumber(11)
  void clearKpn() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get anonymouseUser => $_getBF(11);
  @$pb.TagNumber(12)
  set anonymouseUser($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAnonymouseUser() => $_has(11);
  @$pb.TagNumber(12)
  void clearAnonymouseUser() => $_clearField(12);
}

class DownstreamPayload extends $pb.GeneratedMessage {
  factory DownstreamPayload({
    $core.String? command,
    $fixnum.Int64? seqId,
    $core.int? errorCode,
    $core.List<$core.int>? payloadData,
    $core.String? errorMsg,
    $core.List<$core.int>? errorData,
    $core.String? subBiz,
  }) {
    final result = DownstreamPayload._();
    if (command != null) result.command = command;
    if (seqId != null) result.seqId = seqId;
    if (errorCode != null) result.errorCode = errorCode;
    if (payloadData != null) result.payloadData = payloadData;
    if (errorMsg != null) result.errorMsg = errorMsg;
    if (errorData != null) result.errorData = errorData;
    if (subBiz != null) result.subBiz = subBiz;
    return result;
  }

  DownstreamPayload._();

  factory DownstreamPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownstreamPayload()..mergeFromBuffer(data, registry);
  factory DownstreamPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DownstreamPayload()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DownstreamPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: DownstreamPayload.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'command')
    ..aInt64(2, _omitFieldNames ? '' : 'seqId', protoName: 'seqId')
    ..aI(3, _omitFieldNames ? '' : 'errorCode', protoName: 'errorCode')
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'payloadData', $pb.PbFieldType.OY, protoName: 'payloadData')
    ..aOS(5, _omitFieldNames ? '' : 'errorMsg', protoName: 'errorMsg')
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'errorData', $pb.PbFieldType.OY, protoName: 'errorData')
    ..aOS(7, _omitFieldNames ? '' : 'subBiz', protoName: 'subBiz')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownstreamPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DownstreamPayload copyWith(void Function(DownstreamPayload) updates) =>
      super.copyWith((message) => updates(message as DownstreamPayload)) as DownstreamPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DownstreamPayload() / DownstreamPayload.new instead')
  static DownstreamPayload create() => DownstreamPayload._();
  static $pb.GeneratedMessage $_createMessage() => DownstreamPayload._();
  @$core.override
  DownstreamPayload createEmptyInstance() => DownstreamPayload._();
  @$core.pragma('dart2js:noInline')
  static DownstreamPayload getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DownstreamPayload>(DownstreamPayload.$_createMessage);
  static DownstreamPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get command => $_getSZ(0);
  @$pb.TagNumber(1)
  set command($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommand() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommand() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seqId => $_getI64(1);
  @$pb.TagNumber(2)
  set seqId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeqId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeqId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get errorCode => $_getIZ(2);
  @$pb.TagNumber(3)
  set errorCode($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasErrorCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearErrorCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get payloadData => $_getN(3);
  @$pb.TagNumber(4)
  set payloadData($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPayloadData() => $_has(3);
  @$pb.TagNumber(4)
  void clearPayloadData() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get errorMsg => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMsg($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMsg() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMsg() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get errorData => $_getN(5);
  @$pb.TagNumber(6)
  set errorData($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorData() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorData() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get subBiz => $_getSZ(6);
  @$pb.TagNumber(7)
  set subBiz($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSubBiz() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubBiz() => $_clearField(7);
}

class UserInstance extends $pb.GeneratedMessage {
  factory UserInstance({
    User? user,
    $fixnum.Int64? instanceId,
  }) {
    final result = UserInstance._();
    if (user != null) result.user = user;
    if (instanceId != null) result.instanceId = instanceId;
    return result;
  }

  UserInstance._();

  factory UserInstance.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInstance()..mergeFromBuffer(data, registry);
  factory UserInstance.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInstance()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UserInstance',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: UserInstance.$_createMessage)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'instanceId', protoName: 'instanceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInstance clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInstance copyWith(void Function(UserInstance) updates) =>
      super.copyWith((message) => updates(message as UserInstance)) as UserInstance;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserInstance() / UserInstance.new instead')
  static UserInstance create() => UserInstance._();
  static $pb.GeneratedMessage $_createMessage() => UserInstance._();
  @$core.override
  UserInstance createEmptyInstance() => UserInstance._();
  @$core.pragma('dart2js:noInline')
  static UserInstance getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserInstance>(UserInstance.$_createMessage);
  static UserInstance? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get instanceId => $_getI64(1);
  @$pb.TagNumber(2)
  set instanceId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInstanceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearInstanceId() => $_clearField(2);
}

class User extends $pb.GeneratedMessage {
  factory User({
    $core.int? appId,
    $fixnum.Int64? uid,
  }) {
    final result = User._();
    if (appId != null) result.appId = appId;
    if (uid != null) result.uid = uid;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      User()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'User',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'), createEmptyInstance: User.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'appId', protoName: 'appId')
    ..aInt64(2, _omitFieldNames ? '' : 'uid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) => super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use User() / User.new instead')
  static User create() => User._();
  static $pb.GeneratedMessage $_createMessage() => User._();
  @$core.override
  User createEmptyInstance() => User._();
  @$core.pragma('dart2js:noInline')
  static User getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(User.$_createMessage);
  static User? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get appId => $_getIZ(0);
  @$pb.TagNumber(1)
  set appId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get uid => $_getI64(1);
  @$pb.TagNumber(2)
  set uid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUid() => $_has(1);
  @$pb.TagNumber(2)
  void clearUid() => $_clearField(2);
}

class SettingInfo extends $pb.GeneratedMessage {
  factory SettingInfo({
    $core.String? locale,
    $core.int? timezone,
  }) {
    final result = SettingInfo._();
    if (locale != null) result.locale = locale;
    if (timezone != null) result.timezone = timezone;
    return result;
  }

  SettingInfo._();

  factory SettingInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SettingInfo()..mergeFromBuffer(data, registry);
  factory SettingInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SettingInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SettingInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: SettingInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'locale')
    ..aI(2, _omitFieldNames ? '' : 'timezone', fieldType: $pb.PbFieldType.OS3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingInfo copyWith(void Function(SettingInfo) updates) =>
      super.copyWith((message) => updates(message as SettingInfo)) as SettingInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SettingInfo() / SettingInfo.new instead')
  static SettingInfo create() => SettingInfo._();
  static $pb.GeneratedMessage $_createMessage() => SettingInfo._();
  @$core.override
  SettingInfo createEmptyInstance() => SettingInfo._();
  @$core.pragma('dart2js:noInline')
  static SettingInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SettingInfo>(SettingInfo.$_createMessage);
  static SettingInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get locale => $_getSZ(0);
  @$pb.TagNumber(1)
  set locale($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLocale() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocale() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get timezone => $_getIZ(1);
  @$pb.TagNumber(2)
  set timezone($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimezone() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimezone() => $_clearField(2);
}

class RequsetBasicInfo extends $pb.GeneratedMessage {
  factory RequsetBasicInfo({
    DeviceInfo_PlatformType? clientType,
    $core.String? deviceId,
    $core.String? clientIp,
    $core.String? appVersion,
    $core.String? channel,
    AppInfo? appInfo,
    DeviceInfo? deviceInfo,
    EnvInfo? envInfo,
    $core.int? clientPort,
    $core.String? location,
    $core.String? kpf,
  }) {
    final result = RequsetBasicInfo._();
    if (clientType != null) result.clientType = clientType;
    if (deviceId != null) result.deviceId = deviceId;
    if (clientIp != null) result.clientIp = clientIp;
    if (appVersion != null) result.appVersion = appVersion;
    if (channel != null) result.channel = channel;
    if (appInfo != null) result.appInfo = appInfo;
    if (deviceInfo != null) result.deviceInfo = deviceInfo;
    if (envInfo != null) result.envInfo = envInfo;
    if (clientPort != null) result.clientPort = clientPort;
    if (location != null) result.location = location;
    if (kpf != null) result.kpf = kpf;
    return result;
  }

  RequsetBasicInfo._();

  factory RequsetBasicInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequsetBasicInfo()..mergeFromBuffer(data, registry);
  factory RequsetBasicInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequsetBasicInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RequsetBasicInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: RequsetBasicInfo.$_createMessage)
    ..aE<DeviceInfo_PlatformType>(1, _omitFieldNames ? '' : 'clientType',
        protoName: 'clientType', enumValues: DeviceInfo_PlatformType.values)
    ..aOS(2, _omitFieldNames ? '' : 'deviceId', protoName: 'deviceId')
    ..aOS(3, _omitFieldNames ? '' : 'clientIp', protoName: 'clientIp')
    ..aOS(4, _omitFieldNames ? '' : 'appVersion', protoName: 'appVersion')
    ..aOS(5, _omitFieldNames ? '' : 'channel')
    ..aOM<AppInfo>(6, _omitFieldNames ? '' : 'appInfo', protoName: 'appInfo', subBuilder: AppInfo.$_createMessage)
    ..aOM<DeviceInfo>(7, _omitFieldNames ? '' : 'deviceInfo',
        protoName: 'deviceInfo', subBuilder: DeviceInfo.$_createMessage)
    ..aOM<EnvInfo>(8, _omitFieldNames ? '' : 'envInfo', protoName: 'envInfo', subBuilder: EnvInfo.$_createMessage)
    ..aI(9, _omitFieldNames ? '' : 'clientPort', protoName: 'clientPort')
    ..aOS(10, _omitFieldNames ? '' : 'location')
    ..aOS(11, _omitFieldNames ? '' : 'kpf')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequsetBasicInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequsetBasicInfo copyWith(void Function(RequsetBasicInfo) updates) =>
      super.copyWith((message) => updates(message as RequsetBasicInfo)) as RequsetBasicInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RequsetBasicInfo() / RequsetBasicInfo.new instead')
  static RequsetBasicInfo create() => RequsetBasicInfo._();
  static $pb.GeneratedMessage $_createMessage() => RequsetBasicInfo._();
  @$core.override
  RequsetBasicInfo createEmptyInstance() => RequsetBasicInfo._();
  @$core.pragma('dart2js:noInline')
  static RequsetBasicInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RequsetBasicInfo>(RequsetBasicInfo.$_createMessage);
  static RequsetBasicInfo? _defaultInstance;

  @$pb.TagNumber(1)
  DeviceInfo_PlatformType get clientType => $_getN(0);
  @$pb.TagNumber(1)
  set clientType(DeviceInfo_PlatformType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasClientType() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get clientIp => $_getSZ(2);
  @$pb.TagNumber(3)
  set clientIp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClientIp() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientIp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get appVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set appVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAppVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get channel => $_getSZ(4);
  @$pb.TagNumber(5)
  set channel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChannel() => $_has(4);
  @$pb.TagNumber(5)
  void clearChannel() => $_clearField(5);

  @$pb.TagNumber(6)
  AppInfo get appInfo => $_getN(5);
  @$pb.TagNumber(6)
  set appInfo(AppInfo value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAppInfo() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppInfo() => $_clearField(6);
  @$pb.TagNumber(6)
  AppInfo ensureAppInfo() => $_ensure(5);

  @$pb.TagNumber(7)
  DeviceInfo get deviceInfo => $_getN(6);
  @$pb.TagNumber(7)
  set deviceInfo(DeviceInfo value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDeviceInfo() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeviceInfo() => $_clearField(7);
  @$pb.TagNumber(7)
  DeviceInfo ensureDeviceInfo() => $_ensure(6);

  @$pb.TagNumber(8)
  EnvInfo get envInfo => $_getN(7);
  @$pb.TagNumber(8)
  set envInfo(EnvInfo value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasEnvInfo() => $_has(7);
  @$pb.TagNumber(8)
  void clearEnvInfo() => $_clearField(8);
  @$pb.TagNumber(8)
  EnvInfo ensureEnvInfo() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.int get clientPort => $_getIZ(8);
  @$pb.TagNumber(9)
  set clientPort($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasClientPort() => $_has(8);
  @$pb.TagNumber(9)
  void clearClientPort() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get location => $_getSZ(9);
  @$pb.TagNumber(10)
  set location($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLocation() => $_has(9);
  @$pb.TagNumber(10)
  void clearLocation() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get kpf => $_getSZ(10);
  @$pb.TagNumber(11)
  set kpf($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasKpf() => $_has(10);
  @$pb.TagNumber(11)
  void clearKpf() => $_clearField(11);
}

class FrontendInfo extends $pb.GeneratedMessage {
  factory FrontendInfo({
    $core.String? ip,
    $core.int? port,
  }) {
    final result = FrontendInfo._();
    if (ip != null) result.ip = ip;
    if (port != null) result.port = port;
    return result;
  }

  FrontendInfo._();

  factory FrontendInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrontendInfo()..mergeFromBuffer(data, registry);
  factory FrontendInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FrontendInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FrontendInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: FrontendInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'ip')
    ..aI(2, _omitFieldNames ? '' : 'port')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrontendInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FrontendInfo copyWith(void Function(FrontendInfo) updates) =>
      super.copyWith((message) => updates(message as FrontendInfo)) as FrontendInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FrontendInfo() / FrontendInfo.new instead')
  static FrontendInfo create() => FrontendInfo._();
  static $pb.GeneratedMessage $_createMessage() => FrontendInfo._();
  @$core.override
  FrontendInfo createEmptyInstance() => FrontendInfo._();
  @$core.pragma('dart2js:noInline')
  static FrontendInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FrontendInfo>(FrontendInfo.$_createMessage);
  static FrontendInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ip => $_getSZ(0);
  @$pb.TagNumber(1)
  set ip($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIp() => $_has(0);
  @$pb.TagNumber(1)
  void clearIp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get port => $_getIZ(1);
  @$pb.TagNumber(2)
  set port($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPort() => $_has(1);
  @$pb.TagNumber(2)
  void clearPort() => $_clearField(2);
}

class PacketHeader extends $pb.GeneratedMessage {
  factory PacketHeader({
    $core.int? appId,
    $fixnum.Int64? uid,
    $fixnum.Int64? instanceId,
    $core.int? flags,
    PacketHeader_EncodingType? encodingType,
    $core.int? decodedPayloadLen,
    PacketHeader_EncryptionMode? encryptionMode,
    TokenInfo? tokenInfo,
    $fixnum.Int64? seqId,
    $core.Iterable<PacketHeader_Feature>? features,
    $core.String? kpn,
  }) {
    final result = PacketHeader._();
    if (appId != null) result.appId = appId;
    if (uid != null) result.uid = uid;
    if (instanceId != null) result.instanceId = instanceId;
    if (flags != null) result.flags = flags;
    if (encodingType != null) result.encodingType = encodingType;
    if (decodedPayloadLen != null) result.decodedPayloadLen = decodedPayloadLen;
    if (encryptionMode != null) result.encryptionMode = encryptionMode;
    if (tokenInfo != null) result.tokenInfo = tokenInfo;
    if (seqId != null) result.seqId = seqId;
    if (features != null) result.features.addAll(features);
    if (kpn != null) result.kpn = kpn;
    return result;
  }

  PacketHeader._();

  factory PacketHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PacketHeader()..mergeFromBuffer(data, registry);
  factory PacketHeader.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PacketHeader()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PacketHeader',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: PacketHeader.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'appId', protoName: 'appId')
    ..aInt64(2, _omitFieldNames ? '' : 'uid')
    ..aInt64(3, _omitFieldNames ? '' : 'instanceId', protoName: 'instanceId')
    ..aI(4, _omitFieldNames ? '' : 'flags', fieldType: $pb.PbFieldType.OU3)
    ..aE<PacketHeader_EncodingType>(6, _omitFieldNames ? '' : 'encodingType',
        protoName: 'encodingType', enumValues: PacketHeader_EncodingType.values)
    ..aI(7, _omitFieldNames ? '' : 'decodedPayloadLen', protoName: 'decodedPayloadLen', fieldType: $pb.PbFieldType.OU3)
    ..aE<PacketHeader_EncryptionMode>(8, _omitFieldNames ? '' : 'encryptionMode',
        protoName: 'encryptionMode', enumValues: PacketHeader_EncryptionMode.values)
    ..aOM<TokenInfo>(9, _omitFieldNames ? '' : 'tokenInfo',
        protoName: 'tokenInfo', subBuilder: TokenInfo.$_createMessage)
    ..aInt64(10, _omitFieldNames ? '' : 'seqId', protoName: 'seqId')
    ..pPE<PacketHeader_Feature>(11, _omitFieldNames ? '' : 'features', enumValues: PacketHeader_Feature.values)
    ..aOS(12, _omitFieldNames ? '' : 'kpn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PacketHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PacketHeader copyWith(void Function(PacketHeader) updates) =>
      super.copyWith((message) => updates(message as PacketHeader)) as PacketHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PacketHeader() / PacketHeader.new instead')
  static PacketHeader create() => PacketHeader._();
  static $pb.GeneratedMessage $_createMessage() => PacketHeader._();
  @$core.override
  PacketHeader createEmptyInstance() => PacketHeader._();
  @$core.pragma('dart2js:noInline')
  static PacketHeader getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PacketHeader>(PacketHeader.$_createMessage);
  static PacketHeader? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get appId => $_getIZ(0);
  @$pb.TagNumber(1)
  set appId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get uid => $_getI64(1);
  @$pb.TagNumber(2)
  set uid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUid() => $_has(1);
  @$pb.TagNumber(2)
  void clearUid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get instanceId => $_getI64(2);
  @$pb.TagNumber(3)
  set instanceId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInstanceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInstanceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get flags => $_getIZ(3);
  @$pb.TagNumber(4)
  set flags($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFlags() => $_has(3);
  @$pb.TagNumber(4)
  void clearFlags() => $_clearField(4);

  @$pb.TagNumber(6)
  PacketHeader_EncodingType get encodingType => $_getN(4);
  @$pb.TagNumber(6)
  set encodingType(PacketHeader_EncodingType value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasEncodingType() => $_has(4);
  @$pb.TagNumber(6)
  void clearEncodingType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get decodedPayloadLen => $_getIZ(5);
  @$pb.TagNumber(7)
  set decodedPayloadLen($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(7)
  $core.bool hasDecodedPayloadLen() => $_has(5);
  @$pb.TagNumber(7)
  void clearDecodedPayloadLen() => $_clearField(7);

  @$pb.TagNumber(8)
  PacketHeader_EncryptionMode get encryptionMode => $_getN(6);
  @$pb.TagNumber(8)
  set encryptionMode(PacketHeader_EncryptionMode value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasEncryptionMode() => $_has(6);
  @$pb.TagNumber(8)
  void clearEncryptionMode() => $_clearField(8);

  @$pb.TagNumber(9)
  TokenInfo get tokenInfo => $_getN(7);
  @$pb.TagNumber(9)
  set tokenInfo(TokenInfo value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasTokenInfo() => $_has(7);
  @$pb.TagNumber(9)
  void clearTokenInfo() => $_clearField(9);
  @$pb.TagNumber(9)
  TokenInfo ensureTokenInfo() => $_ensure(7);

  @$pb.TagNumber(10)
  $fixnum.Int64 get seqId => $_getI64(8);
  @$pb.TagNumber(10)
  set seqId($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(10)
  $core.bool hasSeqId() => $_has(8);
  @$pb.TagNumber(10)
  void clearSeqId() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<PacketHeader_Feature> get features => $_getList(9);

  @$pb.TagNumber(12)
  $core.String get kpn => $_getSZ(10);
  @$pb.TagNumber(12)
  set kpn($core.String value) => $_setString(10, value);
  @$pb.TagNumber(12)
  $core.bool hasKpn() => $_has(10);
  @$pb.TagNumber(12)
  void clearKpn() => $_clearField(12);
}

class TokenInfo extends $pb.GeneratedMessage {
  factory TokenInfo({
    TokenInfo_TokenType? tokenType,
    $core.List<$core.int>? token,
  }) {
    final result = TokenInfo._();
    if (tokenType != null) result.tokenType = tokenType;
    if (token != null) result.token = token;
    return result;
  }

  TokenInfo._();

  factory TokenInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TokenInfo()..mergeFromBuffer(data, registry);
  factory TokenInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TokenInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TokenInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: TokenInfo.$_createMessage)
    ..aE<TokenInfo_TokenType>(1, _omitFieldNames ? '' : 'tokenType',
        protoName: 'tokenType', enumValues: TokenInfo_TokenType.values)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'token', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenInfo copyWith(void Function(TokenInfo) updates) =>
      super.copyWith((message) => updates(message as TokenInfo)) as TokenInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TokenInfo() / TokenInfo.new instead')
  static TokenInfo create() => TokenInfo._();
  static $pb.GeneratedMessage $_createMessage() => TokenInfo._();
  @$core.override
  TokenInfo createEmptyInstance() => TokenInfo._();
  @$core.pragma('dart2js:noInline')
  static TokenInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TokenInfo>(TokenInfo.$_createMessage);
  static TokenInfo? _defaultInstance;

  @$pb.TagNumber(1)
  TokenInfo_TokenType get tokenType => $_getN(0);
  @$pb.TagNumber(1)
  set tokenType(TokenInfo_TokenType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTokenType() => $_has(0);
  @$pb.TagNumber(1)
  void clearTokenType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get token => $_getN(1);
  @$pb.TagNumber(2)
  set token($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

class KeepAliveRequest extends $pb.GeneratedMessage {
  factory KeepAliveRequest({
    RegisterRequest_PresenceStatus? presenceStatus,
    RegisterRequest_ActiveStatus? appActiveStatus,
    PushServiceToken? pushServiceToken,
    $core.Iterable<PushServiceToken>? pushServiceTokenList,
    $core.Iterable<$core.int>? keepaliveIntervalSec,
  }) {
    final result = KeepAliveRequest._();
    if (presenceStatus != null) result.presenceStatus = presenceStatus;
    if (appActiveStatus != null) result.appActiveStatus = appActiveStatus;
    if (pushServiceToken != null) result.pushServiceToken = pushServiceToken;
    if (pushServiceTokenList != null) result.pushServiceTokenList.addAll(pushServiceTokenList);
    if (keepaliveIntervalSec != null) result.keepaliveIntervalSec.addAll(keepaliveIntervalSec);
    return result;
  }

  KeepAliveRequest._();

  factory KeepAliveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepAliveRequest()..mergeFromBuffer(data, registry);
  factory KeepAliveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepAliveRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'KeepAliveRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: KeepAliveRequest.$_createMessage)
    ..aE<RegisterRequest_PresenceStatus>(1, _omitFieldNames ? '' : 'presenceStatus',
        protoName: 'presenceStatus', enumValues: RegisterRequest_PresenceStatus.values)
    ..aE<RegisterRequest_ActiveStatus>(2, _omitFieldNames ? '' : 'appActiveStatus',
        protoName: 'appActiveStatus', enumValues: RegisterRequest_ActiveStatus.values)
    ..aOM<PushServiceToken>(3, _omitFieldNames ? '' : 'pushServiceToken',
        protoName: 'pushServiceToken', subBuilder: PushServiceToken.$_createMessage)
    ..pPM<PushServiceToken>(4, _omitFieldNames ? '' : 'pushServiceTokenList',
        protoName: 'pushServiceTokenList', subBuilder: PushServiceToken.$_createMessage)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'keepaliveIntervalSec', $pb.PbFieldType.P3,
        protoName: 'keepaliveIntervalSec')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepAliveRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepAliveRequest copyWith(void Function(KeepAliveRequest) updates) =>
      super.copyWith((message) => updates(message as KeepAliveRequest)) as KeepAliveRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeepAliveRequest() / KeepAliveRequest.new instead')
  static KeepAliveRequest create() => KeepAliveRequest._();
  static $pb.GeneratedMessage $_createMessage() => KeepAliveRequest._();
  @$core.override
  KeepAliveRequest createEmptyInstance() => KeepAliveRequest._();
  @$core.pragma('dart2js:noInline')
  static KeepAliveRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeepAliveRequest>(KeepAliveRequest.$_createMessage);
  static KeepAliveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  RegisterRequest_PresenceStatus get presenceStatus => $_getN(0);
  @$pb.TagNumber(1)
  set presenceStatus(RegisterRequest_PresenceStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPresenceStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearPresenceStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  RegisterRequest_ActiveStatus get appActiveStatus => $_getN(1);
  @$pb.TagNumber(2)
  set appActiveStatus(RegisterRequest_ActiveStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAppActiveStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppActiveStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  PushServiceToken get pushServiceToken => $_getN(2);
  @$pb.TagNumber(3)
  set pushServiceToken(PushServiceToken value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPushServiceToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearPushServiceToken() => $_clearField(3);
  @$pb.TagNumber(3)
  PushServiceToken ensurePushServiceToken() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<PushServiceToken> get pushServiceTokenList => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get keepaliveIntervalSec => $_getList(4);
}

class ZtLiveScMessage extends $pb.GeneratedMessage {
  factory ZtLiveScMessage({
    $core.String? messageType,
    $core.int? compressionType,
    $core.List<$core.int>? payload,
    $core.String? liveId,
    $core.String? ticket,
    $fixnum.Int64? serverTimestampMs,
  }) {
    final result = ZtLiveScMessage._();
    if (messageType != null) result.messageType = messageType;
    if (compressionType != null) result.compressionType = compressionType;
    if (payload != null) result.payload = payload;
    if (liveId != null) result.liveId = liveId;
    if (ticket != null) result.ticket = ticket;
    if (serverTimestampMs != null) result.serverTimestampMs = serverTimestampMs;
    return result;
  }

  ZtLiveScMessage._();

  factory ZtLiveScMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScMessage()..mergeFromBuffer(data, registry);
  factory ZtLiveScMessage.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScMessage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'messageType', protoName: 'messageType')
    ..aI(2, _omitFieldNames ? '' : 'compressionType', protoName: 'compressionType')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'liveId', protoName: 'liveId')
    ..aOS(5, _omitFieldNames ? '' : 'ticket')
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'serverTimestampMs', $pb.PbFieldType.OU6,
        protoName: 'serverTimestampMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScMessage copyWith(void Function(ZtLiveScMessage) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScMessage)) as ZtLiveScMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScMessage() / ZtLiveScMessage.new instead')
  static ZtLiveScMessage create() => ZtLiveScMessage._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScMessage._();
  @$core.override
  ZtLiveScMessage createEmptyInstance() => ZtLiveScMessage._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScMessage>(ZtLiveScMessage.$_createMessage);
  static ZtLiveScMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageType => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get compressionType => $_getIZ(1);
  @$pb.TagNumber(2)
  set compressionType($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompressionType() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompressionType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get liveId => $_getSZ(3);
  @$pb.TagNumber(4)
  set liveId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLiveId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLiveId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get ticket => $_getSZ(4);
  @$pb.TagNumber(5)
  set ticket($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTicket() => $_has(4);
  @$pb.TagNumber(5)
  void clearTicket() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get serverTimestampMs => $_getI64(5);
  @$pb.TagNumber(6)
  set serverTimestampMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasServerTimestampMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearServerTimestampMs() => $_clearField(6);
}

class ZtLiveScNotifySignal_ZtLiveNotifySignalItem extends $pb.GeneratedMessage {
  factory ZtLiveScNotifySignal_ZtLiveNotifySignalItem({
    $core.String? signalType,
    $core.Iterable<$core.List<$core.int>>? payload,
  }) {
    final result = ZtLiveScNotifySignal_ZtLiveNotifySignalItem._();
    if (signalType != null) result.signalType = signalType;
    if (payload != null) result.payload.addAll(payload);
    return result;
  }

  ZtLiveScNotifySignal_ZtLiveNotifySignalItem._();

  factory ZtLiveScNotifySignal_ZtLiveNotifySignalItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScNotifySignal_ZtLiveNotifySignalItem()..mergeFromBuffer(data, registry);
  factory ZtLiveScNotifySignal_ZtLiveNotifySignalItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScNotifySignal_ZtLiveNotifySignalItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ZtLiveScNotifySignal.ZtLiveNotifySignalItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScNotifySignal_ZtLiveNotifySignalItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'signalType', protoName: 'signalType')
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScNotifySignal_ZtLiveNotifySignalItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScNotifySignal_ZtLiveNotifySignalItem copyWith(
          void Function(ZtLiveScNotifySignal_ZtLiveNotifySignalItem) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScNotifySignal_ZtLiveNotifySignalItem))
          as ZtLiveScNotifySignal_ZtLiveNotifySignalItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ZtLiveScNotifySignal_ZtLiveNotifySignalItem() / ZtLiveScNotifySignal_ZtLiveNotifySignalItem.new instead')
  static ZtLiveScNotifySignal_ZtLiveNotifySignalItem create() => ZtLiveScNotifySignal_ZtLiveNotifySignalItem._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScNotifySignal_ZtLiveNotifySignalItem._();
  @$core.override
  ZtLiveScNotifySignal_ZtLiveNotifySignalItem createEmptyInstance() => ZtLiveScNotifySignal_ZtLiveNotifySignalItem._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScNotifySignal_ZtLiveNotifySignalItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScNotifySignal_ZtLiveNotifySignalItem>(
          ZtLiveScNotifySignal_ZtLiveNotifySignalItem.$_createMessage);
  static ZtLiveScNotifySignal_ZtLiveNotifySignalItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signalType => $_getSZ(0);
  @$pb.TagNumber(1)
  set signalType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignalType() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignalType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get payload => $_getList(1);
}

class ZtLiveScNotifySignal extends $pb.GeneratedMessage {
  factory ZtLiveScNotifySignal({
    $core.Iterable<ZtLiveScNotifySignal_ZtLiveNotifySignalItem>? item,
  }) {
    final result = ZtLiveScNotifySignal._();
    if (item != null) result.item.addAll(item);
    return result;
  }

  ZtLiveScNotifySignal._();

  factory ZtLiveScNotifySignal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScNotifySignal()..mergeFromBuffer(data, registry);
  factory ZtLiveScNotifySignal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScNotifySignal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScNotifySignal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScNotifySignal.$_createMessage)
    ..pPM<ZtLiveScNotifySignal_ZtLiveNotifySignalItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: ZtLiveScNotifySignal_ZtLiveNotifySignalItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScNotifySignal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScNotifySignal copyWith(void Function(ZtLiveScNotifySignal) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScNotifySignal)) as ZtLiveScNotifySignal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScNotifySignal() / ZtLiveScNotifySignal.new instead')
  static ZtLiveScNotifySignal create() => ZtLiveScNotifySignal._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScNotifySignal._();
  @$core.override
  ZtLiveScNotifySignal createEmptyInstance() => ZtLiveScNotifySignal._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScNotifySignal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ZtLiveScNotifySignal>(ZtLiveScNotifySignal.$_createMessage);
  static ZtLiveScNotifySignal? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ZtLiveScNotifySignal_ZtLiveNotifySignalItem> get item => $_getList(0);
}

class ZtLiveScActionSignal_ZtLiveActionSignalItem extends $pb.GeneratedMessage {
  factory ZtLiveScActionSignal_ZtLiveActionSignalItem({
    $core.String? signalType,
    $core.Iterable<$core.List<$core.int>>? payload,
  }) {
    final result = ZtLiveScActionSignal_ZtLiveActionSignalItem._();
    if (signalType != null) result.signalType = signalType;
    if (payload != null) result.payload.addAll(payload);
    return result;
  }

  ZtLiveScActionSignal_ZtLiveActionSignalItem._();

  factory ZtLiveScActionSignal_ZtLiveActionSignalItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScActionSignal_ZtLiveActionSignalItem()..mergeFromBuffer(data, registry);
  factory ZtLiveScActionSignal_ZtLiveActionSignalItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScActionSignal_ZtLiveActionSignalItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ZtLiveScActionSignal.ZtLiveActionSignalItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScActionSignal_ZtLiveActionSignalItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'signalType', protoName: 'signalType')
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScActionSignal_ZtLiveActionSignalItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScActionSignal_ZtLiveActionSignalItem copyWith(
          void Function(ZtLiveScActionSignal_ZtLiveActionSignalItem) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScActionSignal_ZtLiveActionSignalItem))
          as ZtLiveScActionSignal_ZtLiveActionSignalItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ZtLiveScActionSignal_ZtLiveActionSignalItem() / ZtLiveScActionSignal_ZtLiveActionSignalItem.new instead')
  static ZtLiveScActionSignal_ZtLiveActionSignalItem create() => ZtLiveScActionSignal_ZtLiveActionSignalItem._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScActionSignal_ZtLiveActionSignalItem._();
  @$core.override
  ZtLiveScActionSignal_ZtLiveActionSignalItem createEmptyInstance() => ZtLiveScActionSignal_ZtLiveActionSignalItem._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScActionSignal_ZtLiveActionSignalItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScActionSignal_ZtLiveActionSignalItem>(
          ZtLiveScActionSignal_ZtLiveActionSignalItem.$_createMessage);
  static ZtLiveScActionSignal_ZtLiveActionSignalItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signalType => $_getSZ(0);
  @$pb.TagNumber(1)
  set signalType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignalType() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignalType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get payload => $_getList(1);
}

class ZtLiveScActionSignal extends $pb.GeneratedMessage {
  factory ZtLiveScActionSignal({
    $core.Iterable<ZtLiveScActionSignal_ZtLiveActionSignalItem>? item,
  }) {
    final result = ZtLiveScActionSignal._();
    if (item != null) result.item.addAll(item);
    return result;
  }

  ZtLiveScActionSignal._();

  factory ZtLiveScActionSignal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScActionSignal()..mergeFromBuffer(data, registry);
  factory ZtLiveScActionSignal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScActionSignal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScActionSignal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScActionSignal.$_createMessage)
    ..pPM<ZtLiveScActionSignal_ZtLiveActionSignalItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: ZtLiveScActionSignal_ZtLiveActionSignalItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScActionSignal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScActionSignal copyWith(void Function(ZtLiveScActionSignal) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScActionSignal)) as ZtLiveScActionSignal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScActionSignal() / ZtLiveScActionSignal.new instead')
  static ZtLiveScActionSignal create() => ZtLiveScActionSignal._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScActionSignal._();
  @$core.override
  ZtLiveScActionSignal createEmptyInstance() => ZtLiveScActionSignal._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScActionSignal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ZtLiveScActionSignal>(ZtLiveScActionSignal.$_createMessage);
  static ZtLiveScActionSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ZtLiveScActionSignal_ZtLiveActionSignalItem> get item => $_getList(0);
}

class ZtLiveScStateSignal_ZtLiveStateSignalItem extends $pb.GeneratedMessage {
  factory ZtLiveScStateSignal_ZtLiveStateSignalItem({
    $core.String? signalType,
    $core.Iterable<$core.List<$core.int>>? payload,
  }) {
    final result = ZtLiveScStateSignal_ZtLiveStateSignalItem._();
    if (signalType != null) result.signalType = signalType;
    if (payload != null) result.payload.addAll(payload);
    return result;
  }

  ZtLiveScStateSignal_ZtLiveStateSignalItem._();

  factory ZtLiveScStateSignal_ZtLiveStateSignalItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStateSignal_ZtLiveStateSignalItem()..mergeFromBuffer(data, registry);
  factory ZtLiveScStateSignal_ZtLiveStateSignalItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStateSignal_ZtLiveStateSignalItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ZtLiveScStateSignal.ZtLiveStateSignalItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScStateSignal_ZtLiveStateSignalItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'signalType', protoName: 'signalType')
    ..p<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStateSignal_ZtLiveStateSignalItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStateSignal_ZtLiveStateSignalItem copyWith(
          void Function(ZtLiveScStateSignal_ZtLiveStateSignalItem) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScStateSignal_ZtLiveStateSignalItem))
          as ZtLiveScStateSignal_ZtLiveStateSignalItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ZtLiveScStateSignal_ZtLiveStateSignalItem() / ZtLiveScStateSignal_ZtLiveStateSignalItem.new instead')
  static ZtLiveScStateSignal_ZtLiveStateSignalItem create() => ZtLiveScStateSignal_ZtLiveStateSignalItem._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScStateSignal_ZtLiveStateSignalItem._();
  @$core.override
  ZtLiveScStateSignal_ZtLiveStateSignalItem createEmptyInstance() => ZtLiveScStateSignal_ZtLiveStateSignalItem._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScStateSignal_ZtLiveStateSignalItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScStateSignal_ZtLiveStateSignalItem>(
          ZtLiveScStateSignal_ZtLiveStateSignalItem.$_createMessage);
  static ZtLiveScStateSignal_ZtLiveStateSignalItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get signalType => $_getSZ(0);
  @$pb.TagNumber(1)
  set signalType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignalType() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignalType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get payload => $_getList(1);
}

class ZtLiveScStateSignal extends $pb.GeneratedMessage {
  factory ZtLiveScStateSignal({
    $core.Iterable<ZtLiveScStateSignal_ZtLiveStateSignalItem>? item,
  }) {
    final result = ZtLiveScStateSignal._();
    if (item != null) result.item.addAll(item);
    return result;
  }

  ZtLiveScStateSignal._();

  factory ZtLiveScStateSignal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStateSignal()..mergeFromBuffer(data, registry);
  factory ZtLiveScStateSignal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStateSignal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScStateSignal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScStateSignal.$_createMessage)
    ..pPM<ZtLiveScStateSignal_ZtLiveStateSignalItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: ZtLiveScStateSignal_ZtLiveStateSignalItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStateSignal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStateSignal copyWith(void Function(ZtLiveScStateSignal) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScStateSignal)) as ZtLiveScStateSignal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScStateSignal() / ZtLiveScStateSignal.new instead')
  static ZtLiveScStateSignal create() => ZtLiveScStateSignal._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScStateSignal._();
  @$core.override
  ZtLiveScStateSignal createEmptyInstance() => ZtLiveScStateSignal._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScStateSignal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScStateSignal>(ZtLiveScStateSignal.$_createMessage);
  static ZtLiveScStateSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ZtLiveScStateSignal_ZtLiveStateSignalItem> get item => $_getList(0);
}

class ZtLiveScStatusChanged_BannedInfo extends $pb.GeneratedMessage {
  factory ZtLiveScStatusChanged_BannedInfo({
    $core.String? banReason,
  }) {
    final result = ZtLiveScStatusChanged_BannedInfo._();
    if (banReason != null) result.banReason = banReason;
    return result;
  }

  ZtLiveScStatusChanged_BannedInfo._();

  factory ZtLiveScStatusChanged_BannedInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStatusChanged_BannedInfo()..mergeFromBuffer(data, registry);
  factory ZtLiveScStatusChanged_BannedInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStatusChanged_BannedInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScStatusChanged.BannedInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScStatusChanged_BannedInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'banReason', protoName: 'banReason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStatusChanged_BannedInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStatusChanged_BannedInfo copyWith(void Function(ZtLiveScStatusChanged_BannedInfo) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScStatusChanged_BannedInfo))
          as ZtLiveScStatusChanged_BannedInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScStatusChanged_BannedInfo() / ZtLiveScStatusChanged_BannedInfo.new instead')
  static ZtLiveScStatusChanged_BannedInfo create() => ZtLiveScStatusChanged_BannedInfo._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScStatusChanged_BannedInfo._();
  @$core.override
  ZtLiveScStatusChanged_BannedInfo createEmptyInstance() => ZtLiveScStatusChanged_BannedInfo._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScStatusChanged_BannedInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveScStatusChanged_BannedInfo>(
          ZtLiveScStatusChanged_BannedInfo.$_createMessage);
  static ZtLiveScStatusChanged_BannedInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get banReason => $_getSZ(0);
  @$pb.TagNumber(1)
  set banReason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBanReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearBanReason() => $_clearField(1);
}

class ZtLiveScStatusChanged extends $pb.GeneratedMessage {
  factory ZtLiveScStatusChanged({
    $core.int? type,
    $fixnum.Int64? maxRandomDelayMs,
    ZtLiveScStatusChanged_BannedInfo? bannedInfo,
  }) {
    final result = ZtLiveScStatusChanged._();
    if (type != null) result.type = type;
    if (maxRandomDelayMs != null) result.maxRandomDelayMs = maxRandomDelayMs;
    if (bannedInfo != null) result.bannedInfo = bannedInfo;
    return result;
  }

  ZtLiveScStatusChanged._();

  factory ZtLiveScStatusChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStatusChanged()..mergeFromBuffer(data, registry);
  factory ZtLiveScStatusChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveScStatusChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveScStatusChanged',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveScStatusChanged.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'type')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'maxRandomDelayMs', $pb.PbFieldType.OU6,
        protoName: 'maxRandomDelayMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ZtLiveScStatusChanged_BannedInfo>(3, _omitFieldNames ? '' : 'bannedInfo',
        protoName: 'bannedInfo', subBuilder: ZtLiveScStatusChanged_BannedInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStatusChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveScStatusChanged copyWith(void Function(ZtLiveScStatusChanged) updates) =>
      super.copyWith((message) => updates(message as ZtLiveScStatusChanged)) as ZtLiveScStatusChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveScStatusChanged() / ZtLiveScStatusChanged.new instead')
  static ZtLiveScStatusChanged create() => ZtLiveScStatusChanged._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveScStatusChanged._();
  @$core.override
  ZtLiveScStatusChanged createEmptyInstance() => ZtLiveScStatusChanged._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveScStatusChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ZtLiveScStatusChanged>(ZtLiveScStatusChanged.$_createMessage);
  static ZtLiveScStatusChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get type => $_getIZ(0);
  @$pb.TagNumber(1)
  set type($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get maxRandomDelayMs => $_getI64(1);
  @$pb.TagNumber(2)
  set maxRandomDelayMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxRandomDelayMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxRandomDelayMs() => $_clearField(2);

  @$pb.TagNumber(3)
  ZtLiveScStatusChanged_BannedInfo get bannedInfo => $_getN(2);
  @$pb.TagNumber(3)
  set bannedInfo(ZtLiveScStatusChanged_BannedInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBannedInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearBannedInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  ZtLiveScStatusChanged_BannedInfo ensureBannedInfo() => $_ensure(2);
}

class CommonActionSignalComment extends $pb.GeneratedMessage {
  factory CommonActionSignalComment({
    $core.String? content,
    $fixnum.Int64? sendTimeMs,
    ZtLiveUserInfo? userInfo,
  }) {
    final result = CommonActionSignalComment._();
    if (content != null) result.content = content;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    if (userInfo != null) result.userInfo = userInfo;
    return result;
  }

  CommonActionSignalComment._();

  factory CommonActionSignalComment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalComment()..mergeFromBuffer(data, registry);
  factory CommonActionSignalComment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalComment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalComment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalComment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ZtLiveUserInfo>(3, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalComment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalComment copyWith(void Function(CommonActionSignalComment) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalComment)) as CommonActionSignalComment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalComment() / CommonActionSignalComment.new instead')
  static CommonActionSignalComment create() => CommonActionSignalComment._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalComment._();
  @$core.override
  CommonActionSignalComment createEmptyInstance() => CommonActionSignalComment._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalComment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonActionSignalComment>(CommonActionSignalComment.$_createMessage);
  static CommonActionSignalComment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sendTimeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSendTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSendTimeMs() => $_clearField(2);

  @$pb.TagNumber(3)
  ZtLiveUserInfo get userInfo => $_getN(2);
  @$pb.TagNumber(3)
  set userInfo(ZtLiveUserInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUserInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearUserInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(2);
}

class CommonActionSignalLike extends $pb.GeneratedMessage {
  factory CommonActionSignalLike({
    ZtLiveUserInfo? userInfo,
    $fixnum.Int64? sendTimeMs,
  }) {
    final result = CommonActionSignalLike._();
    if (userInfo != null) result.userInfo = userInfo;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    return result;
  }

  CommonActionSignalLike._();

  factory CommonActionSignalLike.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalLike()..mergeFromBuffer(data, registry);
  factory CommonActionSignalLike.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalLike()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalLike',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalLike.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalLike clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalLike copyWith(void Function(CommonActionSignalLike) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalLike)) as CommonActionSignalLike;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalLike() / CommonActionSignalLike.new instead')
  static CommonActionSignalLike create() => CommonActionSignalLike._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalLike._();
  @$core.override
  CommonActionSignalLike createEmptyInstance() => CommonActionSignalLike._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalLike getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonActionSignalLike>(CommonActionSignalLike.$_createMessage);
  static CommonActionSignalLike? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sendTimeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSendTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSendTimeMs() => $_clearField(2);
}

class CommonActionSignalGift extends $pb.GeneratedMessage {
  factory CommonActionSignalGift({
    ZtLiveUserInfo? userInfo,
    $fixnum.Int64? sendTimeMs,
    $fixnum.Int64? giftId,
    $core.int? batchSize,
    $core.int? comboCount,
    $fixnum.Int64? rank,
    $core.String? comboKey,
    $fixnum.Int64? slotDisplayDurationMs,
    $fixnum.Int64? expireDurationMs,
  }) {
    final result = CommonActionSignalGift._();
    if (userInfo != null) result.userInfo = userInfo;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    if (giftId != null) result.giftId = giftId;
    if (batchSize != null) result.batchSize = batchSize;
    if (comboCount != null) result.comboCount = comboCount;
    if (rank != null) result.rank = rank;
    if (comboKey != null) result.comboKey = comboKey;
    if (slotDisplayDurationMs != null) result.slotDisplayDurationMs = slotDisplayDurationMs;
    if (expireDurationMs != null) result.expireDurationMs = expireDurationMs;
    return result;
  }

  CommonActionSignalGift._();

  factory CommonActionSignalGift.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalGift()..mergeFromBuffer(data, registry);
  factory CommonActionSignalGift.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalGift()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalGift',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalGift.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'giftId', $pb.PbFieldType.OU6,
        protoName: 'giftId', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(4, _omitFieldNames ? '' : 'batchSize', protoName: 'batchSize', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'comboCount', protoName: 'comboCount', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'rank', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(7, _omitFieldNames ? '' : 'comboKey', protoName: 'comboKey')
    ..a<$fixnum.Int64>(8, _omitFieldNames ? '' : 'slotDisplayDurationMs', $pb.PbFieldType.OU6,
        protoName: 'slotDisplayDurationMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(9, _omitFieldNames ? '' : 'expireDurationMs', $pb.PbFieldType.OU6,
        protoName: 'expireDurationMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalGift clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalGift copyWith(void Function(CommonActionSignalGift) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalGift)) as CommonActionSignalGift;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalGift() / CommonActionSignalGift.new instead')
  static CommonActionSignalGift create() => CommonActionSignalGift._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalGift._();
  @$core.override
  CommonActionSignalGift createEmptyInstance() => CommonActionSignalGift._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalGift getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonActionSignalGift>(CommonActionSignalGift.$_createMessage);
  static CommonActionSignalGift? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sendTimeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSendTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSendTimeMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get giftId => $_getI64(2);
  @$pb.TagNumber(3)
  set giftId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGiftId() => $_has(2);
  @$pb.TagNumber(3)
  void clearGiftId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get batchSize => $_getIZ(3);
  @$pb.TagNumber(4)
  set batchSize($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBatchSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearBatchSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get comboCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set comboCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasComboCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearComboCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get rank => $_getI64(5);
  @$pb.TagNumber(6)
  set rank($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRank() => $_has(5);
  @$pb.TagNumber(6)
  void clearRank() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get comboKey => $_getSZ(6);
  @$pb.TagNumber(7)
  set comboKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasComboKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearComboKey() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get slotDisplayDurationMs => $_getI64(7);
  @$pb.TagNumber(8)
  set slotDisplayDurationMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSlotDisplayDurationMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearSlotDisplayDurationMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get expireDurationMs => $_getI64(8);
  @$pb.TagNumber(9)
  set expireDurationMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasExpireDurationMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearExpireDurationMs() => $_clearField(9);
}

class CommonStateSignalDisplayInfo extends $pb.GeneratedMessage {
  factory CommonStateSignalDisplayInfo({
    $core.String? watchingCount,
    $core.String? likeCount,
    $core.int? likeDelta,
  }) {
    final result = CommonStateSignalDisplayInfo._();
    if (watchingCount != null) result.watchingCount = watchingCount;
    if (likeCount != null) result.likeCount = likeCount;
    if (likeDelta != null) result.likeDelta = likeDelta;
    return result;
  }

  CommonStateSignalDisplayInfo._();

  factory CommonStateSignalDisplayInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalDisplayInfo()..mergeFromBuffer(data, registry);
  factory CommonStateSignalDisplayInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalDisplayInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalDisplayInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalDisplayInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'watchingCount', protoName: 'watchingCount')
    ..aOS(2, _omitFieldNames ? '' : 'likeCount', protoName: 'likeCount')
    ..aI(3, _omitFieldNames ? '' : 'likeDelta', protoName: 'likeDelta', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalDisplayInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalDisplayInfo copyWith(void Function(CommonStateSignalDisplayInfo) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalDisplayInfo)) as CommonStateSignalDisplayInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalDisplayInfo() / CommonStateSignalDisplayInfo.new instead')
  static CommonStateSignalDisplayInfo create() => CommonStateSignalDisplayInfo._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalDisplayInfo._();
  @$core.override
  CommonStateSignalDisplayInfo createEmptyInstance() => CommonStateSignalDisplayInfo._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalDisplayInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonStateSignalDisplayInfo>(CommonStateSignalDisplayInfo.$_createMessage);
  static CommonStateSignalDisplayInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get watchingCount => $_getSZ(0);
  @$pb.TagNumber(1)
  set watchingCount($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWatchingCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearWatchingCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get likeCount => $_getSZ(1);
  @$pb.TagNumber(2)
  set likeCount($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLikeCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearLikeCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get likeDelta => $_getIZ(2);
  @$pb.TagNumber(3)
  set likeDelta($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLikeDelta() => $_has(2);
  @$pb.TagNumber(3)
  void clearLikeDelta() => $_clearField(3);
}

class CommonStateSignalTopUsers_TopUser extends $pb.GeneratedMessage {
  factory CommonStateSignalTopUsers_TopUser({
    ZtLiveUserInfo? userInfo,
    $core.String? customWatchingListData,
    $core.String? displaySendAmount,
    $core.bool? anonymousUser,
  }) {
    final result = CommonStateSignalTopUsers_TopUser._();
    if (userInfo != null) result.userInfo = userInfo;
    if (customWatchingListData != null) result.customWatchingListData = customWatchingListData;
    if (displaySendAmount != null) result.displaySendAmount = displaySendAmount;
    if (anonymousUser != null) result.anonymousUser = anonymousUser;
    return result;
  }

  CommonStateSignalTopUsers_TopUser._();

  factory CommonStateSignalTopUsers_TopUser.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalTopUsers_TopUser()..mergeFromBuffer(data, registry);
  factory CommonStateSignalTopUsers_TopUser.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalTopUsers_TopUser()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalTopUsers.TopUser',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalTopUsers_TopUser.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'customWatchingListData', protoName: 'customWatchingListData')
    ..aOS(3, _omitFieldNames ? '' : 'displaySendAmount', protoName: 'displaySendAmount')
    ..aOB(4, _omitFieldNames ? '' : 'anonymousUser', protoName: 'anonymousUser')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalTopUsers_TopUser clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalTopUsers_TopUser copyWith(void Function(CommonStateSignalTopUsers_TopUser) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalTopUsers_TopUser))
          as CommonStateSignalTopUsers_TopUser;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalTopUsers_TopUser() / CommonStateSignalTopUsers_TopUser.new instead')
  static CommonStateSignalTopUsers_TopUser create() => CommonStateSignalTopUsers_TopUser._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalTopUsers_TopUser._();
  @$core.override
  CommonStateSignalTopUsers_TopUser createEmptyInstance() => CommonStateSignalTopUsers_TopUser._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalTopUsers_TopUser getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonStateSignalTopUsers_TopUser>(
          CommonStateSignalTopUsers_TopUser.$_createMessage);
  static CommonStateSignalTopUsers_TopUser? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get customWatchingListData => $_getSZ(1);
  @$pb.TagNumber(2)
  set customWatchingListData($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCustomWatchingListData() => $_has(1);
  @$pb.TagNumber(2)
  void clearCustomWatchingListData() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displaySendAmount => $_getSZ(2);
  @$pb.TagNumber(3)
  set displaySendAmount($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplaySendAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplaySendAmount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get anonymousUser => $_getBF(3);
  @$pb.TagNumber(4)
  set anonymousUser($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAnonymousUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnonymousUser() => $_clearField(4);
}

class CommonStateSignalTopUsers extends $pb.GeneratedMessage {
  factory CommonStateSignalTopUsers({
    $core.Iterable<CommonStateSignalTopUsers_TopUser>? topUser,
  }) {
    final result = CommonStateSignalTopUsers._();
    if (topUser != null) result.topUser.addAll(topUser);
    return result;
  }

  CommonStateSignalTopUsers._();

  factory CommonStateSignalTopUsers.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalTopUsers()..mergeFromBuffer(data, registry);
  factory CommonStateSignalTopUsers.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalTopUsers()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalTopUsers',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalTopUsers.$_createMessage)
    ..pPM<CommonStateSignalTopUsers_TopUser>(1, _omitFieldNames ? '' : 'topUser',
        protoName: 'topUser', subBuilder: CommonStateSignalTopUsers_TopUser.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalTopUsers clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalTopUsers copyWith(void Function(CommonStateSignalTopUsers) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalTopUsers)) as CommonStateSignalTopUsers;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalTopUsers() / CommonStateSignalTopUsers.new instead')
  static CommonStateSignalTopUsers create() => CommonStateSignalTopUsers._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalTopUsers._();
  @$core.override
  CommonStateSignalTopUsers createEmptyInstance() => CommonStateSignalTopUsers._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalTopUsers getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonStateSignalTopUsers>(CommonStateSignalTopUsers.$_createMessage);
  static CommonStateSignalTopUsers? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CommonStateSignalTopUsers_TopUser> get topUser => $_getList(0);
}

class CommonActionSignalUserEnterRoom extends $pb.GeneratedMessage {
  factory CommonActionSignalUserEnterRoom({
    ZtLiveUserInfo? userInfo,
    $fixnum.Int64? sendTimeMs,
  }) {
    final result = CommonActionSignalUserEnterRoom._();
    if (userInfo != null) result.userInfo = userInfo;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    return result;
  }

  CommonActionSignalUserEnterRoom._();

  factory CommonActionSignalUserEnterRoom.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalUserEnterRoom()..mergeFromBuffer(data, registry);
  factory CommonActionSignalUserEnterRoom.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalUserEnterRoom()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalUserEnterRoom',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalUserEnterRoom.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalUserEnterRoom clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalUserEnterRoom copyWith(void Function(CommonActionSignalUserEnterRoom) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalUserEnterRoom))
          as CommonActionSignalUserEnterRoom;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalUserEnterRoom() / CommonActionSignalUserEnterRoom.new instead')
  static CommonActionSignalUserEnterRoom create() => CommonActionSignalUserEnterRoom._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalUserEnterRoom._();
  @$core.override
  CommonActionSignalUserEnterRoom createEmptyInstance() => CommonActionSignalUserEnterRoom._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalUserEnterRoom getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonActionSignalUserEnterRoom>(
          CommonActionSignalUserEnterRoom.$_createMessage);
  static CommonActionSignalUserEnterRoom? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sendTimeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSendTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSendTimeMs() => $_clearField(2);
}

class CommonActionSignalUserFollowAuthor extends $pb.GeneratedMessage {
  factory CommonActionSignalUserFollowAuthor({
    ZtLiveUserInfo? userInfo,
    $fixnum.Int64? sendTimeMs,
  }) {
    final result = CommonActionSignalUserFollowAuthor._();
    if (userInfo != null) result.userInfo = userInfo;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    return result;
  }

  CommonActionSignalUserFollowAuthor._();

  factory CommonActionSignalUserFollowAuthor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalUserFollowAuthor()..mergeFromBuffer(data, registry);
  factory CommonActionSignalUserFollowAuthor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalUserFollowAuthor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalUserFollowAuthor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalUserFollowAuthor.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalUserFollowAuthor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalUserFollowAuthor copyWith(void Function(CommonActionSignalUserFollowAuthor) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalUserFollowAuthor))
          as CommonActionSignalUserFollowAuthor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalUserFollowAuthor() / CommonActionSignalUserFollowAuthor.new instead')
  static CommonActionSignalUserFollowAuthor create() => CommonActionSignalUserFollowAuthor._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalUserFollowAuthor._();
  @$core.override
  CommonActionSignalUserFollowAuthor createEmptyInstance() => CommonActionSignalUserFollowAuthor._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalUserFollowAuthor getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonActionSignalUserFollowAuthor>(
          CommonActionSignalUserFollowAuthor.$_createMessage);
  static CommonActionSignalUserFollowAuthor? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sendTimeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSendTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSendTimeMs() => $_clearField(2);
}

class CommonActionSignalRichText extends $pb.GeneratedMessage {
  factory CommonActionSignalRichText({
    UserInfoSegment? userInfo,
    PlainSegment? plain,
    ImageSegment? image,
  }) {
    final result = CommonActionSignalRichText._();
    if (userInfo != null) result.userInfo = userInfo;
    if (plain != null) result.plain = plain;
    if (image != null) result.image = image;
    return result;
  }

  CommonActionSignalRichText._();

  factory CommonActionSignalRichText.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalRichText()..mergeFromBuffer(data, registry);
  factory CommonActionSignalRichText.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonActionSignalRichText()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonActionSignalRichText',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonActionSignalRichText.$_createMessage)
    ..aOM<UserInfoSegment>(1, _omitFieldNames ? '' : 'userInfo',
        protoName: 'userInfo', subBuilder: UserInfoSegment.$_createMessage)
    ..aOM<PlainSegment>(2, _omitFieldNames ? '' : 'plain', subBuilder: PlainSegment.$_createMessage)
    ..aOM<ImageSegment>(3, _omitFieldNames ? '' : 'image', subBuilder: ImageSegment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalRichText clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonActionSignalRichText copyWith(void Function(CommonActionSignalRichText) updates) =>
      super.copyWith((message) => updates(message as CommonActionSignalRichText)) as CommonActionSignalRichText;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonActionSignalRichText() / CommonActionSignalRichText.new instead')
  static CommonActionSignalRichText create() => CommonActionSignalRichText._();
  static $pb.GeneratedMessage $_createMessage() => CommonActionSignalRichText._();
  @$core.override
  CommonActionSignalRichText createEmptyInstance() => CommonActionSignalRichText._();
  @$core.pragma('dart2js:noInline')
  static CommonActionSignalRichText getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonActionSignalRichText>(CommonActionSignalRichText.$_createMessage);
  static CommonActionSignalRichText? _defaultInstance;

  @$pb.TagNumber(1)
  UserInfoSegment get userInfo => $_getN(0);
  @$pb.TagNumber(1)
  set userInfo(UserInfoSegment value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  UserInfoSegment ensureUserInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  PlainSegment get plain => $_getN(1);
  @$pb.TagNumber(2)
  set plain(PlainSegment value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlain() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlain() => $_clearField(2);
  @$pb.TagNumber(2)
  PlainSegment ensurePlain() => $_ensure(1);

  @$pb.TagNumber(3)
  ImageSegment get image => $_getN(2);
  @$pb.TagNumber(3)
  set image(ImageSegment value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasImage() => $_has(2);
  @$pb.TagNumber(3)
  void clearImage() => $_clearField(3);
  @$pb.TagNumber(3)
  ImageSegment ensureImage() => $_ensure(2);
}

class UserInfoSegment extends $pb.GeneratedMessage {
  factory UserInfoSegment({
    ZtLiveUserInfo? user,
    $core.String? color,
  }) {
    final result = UserInfoSegment._();
    if (user != null) result.user = user;
    if (color != null) result.color = color;
    return result;
  }

  UserInfoSegment._();

  factory UserInfoSegment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInfoSegment()..mergeFromBuffer(data, registry);
  factory UserInfoSegment.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInfoSegment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UserInfoSegment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: UserInfoSegment.$_createMessage)
    ..aOM<ZtLiveUserInfo>(1, _omitFieldNames ? '' : 'user', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'color')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInfoSegment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInfoSegment copyWith(void Function(UserInfoSegment) updates) =>
      super.copyWith((message) => updates(message as UserInfoSegment)) as UserInfoSegment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserInfoSegment() / UserInfoSegment.new instead')
  static UserInfoSegment create() => UserInfoSegment._();
  static $pb.GeneratedMessage $_createMessage() => UserInfoSegment._();
  @$core.override
  UserInfoSegment createEmptyInstance() => UserInfoSegment._();
  @$core.pragma('dart2js:noInline')
  static UserInfoSegment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserInfoSegment>(UserInfoSegment.$_createMessage);
  static UserInfoSegment? _defaultInstance;

  @$pb.TagNumber(1)
  ZtLiveUserInfo get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(ZtLiveUserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  ZtLiveUserInfo ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get color => $_getSZ(1);
  @$pb.TagNumber(2)
  set color($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);
}

class PlainSegment extends $pb.GeneratedMessage {
  factory PlainSegment({
    $core.String? text,
    $core.String? color,
  }) {
    final result = PlainSegment._();
    if (text != null) result.text = text;
    if (color != null) result.color = color;
    return result;
  }

  PlainSegment._();

  factory PlainSegment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlainSegment()..mergeFromBuffer(data, registry);
  factory PlainSegment.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlainSegment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PlainSegment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: PlainSegment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'color')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlainSegment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlainSegment copyWith(void Function(PlainSegment) updates) =>
      super.copyWith((message) => updates(message as PlainSegment)) as PlainSegment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlainSegment() / PlainSegment.new instead')
  static PlainSegment create() => PlainSegment._();
  static $pb.GeneratedMessage $_createMessage() => PlainSegment._();
  @$core.override
  PlainSegment createEmptyInstance() => PlainSegment._();
  @$core.pragma('dart2js:noInline')
  static PlainSegment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlainSegment>(PlainSegment.$_createMessage);
  static PlainSegment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get color => $_getSZ(1);
  @$pb.TagNumber(2)
  set color($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearColor() => $_clearField(2);
}

class ImageSegment extends $pb.GeneratedMessage {
  factory ImageSegment({
    ImageCdnNode? cdnNode,
    $core.String? alternativeText,
    $core.String? alternativeColor,
  }) {
    final result = ImageSegment._();
    if (cdnNode != null) result.cdnNode = cdnNode;
    if (alternativeText != null) result.alternativeText = alternativeText;
    if (alternativeColor != null) result.alternativeColor = alternativeColor;
    return result;
  }

  ImageSegment._();

  factory ImageSegment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageSegment()..mergeFromBuffer(data, registry);
  factory ImageSegment.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageSegment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ImageSegment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ImageSegment.$_createMessage)
    ..aOM<ImageCdnNode>(1, _omitFieldNames ? '' : 'cdnNode',
        protoName: 'cdnNode', subBuilder: ImageCdnNode.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'alternativeText', protoName: 'alternativeText')
    ..aOS(3, _omitFieldNames ? '' : 'alternativeColor', protoName: 'alternativeColor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageSegment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageSegment copyWith(void Function(ImageSegment) updates) =>
      super.copyWith((message) => updates(message as ImageSegment)) as ImageSegment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageSegment() / ImageSegment.new instead')
  static ImageSegment create() => ImageSegment._();
  static $pb.GeneratedMessage $_createMessage() => ImageSegment._();
  @$core.override
  ImageSegment createEmptyInstance() => ImageSegment._();
  @$core.pragma('dart2js:noInline')
  static ImageSegment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageSegment>(ImageSegment.$_createMessage);
  static ImageSegment? _defaultInstance;

  @$pb.TagNumber(1)
  ImageCdnNode get cdnNode => $_getN(0);
  @$pb.TagNumber(1)
  set cdnNode(ImageCdnNode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCdnNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCdnNode() => $_clearField(1);
  @$pb.TagNumber(1)
  ImageCdnNode ensureCdnNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get alternativeText => $_getSZ(1);
  @$pb.TagNumber(2)
  set alternativeText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlternativeText() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlternativeText() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get alternativeColor => $_getSZ(2);
  @$pb.TagNumber(3)
  set alternativeColor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAlternativeColor() => $_has(2);
  @$pb.TagNumber(3)
  void clearAlternativeColor() => $_clearField(3);
}

class CommonNotifySignalKickedOut extends $pb.GeneratedMessage {
  factory CommonNotifySignalKickedOut({
    $core.String? reason,
  }) {
    final result = CommonNotifySignalKickedOut._();
    if (reason != null) result.reason = reason;
    return result;
  }

  CommonNotifySignalKickedOut._();

  factory CommonNotifySignalKickedOut.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonNotifySignalKickedOut()..mergeFromBuffer(data, registry);
  factory CommonNotifySignalKickedOut.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonNotifySignalKickedOut()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonNotifySignalKickedOut',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonNotifySignalKickedOut.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonNotifySignalKickedOut clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonNotifySignalKickedOut copyWith(void Function(CommonNotifySignalKickedOut) updates) =>
      super.copyWith((message) => updates(message as CommonNotifySignalKickedOut)) as CommonNotifySignalKickedOut;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonNotifySignalKickedOut() / CommonNotifySignalKickedOut.new instead')
  static CommonNotifySignalKickedOut create() => CommonNotifySignalKickedOut._();
  static $pb.GeneratedMessage $_createMessage() => CommonNotifySignalKickedOut._();
  @$core.override
  CommonNotifySignalKickedOut createEmptyInstance() => CommonNotifySignalKickedOut._();
  @$core.pragma('dart2js:noInline')
  static CommonNotifySignalKickedOut getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonNotifySignalKickedOut>(CommonNotifySignalKickedOut.$_createMessage);
  static CommonNotifySignalKickedOut? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

class CommonNotifySignalViolationAlert extends $pb.GeneratedMessage {
  factory CommonNotifySignalViolationAlert({
    $core.String? violationContent,
  }) {
    final result = CommonNotifySignalViolationAlert._();
    if (violationContent != null) result.violationContent = violationContent;
    return result;
  }

  CommonNotifySignalViolationAlert._();

  factory CommonNotifySignalViolationAlert.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonNotifySignalViolationAlert()..mergeFromBuffer(data, registry);
  factory CommonNotifySignalViolationAlert.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonNotifySignalViolationAlert()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonNotifySignalViolationAlert',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonNotifySignalViolationAlert.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'violationContent', protoName: 'violationContent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonNotifySignalViolationAlert clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonNotifySignalViolationAlert copyWith(void Function(CommonNotifySignalViolationAlert) updates) =>
      super.copyWith((message) => updates(message as CommonNotifySignalViolationAlert))
          as CommonNotifySignalViolationAlert;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonNotifySignalViolationAlert() / CommonNotifySignalViolationAlert.new instead')
  static CommonNotifySignalViolationAlert create() => CommonNotifySignalViolationAlert._();
  static $pb.GeneratedMessage $_createMessage() => CommonNotifySignalViolationAlert._();
  @$core.override
  CommonNotifySignalViolationAlert createEmptyInstance() => CommonNotifySignalViolationAlert._();
  @$core.pragma('dart2js:noInline')
  static CommonNotifySignalViolationAlert getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonNotifySignalViolationAlert>(
          CommonNotifySignalViolationAlert.$_createMessage);
  static CommonNotifySignalViolationAlert? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get violationContent => $_getSZ(0);
  @$pb.TagNumber(1)
  set violationContent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasViolationContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearViolationContent() => $_clearField(1);
}

class CommonStateSignalCurrentRedpackList extends $pb.GeneratedMessage {
  factory CommonStateSignalCurrentRedpackList() => CommonStateSignalCurrentRedpackList._();

  CommonStateSignalCurrentRedpackList._();

  factory CommonStateSignalCurrentRedpackList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalCurrentRedpackList()..mergeFromBuffer(data, registry);
  factory CommonStateSignalCurrentRedpackList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalCurrentRedpackList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalCurrentRedpackList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalCurrentRedpackList.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalCurrentRedpackList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalCurrentRedpackList copyWith(void Function(CommonStateSignalCurrentRedpackList) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalCurrentRedpackList))
          as CommonStateSignalCurrentRedpackList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalCurrentRedpackList() / CommonStateSignalCurrentRedpackList.new instead')
  static CommonStateSignalCurrentRedpackList create() => CommonStateSignalCurrentRedpackList._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalCurrentRedpackList._();
  @$core.override
  CommonStateSignalCurrentRedpackList createEmptyInstance() => CommonStateSignalCurrentRedpackList._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalCurrentRedpackList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommonStateSignalCurrentRedpackList>(
          CommonStateSignalCurrentRedpackList.$_createMessage);
  static CommonStateSignalCurrentRedpackList? _defaultInstance;
}

class CommonStateSignalRecentComment extends $pb.GeneratedMessage {
  factory CommonStateSignalRecentComment({
    CommonActionSignalComment? comment,
  }) {
    final result = CommonStateSignalRecentComment._();
    if (comment != null) result.comment = comment;
    return result;
  }

  CommonStateSignalRecentComment._();

  factory CommonStateSignalRecentComment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalRecentComment()..mergeFromBuffer(data, registry);
  factory CommonStateSignalRecentComment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalRecentComment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalRecentComment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalRecentComment.$_createMessage)
    ..aOM<CommonActionSignalComment>(1, _omitFieldNames ? '' : 'comment',
        subBuilder: CommonActionSignalComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalRecentComment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalRecentComment copyWith(void Function(CommonStateSignalRecentComment) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalRecentComment)) as CommonStateSignalRecentComment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalRecentComment() / CommonStateSignalRecentComment.new instead')
  static CommonStateSignalRecentComment create() => CommonStateSignalRecentComment._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalRecentComment._();
  @$core.override
  CommonStateSignalRecentComment createEmptyInstance() => CommonStateSignalRecentComment._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalRecentComment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonStateSignalRecentComment>(CommonStateSignalRecentComment.$_createMessage);
  static CommonStateSignalRecentComment? _defaultInstance;

  @$pb.TagNumber(1)
  CommonActionSignalComment get comment => $_getN(0);
  @$pb.TagNumber(1)
  set comment(CommonActionSignalComment value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComment() => $_has(0);
  @$pb.TagNumber(1)
  void clearComment() => $_clearField(1);
  @$pb.TagNumber(1)
  CommonActionSignalComment ensureComment() => $_ensure(0);
}

class CommonStateSignalChatReady extends $pb.GeneratedMessage {
  factory CommonStateSignalChatReady({
    $core.String? chatId,
    ZtLiveUserInfo? guestUserInfo,
    $core.int? mediaType,
  }) {
    final result = CommonStateSignalChatReady._();
    if (chatId != null) result.chatId = chatId;
    if (guestUserInfo != null) result.guestUserInfo = guestUserInfo;
    if (mediaType != null) result.mediaType = mediaType;
    return result;
  }

  CommonStateSignalChatReady._();

  factory CommonStateSignalChatReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalChatReady()..mergeFromBuffer(data, registry);
  factory CommonStateSignalChatReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalChatReady()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalChatReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalChatReady.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId', protoName: 'chatId')
    ..aOM<ZtLiveUserInfo>(2, _omitFieldNames ? '' : 'guestUserInfo',
        protoName: 'guestUserInfo', subBuilder: ZtLiveUserInfo.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'mediaType', protoName: 'mediaType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalChatReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalChatReady copyWith(void Function(CommonStateSignalChatReady) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalChatReady)) as CommonStateSignalChatReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalChatReady() / CommonStateSignalChatReady.new instead')
  static CommonStateSignalChatReady create() => CommonStateSignalChatReady._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalChatReady._();
  @$core.override
  CommonStateSignalChatReady createEmptyInstance() => CommonStateSignalChatReady._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalChatReady getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonStateSignalChatReady>(CommonStateSignalChatReady.$_createMessage);
  static CommonStateSignalChatReady? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  ZtLiveUserInfo get guestUserInfo => $_getN(1);
  @$pb.TagNumber(2)
  set guestUserInfo(ZtLiveUserInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasGuestUserInfo() => $_has(1);
  @$pb.TagNumber(2)
  void clearGuestUserInfo() => $_clearField(2);
  @$pb.TagNumber(2)
  ZtLiveUserInfo ensureGuestUserInfo() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get mediaType => $_getIZ(2);
  @$pb.TagNumber(3)
  set mediaType($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaType() => $_clearField(3);
}

class CommonStateSignalChatEnd extends $pb.GeneratedMessage {
  factory CommonStateSignalChatEnd({
    $core.String? chatId,
    $core.int? endType,
  }) {
    final result = CommonStateSignalChatEnd._();
    if (chatId != null) result.chatId = chatId;
    if (endType != null) result.endType = endType;
    return result;
  }

  CommonStateSignalChatEnd._();

  factory CommonStateSignalChatEnd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalChatEnd()..mergeFromBuffer(data, registry);
  factory CommonStateSignalChatEnd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommonStateSignalChatEnd()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CommonStateSignalChatEnd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: CommonStateSignalChatEnd.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId', protoName: 'chatId')
    ..aI(2, _omitFieldNames ? '' : 'endType', protoName: 'endType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalChatEnd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonStateSignalChatEnd copyWith(void Function(CommonStateSignalChatEnd) updates) =>
      super.copyWith((message) => updates(message as CommonStateSignalChatEnd)) as CommonStateSignalChatEnd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommonStateSignalChatEnd() / CommonStateSignalChatEnd.new instead')
  static CommonStateSignalChatEnd create() => CommonStateSignalChatEnd._();
  static $pb.GeneratedMessage $_createMessage() => CommonStateSignalChatEnd._();
  @$core.override
  CommonStateSignalChatEnd createEmptyInstance() => CommonStateSignalChatEnd._();
  @$core.pragma('dart2js:noInline')
  static CommonStateSignalChatEnd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonStateSignalChatEnd>(CommonStateSignalChatEnd.$_createMessage);
  static CommonStateSignalChatEnd? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get endType => $_getIZ(1);
  @$pb.TagNumber(2)
  set endType($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndType() => $_clearField(2);
}

class AcfunActionSignalThrowBanana extends $pb.GeneratedMessage {
  factory AcfunActionSignalThrowBanana({
    UserInfo? visitor,
    $core.int? count,
    $fixnum.Int64? sendTimeMs,
  }) {
    final result = AcfunActionSignalThrowBanana._();
    if (visitor != null) result.visitor = visitor;
    if (count != null) result.count = count;
    if (sendTimeMs != null) result.sendTimeMs = sendTimeMs;
    return result;
  }

  AcfunActionSignalThrowBanana._();

  factory AcfunActionSignalThrowBanana.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunActionSignalThrowBanana()..mergeFromBuffer(data, registry);
  factory AcfunActionSignalThrowBanana.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunActionSignalThrowBanana()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AcfunActionSignalThrowBanana',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AcfunActionSignalThrowBanana.$_createMessage)
    ..aOM<UserInfo>(1, _omitFieldNames ? '' : 'visitor', subBuilder: UserInfo.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'count')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'sendTimeMs', $pb.PbFieldType.OU6,
        protoName: 'sendTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunActionSignalThrowBanana clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunActionSignalThrowBanana copyWith(void Function(AcfunActionSignalThrowBanana) updates) =>
      super.copyWith((message) => updates(message as AcfunActionSignalThrowBanana)) as AcfunActionSignalThrowBanana;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AcfunActionSignalThrowBanana() / AcfunActionSignalThrowBanana.new instead')
  static AcfunActionSignalThrowBanana create() => AcfunActionSignalThrowBanana._();
  static $pb.GeneratedMessage $_createMessage() => AcfunActionSignalThrowBanana._();
  @$core.override
  AcfunActionSignalThrowBanana createEmptyInstance() => AcfunActionSignalThrowBanana._();
  @$core.pragma('dart2js:noInline')
  static AcfunActionSignalThrowBanana getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcfunActionSignalThrowBanana>(AcfunActionSignalThrowBanana.$_createMessage);
  static AcfunActionSignalThrowBanana? _defaultInstance;

  @$pb.TagNumber(1)
  UserInfo get visitor => $_getN(0);
  @$pb.TagNumber(1)
  set visitor(UserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVisitor() => $_has(0);
  @$pb.TagNumber(1)
  void clearVisitor() => $_clearField(1);
  @$pb.TagNumber(1)
  UserInfo ensureVisitor() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sendTimeMs => $_getI64(2);
  @$pb.TagNumber(3)
  set sendTimeMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSendTimeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearSendTimeMs() => $_clearField(3);
}

class AcfunStateSignalDisplayInfo extends $pb.GeneratedMessage {
  factory AcfunStateSignalDisplayInfo({
    $core.String? bananaCount,
  }) {
    final result = AcfunStateSignalDisplayInfo._();
    if (bananaCount != null) result.bananaCount = bananaCount;
    return result;
  }

  AcfunStateSignalDisplayInfo._();

  factory AcfunStateSignalDisplayInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunStateSignalDisplayInfo()..mergeFromBuffer(data, registry);
  factory AcfunStateSignalDisplayInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunStateSignalDisplayInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AcfunStateSignalDisplayInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AcfunStateSignalDisplayInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'bananaCount', protoName: 'bananaCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunStateSignalDisplayInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunStateSignalDisplayInfo copyWith(void Function(AcfunStateSignalDisplayInfo) updates) =>
      super.copyWith((message) => updates(message as AcfunStateSignalDisplayInfo)) as AcfunStateSignalDisplayInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AcfunStateSignalDisplayInfo() / AcfunStateSignalDisplayInfo.new instead')
  static AcfunStateSignalDisplayInfo create() => AcfunStateSignalDisplayInfo._();
  static $pb.GeneratedMessage $_createMessage() => AcfunStateSignalDisplayInfo._();
  @$core.override
  AcfunStateSignalDisplayInfo createEmptyInstance() => AcfunStateSignalDisplayInfo._();
  @$core.pragma('dart2js:noInline')
  static AcfunStateSignalDisplayInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcfunStateSignalDisplayInfo>(AcfunStateSignalDisplayInfo.$_createMessage);
  static AcfunStateSignalDisplayInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get bananaCount => $_getSZ(0);
  @$pb.TagNumber(1)
  set bananaCount($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBananaCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearBananaCount() => $_clearField(1);
}

class AcfunActionSignalJoinClub extends $pb.GeneratedMessage {
  factory AcfunActionSignalJoinClub({
    UserInfo? fansInfo,
    UserInfo? uperInfo,
    $fixnum.Int64? joinTimeMs,
  }) {
    final result = AcfunActionSignalJoinClub._();
    if (fansInfo != null) result.fansInfo = fansInfo;
    if (uperInfo != null) result.uperInfo = uperInfo;
    if (joinTimeMs != null) result.joinTimeMs = joinTimeMs;
    return result;
  }

  AcfunActionSignalJoinClub._();

  factory AcfunActionSignalJoinClub.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunActionSignalJoinClub()..mergeFromBuffer(data, registry);
  factory AcfunActionSignalJoinClub.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AcfunActionSignalJoinClub()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AcfunActionSignalJoinClub',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: AcfunActionSignalJoinClub.$_createMessage)
    ..aOM<UserInfo>(1, _omitFieldNames ? '' : 'fansInfo', protoName: 'fansInfo', subBuilder: UserInfo.$_createMessage)
    ..aOM<UserInfo>(2, _omitFieldNames ? '' : 'uperInfo', protoName: 'uperInfo', subBuilder: UserInfo.$_createMessage)
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'joinTimeMs', $pb.PbFieldType.OU6,
        protoName: 'joinTimeMs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunActionSignalJoinClub clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcfunActionSignalJoinClub copyWith(void Function(AcfunActionSignalJoinClub) updates) =>
      super.copyWith((message) => updates(message as AcfunActionSignalJoinClub)) as AcfunActionSignalJoinClub;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AcfunActionSignalJoinClub() / AcfunActionSignalJoinClub.new instead')
  static AcfunActionSignalJoinClub create() => AcfunActionSignalJoinClub._();
  static $pb.GeneratedMessage $_createMessage() => AcfunActionSignalJoinClub._();
  @$core.override
  AcfunActionSignalJoinClub createEmptyInstance() => AcfunActionSignalJoinClub._();
  @$core.pragma('dart2js:noInline')
  static AcfunActionSignalJoinClub getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcfunActionSignalJoinClub>(AcfunActionSignalJoinClub.$_createMessage);
  static AcfunActionSignalJoinClub? _defaultInstance;

  @$pb.TagNumber(1)
  UserInfo get fansInfo => $_getN(0);
  @$pb.TagNumber(1)
  set fansInfo(UserInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFansInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearFansInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  UserInfo ensureFansInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  UserInfo get uperInfo => $_getN(1);
  @$pb.TagNumber(2)
  set uperInfo(UserInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUperInfo() => $_has(1);
  @$pb.TagNumber(2)
  void clearUperInfo() => $_clearField(2);
  @$pb.TagNumber(2)
  UserInfo ensureUperInfo() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get joinTimeMs => $_getI64(2);
  @$pb.TagNumber(3)
  set joinTimeMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasJoinTimeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearJoinTimeMs() => $_clearField(3);
}

class ZtLiveUserInfo extends $pb.GeneratedMessage {
  factory ZtLiveUserInfo({
    $fixnum.Int64? userId,
    $core.String? nickname,
    ImageCdnNode? avatar,
  }) {
    final result = ZtLiveUserInfo._();
    if (userId != null) result.userId = userId;
    if (nickname != null) result.nickname = nickname;
    if (avatar != null) result.avatar = avatar;
    return result;
  }

  ZtLiveUserInfo._();

  factory ZtLiveUserInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveUserInfo()..mergeFromBuffer(data, registry);
  factory ZtLiveUserInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ZtLiveUserInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ZtLiveUserInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ZtLiveUserInfo.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OU6,
        protoName: 'userId', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOM<ImageCdnNode>(3, _omitFieldNames ? '' : 'avatar', subBuilder: ImageCdnNode.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveUserInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ZtLiveUserInfo copyWith(void Function(ZtLiveUserInfo) updates) =>
      super.copyWith((message) => updates(message as ZtLiveUserInfo)) as ZtLiveUserInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ZtLiveUserInfo() / ZtLiveUserInfo.new instead')
  static ZtLiveUserInfo create() => ZtLiveUserInfo._();
  static $pb.GeneratedMessage $_createMessage() => ZtLiveUserInfo._();
  @$core.override
  ZtLiveUserInfo createEmptyInstance() => ZtLiveUserInfo._();
  @$core.pragma('dart2js:noInline')
  static ZtLiveUserInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ZtLiveUserInfo>(ZtLiveUserInfo.$_createMessage);
  static ZtLiveUserInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get userId => $_getI64(0);
  @$pb.TagNumber(1)
  set userId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => $_clearField(2);

  @$pb.TagNumber(3)
  ImageCdnNode get avatar => $_getN(2);
  @$pb.TagNumber(3)
  set avatar(ImageCdnNode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatar() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatar() => $_clearField(3);
  @$pb.TagNumber(3)
  ImageCdnNode ensureAvatar() => $_ensure(2);
}

class ImageCdnNode extends $pb.GeneratedMessage {
  factory ImageCdnNode({
    $core.String? cdn,
    $core.String? url,
    $core.String? urlPattern,
  }) {
    final result = ImageCdnNode._();
    if (cdn != null) result.cdn = cdn;
    if (url != null) result.url = url;
    if (urlPattern != null) result.urlPattern = urlPattern;
    return result;
  }

  ImageCdnNode._();

  factory ImageCdnNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageCdnNode()..mergeFromBuffer(data, registry);
  factory ImageCdnNode.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageCdnNode()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ImageCdnNode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: ImageCdnNode.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'cdn')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'urlPattern', protoName: 'urlPattern')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageCdnNode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageCdnNode copyWith(void Function(ImageCdnNode) updates) =>
      super.copyWith((message) => updates(message as ImageCdnNode)) as ImageCdnNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageCdnNode() / ImageCdnNode.new instead')
  static ImageCdnNode create() => ImageCdnNode._();
  static $pb.GeneratedMessage $_createMessage() => ImageCdnNode._();
  @$core.override
  ImageCdnNode createEmptyInstance() => ImageCdnNode._();
  @$core.pragma('dart2js:noInline')
  static ImageCdnNode getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageCdnNode>(ImageCdnNode.$_createMessage);
  static ImageCdnNode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cdn => $_getSZ(0);
  @$pb.TagNumber(1)
  set cdn($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCdn() => $_has(0);
  @$pb.TagNumber(1)
  void clearCdn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get urlPattern => $_getSZ(2);
  @$pb.TagNumber(3)
  set urlPattern($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrlPattern() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrlPattern() => $_clearField(3);
}

class UserInfo extends $pb.GeneratedMessage {
  factory UserInfo({
    $fixnum.Int64? userId,
    $core.String? name,
  }) {
    final result = UserInfo._();
    if (userId != null) result.userId = userId;
    if (name != null) result.name = name;
    return result;
  }

  UserInfo._();

  factory UserInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInfo()..mergeFromBuffer(data, registry);
  factory UserInfo.fromJson($core.String json, [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UserInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'AcFunPack'),
      createEmptyInstance: UserInfo.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'userId', $pb.PbFieldType.OU6,
        protoName: 'userId', defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserInfo copyWith(void Function(UserInfo) updates) =>
      super.copyWith((message) => updates(message as UserInfo)) as UserInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserInfo() / UserInfo.new instead')
  static UserInfo create() => UserInfo._();
  static $pb.GeneratedMessage $_createMessage() => UserInfo._();
  @$core.override
  UserInfo createEmptyInstance() => UserInfo._();
  @$core.pragma('dart2js:noInline')
  static UserInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserInfo>(UserInfo.$_createMessage);
  static UserInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get userId => $_getI64(0);
  @$pb.TagNumber(1)
  set userId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
