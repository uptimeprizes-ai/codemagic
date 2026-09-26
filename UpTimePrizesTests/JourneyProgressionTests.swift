import XCTest
import SwiftData
import CryptoKit
import AVFoundation
@testable import UpTimePrizes

// MARK: - Fixture manifest
//
// A small Android-schema manifest used to test parsing, ordering and
// wrap-around without depending on the bundled resource. Titles are chosen
// so that alphabetical order differs from sortOrder: sorting by title would
// fail the order tests, as it must (no journey is ever alphabetical).

private let fixtureManifestJSON = """
{
  "version": "2.0",
  "total_songs": 13,
  "generated_at": "test",
  "journeys": [
    { "journeyId": "genesis", "title": "The Genesis", "category": "demo", "totalDays": 9,
      "productId": "", "price": "Free", "description": "d", "sortOrder": 0,
      "packName": "", "framingLine": "f", "entitlementId": "" },
    { "journeyId": "cast-prelude", "title": "The Cast Prelude", "category": "signature", "totalDays": 9,
      "productId": "com.uptime.prizes.signature", "price": "$2.99", "description": "d", "sortOrder": 1,
      "packName": "signature", "framingLine": "f", "entitlementId": "" }
  ],
  "songs": [
    { "id": "g-2", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "zeta.ogg",
      "sortOrder": 2, "title": "Zeta", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 30058}, "loop2Region": {"startMs": 33994, "endMs": 55715},
      "fullRegion": {"startMs": 59737, "endMs": 229592} },
    { "id": "g-1", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "alpha.ogg",
      "sortOrder": 1, "title": "Alpha", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-3", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "mid.ogg",
      "sortOrder": 3, "title": "Mid", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-4", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "d4.ogg",
      "sortOrder": 4, "title": "Beta", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "g-5", "journeyId": "genesis", "category": "demo", "subfolder": "s", "fileName": "d5.ogg",
      "sortOrder": 5, "title": "Yarn", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-1", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp1.ogg",
      "sortOrder": 1, "title": "CP One", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-2", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp2.ogg",
      "sortOrder": 2, "title": "CP Two", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-3", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp3.ogg",
      "sortOrder": 3, "title": "CP Three", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-4", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp4.ogg",
      "sortOrder": 4, "title": "CP Four", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-5", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp5.ogg",
      "sortOrder": 5, "title": "CP Five", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-6", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp6.ogg",
      "sortOrder": 6, "title": "CP Six", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-7", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp7.ogg",
      "sortOrder": 7, "title": "CP Seven", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} },
    { "id": "cp-8", "journeyId": "cast-prelude", "category": "signature", "subfolder": "s", "fileName": "cp8.ogg",
      "sortOrder": 8, "title": "CP Eight", "genre": "g", "lufs": -14.0,
      "loop1Region": {"startMs": 0, "endMs": 100}, "loop2Region": {"startMs": 100, "endMs": 200},
      "fullRegion": {"startMs": 200, "endMs": 300} }
  ]
}
"""

// MARK: - Manifest rules

final class ManifestRulesTests: XCTestCase {

    private var manifest: UpTimeManifest!

    override func setUpWithError() throws {
        manifest = try XCTUnwrap(UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)))
    }

    func testAndroidSchemaParses() {
        XCTAssertEqual(manifest.journeys.count, 2)
        XCTAssertEqual(manifest.songs.count, 13)
        XCTAssertEqual(manifest.journey(withId: "genesis")?.totalDays, 9)
    }

    func testSongOrderIsSortOrderNeverAlphabetical() {
        let titles = manifest.songs(forJourneyId: "genesis").map { $0.title }
        // sortOrder order — the fixture's alphabetical order would be
        // Alpha, Beta, Mid, Yarn, Zeta; the manifest order must win.
        XCTAssertEqual(titles, ["Alpha", "Zeta", "Mid", "Beta", "Yarn"])
    }

    func testMorningLookupWrapsRound() {
        // 5-song Genesis: morning 6 replays song 1; morning 9 is song 4.
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 1)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 6)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 9)?.sortOrder, 4)
        // 8-song journey: morning 9 replays song 1 (the nine-mornings rule).
        XCTAssertEqual(manifest.song(forJourneyId: "cast-prelude", morning: 9)?.sortOrder, 1)
        XCTAssertEqual(manifest.song(forJourneyId: "cast-prelude", morning: 8)?.sortOrder, 8)
    }

    func testMorningLookupNeverFreezesAfterCompletion() {
        // Way past completion the index still resolves, wrapping round.
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 23)?.sortOrder, 3)
        XCTAssertNotNil(manifest.song(forJourneyId: "cast-prelude", morning: 100))
    }

    func testFileStemStripsExtension() {
        XCTAssertEqual(manifest.song(forJourneyId: "genesis", morning: 2)?.fileStem, "zeta")
    }

    func testRealRegionsAreCarried() throws {
        let zeta = try XCTUnwrap(manifest.song(forJourneyId: "genesis", morning: 2))
        XCTAssertEqual(zeta.loop1Region, ManifestRegion(startMs: 0, endMs: 30058))
        XCTAssertEqual(zeta.loop2Region, ManifestRegion(startMs: 33994, endMs: 55715))
        XCTAssertEqual(zeta.fullRegion, ManifestRegion(startMs: 59737, endMs: 229592))
    }
}

// MARK: - Bundled manifest
//
// The test host IS the app, so Bundle.main is the app bundle. If the manifest
// is missing here, the shipped app is broken — that is a failure, never a skip.

final class BundledManifestTests: XCTestCase {

