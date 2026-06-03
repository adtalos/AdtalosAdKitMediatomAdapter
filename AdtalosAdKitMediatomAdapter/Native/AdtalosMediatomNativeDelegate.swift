//
//  AdtalosMediatomNativeDelegate.swift
//  AdtalosAdKitMediatomAdapter
//

import AdtalosAdKit
import Foundation
import MSaas
import UIKit

final class AdtalosMediatomNativeDelegate: NSObject, Listener, VideoListener {
  weak var manager: AdtalosMediatomNativeAdapter?

  func onBeforeRequest() {}

  func onLoaded() {
    manager?.handleNativeOrFeedLoaded()
  }

  func onFailedToLoad(_ error: Error) {
    manager?.deliverFailed(error)
  }

  func onRendered() {}

  func onShown() {
    AdtalosMediatomAdapterSupport.reportMediatomEvent(.mediatomShow, ad: manager?.currentLoadedAd)
    manager?.deliverExposure()
  }

  func onClicked() {
    manager?.deliverClick()
  }

  func onLeftApplication() {}

  func onClosed() {
    manager?.deliverClose()
  }

  // MARK: - VideoListener

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
