//
//  AdtalosMediatomSplashAdapter.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

@objc(AdtalosMediatomSplashAdapter)
public class AdtalosMediatomSplashAdapter: SFBaseManager {

  fileprivate var splashAd: SplashAd?
  private let adListener = AdtalosMediatomSplashAdapterListener()

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

      self.splashAd = SplashAd(unitID: slot)
      self.splashAd?.listener = self.adListener
      self.splashAd?.autoRetry = 0
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomLoad, ad: self.splashAd)
      self.splashAd?.load()
    }
  }

  public override func showSplashAd(in window: UIWindow, withBottomView bottomView: UIView) {
    DispatchQueue.main.async { [weak self, weak window, weak bottomView] in
      guard let self, let ad = self.splashAd else { return }
      if let bottomView = bottomView, let window = window {
        self.bottomView = bottomView
        window.addSubview(bottomView)
        let size =
          bottomView.bounds.size == .zero
          ? CGSize(width: window.bounds.width, height: 0)
          : bottomView.bounds.size
        bottomView.frame = CGRect(
          x: 0,
          y: window.bounds.height - size.height,
          width: window.bounds.width,
          height: size.height
        )
        _ = ad.show(view: window, frame: CGRect(
          x: 0,
          y: 0,
          width: window.bounds.width,
          height: window.bounds.height - bottomView.frame.height
        ))
        return
      }
      ad.show()
    }
  }

  public override func biddingAdFail(withPrice price: String) {
    guard let splashAd = self.splashAd else {
      return
    }
    splashAd.sendLossNotice(.priceLowFilter)
    DispatchQueue.main.async {
      splashAd.destroy()
    }
  }

  public override func biddingAdSuccess(withPrice price: String, secondPrice: String) {
    guard let splashAd = self.splashAd else {
      return
    }
    splashAd.sendWinNotice()
  }

  public override func deallocAllProperty() {
    let ad = splashAd
    splashAd = nil
    let bottom = bottomView
    bottomView = nil
    DispatchQueue.main.async {
      AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomDestroy, ad: ad)
      ad?.destroy()
      bottom?.removeFromSuperview()
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
    guard let ad = splashAd else { return }
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
    bottomView?.removeFromSuperview()
    bottomView = nil
    baseModel.type = 5
    successBlock?(baseModel)
  }
}

private final class AdtalosMediatomSplashAdapterListener: NSObject, Listener {

  weak var manager: AdtalosMediatomSplashAdapter?

  func onBeforeRequest() {}

  func onLoaded() {
    manager?.deliverLoaded()
  }

  func onFailedToLoad(_ error: Error) {
    manager?.deliverFailed(error)
  }

  func onRendered() {}

  func onShown() {
    AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomShow, ad: manager?.splashAd)
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