    func testBundledManifestMatchesAndroidCatalog() throws {
        let manifest = try XCTUnwrap(
            UpTimeManifest.loadFromBundle(),
            "uptime_full_manifest.json is missing from the app bundle — the packaging is broken"
        )
        // Manifest v3.0 (Android, 2026-09-24): seven journeys, ninety songs.
        XCTAssertEqual(manifest.journeys.count, 7, "Expected the full catalog including The Overture")
        XCTAssertEqual(manifest.songs.count, 90)
        XCTAssertEqual(manifest.songs(forJourneyId: "genesis").count, 5)
        // The Overture: 48 songs, 49 mornings — morning 49 replays song 1.
        XCTAssertEqual(manifest.songs(forJourneyId: "overture").count, 48)
        XCTAssertEqual(manifest.journey(withId: "overture")?.totalDays, 49)
        XCTAssertEqual(manifest.song(forJourneyId: "overture", morning: 49)?.sortOrder, 1)
        // Retired store ids ride along so old purchases can still restore.
        XCTAssertEqual(manifest.journey(withId: "cast-prelude")?.legacyProductIds, ["com.uptime.prizes.signature"])
        XCTAssertEqual(manifest.journey(withId: "catalyst")?.legacyProductIds, ["com.uptime.prizes.special_day"])
        // The placeholder pattern from the June build (0/30000/60000 for every
        // song) must never come back: regions are per-song measurements.
        let placeholderCount = manifest.songs.filter {
            $0.loop1Region == ManifestRegion(startMs: 0, endMs: 30000) &&
            $0.loop2Region == ManifestRegion(startMs: 30000, endMs: 60000)
        }.count
        XCTAssertEqual(placeholderCount, 0, "Found placeholder regions — real measurements required")
    }
}

// MARK: - Bundled audio
//
// Builds #1–20 shipped a ~3 MB ipa with NO audio in it — the project config
// silently dropped every song, and nothing failed. This test makes that
// impossible to repeat: it resolves each Genesis file through the exact
// subdirectory the app plays from, and verifies the bytes are the pipeline's
// approved encodes (SHA-256 from 01_IOS_M4A/genesis/ios_regions.json).

final class BundledAudioTests: XCTestCase {

    private let expected: [(stem: String, sha256: String)] = [
        ("bright_side_swing", "02a71fd10c0fddf4bafe06c414ef37b3aa6de2a518866bede3601e2fdf5d12b9"),
        ("the_uptime_swing", "2a823fdc6b4f1c96232250d6a3447d7ae38e94fd54393793db9ed565317922a7"),
        ("wake_up", "54f0a283694bb0bdd214fb6a82ccd705dfa3c4f9df26334bf2e0943105cc2fad"),
        ("no_permission", "f71f52f06b0c2adf9dea9519b66fb2dc5b088068ee208d3d60dbd1fbd0af247d"),
        ("uptime_go_go", "0f68976ffafc923aac82eff58e58857ebefec09390ec17e44f40abc020df208b")
    ]

    func testAllGenesisAudioIsInTheBundle() throws {
        for entry in expected {
            let url = Bundle.main.url(
                forResource: entry.stem, withExtension: "m4a", subdirectory: "Audio/genesis"
            )
            XCTAssertNotNil(url, "\(entry.stem).m4a missing from Audio/genesis — the packaging flaw is back")
        }
    }

    func testGenesisAudioIsThePipelinesApprovedEncode() throws {
        for entry in expected {
            guard let url = Bundle.main.url(
                forResource: entry.stem, withExtension: "m4a", subdirectory: "Audio/genesis"
            ) else { continue } // absence already failed above
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 1_000_000, "\(entry.stem).m4a is implausibly small")
            let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, entry.sha256, "\(entry.stem).m4a is not the pipeline's approved encode")
        }
    }

    /// The AlarmKit doorbell: at the bundle root (where AlertSound.named
    /// looks), exactly the file the founder delivered, and under AlarmKit's
    /// 30-second cap.
    func testDoorbellIsBundledUnchangedAndUnderThirtySeconds() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "door_bell_006", withExtension: "m4a"),
            "door_bell_006.m4a missing from the bundle root — AlarmKit would fall back to the system sound"
        )
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "0f5835e9d2cfde7b525daf838e9e4d57f266b0bb70662024723647fa2b6d7add",
                       "door_bell_006.m4a is not the file the founder delivered")
        let duration = try AVAudioPlayer(contentsOf: url).duration
        XCTAssertGreaterThan(duration, 1)
        XCTAssertLessThan(duration, 30, "AlarmKit plays custom sounds only under 30 seconds")
    }

    func testEveryGenesisManifestSongResolvesToBundledAudio() throws {
        let manifest = try XCTUnwrap(UpTimeManifest.loadFromBundle())
        for song in manifest.songs(forJourneyId: "genesis") {
            let url = Bundle.main.url(
                forResource: song.fileStem, withExtension: "m4a", subdirectory: "Audio/genesis"
            )
            XCTAssertNotNil(url, "Manifest song \(song.id) (\(song.fileStem)) has no bundled audio")
        }
    }
}

// MARK: - Journey progression and independence

