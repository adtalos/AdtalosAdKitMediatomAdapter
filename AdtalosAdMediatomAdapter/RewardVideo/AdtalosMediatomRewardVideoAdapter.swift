//
//  AdtalosMediatomRewardVideoAdapter.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

@objc(AdtalosMediatomRewardVideoAdapter)
public class AdtalosMediatomRewardVideoAdapter: SFBaseManager {

  fileprivate var rewardVideoAd: RewardVideoAd?
  private let adListener = AdtalosMediatomRewardVideoAdapterListener()

  public override init() {
    super.init()
    adListener.manager = self
  }

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
      let slot = AdtalosMediatomAdapterSupport.slotId(from: dic)
      guard !slot.isEmpty else {
        self.fail(model: model, error: AdtalosMediatomAdapterSupport.jsonParseError())
        return
      }

      self.rewardVideoAd = RewardVideoAd(unitID: slot)
      self.rewardVideoAd?.listener = self.adListener
      self.rewardVideoAd?.videoListener = self.adListener
      self.rewardVideoAd?.autoRetry = 0
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.rewardVideoAd)
      self.rewardVideoAd?.load()
    }
  }

  public override func showRewardVideoAD() {
    DispatchQueue.main.async { [weak self] in
      guard let self, let ad = self.rewardVideoAd else { return }
      if let vc = self.showAdController {
        _ = ad.show(viewController: vc)
      } else {
        _ = ad.show()
      }
    }
  }

  public override func biddingAdFail(withPrice price: String) {
    guard let rewardVideoAd = self.rewardVideoAd else {
      return
    }
    rewardVideoAd.sendLossNotice(.priceLowFilter)
    DispatchQueue.main.async {
      rewardVideoAd.destroy()
    }
  }

  public override func biddingAdSuccess(withPrice price: String, secondPrice: String) {
    guard let rewardVideoAd = self.rewardVideoAd else {
      return
    }
    rewardVideoAd.sendWinNotice()
  }

  public override func deallocAllProperty() {
    let ad = rewardVideoAd
    rewardVideoAd = nil
    DispatchQueue.main.async {
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomDestroy, ad: ad)
      ad?.destroy()
    }
    super.deallocAllProperty()
  }

  fileprivate func fail(model: SFAdSourcesModel, error: Error) {
    let target = baseModel ?? model
    target.type = 2
    target.error = error as NSError
    successBlock?(target)
  }

  fileprivate func deliverLoaded() {
    guard let ad = rewardVideoAd else { return }
    isValidBidECPM(withPrice: Double(ad.price))
  }

  fileprivate func deliverFailed(_ error: Error) {
    guard let baseModel = baseModel else { return }
    baseModel.type = 2
    baseModel.error = error as NSError
    successBlock?(baseModel)
  }

  fileprivate func deliverExposure() {
    guard let baseModel = baseModel else { return }
    baseModel.type = 6
    successBlock?(baseModel)
  }

  fileprivate func deliverClick() {
    guard let baseModel = baseModel else { return }
    baseModel.type = 3
    successBlock?(baseModel)
  }

  fileprivate func deliverClose() {
    guard let baseModel = baseModel else { return }
    baseModel.type = 5
    successBlock?(baseModel)
  }

  fileprivate func deliverReward() {
    guard let baseModel = baseModel else { return }
    baseModel.type = 7
    successBlock?(baseModel)
  }

  fileprivate func deliverVideoStatus(_ status: Int) {
    guard let baseModel = baseModel else { return }
    baseModel.type = 9
    baseModel.status = status
    successBlock?(baseModel)
  }
}

private final class AdtalosMediatomRewardVideoAdapterListener: NSObject, Listener,
  RewardVideoListener,
  VideoListener
{
  weak var manager: AdtalosMediatomRewardVideoAdapter?

  func onBeforeRequest() {}

  func onLoaded() {
    manager?.deliverLoaded()
  }

  func onFailedToLoad(_ error: Error) {
    manager?.deliverFailed(error)
  }

  func onRendered() {}

  func onShown() {
    AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomShow, ad: manager?.rewardVideoAd)
    manager?.deliverExposure()
  }

  func onClicked() {
    manager?.deliverClick()
  }

  func onLeftApplication() {}

  func onClosed() {
    manager?.deliverClose()
  }

  func onRewarded(_ data: String) {
    manager?.deliverReward()
  }

  func onVideoLoad(_ metadata: VideoMetadata) {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.loading)
  }

  func onVideoStart() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.started)
  }

  func onVideoPlay() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.playing)
  }

  func onVideoPause() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.paused)
  }

  func onVideoEnd() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.stopped)
  }

  func onVideoVolumeChange(_ volume: Double, muted: Bool) {}

  func onVideoTimeUpdate(_ currentTime: Double, duration: Double) {}

  func onVideoError() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.error)
  }

  func onVideoBreak() {
    manager?.deliverVideoStatus(AdtalosMediatomMediaPlayerStatus.stopped)
  }
}
