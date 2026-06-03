//
//  AdtalosMediatomBannerAdapter.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

@objc(AdtalosMediatomBannerAdapter)
public class AdtalosMediatomBannerAdapter: SFBaseManager {

  fileprivate var bannerAd: BannerAd?
  fileprivate var parentView: UIView?
  private let adListener = AdtalosMediatomBannerAdapterListener()

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

      let rect = CGRect(origin: .zero, size: self.size)
      self.parentView = UIView(frame: rect)
      self.bannerAd = BannerAd(frame: rect, unitID: slot)
      self.bannerAd?.listener = self.adListener
      self.bannerAd?.autoRetry = 0
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.bannerAd)

      self.bannerAd?.load()
    }
  }

  public override func showBannerAd(with view: UIView) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let banner = self.bannerAd else { return }
      self.parentView?.frame = view.bounds
      if let parent = self.parentView {
        view.addSubview(parent)
      }
      if let v = banner.view {
        v.frame = self.parentView?.bounds ?? view.bounds
        self.parentView?.addSubview(v)
      }
    }
  }

  public override func biddingAdFail(withPrice price: String) {
    guard let bannerAd = self.bannerAd else {
      return
    }
    bannerAd.sendLossNotice(.priceLowFilter)
    DispatchQueue.main.async {
      bannerAd.destroy()
    }
  }

  public override func biddingAdSuccess(withPrice price: String, secondPrice: String) {
    guard let bannerAd = self.bannerAd else {
      return
    }
    bannerAd.sendWinNotice()
  }

  public override func deallocAllProperty() {
    let ad = bannerAd
    bannerAd = nil
    parentView?.removeFromSuperview()
    parentView = nil
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
    guard let banner = bannerAd else { return }
    isValidBidECPM(withPrice: Double(banner.price))
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
    let ad = bannerAd
    bannerAd = nil
    DispatchQueue.main.async {
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomDestroy, ad: ad)
      ad?.destroy()
    }
  }
}

// MARK: - Listener

private final class AdtalosMediatomBannerAdapterListener: NSObject, Listener {

  weak var manager: AdtalosMediatomBannerAdapter?

  func onBeforeRequest() {}

  func onLoaded() {
    guard let manager, let banner = manager.bannerAd, banner.isLoaded else { return }
    DispatchQueue.main.async {
      if let v = banner.view, let parent = manager.parentView {
        v.frame = parent.bounds
        parent.addSubview(v)
      }
      manager.deliverLoaded()
    }
  }

  func onFailedToLoad(_ error: Error) {
    manager?.deliverFailed(error)
  }

  func onRendered() {}

  func onShown() {
    AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomShow, ad: manager?.bannerAd)
    manager?.deliverExposure()
  }

  func onClicked() {
    manager?.deliverClick()
  }

  func onLeftApplication() {}

  func onClosed() {
    manager?.deliverClose()
  }
}