@MainActor
final class JourneyProgressionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var alarmEngine: AlarmEngine!

    /// Fixed date anchor; each counted morning advances one calendar day, so
    /// the one-morning-per-day rule never collides inside a test.
    private var testDay = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self, MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        seedFromFixture()
        alarmEngine = AlarmEngine(context: context)
    }

    /// A full counted morning: new session, sounded audio, next calendar day.
    @discardableResult
    private func dismissMorning(reachedPrize: Bool = true) -> AlarmEngine.MorningOutcome? {
        alarmEngine.beginAlarmSession()
        let outcome = alarmEngine.handleAlarmDismissed(
            audioSounded: true,
            stageAtDismiss: reachedPrize ? "prize" : "invite",
            reachedPrize: reachedPrize,
            date: testDay
        )
        testDay = Calendar.current.date(byAdding: .day, value: 1, to: testDay)!
        return outcome
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        alarmEngine = nil
    }

    /// Seeds journeys directly from the fixture manifest, mirroring
    /// DatabaseSeeder's rules (which read the bundled file).
    private func seedFromFixture() {
        guard let manifest = UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)) else { return }
        context.insert(DemoStateEntity())
        context.insert(AlarmEntity())
        for mj in manifest.journeys {
            let isGenesis = mj.journeyId == "genesis"
            context.insert(JourneyEntity(
                id: mj.journeyId, title: mj.title, descriptionText: mj.description,
                framingLine: mj.framingLine, totalDays: mj.totalDays, sortOrder: mj.sortOrder,
                packName: mj.packName, productId: mj.productId, entitlementId: mj.entitlementId,
                isPurchaseOffered: !mj.productId.isEmpty,
                isActive: isGenesis,
                purchaseState: isGenesis ? "ACTIVE_IN_PROGRESS" : "NOT_OWNED",
                completedDays: 0, currentDay: 1
            ))
        }
        for ms in manifest.songs {
            context.insert(SongEntity(
                id: ms.id, title: ms.title, journeyId: ms.journeyId,
                sortOrder: ms.sortOrder, fileStem: ms.fileStem,
                isAvailable: ms.journeyId == "genesis"
            ))
        }
        try? context.save()
    }

    // MARK: Initial state

    func testOnlyGenesisIsActiveOnFirstLaunch() throws {
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        let active = journeys.filter { $0.isActive }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, "genesis")
    }

    func testGenesisSongsAvailableOthersNot() throws {
        let songs = try context.fetch(FetchDescriptor<SongEntity>())
        XCTAssertTrue(songs.filter { $0.journeyId == "genesis" }.allSatisfy { $0.isAvailable })
        XCTAssertTrue(songs.filter { $0.journeyId != "genesis" }.allSatisfy { !$0.isAvailable })
    }

    func testDiscoverLockedInitially() throws {
        let demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertFalse(demo?.isPurchaseOffered ?? true)
    }

    // MARK: Progression

    func testDismissIncrementsCountAndMovesMorningForward() throws {
        dismissMorning()
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 1)
        XCTAssertEqual(genesis?.currentDay, 2)
    }

    func testNineDismissalsUnlockDiscover() throws {
        for _ in 0..<9 { dismissMorning() }
        let demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false)
    }

    func testCompletionSetsUnlockedStateAndIndexKeepsMoving() throws {
        for _ in 0..<9 { dismissMorning() }
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.purchaseState, "UNLOCKED_FOR_PLAYBACK")
        // The morning number must keep moving after completion — never freeze.
        dismissMorning()
        XCTAssertEqual(genesis?.currentDay, 11)
    }

    // MARK: Independence

    func testDismissingGenesisNeverAdvancesAnotherJourney() throws {
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "cast-prelude" })
        if let castPrelude = try context.fetch(fetch).first {
            castPrelude.purchaseState = "ACTIVE_IN_PROGRESS"
            castPrelude.completedDays = 5
            castPrelude.isActive = false
        }
        try context.save()

        dismissMorning() // Genesis is active

        let castPrelude = try context.fetch(fetch).first
        XCTAssertEqual(castPrelude?.completedDays, 5)
    }

    func testSwitchingJourneysPreservesProgress() throws {
        for _ in 0..<3 { dismissMorning() }
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        for journey in journeys { journey.isActive = journey.id == "cast-prelude" }
        try context.save()

        let genesis = journeys.first { $0.id == "genesis" }
        XCTAssertEqual(genesis?.completedDays, 3, "Switching must preserve each journey's place")
        XCTAssertEqual(journeys.filter { $0.isActive }.count, 1)
    }

    // MARK: StageCoordinator

    func testStageCoordinatorAdvancesInOrder() {
        let coordinator = StageCoordinator()
        XCTAssertEqual(coordinator.currentStage, .stage1)
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage2)
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage3)
    }

    func testStageCoordinatorReplayDoesNotAdvanceBeyond() {
        let coordinator = StageCoordinator()
        coordinator.advanceStage()
        coordinator.advanceStage()
        coordinator.advanceStage()
        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .replay)
    }

    // MARK: Counting rules (§2.4)

    func testNothingSoundedNothingCounted() throws {
        alarmEngine.beginAlarmSession()
        let outcome = alarmEngine.handleAlarmDismissed(
            audioSounded: false, stageAtDismiss: "invite", reachedPrize: false, date: testDay
        )
        XCTAssertNil(outcome, "No Prize screen without a counted morning")
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 0)
        XCTAssertEqual(MorningLedger(context: context).soundedMorningsCount(), 0)
    }

    func testSecondAlarmSameDayNeverCountsTwice() throws {
        let day = testDay
        alarmEngine.beginAlarmSession()
        XCTAssertNotNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day
        ))
        alarmEngine.beginAlarmSession() // a new session, same calendar day
        XCTAssertNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day
        ))
        let genesis = try context.fetch(
            FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        ).first
        XCTAssertEqual(genesis?.completedDays, 1)
    }

    func testOneRecordedMorningPerAlarmSession() throws {
        alarmEngine.beginAlarmSession()
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: testDay)!
        XCTAssertNotNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: testDay
        ))
        // Same session, even on a new calendar day (midnight crossed): no second count.
        XCTAssertNil(alarmEngine.handleAlarmDismissed(
            audioSounded: true, stageAtDismiss: "prize", reachedPrize: true, date: day2
        ))
    }

    func testCatalystMorningHoldsStreakAndAdvancesNoJourney() throws {
        // Add the Catalyst journey and make it active.
        context.insert(JourneyEntity(
            id: "catalyst", title: "The Catalyst Tracks", descriptionText: "d",
            framingLine: "f", totalDays: 5, sortOrder: 4, packName: "special_day",
            productId: "com.uptime.prizes.special_day", entitlementId: "",
            isPurchaseOffered: true, isActive: false,
            purchaseState: "UNLOCKED_FOR_PLAYBACK", completedDays: 0, currentDay: 1
        ))
        let journeys = try context.fetch(FetchDescriptor<JourneyEntity>())
        for j in journeys { j.isActive = j.id == "catalyst" }
        try context.save()

        let outcome = try XCTUnwrap(dismissMorning())
        XCTAssertTrue(outcome.heldStreakOnly)
        XCTAssertEqual(outcome.journeyTitle, "The Catalyst Tracks")

        // No journey count moved anywhere.
        for j in try context.fetch(FetchDescriptor<JourneyEntity>()) {
            XCTAssertEqual(j.completedDays, 0)
        }
    }

    // MARK: Nine mornings (founder, 2026-09-15; Android 49/50 parity)

    func testDiscoverOpensAfterNinthCountedMorningNotEighth() throws {
        // The gate reads COUNTED mornings, never "the day you are on" —
        // Android opened a morning early by reading the latter.
        for _ in 0..<8 { dismissMorning() }
        var demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertFalse(demo?.isPurchaseOffered ?? true, "Eight counted mornings must not open Discover")

        dismissMorning() // the ninth
        demo = try context.fetch(FetchDescriptor<DemoStateEntity>()).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false, "The ninth counted morning opens Discover")
    }

    func testJourneyLengthResyncNeverRelocksAndRidesCountUp() throws {
        // Simulate a device that finished The Cast Prelude at 8/8 before the
        // manifest grew the cycle to 9 (and one journey still in progress).
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "cast-prelude" })
        let finished = try XCTUnwrap(try context.fetch(fetch).first)
        finished.purchaseState = "UNLOCKED_FOR_PLAYBACK"
        finished.completedDays = 8
        finished.totalDays = 8

        let genesisFetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "genesis" })
        let inProgress = try XCTUnwrap(try context.fetch(genesisFetch).first)
        inProgress.completedDays = 3
        try context.save()

        let manifest = try XCTUnwrap(UpTimeManifest.decode(from: Data(fixtureManifestJSON.utf8)))
        DatabaseSeeder.syncJourneys(from: manifest, context: context)

        // Finished journey: never re-locks; its count rises with its total.
        XCTAssertEqual(finished.totalDays, 9)
        XCTAssertEqual(finished.completedDays, 9, "8/8 must read 9/9, still complete")
        XCTAssertEqual(finished.purchaseState, "UNLOCKED_FOR_PLAYBACK")

        // In-progress journey: real count preserved, simply further to go.
        XCTAssertEqual(inProgress.totalDays, 9)
        XCTAssertEqual(inProgress.completedDays, 3)
    }
}

