//
//  AdtalosMediatomNativeAdPayload.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation

/// 挂在 `SFFeedAdData.data` 上，供 `registerAd(for:adData:)` 时取回 `NativeAd`。
@objc(AdtalosMediatomNativeAdPayload)
public final class AdtalosMediatomNativeAdPayload: NSObject {
  @objc public weak var nativeAd: NativeAd?
}
