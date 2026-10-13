import BackgroundAssets
import ExtensionFoundation
import StoreKit
import os

// MARK: - The downloader (Apple-Hosted Background Assets)
//
// iOS runs this small extension on the app's behalf to fetch the paid
// journeys' music from Apple, even when the app is not running. The system
// does the work (StoreDownloaderExtension's default implementation); the app
// asks for a journey's pack after it is bought (DeliveryManager). It shares
// the App Group group.com.uptimeprizes.app with the app — Background Assets
// coordinates the two through it.
//
// One pack per paid journey, named by its journeyId, every pack on demand.

@main
struct DownloaderExtension: StoreDownloaderExtension {

    private static let log = Logger(subsystem: "com.uptimeprizes.app", category: "delivery")

    /// Every pack the app asks for is wanted. Said in the log either way, so
    /// "the downloader ran" can be told apart from "it never ran".
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        Self.log.notice("[DELIVERY] downloader: the system offers pack \(assetPack.id, privacy: .public) — downloading")
        return true
    }
}