// MARK: - Snooze rules (§2.1, §2.5)

@MainActor
final class SnoozeRulesTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var engine: AlarmEngine!

    override func setUpWithError() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self, MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        context.insert(AlarmEntity())
        try context.save()
        engine = AlarmEngine(context: context)
    }

    func testSnoozeReturnsOneStageFurther() {
        XCTAssertEqual(AlarmEngine.stageAfterSnooze("invite"), "nudge")
        XCTAssertEqual(AlarmEngine.stageAfterSnooze("nudge"), "prize")
        // There is no Snooze in the Prize stage; the mapping must not move it.
        XCTAssertEqual(AlarmEngine.stageAfterSnooze("prize"), "prize")
    }

    func testDefaultSnoozeIsTenMinutes() {
        XCTAssertEqual(engine.snoozeMinutes, 10)
        XCTAssertEqual(AlarmEngine.snoozeOptions, [5, 10, 15, 20, 30])
    }

    func testSnoozePersistsResumeStageWithValidity() throws {
        engine.snoozeAlarm(stageAtSnooze: "invite")
        let alarm = try XCTUnwrap(try context.fetch(FetchDescriptor<AlarmEntity>()).first)
        XCTAssertEqual(alarm.resumeStage, "nudge")
        XCTAssertGreaterThan(alarm.resumeStageValidUntil, Date())
    }

    func testResumeIsConsumedOnceAndOnlyWhileValid() throws {
        let alarm = try XCTUnwrap(try context.fetch(FetchDescriptor<AlarmEntity>()).first)

        // Valid resume: returned once, then reset.
        alarm.resumeStage = "nudge"
        alarm.resumeStageValidUntil = Date().addingTimeInterval(600)
        try context.save()
        XCTAssertEqual(engine.consumeResumeStage(), "nudge")
        XCTAssertEqual(engine.consumeResumeStage(), "invite", "A resume must be consumed exactly once")

        // Expired resume: a stale snooze must never leak into the next morning.
        alarm.resumeStage = "prize"
        alarm.resumeStageValidUntil = Date().addingTimeInterval(-60)
        try context.save()
        XCTAssertEqual(engine.consumeResumeStage(), "invite")
    }

    func testAutoSnoozeIsMarkedUsedAndResetsOnAFreshMorning() throws {
        XCTAssertFalse(engine.autoSnoozeUsed)

        engine.autoSnooze(stageAtSnooze: "invite")
        XCTAssertTrue(engine.autoSnoozeUsed, "One auto-snooze per alarm, persisted")

        let alarm = try XCTUnwrap(try context.fetch(FetchDescriptor<AlarmEntity>()).first)
        XCTAssertEqual(alarm.resumeStage, "nudge", "Auto-snooze rides the same path as a person's snooze")

        // The snooze return (resumes at the Nudge) must NOT reset the allowance…
        XCTAssertEqual(engine.consumeResumeStage(), "nudge")
        XCTAssertTrue(engine.autoSnoozeUsed)

        // …but the next fresh morning (starting at the Invite) does.
        XCTAssertEqual(engine.consumeResumeStage(), "invite")
        XCTAssertFalse(engine.autoSnoozeUsed)
    }
}

