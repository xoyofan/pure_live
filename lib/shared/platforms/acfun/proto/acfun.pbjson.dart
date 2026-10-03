// This is a generated file - do not edit.
//
// Generated from acfun.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use registerRequestDescriptor instead')
const RegisterRequest$json = {
  '1': 'RegisterRequest',
  '2': [
    {'1': 'appInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.AppInfo', '10': 'appInfo'},
    {'1': 'deviceInfo', '3': 2, '4': 1, '5': 11, '6': '.AcFunPack.DeviceInfo', '10': 'deviceInfo'},
    {'1': 'envInfo', '3': 3, '4': 1, '5': 11, '6': '.AcFunPack.EnvInfo', '10': 'envInfo'},
    {
      '1': 'presenceStatus',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.AcFunPack.RegisterRequest.PresenceStatus',
      '10': 'presenceStatus'
    },
    {
      '1': 'appActiveStatus',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.AcFunPack.RegisterRequest.ActiveStatus',
      '10': 'appActiveStatus'
    },
    {'1': 'appCustomStatus', '3': 6, '4': 1, '5': 12, '10': 'appCustomStatus'},
    {'1': 'pushServiceToken', '3': 7, '4': 1, '5': 11, '6': '.AcFunPack.PushServiceToken', '10': 'pushServiceToken'},
    {'1': 'instanceId', '3': 8, '4': 1, '5': 3, '10': 'instanceId'},
    {
      '1': 'pushServiceTokenList',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.AcFunPack.PushServiceToken',
      '10': 'pushServiceTokenList'
    },
    {'1': 'keepaliveIntervalSec', '3': 10, '4': 1, '5': 5, '10': 'keepaliveIntervalSec'},
    {'1': 'ztCommonInfo', '3': 11, '4': 1, '5': 11, '6': '.AcFunPack.ZtCommonInfo', '10': 'ztCommonInfo'},
  ],
  '4': [RegisterRequest_PresenceStatus$json, RegisterRequest_ActiveStatus$json],
};

@$core.Deprecated('Use registerRequestDescriptor instead')
const RegisterRequest_PresenceStatus$json = {
  '1': 'PresenceStatus',
  '2': [
    {'1': 'kPresenceOffline', '2': 0},
    {'1': 'kPresenceOnline', '2': 1},
  ],
};

@$core.Deprecated('Use registerRequestDescriptor instead')
const RegisterRequest_ActiveStatus$json = {
  '1': 'ActiveStatus',
  '2': [
    {'1': 'kInvalid', '2': 0},
    {'1': 'kAppInForeground', '2': 1},
    {'1': 'kAppInBackground', '2': 2},
  ],
};

/// Descriptor for `RegisterRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerRequestDescriptor =
    $convert.base64Decode('Cg9SZWdpc3RlclJlcXVlc3QSLAoHYXBwSW5mbxgBIAEoCzISLkFjRnVuUGFjay5BcHBJbmZvUg'
        'dhcHBJbmZvEjUKCmRldmljZUluZm8YAiABKAsyFS5BY0Z1blBhY2suRGV2aWNlSW5mb1IKZGV2'
        'aWNlSW5mbxIsCgdlbnZJbmZvGAMgASgLMhIuQWNGdW5QYWNrLkVudkluZm9SB2VudkluZm8SUQ'
        'oOcHJlc2VuY2VTdGF0dXMYBCABKA4yKS5BY0Z1blBhY2suUmVnaXN0ZXJSZXF1ZXN0LlByZXNl'
        'bmNlU3RhdHVzUg5wcmVzZW5jZVN0YXR1cxJRCg9hcHBBY3RpdmVTdGF0dXMYBSABKA4yJy5BY0'
        'Z1blBhY2suUmVnaXN0ZXJSZXF1ZXN0LkFjdGl2ZVN0YXR1c1IPYXBwQWN0aXZlU3RhdHVzEigK'
        'D2FwcEN1c3RvbVN0YXR1cxgGIAEoDFIPYXBwQ3VzdG9tU3RhdHVzEkcKEHB1c2hTZXJ2aWNlVG'
        '9rZW4YByABKAsyGy5BY0Z1blBhY2suUHVzaFNlcnZpY2VUb2tlblIQcHVzaFNlcnZpY2VUb2tl'
        'bhIeCgppbnN0YW5jZUlkGAggASgDUgppbnN0YW5jZUlkEk8KFHB1c2hTZXJ2aWNlVG9rZW5MaX'
        'N0GAkgAygLMhsuQWNGdW5QYWNrLlB1c2hTZXJ2aWNlVG9rZW5SFHB1c2hTZXJ2aWNlVG9rZW5M'
        'aXN0EjIKFGtlZXBhbGl2ZUludGVydmFsU2VjGAogASgFUhRrZWVwYWxpdmVJbnRlcnZhbFNlYx'
        'I7Cgx6dENvbW1vbkluZm8YCyABKAsyFy5BY0Z1blBhY2suWnRDb21tb25JbmZvUgx6dENvbW1v'
        'bkluZm8iOwoOUHJlc2VuY2VTdGF0dXMSFAoQa1ByZXNlbmNlT2ZmbGluZRAAEhMKD2tQcmVzZW'
        '5jZU9ubGluZRABIkgKDEFjdGl2ZVN0YXR1cxIMCghrSW52YWxpZBAAEhQKEGtBcHBJbkZvcmVn'
        'cm91bmQQARIUChBrQXBwSW5CYWNrZ3JvdW5kEAI=');

@$core.Deprecated('Use registerResponseDescriptor instead')
const RegisterResponse$json = {
  '1': 'RegisterResponse',
  '2': [
    {
      '1': 'accessPointsConfig',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.AcFunPack.AccessPointsConfig',
      '10': 'accessPointsConfig'
    },
    {'1': 'sessKey', '3': 2, '4': 1, '5': 12, '10': 'sessKey'},
    {'1': 'instanceId', '3': 3, '4': 1, '5': 3, '10': 'instanceId'},
    {'1': 'sdkOption', '3': 4, '4': 1, '5': 11, '6': '.AcFunPack.SdkOption', '10': 'sdkOption'},
    {
      '1': 'accessPointsConfigIpv6',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.AcFunPack.AccessPointsConfig',
      '10': 'accessPointsConfigIpv6'
    },
  ],
};

/// Descriptor for `RegisterResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerResponseDescriptor =
    $convert.base64Decode('ChBSZWdpc3RlclJlc3BvbnNlEk0KEmFjY2Vzc1BvaW50c0NvbmZpZxgBIAEoCzIdLkFjRnVuUG'
        'Fjay5BY2Nlc3NQb2ludHNDb25maWdSEmFjY2Vzc1BvaW50c0NvbmZpZxIYCgdzZXNzS2V5GAIg'
        'ASgMUgdzZXNzS2V5Eh4KCmluc3RhbmNlSWQYAyABKANSCmluc3RhbmNlSWQSMgoJc2RrT3B0aW'
        '9uGAQgASgLMhQuQWNGdW5QYWNrLlNka09wdGlvblIJc2RrT3B0aW9uElUKFmFjY2Vzc1BvaW50'
        'c0NvbmZpZ0lwdjYYBSABKAsyHS5BY0Z1blBhY2suQWNjZXNzUG9pbnRzQ29uZmlnUhZhY2Nlc3'
        'NQb2ludHNDb25maWdJcHY2');

@$core.Deprecated('Use accessPointsConfigDescriptor instead')
const AccessPointsConfig$json = {
  '1': 'AccessPointsConfig',
  '2': [
    {'1': 'optimalAps', '3': 1, '4': 3, '5': 11, '6': '.AcFunPack.AccessPoint', '10': 'optimalAps'},
    {'1': 'backupAps', '3': 2, '4': 3, '5': 11, '6': '.AcFunPack.AccessPoint', '10': 'backupAps'},
    {'1': 'availablePorts', '3': 3, '4': 3, '5': 13, '10': 'availablePorts'},
    {'1': 'forceLastConnectedAp', '3': 4, '4': 1, '5': 11, '6': '.AcFunPack.AccessPoint', '10': 'forceLastConnectedAp'},
  ],
};

/// Descriptor for `AccessPointsConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessPointsConfigDescriptor =
    $convert.base64Decode('ChJBY2Nlc3NQb2ludHNDb25maWcSNgoKb3B0aW1hbEFwcxgBIAMoCzIWLkFjRnVuUGFjay5BY2'
        'Nlc3NQb2ludFIKb3B0aW1hbEFwcxI0CgliYWNrdXBBcHMYAiADKAsyFi5BY0Z1blBhY2suQWNj'
        'ZXNzUG9pbnRSCWJhY2t1cEFwcxImCg5hdmFpbGFibGVQb3J0cxgDIAMoDVIOYXZhaWxhYmxlUG'
        '9ydHMSSgoUZm9yY2VMYXN0Q29ubmVjdGVkQXAYBCABKAsyFi5BY0Z1blBhY2suQWNjZXNzUG9p'
        'bnRSFGZvcmNlTGFzdENvbm5lY3RlZEFw');

@$core.Deprecated('Use accessPointDescriptor instead')
const AccessPoint$json = {
  '1': 'AccessPoint',
  '2': [
    {'1': 'addressType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.AccessPoint.AddressType', '10': 'addressType'},
    {'1': 'port', '3': 2, '4': 1, '5': 13, '10': 'port'},
    {'1': 'ipV4', '3': 3, '4': 1, '5': 7, '10': 'ipV4'},
    {'1': 'ipV6', '3': 4, '4': 1, '5': 12, '10': 'ipV6'},
    {'1': 'domain', '3': 5, '4': 1, '5': 9, '10': 'domain'},
  ],
  '4': [AccessPoint_AddressType$json],
};

