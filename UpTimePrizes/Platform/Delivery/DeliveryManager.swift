import Foundation
import System
#if canImport(BackgroundAssets)
import BackgroundAssets
#endif

// MARK: - DeliveryManager
//
// Brings a bought journey's music onto the phone (delivery memo, 26 Sept):
// one Apple-hosted asset pack per journey, named by its journeyId, holding
// `<journeyId>/<fileStem>.m4a` exactly as the pipeline delivered them. The
// Genesis ships inside the app and is never downloaded.
//
// Every step speaks in the device log under [DELIVERY], on success as well
// as failure (verification protocol, rule 4). Until the packs and the
// downloader extension exist, every request here fails — and says so.

@MainActor
final class DeliveryManager: ObservableObject {

    static let shared = DeliveryManager()

    /// Journeys whose music ships inside the app.
    static let inAppJourneys: Set<String> = ["genesis"]

    @Published private(set) var states: [String: DeliveryState] = [:]

    /// Downloaded song files by file stem (stems are unique in the catalog).
    private var resolved: [String: URL] = [:]
    private let manifest = UpTimeManifest.loadFromBundle()

    func state(for journeyId: String) -> DeliveryState {
        if Self.inAppJourneys.contains(journeyId) { return .inApp }
        return states[journeyId] ?? .notDownloaded
    }

    /// A downloaded song's file, or nil if it is not on this phone. Songs
    /// inside the app are found by the players directly.
    func downloadedURL(fileStem: String) -> URL? {
        resolved[fileStem]
    }

    /// Whether a song can play right now, from the app or from its pack.
    func isPlayable(journeyId: String, fileStem: String) -> Bool {
        if Bundle.main.url(forResource: fileStem, withExtension: "m4a", subdirectory: "Audio/\(journeyId)") != nil {
            return true
        }
        return resolved[fileStem] != nil
    }

    private func stems(for journeyId: String) -> [String] {
        manifest?.songs(forJourneyId: journeyId).map(\.fileStem) ?? []
    }

    // MARK: - What is already here

    /// At launch, and after a restore: which owned journeys' music is on the
    /// phone already. Never starts a download.
    func refresh(ownedJourneyIds: [String]) async {
        for journeyId in ownedJourneyIds where !Self.inAppJourneys.contains(journeyId) {
            if case .arriving = state(for: journeyId) { continue }
            let here = await resolveIfPresent(journeyId: journeyId)
            states[journeyId] = here ? .ready : .notDownloaded
            UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): \(here ? "on this phone" : "not downloaded", privacy: .public)")
        }
    }

    private func resolveIfPresent(journeyId: String) async -> Bool {
        #if canImport(BackgroundAssets)
        if #available(iOS 26.0, *) {
            let manager = AssetPackManager.shared
            guard await manager.assetPackIsAvailableLocally(withID: journeyId) else { return false }
            var found = 0
            let wanted = stems(for: journeyId)
            for stem in wanted {
                if let url = try? await manager.url(for: FilePath("\(journeyId)/\(stem).m4a")) {
                    resolved[stem] = url
                    found += 1
                }
            }
            UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): \(found, privacy: .public)/\(wanted.count, privacy: .public) songs found in its pack")
            return found == wanted.count && found > 0
        }
        #endif
        return false
    }

    // MARK: - Download

    /// Asks Apple for a journey's pack and follows it to the phone.
    func download(journeyId: String) async {
        guard !Self.inAppJourneys.contains(journeyId) else { return }
        if case .arriving = state(for: journeyId) { return }
        #if canImport(BackgroundAssets)
        if #available(iOS 26.0, *) {
            states[journeyId] = .arriving(0)
            UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): asking Apple for its pack")
            let manager = AssetPackManager.shared
            let updates = await manager.statusUpdates(forAssetPackWithID: journeyId)
            let watcher = Task { @MainActor [weak self] in
                for await update in updates {
                    switch update {
                    case .downloading(_, let progress):
                        self?.states[journeyId] = .arriving(progress.fractionCompleted)
                    case .paused:
                        self?.states[journeyId] = .waitingForWiFi
                        UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): paused by the system")
                    default:
                        break
                    }
                }
            }
            do {
                let pack = try await manager.assetPack(withID: journeyId)
                UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): Apple has the pack, \(pack.downloadSize, privacy: .public) bytes")
                try await manager.ensureLocalAvailability(of: pack)
                watcher.cancel()
                let here = await resolveIfPresent(journeyId: journeyId)
                states[journeyId] = here ? .ready : .didNotArrive
                UpTimeLog.delivery.notice("[DELIVERY] \(journeyId, privacy: .public): \(here ? "arrived" : "arrived incomplete", privacy: .public)")
            } catch {
                watcher.cancel()
                states[journeyId] = .didNotArrive
                UpTimeLog.delivery.error("[DELIVERY] \(journeyId, privacy: .public): did not arrive: \(error, privacy: .public)")
            }
            return
        }
        #endif
        states[journeyId] = .didNotArrive
        UpTimeLog.delivery.error("[DELIVERY] \(journeyId, privacy: .public): downloads need iOS 26")
    }
}