// MARK: - Streak rules (§2.4)

@MainActor
final class StreakTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var ledger: MorningLedger!

    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: anchor)!
    }

    override func setUpWithError() throws {
        let schema = Schema([MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        ledger = MorningLedger(context: context)
    }

    private func count(_ offset: Int, catalyst: Bool = false) {
        ledger.record(
            date: day(offset), journeyId: catalyst ? "catalyst" : "genesis",
            stageAtDismiss: "prize", reachedPrize: true,
            heldStreakOnly: catalyst, advancedJourney: !catalyst
        )
    }

    func testConsecutiveMorningsCount() {
        count(0); count(1); count(2)
        XCTAssertEqual(ledger.streak(asOf: day(2)), 3)
    }

    func testStreakShowsZeroTheMomentItIsBroken() {
        count(0); count(1)
        // Last counted day is two days before "today" — not live, shows 0.
        XCTAssertEqual(ledger.streak(asOf: day(3)), 0)
    }

    func testYesterdayKeepsTheRunLive() {
        count(0); count(1)
        XCTAssertEqual(ledger.streak(asOf: day(2)), 2)
    }

    func testCatalystMorningHoldsWithoutExtending() {
        count(0)
        count(1, catalyst: true)
        count(2)
        // Three counted days, but the Catalyst day adds nothing: streak is 2.
        XCTAssertEqual(ledger.streak(asOf: day(2)), 2)
    }

    func testGapBreaksEvenWithCatalystEitherSide() {
        count(0)
        // day 1 has no morning at all
        count(2, catalyst: true)
        count(3)
        // Walk back from day 3: counted day 3 (1), catalyst day 2 (holds),
        // day 1 empty → stop. The day-0 morning is beyond the break.
        XCTAssertEqual(ledger.streak(asOf: day(3)), 1)
    }
}

// MARK: - Prize screen copy selection (§2.5, §2.9)

final class PrizeCopyTests: XCTestCase {

    private func outcome(
        title: String = "The Genesis", morning: Int = 3, total: Int = 9,
        complete: Bool = false, reachedPrize: Bool = false, heldOnly: Bool = false,
        unanswered: Bool = false
    ) -> AlarmEngine.MorningOutcome {
        AlarmEngine.MorningOutcome(
            journeyTitle: title, morningNumber: morning, totalDays: total,
            journeyComplete: complete, reachedPrize: reachedPrize, heldStreakOnly: heldOnly,
            wasUnanswered: unanswered
        )
    }

    func testHeaderMorningXofY() {
        XCTAssertEqual(outcome().prizeHeader, "The Genesis · Morning 3 of 9")
    }

    func testHeaderCompleteOnLastMorning() {
        XCTAssertEqual(outcome(morning: 9, complete: true).prizeHeader, "The Genesis · Complete")
    }

    func testHeaderJourneyNameAloneForCatalyst() {
        XCTAssertEqual(outcome(title: "The Catalyst Tracks", heldOnly: true).prizeHeader, "The Catalyst Tracks")
    }

    func testMessagePrizeReached() {
        XCTAssertEqual(outcome(reachedPrize: true).prizeMessage, CuratorCopy.prizeMessagePrizeReached)
    }

    func testMessageDismissedEarly() {
        XCTAssertEqual(outcome().prizeMessage, CuratorCopy.prizeMessageDismissedEarly)
    }

    func testMessageJourneyCompleteWinsOverPrize() {
        XCTAssertEqual(outcome(complete: true, reachedPrize: true).prizeMessage, CuratorCopy.prizeMessageJourneyComplete)
    }

    func testMessageCatalystWinsOverEverything() {
        XCTAssertEqual(outcome(complete: true, reachedPrize: true, heldOnly: true).prizeMessage, CuratorCopy.prizeMessageCatalystOrFallback)
    }

    // Curator, 2026-09-23: the unheard morning leads; fact-lines stack under it.

    func testUnheardMorningLeadsAlone() {
        XCTAssertEqual(outcome(unanswered: true).prizeMessage, CuratorCopy.prizeMessageUnheard)
    }

    func testUnheardStacksWithJourneyComplete() {
        XCTAssertEqual(
            outcome(complete: true, unanswered: true).prizeMessage,
            CuratorCopy.prizeMessageUnheard + "\n\n" + CuratorCopy.prizeMessageJourneyComplete
        )
    }

    func testUnheardNeverWearsTheExperienceLines() {
        // "The UpTime swing" describes a person who was there; an unheard
        // morning must never claim it, even when the Prize region played out.
        XCTAssertFalse(outcome(reachedPrize: true, unanswered: true).prizeMessage
            .contains(CuratorCopy.prizeMessagePrizeReached))
    }
}

// MARK: - What the Player shows (Android screen map, 2026-09-25)

final class CatalogRulesTests: XCTestCase {

    private func j(_ id: String, total: Int = 9, done: Int = 0, active: Bool = false,
                   state: String = "NOT_OWNED", order: Int = 0) -> CatalogRules.JourneyFacts {
        CatalogRules.JourneyFacts(id: id, totalDays: total, completedDays: done, isActive: active,
                                  purchaseState: state, sortOrder: order)
    }

    func testCatalogHiddenUntilTheNinthCountedMorningAndUntilSomethingIsOwned() {
        let owned = [
            j("genesis", done: 9, active: true, state: "ACTIVE_IN_PROGRESS"),
            j("warm-front", state: "ACTIVE_IN_PROGRESS", order: 2)
        ]
        XCTAssertFalse(CatalogRules.showsCatalog(owned, genesisCompletedDays: 8))
        XCTAssertTrue(CatalogRules.showsCatalog(owned, genesisCompletedDays: 9))
        // Day nine alone does not open it: nothing is owned yet.
        let nothingOwned = [j("genesis", done: 9, active: true, state: "ACTIVE_IN_PROGRESS"), j("overture", order: 6)]
        XCTAssertFalse(CatalogRules.showsCatalog(nothingOwned, genesisCompletedDays: 9))
        // The Catalyst alone is enough.
        XCTAssertTrue(CatalogRules.showsCatalog([j("catalyst", total: 5, state: "UNLOCKED_FOR_PLAYBACK")], genesisCompletedDays: 9))
    }

    func testOwnedRowsAreInSortOrderAndNeverGenesisCatalystOrUnowned() {
        let journeys = [
            j("warm-front", state: "ACTIVE_IN_PROGRESS", order: 2),
            j("overture", state: "NOT_OWNED", order: 6),
            j("genesis", done: 9, state: "UNLOCKED_FOR_PLAYBACK", order: 0),
            j("catalyst", total: 5, state: "UNLOCKED_FOR_PLAYBACK", order: 4),
            j("cast-prelude", state: "UNLOCKED_FOR_PLAYBACK", order: 1)
        ]
        XCTAssertEqual(CatalogRules.ownedRows(journeys).map(\.id), ["cast-prelude", "warm-front"])
        XCTAssertTrue(CatalogRules.isCatalystOwned(journeys))
    }

    func testSongsOnlyWhenFinishedExceptCatalystWhenOwnedAndNeverGenesis() {
        XCTAssertFalse(CatalogRules.songsVisible(j("warm-front", done: 4, state: "ACTIVE_IN_PROGRESS")))
        XCTAssertTrue(CatalogRules.songsVisible(j("warm-front", done: 9, state: "UNLOCKED_FOR_PLAYBACK")))
        XCTAssertTrue(CatalogRules.songsVisible(j("catalyst", total: 5, state: "UNLOCKED_FOR_PLAYBACK")))
        XCTAssertFalse(CatalogRules.songsVisible(j("catalyst", total: 5, state: "NOT_OWNED")))
        XCTAssertFalse(CatalogRules.songsVisible(j("genesis", done: 9, state: "UNLOCKED_FOR_PLAYBACK")))
    }

    func testGenesisPill() {
        XCTAssertEqual(CatalogRules.genesisPill(completedDays: 0, currentDay: 1, isActive: true),
                       CatalogRules.Pill(label: "Free", style: .price))
        XCTAssertEqual(CatalogRules.genesisPill(completedDays: 3, currentDay: 4, isActive: true),
                       CatalogRules.Pill(label: "Day 4 of 9", style: .active))
        XCTAssertEqual(CatalogRules.genesisPill(completedDays: 9, currentDay: 10, isActive: true),
                       CatalogRules.Pill(label: "Complete", style: .active))
    }

    func testJourneyPills() {
        XCTAssertEqual(CatalogRules.journeyPill(j("warm-front", done: 2, active: true, state: "ACTIVE_IN_PROGRESS")).label, "Active")
        XCTAssertEqual(CatalogRules.journeyPill(j("warm-front", done: 2, active: false, state: "ACTIVE_IN_PROGRESS")).label, "Owned")
        XCTAssertEqual(CatalogRules.journeyPill(j("warm-front", done: 9, state: "UNLOCKED_FOR_PLAYBACK")).label, "Complete")
    }

    func testDayPillNeverPrintsPastTheEndAndCompleteStandsAlone() {
        let genesis = j("genesis", done: 3, active: true, state: "ACTIVE_IN_PROGRESS")
        let day = CatalogRules.dayCount(genesis, genesisCurrentDay: 4, countedToday: true)
        XCTAssertEqual(CatalogRules.dayPill(genesis, dayCount: day), "DAY 4 / 9")
        let finished = j("genesis", done: 33, state: "UNLOCKED_FOR_PLAYBACK")
        XCTAssertEqual(CatalogRules.dayPill(finished, dayCount: 34), "COMPLETE")
    }

    func testAJourneyShowsTodaysMorningOnceCountedOtherwiseTheNext() {
        let warm = j("warm-front", done: 2, active: true, state: "ACTIVE_IN_PROGRESS")
        XCTAssertEqual(CatalogRules.dayCount(warm, genesisCurrentDay: 10, countedToday: true), 2)
        XCTAssertEqual(CatalogRules.dayCount(warm, genesisCurrentDay: 10, countedToday: false), 3)
        XCTAssertEqual(CatalogRules.progress(dayCount: 3, totalDays: 9), 3.0 / 9.0, accuracy: 0.0001)
        XCTAssertEqual(CatalogRules.progress(dayCount: 40, totalDays: 9), 1)
    }

    func testHomeFormatting() {
        XCTAssertEqual(HomeFormat.clock(hour: 7, minute: 5), "7:05 AM")
        XCTAssertEqual(HomeFormat.clock(hour: 0, minute: 0), "12:00 AM")
        XCTAssertEqual(HomeFormat.clock(hour: 13, minute: 34), "1:34 PM")
        XCTAssertEqual(HomeFormat.repeatLine([6, 2, 4]), "·  MON  WED  FRI  ·")
    }

    func testSettingsNextSoundsLine() {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(timeZone: .current, year: 2026, month: 9, day: 25, hour: 13, minute: 0))!
        let tomorrow = SettingsFormat.nextTrigger(hour: 7, minute: 0, repeatDays: [], now: now, calendar: cal)
        XCTAssertEqual(SettingsFormat.occurrenceText(trigger: tomorrow, now: now, calendar: cal), "Tomorrow morning · in 18h")
        let later = SettingsFormat.nextTrigger(hour: 13, minute: 30, repeatDays: [], now: now, calendar: cal)
        XCTAssertEqual(SettingsFormat.occurrenceText(trigger: later, now: now, calendar: cal), "Today afternoon · in 30m")
        // 2026-09-25 is a Friday; Mondays only → Monday the 28th.
        let monday = SettingsFormat.nextTrigger(hour: 7, minute: 15, repeatDays: [2], now: now, calendar: cal)
        XCTAssertEqual(SettingsFormat.occurrenceText(trigger: monday, now: now, calendar: cal), "Monday morning · in 66h 15m")
        XCTAssertEqual(SettingsFormat.repeatDays([6, 2, 4]), "Mon, Wed, Fri")
    }

    func testDiscoverCountdownLine() {
        XCTAssertEqual(DiscoverView.countdownLine(currentDay: 1), "Eight more mornings until you meet the rest of UpTime Prizes.")
        XCTAssertEqual(DiscoverView.countdownLine(currentDay: 4), "Five more mornings until you meet the rest of UpTime Prizes.")
        XCTAssertEqual(DiscoverView.countdownLine(currentDay: 8), "Tomorrow.")
        XCTAssertEqual(DiscoverView.countdownLine(currentDay: 9), "Today.")
    }
}

