//
//  AdtalosMediatomNativeAdapter.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

@objc(AdtalosMediatomNativeAdapter)
public class AdtalosMediatomNativeAdapter: SFBaseManager {

  fileprivate var nativeAd: NativeAd?
  fileprivate var feedAd: FeedAd?
  private let adListener = AdtalosMediatomNativeDelegate()
  private var isTemplateMode = false

  public override init() {
    super.init()
    adListener.manager = self
  }

  var currentLoadedAd: BaseAd? {
    nativeAd ?? feedAd
  }

  // MARK: - Load

  public override func loadAD(with model: SFAdSourcesModel) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let dic = AdtalosMediatomAdapterSupport.parseExt(model.ext) else {
        self.fail(model: model, error: AdtalosMediatomAdapterSupport.jsonParseError())
        return
      }
      guard AdtalosMediatomAdapterSupport.hasValidAdtalosCredentials(dictionary: dic) else {
        self.fail(model: model, error: AdtalosMediatomAdapterSupport.jsonParseError())
        return
      }
      AdtalosMediatomAdapterSupport.initializeAdtalosIfNeeded(dictionary: dic)
      let slot = AdtalosMediatomAdapterSupport.nativeSlotId(from: dic, model: model)
      guard !slot.isEmpty else {
        self.fail(model: model, error: AdtalosMediatomAdapterSupport.jsonParseError())
        return
      }

      let placeType = Int(model.adv_place_type)
      self.isTemplateMode = placeType == AdtalosMediatomAdapterSupport.advPlaceNativeTemplate

