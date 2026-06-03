//
//  AdtalosMediatomAdapterSupport.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas

/// Mediatom 适配器事件码（与上报服务、`AdtalosAdKit.EventType` 中 Mediatom 段一致）。
enum MediatomAdapterEvent: Int32 {
  case mediatomInit = 490
  case mediatomLoad = 491
  case mediatomShow = 492
  case mediatomDestroy = 493
}

enum AdtalosMediatomMediaPlayerStatus {
  static let loading = 1
  static let started = 2
  static let paused = 3
  static let error = 4
  static let stopped = 5
  static let playing = 6
}

@objc(AdtalosMediatomAdapterSupport)
public final class AdtalosMediatomAdapterSupport: NSObject {
  public static let adapterSDKVersion: String = "1.0.0"

  /// Mediatom 信息流：`adv_place_type` 31 原生自渲染，32 模板（见 `SFAdSourcesModel.h`）
  static let advPlaceNativeSelfRender: Int = 31
  static let advPlaceNativeTemplate: Int = 32

  /// Mediatom 联盟 SDK 竞价（与 `SFAdSourcesModel.h` 中 `SFSDKBidAD` 一致）
  static let sdkBidAdRawValue: UInt = 3

  /// 采集相关配置，默认全部开启，外部可通过静态方法修改
  private static var presetIdfa: String = ""
  private static var acquireIDFA: Bool = true
  private static var acquireIDFV: Bool = true
  private static var acquireUserAgent: Bool = true
  private static var acquireGeoInfo: Bool = true
  private static var acquireInstalledApps: Bool = true
  private static var enableLocalLog: Bool = true
  private static var presetJoinKey: JoinKey? = nil
  private static var presetJoinKey2: JoinKey? = nil

  @objc public static func setIdfa(_ idfa: String) {
    presetIdfa = idfa
  }

  @objc public static func setAcquireIDFA(_ enabled: Bool) {
    acquireIDFA = enabled
  }

  @objc public static func setAcquireIDFV(_ enabled: Bool) {
    acquireIDFV = enabled
  }

  @objc public static func setAcquireUserAgent(_ enabled: Bool) {
    acquireUserAgent = enabled
  }

  @objc public static func setAcquireGeoInfo(_ enabled: Bool) {
    acquireGeoInfo = enabled
  }

  @objc public static func setAcquireInstalledApps(_ enabled: Bool) {
    acquireInstalledApps = enabled
  }

  @objc public static func setEnableLocalLog(_ enabled: Bool) {
    enableLocalLog = enabled
  }

  @objc public static func setJoinKey(_ joinKey: JoinKey?) {
    presetJoinKey = joinKey
  }

  @objc public static func getJoinKey() -> JoinKey? {
    return presetJoinKey
  }

  @objc public static func setJoinKey2(_ joinKey2: JoinKey?) {
    presetJoinKey2 = joinKey2
  }

  @objc public static func getJoinKey2() -> JoinKey? {
    return presetJoinKey2
  }

  @objc public func adapterVersion() -> String {
    AdtalosMediatomAdapterSupport.adapterSDKVersion
  }

  static func parseExt(_ ext: String?) -> [String: Any]? {
    guard let ext, let data = ext.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  /// Mediatom `ext` 中需包含非空字符串 `token`、`appKey`，否则不应调用 `SDK.initialize`。
  static func hasValidAdtalosCredentials(dictionary: [String: Any]) -> Bool {
    let token =
      (dictionary["token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let appKey =
      (dictionary["appKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return !token.isEmpty && !appKey.isEmpty
  }

  /// 首次有效调用会初始化 Adtalos SDK；后续调用被 `SDK.initialize` 忽略。
  static func initializeAdtalosIfNeeded(dictionary: [String: Any]) {
    let token = dictionary["token"] as? String ?? ""
    let appToken = dictionary["appKey"] as? String ?? ""

    var joinKey = presetJoinKey ?? JoinKey()
    var joinKey2 = presetJoinKey2 ?? JoinKey()

    // joinKey 为空时，尝试从 SFNetTool 获取 ADID（CAID）作为 joinKey/joinKey2
    if joinKey.joinKey.isEmpty {
      let selector = Selector(("getADIDValue"))
      if let cls = NSClassFromString("SFNetTool") as? NSObject.Type,
         cls.responds(to: selector),
         let adidJson = cls.perform(selector)?.takeUnretainedValue() as? String,
         let data = adidJson.data(using: .utf8),
         let entries = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
        if let first = entries.first,
           let caid = first["caid"] as? String,
           let version = first["version"] as? String {
          joinKey = JoinKey(joinKey: caid, version: version)
        }
        if entries.count > 1,
           joinKey2.joinKey.isEmpty,
           let caid = entries[1]["caid"] as? String,
           let version = entries[1]["version"] as? String {
          joinKey2 = JoinKey(joinKey: caid, version: version)
        }
      }
    }
    
    let config = Configuration(
      token: token,
      appToken: appToken,
      idfa: presetIdfa,
      acquireIDFA: acquireIDFA,
      acquireIDFV: acquireIDFV,
      acquireUserAgent: acquireUserAgent,
      acquireGeoInfo: acquireGeoInfo,
      acquireInstalledApps: acquireInstalledApps,
      enableLocalLog: enableLocalLog,
      joinKey: joinKey,
      joinKey2: joinKey2
    )

    SDK.initialize(config)
    EventReporter.apply(
      eventType: MediatomAdapterEvent.mediatomInit.rawValue,
      adToken: "",
      eventID: "",
      requestID: ""
    )
  }

  static func slotId(from dictionary: [String: Any]) -> String {
    dictionary["placeId"] as? String ?? ""
  }

  /// 原生/信息流广告位：`ext` 中 `placeId`
  static func nativeSlotId(from dictionary: [String: Any], model: SFAdSourcesModel) -> String {
    let fromExt =
      (dictionary["placeId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? ""
    if !fromExt.isEmpty { return fromExt }
    return model.tagid.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func reportMediatomEvent(_ eventType: MediatomAdapterEvent, ad: BaseAd?) {
    DispatchQueue.main.async {
      EventReporter.apply(
        eventType: eventType.rawValue,
        adToken: ad?.unitID ?? "",
        eventID: ad?.adResponseEventID ?? "",
        requestID: ad?.adResponseRequestID ?? ""
      )
    }
  }

  static func jsonParseError() -> NSError {
    NSError(
      domain: "com.adtalos.mediatomAdapter",
      code: 409,
      userInfo: [NSLocalizedDescriptionKey: "自定义 json 字符串解析有误"]
    )
  }

  static func isSDKBidding(_ model: SFAdSourcesModel) -> Bool {
    model.adType.rawValue == sdkBidAdRawValue
  }
}