// MARK: - Unanswered mornings (founder ruling 2026-09-25: never counted)

final class UnattendedMorningTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(timeZone: .current, year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    // 2026-09-25 is a Friday (weekday 6).
    func testMostRecentOccurrenceIsTodayWhenPassed() {
        let now = date(25, 10, 0)
        XCTAssertEqual(UnattendedMorning.mostRecentOccurrence(before: now, hour: 7, minute: 0, repeatDays: [], calendar: cal), date(25, 7, 0))
    }

    func testMostRecentOccurrenceIsYesterdayWhenNotYetDue() {
        let now = date(25, 6, 0)
        XCTAssertEqual(UnattendedMorning.mostRecentOccurrence(before: now, hour: 7, minute: 0, repeatDays: [], calendar: cal), date(24, 7, 0))
    }

    func testMostRecentOccurrenceHonoursRepeatDays() {
        // Weekdays only (Mon=2 … Fri=6); from Sunday 27th the last is Friday 25th.
        let now = date(27, 10, 0)
        XCTAssertEqual(UnattendedMorning.mostRecentOccurrence(before: now, hour: 7, minute: 0, repeatDays: [2, 3, 4, 5, 6], calendar: cal), date(25, 7, 0))
    }

    private func verdict(
        now: Date, occurrence: Date? , armedSince: Date? = nil, snooze: Date? = nil,
        answered: Date? = nil, boot: Date? = nil, recorded: Bool = false, evaluated: Bool = false
    ) -> UnattendedMorning.Verdict {
        UnattendedMorning.evaluate(
            now: now, occurrence: occurrence,
            armedSince: armedSince ?? date(1, 0, 0),
            lastSnoozeReturnAt: snooze, lastAnsweredAt: answered, bootTime: boot,
            alreadyRecorded: recorded, alreadyEvaluated: evaluated
        )
    }

    func testRangAndNobodyAnsweredIsReportedSoundedNotCounted() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 9, 0), occurrence: t), .soundedUnanswered(occurrence: t))
    }

    func testPhoneOffAtRingTimeIsReportedDidNotSound() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 9, 0), occurrence: t, boot: date(25, 8, 0)), .didNotSound(occurrence: t))
    }

    func testAnsweredRingIsNeverReported() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 9, 0), occurrence: t, answered: date(25, 7, 1)), .none)
    }

    func testAnsweredThenSnoozeReturnUnansweredIsReported() {
        let t = date(25, 7, 0)
        XCTAssertEqual(
            verdict(now: date(25, 9, 0), occurrence: t, snooze: date(25, 7, 11), answered: date(25, 7, 1)),
            .soundedUnanswered(occurrence: t)
        )
    }

    func testNothingIsJudgedWhileTheRingMayStillBeGoing() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 7, 20), occurrence: t), .none)
    }

    func testAMorningFromBeforeTheAlarmExistedIsNeverJudged() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 12, 0), occurrence: t, armedSince: date(25, 11, 0)), .none)
    }

    func testADismissMoreThanThirtyMinutesAfterTheRingIsNotAnAnswer() {
        let t = date(26, 7, 0)
        XCTAssertFalse(UnattendedMorning.isLateAnswer(now: date(26, 7, 10), occurrence: t, lastSnoozeReturnAt: nil))
        XCTAssertFalse(UnattendedMorning.isLateAnswer(now: date(26, 7, 30), occurrence: t, lastSnoozeReturnAt: nil))
        XCTAssertTrue(UnattendedMorning.isLateAnswer(now: date(26, 7, 31), occurrence: t, lastSnoozeReturnAt: nil))
        XCTAssertTrue(UnattendedMorning.isLateAnswer(now: date(26, 7, 49), occurrence: t, lastSnoozeReturnAt: nil))
    }

    func testTheWindowRunsFromTheLatestSnoozeReturn() {
        let t = date(26, 7, 0)
        // Snoozed at the Invite; the return rang at 7:20 — 7:45 is on time.
        XCTAssertFalse(UnattendedMorning.isLateAnswer(now: date(26, 7, 45), occurrence: t, lastSnoozeReturnAt: date(26, 7, 20)))
        // A snooze return from an earlier morning does not extend today's window.
        XCTAssertTrue(UnattendedMorning.isLateAnswer(now: date(26, 7, 45), occurrence: t, lastSnoozeReturnAt: date(25, 20, 32)))
    }

    func testRecordedOrAlreadyReportedMorningsAreSkipped() {
        let t = date(25, 7, 0)
        XCTAssertEqual(verdict(now: date(25, 9, 0), occurrence: t, recorded: true), .none)
        XCTAssertEqual(verdict(now: date(25, 9, 0), occurrence: t, evaluated: true), .none)
    }
}