      if self.isTemplateMode {
        self.nativeAd = nil
        self.feedAd = FeedAd(unitID: slot)
        self.feedAd?.listener = self.adListener
        self.feedAd?.videoListener = self.adListener
        self.feedAd?.autoRetry = 0
        AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.feedAd)
        self.feedAd?.load()
      } else {
        self.feedAd = nil
        self.nativeAd = NativeAd(unitID: slot)
        self.nativeAd?.listener = self.adListener
        self.nativeAd?.videoListener = self.adListener
        self.nativeAd?.autoRetry = 0
        AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.nativeAd)
        self.nativeAd?.load()
      }
    }
  }

  // MARK: - 模板渲染

  public override func renderView(withViewArray viewArray: [Any]) {
    guard let baseModel = baseModel else { return }
    baseModel.type = 8
    baseModel.views = viewArray
    successBlock?(baseModel)
  }

  // MARK: - 自渲染注册

  public override func registerAd(for view: UIView, adData: SFFeedAdData) {
    DispatchQueue.main.async {
      guard let payload = adData.data as? AdtalosMediatomNativeAdPayload,
        let nativeAd = payload.nativeAd,
        let response = nativeAd.nativeResponse
      else { return }
      guard let render = view as? SFNativeAdRenderProtocol else { return }

      if adData.isVideoAd, let videoView = response.videoView, adData.isCustomRender != true {
        guard let main = render.mainImageView() else { return }
        videoView.removeFromSuperview()
        main.addSubview(videoView)
        main.bringSubviewToFront(videoView)
        videoView.frame = main.bounds
      }

      let raw = render.clickViewArray()
      let clickViews: [UIView] =
        (raw as? [UIView])
        ?? (raw as NSArray?)?.compactMap { $0 as? UIView }
        ?? []
      response.registerViews(view, clickViews: clickViews, closeViews: [])
    }
  }

  public override func biddingAdFail(withPrice price: String) {
    guard let ad = self.currentLoadedAd else {
      return
    }
    ad.sendLossNotice(.priceLowFilter)
    DispatchQueue.main.async {
      ad.destroy()
    }
  }

  public override func biddingAdSuccess(withPrice price: String, secondPrice: String) {
    guard let ad = self.currentLoadedAd else {
      return
    }
    ad.sendWinNotice()
  }

  public override func unregisterAdData(_ adData: SFFeedAdData) {
    guard let payload = adData.data as? AdtalosMediatomNativeAdPayload,
      let nativeAd = payload.nativeAd
    else { return }
    DispatchQueue.main.async {
      nativeAd.nativeResponse?.unregisterViews()
    }
  }

  public override func deallocAllProperty() {
    teardownAds()
    super.deallocAllProperty()
  }

  // MARK: - Internal

  func handleNativeOrFeedLoaded() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if self.isTemplateMode {
        self.handleFeedTemplateLoaded()
      } else {
        self.handleNativeSelfRenderLoaded()
      }
    }
  }

  @MainActor
  private func handleFeedTemplateLoaded() {
    guard let baseModel = baseModel, let feedAd = feedAd, feedAd.isLoaded, let adView = feedAd.view
    else {
      deliverInvalidMaterial()
      return
    }
    baseModel.views = [adView]
    isValidBidECPM(withPrice: Double(feedAd.price))
  }

  @MainActor
  private func handleNativeSelfRenderLoaded() {
    guard let baseModel = baseModel, let nativeAd = nativeAd, nativeAd.isLoaded,
      let response = nativeAd.nativeResponse
    else {
      deliverInvalidMaterial()
      return
    }
    let feed = SFFeedAdData()
    feed.isRenderImage = true
    feed.adTitle = response.title
    feed.adContent = response.desc
    feed.buttonText = response.buttonText
    feed.imageUrl = response.imageURL
    feed.iconUrl = response.iconURL
    feed.logoUrl = response.logoURL
    feed.imageWidth = Double(response.imageWidth)
    feed.imageHeight = Double(response.imageHeight)
    if feed.imageHeight > 0 {
      feed.imageRatio = feed.imageWidth / feed.imageHeight
    }
    feed.isVideoAd = response.hasVideo
    feed.videoUrl = response.videoURL
    if let meta = response.videoMetadata {
      feed.videoDuration = Double(meta.duration)
      feed.videoWidth = Double(meta.videoWidth)
      feed.videoHeight = Double(meta.videoHeight)
    }
    if response.hasVideo, let videoView = response.videoView {
      feed.mediaView = videoView
    }
    feed.icon = response.icon
    feed.bgImage = response.image
    feed.logo = response.logo
    feed.adOriginName = "广告"
    feed.adType = baseModel.adv_id
    let payload = AdtalosMediatomNativeAdPayload()
    payload.nativeAd = nativeAd
    feed.data = payload

    baseModel.views = [feed]

    isValidBidECPM(withPrice: Double(nativeAd.price))
  }

  func deliverFailed(_ error: Error) {
    guard let bm = baseModel else { return }
    bm.type = 2
    bm.error = error as NSError
    successBlock?(bm)
  }

  private func deliverInvalidMaterial() {
    guard let bm = baseModel else { return }
    bm.type = 2
    bm.error = NSError(
      domain: "com.adtalos.mediatomAdapter",
      code: 4014,
      userInfo: [NSLocalizedDescriptionKey: "广告素材无效"]
    )
    successBlock?(bm)
  }

  func deliverExposure() {
    guard let bm = baseModel else { return }
    bm.type = 6
    successBlock?(bm)
  }

  func deliverClick() {
    guard let bm = baseModel else { return }
    bm.type = 3
    successBlock?(bm)
  }

  func deliverClose() {
    guard let bm = baseModel else { return }
    bm.type = 5
    successBlock?(bm)
    teardownAds()
  }

  func deliverVideoStatus(_ status: Int) {
    guard let bm = baseModel else { return }
    bm.type = 9
    bm.status = status
    successBlock?(bm)
  }

  private func fail(model: SFAdSourcesModel, error: Error) {
    let target = baseModel ?? model
    target.type = 2
    target.error = error as NSError
    successBlock?(target)
  }

  private func teardownAds() {
    let na = nativeAd
    let fa = feedAd
    nativeAd = nil
    feedAd = nil
    na?.listener = nil
    na?.videoListener = nil
    fa?.listener = nil
    fa?.videoListener = nil
    DispatchQueue.main.async {
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomDestroy, ad: na ?? fa)
      na?.destroy()
      fa?.destroy()
    }
  }
}
