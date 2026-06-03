//
//  AdtalosMediatomInterstitialAdapter.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

@objc(AdtalosMediatomInterstitialAdapter)
public class AdtalosMediatomInterstitialAdapter: SFBaseManager {

  fileprivate var interstitialAd: InterstitialAd?
  private let adListener = AdtalosMediatomInterstitialAdapterListener()

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

      self.interstitialAd = InterstitialAd(unitID: slot)
      self.interstitialAd?.listener = self.adListener
      self.interstitialAd?.autoRetry = 0
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.interstitialAd)
      self.interstitialAd?.load()
    }
  }

  public override func biddingAdFail(withPrice price: String) {
    guard let interstitialAd = self.interstitialAd else {
      return
    }
    interstitialAd.sendLossNotice(.priceLowFilter)
    DispatchQueue.main.async {
      interstitialAd.destroy()
    }
  }

  public override func biddingAdSuccess(withPrice price: String, secondPrice: String) {
    guard let interstitialAd = self.interstitialAd else {
      return
    }
    interstitialAd.sendWinNotice()
  }

  public override func showInterstitialAd() {
    DispatchQueue.main.async { [weak self] in
      guard let self, let ad = self.interstitialAd else { return }
      _ = ad.show()
    }
  }

  public override func deallocAllProperty() {
    let ad = interstitialAd
    interstitialAd = nil
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
    guard let ad = interstitialAd else { return }
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
}

private final class AdtalosMediatomInterstitialAdapterListener: NSObject, Listener {

  weak var manager: AdtalosMediatomInterstitialAdapter?

  func onBeforeRequest() {}

  func onLoaded() {
    manager?.deliverLoaded()
  }

  func onFailedToLoad(_ error: Error) {
    manager?.deliverFailed(error)
  }

  func onRendered() {}

  func onShown() {
    AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomShow, ad: manager?.interstitialAd)
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