@MainActor
final class UnansweredNeverCountsTests: XCTestCase {

    func testALockScreenMorningReachingThePrizeInTheAppSaysSo() {
        let answered = AlarmEngine.MorningOutcome(
            journeyTitle: "The Genesis", morningNumber: 5, totalDays: 9, journeyComplete: false,
            reachedPrize: false, heldStreakOnly: false, wasUnanswered: false
        )
        XCTAssertFalse(answered.reachingPrize(false).reachedPrize)
        XCTAssertTrue(answered.reachingPrize(true).reachedPrize)
        XCTAssertEqual(answered.reachingPrize(true).morningNumber, 5)
    }


    /// The in-app Option B stop ends the session without recording anything:
    /// no journey progress, no streak (founder ruling 2026-09-25).
    func testEndingAnUnansweredSessionRecordsNoMorning() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self, MorningRecordEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let engine = AlarmEngine(context: context)

        engine.beginAlarmSession()
        engine.endUnansweredSession()

        XCTAssertFalse(engine.isAlarmActive)
        XCTAssertEqual(MorningLedger(context: context).soundedMorningsCount(), 0)
        XCTAssertEqual(MorningLedger(context: context).streak(), 0)
    }
}

// MARK: - AlarmKit Dismiss → the morning

final class PendingMorningStartTests: XCTestCase {

