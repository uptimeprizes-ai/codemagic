import Foundation

// MARK: - UpTime manifest (Android schema — uptime_full_manifest.json)
//
// The manifest is the single source of truth, shared byte-for-byte with the
// Android repository (app/src/main/assets/uptime_full_manifest.json).
// Identity is journeyId, never a journey "type". Song order is sortOrder —
// never title or filename; the order carries a tone-and-pace arc.

struct ManifestRegion: Codable, Equatable {
    let startMs: Int
    let endMs: Int
}

struct ManifestJourney: Codable {
    let journeyId: String
    let title: String
    let category: String
    let totalDays: Int
    let productId: String
    let price: String
    let description: String
    let sortOrder: Int
    let packName: String
    let framingLine: String
    let entitlementId: String
}

struct ManifestSong: Codable {
    let id: String
    let journeyId: String
    let category: String
    let subfolder: String
    let fileName: String
    let sortOrder: Int
    let title: String
    let genre: String?
    let lufs: Double?
    let loop1Region: ManifestRegion
    let loop2Region: ManifestRegion
    let fullRegion: ManifestRegion

    /// "bright_side_swing.ogg" → "bright_side_swing". The manifest carries
    /// Android's .ogg names; iOS resolves the same stem as .m4a.
    var fileStem: String {
        (fileName as NSString).deletingPathExtension
    }
}

struct UpTimeManifest: Codable {
    let version: String
    let journeys: [ManifestJourney]
    let songs: [ManifestSong]

    static let resourceName = "uptime_full_manifest"

    static func loadFromBundle() -> UpTimeManifest? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[UpTimeManifest] \(resourceName).json not found in bundle")
            return nil
        }
        return decode(from: data)
    }

    static func decode(from data: Data) -> UpTimeManifest? {
        do {
            return try JSONDecoder().decode(UpTimeManifest.self, from: data)
        } catch {
            print("[UpTimeManifest] decode failed: \(error)")
            return nil
        }
    }

    func journey(withId journeyId: String) -> ManifestJourney? {
        journeys.first { $0.journeyId == journeyId }
    }

    /// Songs for a journey, in manifest sortOrder.
    func songs(forJourneyId journeyId: String) -> [ManifestSong] {
        songs.filter { $0.journeyId == journeyId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The song for a 1-based morning number, wrapping round after the last
    /// song: an 8-song journey replays song 1 on morning 9. The index keeps
    /// moving after completion; it must not freeze.
    func song(forJourneyId journeyId: String, morning: Int) -> ManifestSong? {
        let ordered = songs(forJourneyId: journeyId)
        guard !ordered.isEmpty, morning >= 1 else { return nil }
        return ordered[(morning - 1) % ordered.count]
    }
}