@$core.Deprecated('Use accessPointDescriptor instead')
const AccessPoint_AddressType$json = {
  '1': 'AddressType',
  '2': [
    {'1': 'kIPV4', '2': 0},
    {'1': 'kIPV6', '2': 1},
    {'1': 'kDomain', '2': 2},
  ],
};

/// Descriptor for `AccessPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessPointDescriptor =
    $convert.base64Decode('CgtBY2Nlc3NQb2ludBJECgthZGRyZXNzVHlwZRgBIAEoDjIiLkFjRnVuUGFjay5BY2Nlc3NQb2'
        'ludC5BZGRyZXNzVHlwZVILYWRkcmVzc1R5cGUSEgoEcG9ydBgCIAEoDVIEcG9ydBISCgRpcFY0'
        'GAMgASgHUgRpcFY0EhIKBGlwVjYYBCABKAxSBGlwVjYSFgoGZG9tYWluGAUgASgJUgZkb21haW'
        '4iMAoLQWRkcmVzc1R5cGUSCQoFa0lQVjQQABIJCgVrSVBWNhABEgsKB2tEb21haW4QAg==');

@$core.Deprecated('Use sdkOptionDescriptor instead')
const SdkOption$json = {
  '1': 'SdkOption',
  '2': [
    {'1': 'reportIntervalSeconds', '3': 1, '4': 1, '5': 5, '10': 'reportIntervalSeconds'},
    {'1': 'reportSecurity', '3': 2, '4': 1, '5': 9, '10': 'reportSecurity'},
    {'1': 'lz4CompressionThresholdBytes', '3': 3, '4': 1, '5': 5, '10': 'lz4CompressionThresholdBytes'},
    {'1': 'netCheckServers', '3': 4, '4': 3, '5': 9, '10': 'netCheckServers'},
  ],
};

/// Descriptor for `SdkOption`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sdkOptionDescriptor =
    $convert.base64Decode('CglTZGtPcHRpb24SNAoVcmVwb3J0SW50ZXJ2YWxTZWNvbmRzGAEgASgFUhVyZXBvcnRJbnRlcn'
        'ZhbFNlY29uZHMSJgoOcmVwb3J0U2VjdXJpdHkYAiABKAlSDnJlcG9ydFNlY3VyaXR5EkIKHGx6'
        'NENvbXByZXNzaW9uVGhyZXNob2xkQnl0ZXMYAyABKAVSHGx6NENvbXByZXNzaW9uVGhyZXNob2'
        'xkQnl0ZXMSKAoPbmV0Q2hlY2tTZXJ2ZXJzGAQgAygJUg9uZXRDaGVja1NlcnZlcnM=');

@$core.Deprecated('Use ztLiveCsEnterRoomDescriptor instead')
const ZtLiveCsEnterRoom$json = {
  '1': 'ZtLiveCsEnterRoom',
  '2': [
    {'1': 'isAuthor', '3': 1, '4': 1, '5': 8, '10': 'isAuthor'},
    {'1': 'reconnectCount', '3': 2, '4': 1, '5': 13, '10': 'reconnectCount'},
    {'1': 'lastErrorCode', '3': 3, '4': 1, '5': 13, '10': 'lastErrorCode'},
    {'1': 'enterRoomAttach', '3': 4, '4': 1, '5': 9, '10': 'enterRoomAttach'},
    {'1': 'clientLiveSdkVersion', '3': 5, '4': 1, '5': 9, '10': 'clientLiveSdkVersion'},
  ],
};

/// Descriptor for `ZtLiveCsEnterRoom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveCsEnterRoomDescriptor =
    $convert.base64Decode('ChFadExpdmVDc0VudGVyUm9vbRIaCghpc0F1dGhvchgBIAEoCFIIaXNBdXRob3ISJgoOcmVjb2'
        '5uZWN0Q291bnQYAiABKA1SDnJlY29ubmVjdENvdW50EiQKDWxhc3RFcnJvckNvZGUYAyABKA1S'
        'DWxhc3RFcnJvckNvZGUSKAoPZW50ZXJSb29tQXR0YWNoGAQgASgJUg9lbnRlclJvb21BdHRhY2'
        'gSMgoUY2xpZW50TGl2ZVNka1ZlcnNpb24YBSABKAlSFGNsaWVudExpdmVTZGtWZXJzaW9u');

@$core.Deprecated('Use ztLiveCsHeartbeatDescriptor instead')
const ZtLiveCsHeartbeat$json = {
  '1': 'ZtLiveCsHeartbeat',
  '2': [
    {'1': 'clientTimestampMs', '3': 1, '4': 1, '5': 4, '10': 'clientTimestampMs'},
    {'1': 'sequence', '3': 2, '4': 1, '5': 8, '10': 'sequence'},
  ],
};

/// Descriptor for `ZtLiveCsHeartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveCsHeartbeatDescriptor =
    $convert.base64Decode('ChFadExpdmVDc0hlYXJ0YmVhdBIsChFjbGllbnRUaW1lc3RhbXBNcxgBIAEoBFIRY2xpZW50VG'
        'ltZXN0YW1wTXMSGgoIc2VxdWVuY2UYAiABKAhSCHNlcXVlbmNl');

@$core.Deprecated('Use csCmdDescriptor instead')
const CsCmd$json = {
  '1': 'CsCmd',
  '2': [
    {'1': 'cmdType', '3': 1, '4': 1, '5': 9, '10': 'cmdType'},
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'ticket', '3': 3, '4': 1, '5': 9, '10': 'ticket'},
    {'1': 'liveId', '3': 4, '4': 1, '5': 9, '10': 'liveId'},
  ],
};

/// Descriptor for `CsCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List csCmdDescriptor =
    $convert.base64Decode('CgVDc0NtZBIYCgdjbWRUeXBlGAEgASgJUgdjbWRUeXBlEhgKB3BheWxvYWQYAiABKAxSB3BheW'
        'xvYWQSFgoGdGlja2V0GAMgASgJUgZ0aWNrZXQSFgoGbGl2ZUlkGAQgASgJUgZsaXZlSWQ=');

@$core.Deprecated('Use appInfoDescriptor instead')
const AppInfo$json = {
  '1': 'AppInfo',
  '2': [
    {'1': 'appName', '3': 1, '4': 1, '5': 9, '10': 'appName'},
    {'1': 'appVersion', '3': 2, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'appChannel', '3': 3, '4': 1, '5': 9, '10': 'appChannel'},
    {'1': 'sdkVersion', '3': 4, '4': 1, '5': 9, '10': 'sdkVersion'},
    {
      '1': 'extensionInfo',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.AcFunPack.AppInfo.ExtensionInfoEntry',
      '10': 'extensionInfo'
    },
  ],
  '3': [AppInfo_ExtensionInfoEntry$json],
};