    override func tearDown() {
        _ = PendingMorningStart.consume() // leave no request behind
    }

    func testAFreshRequestStartsTheMorningExactlyOnce() {
        let now = Date()
        PendingMorningStart.record(now: now)
        XCTAssertTrue(PendingMorningStart.consume(now: now.addingTimeInterval(5)))
        XCTAssertFalse(PendingMorningStart.consume(now: now.addingTimeInterval(6)),
                       "A Dismiss must open the morning once, never twice")
    }

    func testAStaleRequestNeverStartsALaterMorning() {
        let now = Date()
        PendingMorningStart.record(now: now)
        XCTAssertFalse(PendingMorningStart.consume(now: now.addingTimeInterval(11 * 60)))
    }

    func testNoRequestMeansNoStart() {
        XCTAssertFalse(PendingMorningStart.consume())
    }
}

// MARK: - Storefront honesty

@MainActor
final class StorefrontTests: XCTestCase {

    /// No product in App Store Connect means nothing to price and nothing to
    /// buy: product(for:) must return nil for every journey until iOS
    /// product ids exist, which is what removes the buy affordance from a
    /// card. Ownership (purchaseState) never flows through this path, so
    /// invisible-to-buy can never mean invisible-to-own.
    func testNoStoreProductsMeansNothingQuotedOrBuyable() {
        let storeKit = StoreKitManager()
        // products is empty until ASC returns real ids (none exist yet).
        for journeyId in ["genesis", "cast-prelude", "warm-front", "daybreak-shuffle", "catalyst", "educator", "overture"] {
            XCTAssertNil(storeKit.product(for: journeyId))
            XCTAssertFalse(storeKit.isPurchased(journeyId))
        }
    }
}

// MARK: - Option B ring decisions (founder, 2026-09-15)

final class RingDecisionTests: XCTestCase {

    func testInviteUnansweredAutoSnoozesOnce() {
        XCTAssertEqual(RingDecision.onRingLimitReached(stage: "invite", autoSnoozeUsed: false), .autoSnooze)
    }

    func testInviteAfterUsedAutoSnoozeStops() {
        XCTAssertEqual(RingDecision.onRingLimitReached(stage: "invite", autoSnoozeUsed: true), .stopAndReport)
    }

    func testNudgeUnansweredStopsAndReportsNeverCounts() {
        XCTAssertEqual(RingDecision.onRingLimitReached(stage: "nudge", autoSnoozeUsed: false), .stopAndReport)
        XCTAssertEqual(RingDecision.onRingLimitReached(stage: "nudge", autoSnoozeUsed: true), .stopAndReport)
    }

    func testPrizeIsNeverCutShortByTheSevenMinuteRule() {
        XCTAssertEqual(RingDecision.onRingLimitReached(stage: "prize", autoSnoozeUsed: false), .keepRinging)
    }

    func testLimitsAreSevenMinutesAndTheThirtyMinuteBackstop() {
        XCTAssertEqual(RingDecision.limitSeconds(forStage: "invite"), 7 * 60)
        XCTAssertEqual(RingDecision.limitSeconds(forStage: "nudge"), 7 * 60)
        XCTAssertEqual(RingDecision.limitSeconds(forStage: "prize"), 30 * 60)
    }
}

// MARK: - Review prompt eligibility (§2.6)

final class ReviewPromptTests: XCTestCase {

    private func ask(
        mornings: Int = 5, attempts: Int = 0, recent: Bool = true,
        alarm: Bool = false, audio: Bool = false, missed: Bool = false
    ) -> Bool {
        ReviewPromptManager.shouldAsk(
            soundedMornings: mornings, attemptsSoFar: attempts,
            lastCountedMorningIsRecent: recent, alarmActive: alarm,
            audioPlaying: audio, hasUnacknowledgedMissedAlarm: missed
        )
    }

    func testAsksAfterFiveSoundedMornings() { XCTAssertTrue(ask()) }
    func testNeverBeforeFiveMornings() { XCTAssertFalse(ask(mornings: 4)) }
    func testAtMostThreeAttempts() {
        XCTAssertTrue(ask(attempts: 2))
        XCTAssertFalse(ask(attempts: 3))
    }
    func testOnlyWhenLastMorningIsRecent() { XCTAssertFalse(ask(recent: false)) }
    func testNeverDuringAlarm() { XCTAssertFalse(ask(alarm: true)) }
    func testNeverWhileAudioPlays() { XCTAssertFalse(ask(audio: true)) }
    func testNeverWithUnacknowledgedMissedAlarm() { XCTAssertFalse(ask(missed: true)) }
}