@$core.Deprecated('Use appInfoDescriptor instead')
const AppInfo_ExtensionInfoEntry$json = {
  '1': 'ExtensionInfoEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `AppInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appInfoDescriptor =
    $convert.base64Decode('CgdBcHBJbmZvEhgKB2FwcE5hbWUYASABKAlSB2FwcE5hbWUSHgoKYXBwVmVyc2lvbhgCIAEoCV'
        'IKYXBwVmVyc2lvbhIeCgphcHBDaGFubmVsGAMgASgJUgphcHBDaGFubmVsEh4KCnNka1ZlcnNp'
        'b24YBCABKAlSCnNka1ZlcnNpb24SSwoNZXh0ZW5zaW9uSW5mbxgFIAMoCzIlLkFjRnVuUGFjay'
        '5BcHBJbmZvLkV4dGVuc2lvbkluZm9FbnRyeVINZXh0ZW5zaW9uSW5mbxpAChJFeHRlbnNpb25J'
        'bmZvRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use deviceInfoDescriptor instead')
const DeviceInfo$json = {
  '1': 'DeviceInfo',
  '2': [
    {'1': 'platformType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.DeviceInfo.PlatformType', '10': 'platformType'},
    {'1': 'osVersion', '3': 2, '4': 1, '5': 9, '10': 'osVersion'},
    {'1': 'deviceModel', '3': 3, '4': 1, '5': 9, '10': 'deviceModel'},
    {'1': 'imeiMd5', '3': 4, '4': 1, '5': 12, '10': 'imeiMd5'},
    {'1': 'deviceId', '3': 5, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'softDid', '3': 6, '4': 1, '5': 9, '10': 'softDid'},
    {'1': 'kwaiDid', '3': 7, '4': 1, '5': 9, '10': 'kwaiDid'},
    {'1': 'manufacturer', '3': 8, '4': 1, '5': 9, '10': 'manufacturer'},
    {'1': 'deviceName', '3': 9, '4': 1, '5': 9, '10': 'deviceName'},
  ],
  '4': [DeviceInfo_PlatformType$json],
};

@$core.Deprecated('Use deviceInfoDescriptor instead')
const DeviceInfo_PlatformType$json = {
  '1': 'PlatformType',
  '2': [
    {'1': 'kInvalid', '2': 0},
    {'1': 'kAndroid', '2': 1},
    {'1': 'kiOS', '2': 2},
    {'1': 'kWindows', '2': 3},
    {'1': 'WECHAT_ANDROID', '2': 4},
    {'1': 'WECHAT_IOS', '2': 5},
    {'1': 'H5', '2': 6},
    {'1': 'H5_ANDROID', '2': 7},
    {'1': 'H5_IOS', '2': 8},
    {'1': 'H5_WINDOWS', '2': 9},
    {'1': 'H5_MAC', '2': 10},
    {'1': 'kPlatformNum', '2': 11},
  ],
};

/// Descriptor for `DeviceInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceInfoDescriptor =
    $convert.base64Decode('CgpEZXZpY2VJbmZvEkYKDHBsYXRmb3JtVHlwZRgBIAEoDjIiLkFjRnVuUGFjay5EZXZpY2VJbm'
        'ZvLlBsYXRmb3JtVHlwZVIMcGxhdGZvcm1UeXBlEhwKCW9zVmVyc2lvbhgCIAEoCVIJb3NWZXJz'
        'aW9uEiAKC2RldmljZU1vZGVsGAMgASgJUgtkZXZpY2VNb2RlbBIYCgdpbWVpTWQ1GAQgASgMUg'
        'dpbWVpTWQ1EhoKCGRldmljZUlkGAUgASgJUghkZXZpY2VJZBIYCgdzb2Z0RGlkGAYgASgJUgdz'
        'b2Z0RGlkEhgKB2t3YWlEaWQYByABKAlSB2t3YWlEaWQSIgoMbWFudWZhY3R1cmVyGAggASgJUg'
        'xtYW51ZmFjdHVyZXISHgoKZGV2aWNlTmFtZRgJIAEoCVIKZGV2aWNlTmFtZSK4AQoMUGxhdGZv'
        'cm1UeXBlEgwKCGtJbnZhbGlkEAASDAoIa0FuZHJvaWQQARIICgRraU9TEAISDAoIa1dpbmRvd3'
        'MQAxISCg5XRUNIQVRfQU5EUk9JRBAEEg4KCldFQ0hBVF9JT1MQBRIGCgJINRAGEg4KCkg1X0FO'
        'RFJPSUQQBxIKCgZINV9JT1MQCBIOCgpINV9XSU5ET1dTEAkSCgoGSDVfTUFDEAoSEAoMa1BsYX'
        'Rmb3JtTnVtEAs=');

@$core.Deprecated('Use envInfoDescriptor instead')
const EnvInfo$json = {
  '1': 'EnvInfo',
  '2': [
    {'1': 'networkType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.EnvInfo.NetworkType', '10': 'networkType'},
    {'1': 'apnName', '3': 2, '4': 1, '5': 12, '10': 'apnName'},
  ],
  '4': [EnvInfo_NetworkType$json],
};

@$core.Deprecated('Use envInfoDescriptor instead')
const EnvInfo_NetworkType$json = {
  '1': 'NetworkType',
  '2': [
    {'1': 'kInvalid', '2': 0},
    {'1': 'kWIFI', '2': 1},
    {'1': 'kCellular', '2': 2},
  ],
};

/// Descriptor for `EnvInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envInfoDescriptor =
    $convert.base64Decode('CgdFbnZJbmZvEkAKC25ldHdvcmtUeXBlGAEgASgOMh4uQWNGdW5QYWNrLkVudkluZm8uTmV0d2'
        '9ya1R5cGVSC25ldHdvcmtUeXBlEhgKB2Fwbk5hbWUYAiABKAxSB2Fwbk5hbWUiNQoLTmV0d29y'
        'a1R5cGUSDAoIa0ludmFsaWQQABIJCgVrV0lGSRABEg0KCWtDZWxsdWxhchAC');

@$core.Deprecated('Use pushServiceTokenDescriptor instead')
const PushServiceToken$json = {
  '1': 'PushServiceToken',
  '2': [
    {'1': 'pushType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.PushServiceToken.PushType', '10': 'pushType'},
    {'1': 'token', '3': 2, '4': 1, '5': 12, '10': 'token'},
    {'1': 'isPassThrough', '3': 3, '4': 1, '5': 8, '10': 'isPassThrough'},
  ],
  '4': [PushServiceToken_PushType$json],
};

@$core.Deprecated('Use pushServiceTokenDescriptor instead')
const PushServiceToken_PushType$json = {
  '1': 'PushType',
  '2': [
    {'1': 'kPushTypeInvalid', '2': 0},
    {'1': 'kPushTypeAPNS', '2': 1},
    {'1': 'kPushTypeXmPush', '2': 2},
    {'1': 'kPushTypeJgPush', '2': 3},
    {'1': 'kPushTypeGtPush', '2': 4},
    {'1': 'kPushTypeOpPush', '2': 5},
    {'1': 'kPushTypeVvPush', '2': 6},
    {'1': 'kPushTypeHwPush', '2': 7},
    {'1': 'kPushTypeFcm', '2': 8},
  ],
};

/// Descriptor for `PushServiceToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushServiceTokenDescriptor =
    $convert.base64Decode('ChBQdXNoU2VydmljZVRva2VuEkAKCHB1c2hUeXBlGAEgASgOMiQuQWNGdW5QYWNrLlB1c2hTZX'
        'J2aWNlVG9rZW4uUHVzaFR5cGVSCHB1c2hUeXBlEhQKBXRva2VuGAIgASgMUgV0b2tlbhIkCg1p'
        'c1Bhc3NUaHJvdWdoGAMgASgIUg1pc1Bhc3NUaHJvdWdoIsMBCghQdXNoVHlwZRIUChBrUHVzaF'
        'R5cGVJbnZhbGlkEAASEQoNa1B1c2hUeXBlQVBOUxABEhMKD2tQdXNoVHlwZVhtUHVzaBACEhMK'
        'D2tQdXNoVHlwZUpnUHVzaBADEhMKD2tQdXNoVHlwZUd0UHVzaBAEEhMKD2tQdXNoVHlwZU9wUH'
        'VzaBAFEhMKD2tQdXNoVHlwZVZ2UHVzaBAGEhMKD2tQdXNoVHlwZUh3UHVzaBAHEhAKDGtQdXNo'
        'VHlwZUZjbRAI');

@$core.Deprecated('Use ztCommonInfoDescriptor instead')
const ZtCommonInfo$json = {
  '1': 'ZtCommonInfo',
  '2': [
    {'1': 'kpn', '3': 1, '4': 1, '5': 9, '10': 'kpn'},
    {'1': 'kpf', '3': 2, '4': 1, '5': 9, '10': 'kpf'},
    {'1': 'uid', '3': 4, '4': 1, '5': 3, '10': 'uid'},
    {'1': 'did', '3': 5, '4': 1, '5': 9, '10': 'did'},
  ],
};

/// Descriptor for `ZtCommonInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztCommonInfoDescriptor =
    $convert.base64Decode('CgxadENvbW1vbkluZm8SEAoDa3BuGAEgASgJUgNrcG4SEAoDa3BmGAIgASgJUgNrcGYSEAoDdW'
        'lkGAQgASgDUgN1aWQSEAoDZGlkGAUgASgJUgNkaWQ=');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
  '2': [
    {'1': 'serverTimestamp', '3': 1, '4': 1, '5': 15, '10': 'serverTimestamp'},
    {'1': 'clientIp', '3': 2, '4': 1, '5': 7, '10': 'clientIp'},
    {'1': 'redirectIp', '3': 3, '4': 1, '5': 7, '10': 'redirectIp'},
    {'1': 'redirectPort', '3': 4, '4': 1, '5': 13, '10': 'redirectPort'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor =
    $convert.base64Decode('CgxQaW5nUmVzcG9uc2USKAoPc2VydmVyVGltZXN0YW1wGAEgASgPUg9zZXJ2ZXJUaW1lc3RhbX'
        'ASGgoIY2xpZW50SXAYAiABKAdSCGNsaWVudElwEh4KCnJlZGlyZWN0SXAYAyABKAdSCnJlZGly'
        'ZWN0SXASIgoMcmVkaXJlY3RQb3J0GAQgASgNUgxyZWRpcmVjdFBvcnQ=');

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
  '2': [
    {'1': 'pingType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.PingRequest.PingType', '10': 'pingType'},
    {'1': 'pingRound', '3': 2, '4': 1, '5': 13, '10': 'pingRound'},
  ],
  '4': [PingRequest_PingType$json],
};

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest_PingType$json = {
  '1': 'PingType',
  '2': [
    {'1': 'kInvalid', '2': 0},
    {'1': 'kPriorRegister', '2': 1},
    {'1': 'kPostRegister', '2': 2},
  ],
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor =
    $convert.base64Decode('CgtQaW5nUmVxdWVzdBI7CghwaW5nVHlwZRgBIAEoDjIfLkFjRnVuUGFjay5QaW5nUmVxdWVzdC'
        '5QaW5nVHlwZVIIcGluZ1R5cGUSHAoJcGluZ1JvdW5kGAIgASgNUglwaW5nUm91bmQiPwoIUGlu'
        'Z1R5cGUSDAoIa0ludmFsaWQQABISCg5rUHJpb3JSZWdpc3RlchABEhEKDWtQb3N0UmVnaXN0ZX'
        'IQAg==');

@$core.Deprecated('Use upstreamPayloadDescriptor instead')
const UpstreamPayload$json = {
  '1': 'UpstreamPayload',
  '2': [
    {'1': 'command', '3': 1, '4': 1, '5': 9, '10': 'command'},
    {'1': 'seqId', '3': 2, '4': 1, '5': 3, '10': 'seqId'},
    {'1': 'retryCount', '3': 3, '4': 1, '5': 13, '10': 'retryCount'},
    {'1': 'payloadData', '3': 4, '4': 1, '5': 12, '10': 'payloadData'},
    {'1': 'userInstance', '3': 5, '4': 1, '5': 11, '6': '.AcFunPack.UserInstance', '10': 'userInstance'},
    {'1': 'errorCode', '3': 6, '4': 1, '5': 5, '10': 'errorCode'},
    {'1': 'settingInfo', '3': 7, '4': 1, '5': 11, '6': '.AcFunPack.SettingInfo', '10': 'settingInfo'},
    {'1': 'requestBasicInfo', '3': 8, '4': 1, '5': 11, '6': '.AcFunPack.RequsetBasicInfo', '10': 'requestBasicInfo'},
    {'1': 'subBiz', '3': 9, '4': 1, '5': 9, '10': 'subBiz'},
    {'1': 'frontendInfo', '3': 10, '4': 1, '5': 11, '6': '.AcFunPack.FrontendInfo', '10': 'frontendInfo'},
    {'1': 'kpn', '3': 11, '4': 1, '5': 9, '10': 'kpn'},
    {'1': 'anonymouseUser', '3': 12, '4': 1, '5': 8, '10': 'anonymouseUser'},
  ],
};

/// Descriptor for `UpstreamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upstreamPayloadDescriptor =
    $convert.base64Decode('Cg9VcHN0cmVhbVBheWxvYWQSGAoHY29tbWFuZBgBIAEoCVIHY29tbWFuZBIUCgVzZXFJZBgCIA'
        'EoA1IFc2VxSWQSHgoKcmV0cnlDb3VudBgDIAEoDVIKcmV0cnlDb3VudBIgCgtwYXlsb2FkRGF0'
        'YRgEIAEoDFILcGF5bG9hZERhdGESOwoMdXNlckluc3RhbmNlGAUgASgLMhcuQWNGdW5QYWNrLl'
        'VzZXJJbnN0YW5jZVIMdXNlckluc3RhbmNlEhwKCWVycm9yQ29kZRgGIAEoBVIJZXJyb3JDb2Rl'
        'EjgKC3NldHRpbmdJbmZvGAcgASgLMhYuQWNGdW5QYWNrLlNldHRpbmdJbmZvUgtzZXR0aW5nSW'
        '5mbxJHChByZXF1ZXN0QmFzaWNJbmZvGAggASgLMhsuQWNGdW5QYWNrLlJlcXVzZXRCYXNpY0lu'
        'Zm9SEHJlcXVlc3RCYXNpY0luZm8SFgoGc3ViQml6GAkgASgJUgZzdWJCaXoSOwoMZnJvbnRlbm'
        'RJbmZvGAogASgLMhcuQWNGdW5QYWNrLkZyb250ZW5kSW5mb1IMZnJvbnRlbmRJbmZvEhAKA2tw'
        'bhgLIAEoCVIDa3BuEiYKDmFub255bW91c2VVc2VyGAwgASgIUg5hbm9ueW1vdXNlVXNlcg==');

@$core.Deprecated('Use downstreamPayloadDescriptor instead')
const DownstreamPayload$json = {
  '1': 'DownstreamPayload',
  '2': [
    {'1': 'command', '3': 1, '4': 1, '5': 9, '10': 'command'},
    {'1': 'seqId', '3': 2, '4': 1, '5': 3, '10': 'seqId'},
    {'1': 'errorCode', '3': 3, '4': 1, '5': 5, '10': 'errorCode'},
    {'1': 'payloadData', '3': 4, '4': 1, '5': 12, '10': 'payloadData'},
    {'1': 'errorMsg', '3': 5, '4': 1, '5': 9, '10': 'errorMsg'},
    {'1': 'errorData', '3': 6, '4': 1, '5': 12, '10': 'errorData'},
    {'1': 'subBiz', '3': 7, '4': 1, '5': 9, '10': 'subBiz'},
  ],
};

/// Descriptor for `DownstreamPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List downstreamPayloadDescriptor =
    $convert.base64Decode('ChFEb3duc3RyZWFtUGF5bG9hZBIYCgdjb21tYW5kGAEgASgJUgdjb21tYW5kEhQKBXNlcUlkGA'
        'IgASgDUgVzZXFJZBIcCgllcnJvckNvZGUYAyABKAVSCWVycm9yQ29kZRIgCgtwYXlsb2FkRGF0'
        'YRgEIAEoDFILcGF5bG9hZERhdGESGgoIZXJyb3JNc2cYBSABKAlSCGVycm9yTXNnEhwKCWVycm'
        '9yRGF0YRgGIAEoDFIJZXJyb3JEYXRhEhYKBnN1YkJpehgHIAEoCVIGc3ViQml6');

@$core.Deprecated('Use userInstanceDescriptor instead')
const UserInstance$json = {
  '1': 'UserInstance',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.User', '10': 'user'},
    {'1': 'instanceId', '3': 2, '4': 1, '5': 3, '10': 'instanceId'},
  ],
};

/// Descriptor for `UserInstance`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userInstanceDescriptor =
    $convert.base64Decode('CgxVc2VySW5zdGFuY2USIwoEdXNlchgBIAEoCzIPLkFjRnVuUGFjay5Vc2VyUgR1c2VyEh4KCm'
        'luc3RhbmNlSWQYAiABKANSCmluc3RhbmNlSWQ=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'appId', '3': 1, '4': 1, '5': 5, '10': 'appId'},
    {'1': 'uid', '3': 2, '4': 1, '5': 3, '10': 'uid'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor =
    $convert.base64Decode('CgRVc2VyEhQKBWFwcElkGAEgASgFUgVhcHBJZBIQCgN1aWQYAiABKANSA3VpZA==');

@$core.Deprecated('Use settingInfoDescriptor instead')
const SettingInfo$json = {
  '1': 'SettingInfo',
  '2': [
    {'1': 'locale', '3': 1, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'timezone', '3': 2, '4': 1, '5': 17, '10': 'timezone'},
  ],
};

/// Descriptor for `SettingInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingInfoDescriptor =
    $convert.base64Decode('CgtTZXR0aW5nSW5mbxIWCgZsb2NhbGUYASABKAlSBmxvY2FsZRIaCgh0aW1lem9uZRgCIAEoEV'
        'IIdGltZXpvbmU=');

@$core.Deprecated('Use requsetBasicInfoDescriptor instead')
const RequsetBasicInfo$json = {
  '1': 'RequsetBasicInfo',
  '2': [
    {'1': 'clientType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.DeviceInfo.PlatformType', '10': 'clientType'},
    {'1': 'deviceId', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'clientIp', '3': 3, '4': 1, '5': 9, '10': 'clientIp'},
    {'1': 'appVersion', '3': 4, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'channel', '3': 5, '4': 1, '5': 9, '10': 'channel'},
    {'1': 'appInfo', '3': 6, '4': 1, '5': 11, '6': '.AcFunPack.AppInfo', '10': 'appInfo'},
    {'1': 'deviceInfo', '3': 7, '4': 1, '5': 11, '6': '.AcFunPack.DeviceInfo', '10': 'deviceInfo'},
    {'1': 'envInfo', '3': 8, '4': 1, '5': 11, '6': '.AcFunPack.EnvInfo', '10': 'envInfo'},
    {'1': 'clientPort', '3': 9, '4': 1, '5': 5, '10': 'clientPort'},
    {'1': 'location', '3': 10, '4': 1, '5': 9, '10': 'location'},
    {'1': 'kpf', '3': 11, '4': 1, '5': 9, '10': 'kpf'},
  ],
};

/// Descriptor for `RequsetBasicInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requsetBasicInfoDescriptor =
    $convert.base64Decode('ChBSZXF1c2V0QmFzaWNJbmZvEkIKCmNsaWVudFR5cGUYASABKA4yIi5BY0Z1blBhY2suRGV2aW'
        'NlSW5mby5QbGF0Zm9ybVR5cGVSCmNsaWVudFR5cGUSGgoIZGV2aWNlSWQYAiABKAlSCGRldmlj'
        'ZUlkEhoKCGNsaWVudElwGAMgASgJUghjbGllbnRJcBIeCgphcHBWZXJzaW9uGAQgASgJUgphcH'
        'BWZXJzaW9uEhgKB2NoYW5uZWwYBSABKAlSB2NoYW5uZWwSLAoHYXBwSW5mbxgGIAEoCzISLkFj'
        'RnVuUGFjay5BcHBJbmZvUgdhcHBJbmZvEjUKCmRldmljZUluZm8YByABKAsyFS5BY0Z1blBhY2'
        'suRGV2aWNlSW5mb1IKZGV2aWNlSW5mbxIsCgdlbnZJbmZvGAggASgLMhIuQWNGdW5QYWNrLkVu'
        'dkluZm9SB2VudkluZm8SHgoKY2xpZW50UG9ydBgJIAEoBVIKY2xpZW50UG9ydBIaCghsb2NhdG'
        'lvbhgKIAEoCVIIbG9jYXRpb24SEAoDa3BmGAsgASgJUgNrcGY=');

@$core.Deprecated('Use frontendInfoDescriptor instead')
const FrontendInfo$json = {
  '1': 'FrontendInfo',
  '2': [
    {'1': 'ip', '3': 1, '4': 1, '5': 9, '10': 'ip'},
    {'1': 'port', '3': 2, '4': 1, '5': 5, '10': 'port'},
  ],
};

/// Descriptor for `FrontendInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frontendInfoDescriptor =
    $convert.base64Decode('CgxGcm9udGVuZEluZm8SDgoCaXAYASABKAlSAmlwEhIKBHBvcnQYAiABKAVSBHBvcnQ=');

@$core.Deprecated('Use packetHeaderDescriptor instead')
const PacketHeader$json = {
  '1': 'PacketHeader',
  '2': [
    {'1': 'appId', '3': 1, '4': 1, '5': 5, '10': 'appId'},
    {'1': 'uid', '3': 2, '4': 1, '5': 3, '10': 'uid'},
    {'1': 'instanceId', '3': 3, '4': 1, '5': 3, '10': 'instanceId'},
    {'1': 'flags', '3': 4, '4': 1, '5': 13, '10': 'flags'},
    {'1': 'encodingType', '3': 6, '4': 1, '5': 14, '6': '.AcFunPack.PacketHeader.EncodingType', '10': 'encodingType'},
    {'1': 'decodedPayloadLen', '3': 7, '4': 1, '5': 13, '10': 'decodedPayloadLen'},
    {
      '1': 'encryptionMode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.AcFunPack.PacketHeader.EncryptionMode',
      '10': 'encryptionMode'
    },
    {'1': 'tokenInfo', '3': 9, '4': 1, '5': 11, '6': '.AcFunPack.TokenInfo', '10': 'tokenInfo'},
    {'1': 'seqId', '3': 10, '4': 1, '5': 3, '10': 'seqId'},
    {'1': 'features', '3': 11, '4': 3, '5': 14, '6': '.AcFunPack.PacketHeader.Feature', '10': 'features'},
    {'1': 'kpn', '3': 12, '4': 1, '5': 9, '10': 'kpn'},
  ],
  '4': [
    PacketHeader_Flags$json,
    PacketHeader_EncodingType$json,
    PacketHeader_EncryptionMode$json,
    PacketHeader_Feature$json
  ],
};

@$core.Deprecated('Use packetHeaderDescriptor instead')
const PacketHeader_Flags$json = {
  '1': 'Flags',
  '2': [
    {'1': 'kDirUpstream', '2': 0},
    {'1': 'kDirDownstream', '2': 1},
    {'1': 'kDirMask', '2': 1},
  ],
  '3': {'2': true},
};

@$core.Deprecated('Use packetHeaderDescriptor instead')
const PacketHeader_EncodingType$json = {
  '1': 'EncodingType',
  '2': [
    {'1': 'kEncodingNone', '2': 0},
    {'1': 'kEncodingLz4', '2': 1},
  ],
};

@$core.Deprecated('Use packetHeaderDescriptor instead')
const PacketHeader_EncryptionMode$json = {
  '1': 'EncryptionMode',
  '2': [
    {'1': 'kEncryptionNone', '2': 0},
    {'1': 'kEncryptionServiceToken', '2': 1},
    {'1': 'kEncryptionSessionKey', '2': 2},
  ],
};

@$core.Deprecated('Use packetHeaderDescriptor instead')
const PacketHeader_Feature$json = {
  '1': 'Feature',
  '2': [
    {'1': 'kReserve', '2': 0},
    {'1': 'kCompressLz4', '2': 1},
  ],
};

/// Descriptor for `PacketHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List packetHeaderDescriptor =
    $convert.base64Decode('CgxQYWNrZXRIZWFkZXISFAoFYXBwSWQYASABKAVSBWFwcElkEhAKA3VpZBgCIAEoA1IDdWlkEh'
        '4KCmluc3RhbmNlSWQYAyABKANSCmluc3RhbmNlSWQSFAoFZmxhZ3MYBCABKA1SBWZsYWdzEkgK'
        'DGVuY29kaW5nVHlwZRgGIAEoDjIkLkFjRnVuUGFjay5QYWNrZXRIZWFkZXIuRW5jb2RpbmdUeX'
        'BlUgxlbmNvZGluZ1R5cGUSLAoRZGVjb2RlZFBheWxvYWRMZW4YByABKA1SEWRlY29kZWRQYXls'
        'b2FkTGVuEk4KDmVuY3J5cHRpb25Nb2RlGAggASgOMiYuQWNGdW5QYWNrLlBhY2tldEhlYWRlci'
        '5FbmNyeXB0aW9uTW9kZVIOZW5jcnlwdGlvbk1vZGUSMgoJdG9rZW5JbmZvGAkgASgLMhQuQWNG'
        'dW5QYWNrLlRva2VuSW5mb1IJdG9rZW5JbmZvEhQKBXNlcUlkGAogASgDUgVzZXFJZBI7CghmZW'
        'F0dXJlcxgLIAMoDjIfLkFjRnVuUGFjay5QYWNrZXRIZWFkZXIuRmVhdHVyZVIIZmVhdHVyZXMS'
        'EAoDa3BuGAwgASgJUgNrcG4iPwoFRmxhZ3MSEAoMa0RpclVwc3RyZWFtEAASEgoOa0RpckRvd2'
        '5zdHJlYW0QARIMCghrRGlyTWFzaxABGgIQASIzCgxFbmNvZGluZ1R5cGUSEQoNa0VuY29kaW5n'
        'Tm9uZRAAEhAKDGtFbmNvZGluZ0x6NBABIl0KDkVuY3J5cHRpb25Nb2RlEhMKD2tFbmNyeXB0aW'
        '9uTm9uZRAAEhsKF2tFbmNyeXB0aW9uU2VydmljZVRva2VuEAESGQoVa0VuY3J5cHRpb25TZXNz'
        'aW9uS2V5EAIiKQoHRmVhdHVyZRIMCghrUmVzZXJ2ZRAAEhAKDGtDb21wcmVzc0x6NBAB');

@$core.Deprecated('Use tokenInfoDescriptor instead')
const TokenInfo$json = {
  '1': 'TokenInfo',
  '2': [
    {'1': 'tokenType', '3': 1, '4': 1, '5': 14, '6': '.AcFunPack.TokenInfo.TokenType', '10': 'tokenType'},
    {'1': 'token', '3': 2, '4': 1, '5': 12, '10': 'token'},
  ],
  '4': [TokenInfo_TokenType$json],
};

@$core.Deprecated('Use tokenInfoDescriptor instead')
const TokenInfo_TokenType$json = {
  '1': 'TokenType',
  '2': [
    {'1': 'kInvalid', '2': 0},
    {'1': 'kServiceToken', '2': 1},
  ],
};

/// Descriptor for `TokenInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tokenInfoDescriptor =
    $convert.base64Decode('CglUb2tlbkluZm8SPAoJdG9rZW5UeXBlGAEgASgOMh4uQWNGdW5QYWNrLlRva2VuSW5mby5Ub2'
        'tlblR5cGVSCXRva2VuVHlwZRIUCgV0b2tlbhgCIAEoDFIFdG9rZW4iLAoJVG9rZW5UeXBlEgwK'
        'CGtJbnZhbGlkEAASEQoNa1NlcnZpY2VUb2tlbhAB');

@$core.Deprecated('Use keepAliveRequestDescriptor instead')
const KeepAliveRequest$json = {
  '1': 'KeepAliveRequest',
  '2': [
    {
      '1': 'presenceStatus',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.AcFunPack.RegisterRequest.PresenceStatus',
      '10': 'presenceStatus'
    },
    {
      '1': 'appActiveStatus',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.AcFunPack.RegisterRequest.ActiveStatus',
      '10': 'appActiveStatus'
    },
    {'1': 'pushServiceToken', '3': 3, '4': 1, '5': 11, '6': '.AcFunPack.PushServiceToken', '10': 'pushServiceToken'},
    {
      '1': 'pushServiceTokenList',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.AcFunPack.PushServiceToken',
      '10': 'pushServiceTokenList'
    },
    {'1': 'keepaliveIntervalSec', '3': 5, '4': 3, '5': 5, '10': 'keepaliveIntervalSec'},
  ],
};

/// Descriptor for `KeepAliveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepAliveRequestDescriptor =
    $convert.base64Decode('ChBLZWVwQWxpdmVSZXF1ZXN0ElEKDnByZXNlbmNlU3RhdHVzGAEgASgOMikuQWNGdW5QYWNrLl'
        'JlZ2lzdGVyUmVxdWVzdC5QcmVzZW5jZVN0YXR1c1IOcHJlc2VuY2VTdGF0dXMSUQoPYXBwQWN0'
        'aXZlU3RhdHVzGAIgASgOMicuQWNGdW5QYWNrLlJlZ2lzdGVyUmVxdWVzdC5BY3RpdmVTdGF0dX'
        'NSD2FwcEFjdGl2ZVN0YXR1cxJHChBwdXNoU2VydmljZVRva2VuGAMgASgLMhsuQWNGdW5QYWNr'
        'LlB1c2hTZXJ2aWNlVG9rZW5SEHB1c2hTZXJ2aWNlVG9rZW4STwoUcHVzaFNlcnZpY2VUb2tlbk'
        'xpc3QYBCADKAsyGy5BY0Z1blBhY2suUHVzaFNlcnZpY2VUb2tlblIUcHVzaFNlcnZpY2VUb2tl'
        'bkxpc3QSMgoUa2VlcGFsaXZlSW50ZXJ2YWxTZWMYBSADKAVSFGtlZXBhbGl2ZUludGVydmFsU2'
        'Vj');

@$core.Deprecated('Use ztLiveScMessageDescriptor instead')
const ZtLiveScMessage$json = {
  '1': 'ZtLiveScMessage',
  '2': [
    {'1': 'messageType', '3': 1, '4': 1, '5': 9, '10': 'messageType'},
    {'1': 'compressionType', '3': 2, '4': 1, '5': 5, '10': 'compressionType'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'liveId', '3': 4, '4': 1, '5': 9, '10': 'liveId'},
    {'1': 'ticket', '3': 5, '4': 1, '5': 9, '10': 'ticket'},
    {'1': 'serverTimestampMs', '3': 6, '4': 1, '5': 4, '10': 'serverTimestampMs'},
  ],
};

/// Descriptor for `ZtLiveScMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveScMessageDescriptor =
    $convert.base64Decode('Cg9adExpdmVTY01lc3NhZ2USIAoLbWVzc2FnZVR5cGUYASABKAlSC21lc3NhZ2VUeXBlEigKD2'
        'NvbXByZXNzaW9uVHlwZRgCIAEoBVIPY29tcHJlc3Npb25UeXBlEhgKB3BheWxvYWQYAyABKAxS'
        'B3BheWxvYWQSFgoGbGl2ZUlkGAQgASgJUgZsaXZlSWQSFgoGdGlja2V0GAUgASgJUgZ0aWNrZX'
        'QSLAoRc2VydmVyVGltZXN0YW1wTXMYBiABKARSEXNlcnZlclRpbWVzdGFtcE1z');

@$core.Deprecated('Use ztLiveScNotifySignalDescriptor instead')
const ZtLiveScNotifySignal$json = {
  '1': 'ZtLiveScNotifySignal',
  '2': [
    {'1': 'item', '3': 1, '4': 3, '5': 11, '6': '.AcFunPack.ZtLiveScNotifySignal.ZtLiveNotifySignalItem', '10': 'item'},
  ],
  '3': [ZtLiveScNotifySignal_ZtLiveNotifySignalItem$json],
};

@$core.Deprecated('Use ztLiveScNotifySignalDescriptor instead')
const ZtLiveScNotifySignal_ZtLiveNotifySignalItem$json = {
  '1': 'ZtLiveNotifySignalItem',
  '2': [
    {'1': 'signalType', '3': 1, '4': 1, '5': 9, '10': 'signalType'},
    {'1': 'payload', '3': 2, '4': 3, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `ZtLiveScNotifySignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveScNotifySignalDescriptor =
    $convert.base64Decode('ChRadExpdmVTY05vdGlmeVNpZ25hbBJKCgRpdGVtGAEgAygLMjYuQWNGdW5QYWNrLlp0TGl2ZV'
        'NjTm90aWZ5U2lnbmFsLlp0TGl2ZU5vdGlmeVNpZ25hbEl0ZW1SBGl0ZW0aUgoWWnRMaXZlTm90'
        'aWZ5U2lnbmFsSXRlbRIeCgpzaWduYWxUeXBlGAEgASgJUgpzaWduYWxUeXBlEhgKB3BheWxvYW'
        'QYAiADKAxSB3BheWxvYWQ=');

@$core.Deprecated('Use ztLiveScActionSignalDescriptor instead')
const ZtLiveScActionSignal$json = {
  '1': 'ZtLiveScActionSignal',
  '2': [
    {'1': 'item', '3': 1, '4': 3, '5': 11, '6': '.AcFunPack.ZtLiveScActionSignal.ZtLiveActionSignalItem', '10': 'item'},
  ],
  '3': [ZtLiveScActionSignal_ZtLiveActionSignalItem$json],
};

@$core.Deprecated('Use ztLiveScActionSignalDescriptor instead')
const ZtLiveScActionSignal_ZtLiveActionSignalItem$json = {
  '1': 'ZtLiveActionSignalItem',
  '2': [
    {'1': 'signalType', '3': 1, '4': 1, '5': 9, '10': 'signalType'},
    {'1': 'payload', '3': 2, '4': 3, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `ZtLiveScActionSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveScActionSignalDescriptor =
    $convert.base64Decode('ChRadExpdmVTY0FjdGlvblNpZ25hbBJKCgRpdGVtGAEgAygLMjYuQWNGdW5QYWNrLlp0TGl2ZV'
        'NjQWN0aW9uU2lnbmFsLlp0TGl2ZUFjdGlvblNpZ25hbEl0ZW1SBGl0ZW0aUgoWWnRMaXZlQWN0'
        'aW9uU2lnbmFsSXRlbRIeCgpzaWduYWxUeXBlGAEgASgJUgpzaWduYWxUeXBlEhgKB3BheWxvYW'
        'QYAiADKAxSB3BheWxvYWQ=');

@$core.Deprecated('Use ztLiveScStateSignalDescriptor instead')
const ZtLiveScStateSignal$json = {
  '1': 'ZtLiveScStateSignal',
  '2': [
    {'1': 'item', '3': 1, '4': 3, '5': 11, '6': '.AcFunPack.ZtLiveScStateSignal.ZtLiveStateSignalItem', '10': 'item'},
  ],
  '3': [ZtLiveScStateSignal_ZtLiveStateSignalItem$json],
};

@$core.Deprecated('Use ztLiveScStateSignalDescriptor instead')
const ZtLiveScStateSignal_ZtLiveStateSignalItem$json = {
  '1': 'ZtLiveStateSignalItem',
  '2': [
    {'1': 'signalType', '3': 1, '4': 1, '5': 9, '10': 'signalType'},
    {'1': 'payload', '3': 2, '4': 3, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `ZtLiveScStateSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveScStateSignalDescriptor =
    $convert.base64Decode('ChNadExpdmVTY1N0YXRlU2lnbmFsEkgKBGl0ZW0YASADKAsyNC5BY0Z1blBhY2suWnRMaXZlU2'
        'NTdGF0ZVNpZ25hbC5adExpdmVTdGF0ZVNpZ25hbEl0ZW1SBGl0ZW0aUQoVWnRMaXZlU3RhdGVT'
        'aWduYWxJdGVtEh4KCnNpZ25hbFR5cGUYASABKAlSCnNpZ25hbFR5cGUSGAoHcGF5bG9hZBgCIA'
        'MoDFIHcGF5bG9hZA==');

@$core.Deprecated('Use ztLiveScStatusChangedDescriptor instead')
const ZtLiveScStatusChanged$json = {
  '1': 'ZtLiveScStatusChanged',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 5, '10': 'type'},
    {'1': 'maxRandomDelayMs', '3': 2, '4': 1, '5': 4, '10': 'maxRandomDelayMs'},
    {
      '1': 'bannedInfo',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.AcFunPack.ZtLiveScStatusChanged.BannedInfo',
      '10': 'bannedInfo'
    },
  ],
  '3': [ZtLiveScStatusChanged_BannedInfo$json],
};

@$core.Deprecated('Use ztLiveScStatusChangedDescriptor instead')
const ZtLiveScStatusChanged_BannedInfo$json = {
  '1': 'BannedInfo',
  '2': [
    {'1': 'banReason', '3': 1, '4': 1, '5': 9, '10': 'banReason'},
  ],
};

/// Descriptor for `ZtLiveScStatusChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveScStatusChangedDescriptor =
    $convert.base64Decode('ChVadExpdmVTY1N0YXR1c0NoYW5nZWQSEgoEdHlwZRgBIAEoBVIEdHlwZRIqChBtYXhSYW5kb2'
        '1EZWxheU1zGAIgASgEUhBtYXhSYW5kb21EZWxheU1zEksKCmJhbm5lZEluZm8YAyABKAsyKy5B'
        'Y0Z1blBhY2suWnRMaXZlU2NTdGF0dXNDaGFuZ2VkLkJhbm5lZEluZm9SCmJhbm5lZEluZm8aKg'
        'oKQmFubmVkSW5mbxIcCgliYW5SZWFzb24YASABKAlSCWJhblJlYXNvbg==');

@$core.Deprecated('Use commonActionSignalCommentDescriptor instead')
const CommonActionSignalComment$json = {
  '1': 'CommonActionSignalComment',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
    {'1': 'sendTimeMs', '3': 2, '4': 1, '5': 4, '10': 'sendTimeMs'},
    {'1': 'userInfo', '3': 3, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
  ],
};

/// Descriptor for `CommonActionSignalComment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalCommentDescriptor =
    $convert.base64Decode('ChlDb21tb25BY3Rpb25TaWduYWxDb21tZW50EhgKB2NvbnRlbnQYASABKAlSB2NvbnRlbnQSHg'
        'oKc2VuZFRpbWVNcxgCIAEoBFIKc2VuZFRpbWVNcxI1Cgh1c2VySW5mbxgDIAEoCzIZLkFjRnVu'
        'UGFjay5adExpdmVVc2VySW5mb1IIdXNlckluZm8=');

@$core.Deprecated('Use commonActionSignalLikeDescriptor instead')
const CommonActionSignalLike$json = {
  '1': 'CommonActionSignalLike',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
    {'1': 'sendTimeMs', '3': 2, '4': 1, '5': 4, '10': 'sendTimeMs'},
  ],
};

/// Descriptor for `CommonActionSignalLike`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalLikeDescriptor =
    $convert.base64Decode('ChZDb21tb25BY3Rpb25TaWduYWxMaWtlEjUKCHVzZXJJbmZvGAEgASgLMhkuQWNGdW5QYWNrLl'
        'p0TGl2ZVVzZXJJbmZvUgh1c2VySW5mbxIeCgpzZW5kVGltZU1zGAIgASgEUgpzZW5kVGltZU1z');

@$core.Deprecated('Use commonActionSignalGiftDescriptor instead')
const CommonActionSignalGift$json = {
  '1': 'CommonActionSignalGift',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
    {'1': 'sendTimeMs', '3': 2, '4': 1, '5': 4, '10': 'sendTimeMs'},
    {'1': 'giftId', '3': 3, '4': 1, '5': 4, '10': 'giftId'},
    {'1': 'batchSize', '3': 4, '4': 1, '5': 13, '10': 'batchSize'},
    {'1': 'comboCount', '3': 5, '4': 1, '5': 13, '10': 'comboCount'},
    {'1': 'rank', '3': 6, '4': 1, '5': 4, '10': 'rank'},
    {'1': 'comboKey', '3': 7, '4': 1, '5': 9, '10': 'comboKey'},
    {'1': 'slotDisplayDurationMs', '3': 8, '4': 1, '5': 4, '10': 'slotDisplayDurationMs'},
    {'1': 'expireDurationMs', '3': 9, '4': 1, '5': 4, '10': 'expireDurationMs'},
  ],
};

/// Descriptor for `CommonActionSignalGift`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalGiftDescriptor =
    $convert.base64Decode('ChZDb21tb25BY3Rpb25TaWduYWxHaWZ0EjUKCHVzZXJJbmZvGAEgASgLMhkuQWNGdW5QYWNrLl'
        'p0TGl2ZVVzZXJJbmZvUgh1c2VySW5mbxIeCgpzZW5kVGltZU1zGAIgASgEUgpzZW5kVGltZU1z'
        'EhYKBmdpZnRJZBgDIAEoBFIGZ2lmdElkEhwKCWJhdGNoU2l6ZRgEIAEoDVIJYmF0Y2hTaXplEh'
        '4KCmNvbWJvQ291bnQYBSABKA1SCmNvbWJvQ291bnQSEgoEcmFuaxgGIAEoBFIEcmFuaxIaCghj'
        'b21ib0tleRgHIAEoCVIIY29tYm9LZXkSNAoVc2xvdERpc3BsYXlEdXJhdGlvbk1zGAggASgEUh'
        'VzbG90RGlzcGxheUR1cmF0aW9uTXMSKgoQZXhwaXJlRHVyYXRpb25NcxgJIAEoBFIQZXhwaXJl'
        'RHVyYXRpb25Ncw==');

@$core.Deprecated('Use commonStateSignalDisplayInfoDescriptor instead')
const CommonStateSignalDisplayInfo$json = {
  '1': 'CommonStateSignalDisplayInfo',
  '2': [
    {'1': 'watchingCount', '3': 1, '4': 1, '5': 9, '10': 'watchingCount'},
    {'1': 'likeCount', '3': 2, '4': 1, '5': 9, '10': 'likeCount'},
    {'1': 'likeDelta', '3': 3, '4': 1, '5': 13, '10': 'likeDelta'},
  ],
};

/// Descriptor for `CommonStateSignalDisplayInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalDisplayInfoDescriptor =
    $convert.base64Decode('ChxDb21tb25TdGF0ZVNpZ25hbERpc3BsYXlJbmZvEiQKDXdhdGNoaW5nQ291bnQYASABKAlSDX'
        'dhdGNoaW5nQ291bnQSHAoJbGlrZUNvdW50GAIgASgJUglsaWtlQ291bnQSHAoJbGlrZURlbHRh'
        'GAMgASgNUglsaWtlRGVsdGE=');

@$core.Deprecated('Use commonStateSignalTopUsersDescriptor instead')
const CommonStateSignalTopUsers$json = {
  '1': 'CommonStateSignalTopUsers',
  '2': [
    {'1': 'topUser', '3': 1, '4': 3, '5': 11, '6': '.AcFunPack.CommonStateSignalTopUsers.TopUser', '10': 'topUser'},
  ],
  '3': [CommonStateSignalTopUsers_TopUser$json],
};

@$core.Deprecated('Use commonStateSignalTopUsersDescriptor instead')
const CommonStateSignalTopUsers_TopUser$json = {
  '1': 'TopUser',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
    {'1': 'customWatchingListData', '3': 2, '4': 1, '5': 9, '10': 'customWatchingListData'},
    {'1': 'displaySendAmount', '3': 3, '4': 1, '5': 9, '10': 'displaySendAmount'},
    {'1': 'anonymousUser', '3': 4, '4': 1, '5': 8, '10': 'anonymousUser'},
  ],
};

/// Descriptor for `CommonStateSignalTopUsers`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalTopUsersDescriptor =
    $convert.base64Decode('ChlDb21tb25TdGF0ZVNpZ25hbFRvcFVzZXJzEkYKB3RvcFVzZXIYASADKAsyLC5BY0Z1blBhY2'
        'suQ29tbW9uU3RhdGVTaWduYWxUb3BVc2Vycy5Ub3BVc2VyUgd0b3BVc2VyGswBCgdUb3BVc2Vy'
        'EjUKCHVzZXJJbmZvGAEgASgLMhkuQWNGdW5QYWNrLlp0TGl2ZVVzZXJJbmZvUgh1c2VySW5mbx'
        'I2ChZjdXN0b21XYXRjaGluZ0xpc3REYXRhGAIgASgJUhZjdXN0b21XYXRjaGluZ0xpc3REYXRh'
        'EiwKEWRpc3BsYXlTZW5kQW1vdW50GAMgASgJUhFkaXNwbGF5U2VuZEFtb3VudBIkCg1hbm9ueW'
        '1vdXNVc2VyGAQgASgIUg1hbm9ueW1vdXNVc2Vy');

@$core.Deprecated('Use commonActionSignalUserEnterRoomDescriptor instead')
const CommonActionSignalUserEnterRoom$json = {
  '1': 'CommonActionSignalUserEnterRoom',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
    {'1': 'sendTimeMs', '3': 2, '4': 1, '5': 4, '10': 'sendTimeMs'},
  ],
};

/// Descriptor for `CommonActionSignalUserEnterRoom`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalUserEnterRoomDescriptor =
    $convert.base64Decode('Ch9Db21tb25BY3Rpb25TaWduYWxVc2VyRW50ZXJSb29tEjUKCHVzZXJJbmZvGAEgASgLMhkuQW'
        'NGdW5QYWNrLlp0TGl2ZVVzZXJJbmZvUgh1c2VySW5mbxIeCgpzZW5kVGltZU1zGAIgASgEUgpz'
        'ZW5kVGltZU1z');

@$core.Deprecated('Use commonActionSignalUserFollowAuthorDescriptor instead')
const CommonActionSignalUserFollowAuthor$json = {
  '1': 'CommonActionSignalUserFollowAuthor',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'userInfo'},
    {'1': 'sendTimeMs', '3': 2, '4': 1, '5': 4, '10': 'sendTimeMs'},
  ],
};

/// Descriptor for `CommonActionSignalUserFollowAuthor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalUserFollowAuthorDescriptor =
    $convert.base64Decode('CiJDb21tb25BY3Rpb25TaWduYWxVc2VyRm9sbG93QXV0aG9yEjUKCHVzZXJJbmZvGAEgASgLMh'
        'kuQWNGdW5QYWNrLlp0TGl2ZVVzZXJJbmZvUgh1c2VySW5mbxIeCgpzZW5kVGltZU1zGAIgASgE'
        'UgpzZW5kVGltZU1z');

@$core.Deprecated('Use commonActionSignalRichTextDescriptor instead')
const CommonActionSignalRichText$json = {
  '1': 'CommonActionSignalRichText',
  '2': [
    {'1': 'userInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.UserInfoSegment', '10': 'userInfo'},
    {'1': 'plain', '3': 2, '4': 1, '5': 11, '6': '.AcFunPack.PlainSegment', '10': 'plain'},
    {'1': 'image', '3': 3, '4': 1, '5': 11, '6': '.AcFunPack.ImageSegment', '10': 'image'},
  ],
};

/// Descriptor for `CommonActionSignalRichText`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonActionSignalRichTextDescriptor =
    $convert.base64Decode('ChpDb21tb25BY3Rpb25TaWduYWxSaWNoVGV4dBI2Cgh1c2VySW5mbxgBIAEoCzIaLkFjRnVuUG'
        'Fjay5Vc2VySW5mb1NlZ21lbnRSCHVzZXJJbmZvEi0KBXBsYWluGAIgASgLMhcuQWNGdW5QYWNr'
        'LlBsYWluU2VnbWVudFIFcGxhaW4SLQoFaW1hZ2UYAyABKAsyFy5BY0Z1blBhY2suSW1hZ2VTZW'
        'dtZW50UgVpbWFnZQ==');

@$core.Deprecated('Use userInfoSegmentDescriptor instead')
const UserInfoSegment$json = {
  '1': 'UserInfoSegment',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'user'},
    {'1': 'color', '3': 2, '4': 1, '5': 9, '10': 'color'},
  ],
};

/// Descriptor for `UserInfoSegment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userInfoSegmentDescriptor =
    $convert.base64Decode('Cg9Vc2VySW5mb1NlZ21lbnQSLQoEdXNlchgBIAEoCzIZLkFjRnVuUGFjay5adExpdmVVc2VySW'
        '5mb1IEdXNlchIUCgVjb2xvchgCIAEoCVIFY29sb3I=');

@$core.Deprecated('Use plainSegmentDescriptor instead')
const PlainSegment$json = {
  '1': 'PlainSegment',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'color', '3': 2, '4': 1, '5': 9, '10': 'color'},
  ],
};

/// Descriptor for `PlainSegment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plainSegmentDescriptor =
    $convert.base64Decode('CgxQbGFpblNlZ21lbnQSEgoEdGV4dBgBIAEoCVIEdGV4dBIUCgVjb2xvchgCIAEoCVIFY29sb3'
        'I=');

@$core.Deprecated('Use imageSegmentDescriptor instead')
const ImageSegment$json = {
  '1': 'ImageSegment',
  '2': [
    {'1': 'cdnNode', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.ImageCdnNode', '10': 'cdnNode'},
    {'1': 'alternativeText', '3': 2, '4': 1, '5': 9, '10': 'alternativeText'},
    {'1': 'alternativeColor', '3': 3, '4': 1, '5': 9, '10': 'alternativeColor'},
  ],
};

/// Descriptor for `ImageSegment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageSegmentDescriptor =
    $convert.base64Decode('CgxJbWFnZVNlZ21lbnQSMQoHY2RuTm9kZRgBIAEoCzIXLkFjRnVuUGFjay5JbWFnZUNkbk5vZG'
        'VSB2Nkbk5vZGUSKAoPYWx0ZXJuYXRpdmVUZXh0GAIgASgJUg9hbHRlcm5hdGl2ZVRleHQSKgoQ'
        'YWx0ZXJuYXRpdmVDb2xvchgDIAEoCVIQYWx0ZXJuYXRpdmVDb2xvcg==');

@$core.Deprecated('Use commonNotifySignalKickedOutDescriptor instead')
const CommonNotifySignalKickedOut$json = {
  '1': 'CommonNotifySignalKickedOut',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `CommonNotifySignalKickedOut`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonNotifySignalKickedOutDescriptor =
    $convert.base64Decode('ChtDb21tb25Ob3RpZnlTaWduYWxLaWNrZWRPdXQSFgoGcmVhc29uGAEgASgJUgZyZWFzb24=');

@$core.Deprecated('Use commonNotifySignalViolationAlertDescriptor instead')
const CommonNotifySignalViolationAlert$json = {
  '1': 'CommonNotifySignalViolationAlert',
  '2': [
    {'1': 'violationContent', '3': 1, '4': 1, '5': 9, '10': 'violationContent'},
  ],
};

/// Descriptor for `CommonNotifySignalViolationAlert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonNotifySignalViolationAlertDescriptor =
    $convert.base64Decode('CiBDb21tb25Ob3RpZnlTaWduYWxWaW9sYXRpb25BbGVydBIqChB2aW9sYXRpb25Db250ZW50GA'
        'EgASgJUhB2aW9sYXRpb25Db250ZW50');

@$core.Deprecated('Use commonStateSignalCurrentRedpackListDescriptor instead')
const CommonStateSignalCurrentRedpackList$json = {
  '1': 'CommonStateSignalCurrentRedpackList',
};

/// Descriptor for `CommonStateSignalCurrentRedpackList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalCurrentRedpackListDescriptor =
    $convert.base64Decode('CiNDb21tb25TdGF0ZVNpZ25hbEN1cnJlbnRSZWRwYWNrTGlzdA==');

@$core.Deprecated('Use commonStateSignalRecentCommentDescriptor instead')
const CommonStateSignalRecentComment$json = {
  '1': 'CommonStateSignalRecentComment',
  '2': [
    {'1': 'comment', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.CommonActionSignalComment', '10': 'comment'},
  ],
};

/// Descriptor for `CommonStateSignalRecentComment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalRecentCommentDescriptor =
    $convert.base64Decode('Ch5Db21tb25TdGF0ZVNpZ25hbFJlY2VudENvbW1lbnQSPgoHY29tbWVudBgBIAEoCzIkLkFjRn'
        'VuUGFjay5Db21tb25BY3Rpb25TaWduYWxDb21tZW50Ugdjb21tZW50');

@$core.Deprecated('Use commonStateSignalChatReadyDescriptor instead')
const CommonStateSignalChatReady$json = {
  '1': 'CommonStateSignalChatReady',
  '2': [
    {'1': 'chatId', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'guestUserInfo', '3': 2, '4': 1, '5': 11, '6': '.AcFunPack.ZtLiveUserInfo', '10': 'guestUserInfo'},
    {'1': 'mediaType', '3': 3, '4': 1, '5': 5, '10': 'mediaType'},
  ],
};

/// Descriptor for `CommonStateSignalChatReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalChatReadyDescriptor =
    $convert.base64Decode('ChpDb21tb25TdGF0ZVNpZ25hbENoYXRSZWFkeRIWCgZjaGF0SWQYASABKAlSBmNoYXRJZBI/Cg'
        '1ndWVzdFVzZXJJbmZvGAIgASgLMhkuQWNGdW5QYWNrLlp0TGl2ZVVzZXJJbmZvUg1ndWVzdFVz'
        'ZXJJbmZvEhwKCW1lZGlhVHlwZRgDIAEoBVIJbWVkaWFUeXBl');

@$core.Deprecated('Use commonStateSignalChatEndDescriptor instead')
const CommonStateSignalChatEnd$json = {
  '1': 'CommonStateSignalChatEnd',
  '2': [
    {'1': 'chatId', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'endType', '3': 2, '4': 1, '5': 5, '10': 'endType'},
  ],
};

/// Descriptor for `CommonStateSignalChatEnd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonStateSignalChatEndDescriptor =
    $convert.base64Decode('ChhDb21tb25TdGF0ZVNpZ25hbENoYXRFbmQSFgoGY2hhdElkGAEgASgJUgZjaGF0SWQSGAoHZW'
        '5kVHlwZRgCIAEoBVIHZW5kVHlwZQ==');

@$core.Deprecated('Use acfunActionSignalThrowBananaDescriptor instead')
const AcfunActionSignalThrowBanana$json = {
  '1': 'AcfunActionSignalThrowBanana',
  '2': [
    {'1': 'visitor', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.UserInfo', '10': 'visitor'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
    {'1': 'sendTimeMs', '3': 3, '4': 1, '5': 4, '10': 'sendTimeMs'},
  ],
};

/// Descriptor for `AcfunActionSignalThrowBanana`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acfunActionSignalThrowBananaDescriptor =
    $convert.base64Decode('ChxBY2Z1bkFjdGlvblNpZ25hbFRocm93QmFuYW5hEi0KB3Zpc2l0b3IYASABKAsyEy5BY0Z1bl'
        'BhY2suVXNlckluZm9SB3Zpc2l0b3ISFAoFY291bnQYAiABKAVSBWNvdW50Eh4KCnNlbmRUaW1l'
        'TXMYAyABKARSCnNlbmRUaW1lTXM=');

@$core.Deprecated('Use acfunStateSignalDisplayInfoDescriptor instead')
const AcfunStateSignalDisplayInfo$json = {
  '1': 'AcfunStateSignalDisplayInfo',
  '2': [
    {'1': 'bananaCount', '3': 1, '4': 1, '5': 9, '10': 'bananaCount'},
  ],
};

/// Descriptor for `AcfunStateSignalDisplayInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acfunStateSignalDisplayInfoDescriptor =
    $convert.base64Decode('ChtBY2Z1blN0YXRlU2lnbmFsRGlzcGxheUluZm8SIAoLYmFuYW5hQ291bnQYASABKAlSC2Jhbm'
        'FuYUNvdW50');

@$core.Deprecated('Use acfunActionSignalJoinClubDescriptor instead')
const AcfunActionSignalJoinClub$json = {
  '1': 'AcfunActionSignalJoinClub',
  '2': [
    {'1': 'fansInfo', '3': 1, '4': 1, '5': 11, '6': '.AcFunPack.UserInfo', '10': 'fansInfo'},
    {'1': 'uperInfo', '3': 2, '4': 1, '5': 11, '6': '.AcFunPack.UserInfo', '10': 'uperInfo'},
    {'1': 'joinTimeMs', '3': 3, '4': 1, '5': 4, '10': 'joinTimeMs'},
  ],
};

/// Descriptor for `AcfunActionSignalJoinClub`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acfunActionSignalJoinClubDescriptor =
    $convert.base64Decode('ChlBY2Z1bkFjdGlvblNpZ25hbEpvaW5DbHViEi8KCGZhbnNJbmZvGAEgASgLMhMuQWNGdW5QYW'
        'NrLlVzZXJJbmZvUghmYW5zSW5mbxIvCgh1cGVySW5mbxgCIAEoCzITLkFjRnVuUGFjay5Vc2Vy'
        'SW5mb1IIdXBlckluZm8SHgoKam9pblRpbWVNcxgDIAEoBFIKam9pblRpbWVNcw==');

@$core.Deprecated('Use ztLiveUserInfoDescriptor instead')
const ZtLiveUserInfo$json = {
  '1': 'ZtLiveUserInfo',
  '2': [
    {'1': 'userId', '3': 1, '4': 1, '5': 4, '10': 'userId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar', '3': 3, '4': 1, '5': 11, '6': '.AcFunPack.ImageCdnNode', '10': 'avatar'},
  ],
};

/// Descriptor for `ZtLiveUserInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ztLiveUserInfoDescriptor =
    $convert.base64Decode('Cg5adExpdmVVc2VySW5mbxIWCgZ1c2VySWQYASABKARSBnVzZXJJZBIaCghuaWNrbmFtZRgCIA'
        'EoCVIIbmlja25hbWUSLwoGYXZhdGFyGAMgASgLMhcuQWNGdW5QYWNrLkltYWdlQ2RuTm9kZVIG'
        'YXZhdGFy');

@$core.Deprecated('Use imageCdnNodeDescriptor instead')
const ImageCdnNode$json = {
  '1': 'ImageCdnNode',
  '2': [
    {'1': 'cdn', '3': 1, '4': 1, '5': 9, '10': 'cdn'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'urlPattern', '3': 3, '4': 1, '5': 9, '10': 'urlPattern'},
  ],
};

/// Descriptor for `ImageCdnNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageCdnNodeDescriptor =
    $convert.base64Decode('CgxJbWFnZUNkbk5vZGUSEAoDY2RuGAEgASgJUgNjZG4SEAoDdXJsGAIgASgJUgN1cmwSHgoKdX'
        'JsUGF0dGVybhgDIAEoCVIKdXJsUGF0dGVybg==');

@$core.Deprecated('Use userInfoDescriptor instead')
const UserInfo$json = {
  '1': 'UserInfo',
  '2': [
    {'1': 'userId', '3': 1, '4': 1, '5': 4, '10': 'userId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `UserInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userInfoDescriptor =
    $convert.base64Decode('CghVc2VySW5mbxIWCgZ1c2VySWQYASABKARSBnVzZXJJZBISCgRuYW1lGAIgASgJUgRuYW1l');
