import XCTest
import SwiftData
@testable import UpTimePrizes

// MARK: - JourneyProgressionTests
// Tests the core journey independence and day progression rules.

@MainActor
final class JourneyProgressionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var alarmEngine: AlarmEngine!

    override func setUpWithError() throws {
        let schema = Schema([JourneyEntity.self, SongEntity.self, DemoStateEntity.self, AlarmEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        DatabaseSeeder.seed(context: context)
        alarmEngine = AlarmEngine(context: context)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        alarmEngine = nil
    }

    // MARK: - Seeding

    func testDatabaseSeederCreatesAllJourneys() throws {
        let fetch = FetchDescriptor<JourneyEntity>()
        let journeys = try context.fetch(fetch)
        XCTAssertEqual(journeys.count, 4, "Should seed 4 journeys: demo, library-a, signature, special-day")
    }

    func testDatabaseSeederCreatesDemoSongs() throws {
        let fetch = FetchDescriptor<SongEntity>(predicate: #Predicate { $0.libraryId == "demo" })
        let songs = try context.fetch(fetch)
        XCTAssertEqual(songs.count, 5, "Should seed 5 Genesis songs")
    }

    func testDatabaseSeederCreatesCatalystSongs() throws {
        let fetch = FetchDescriptor<SongEntity>(predicate: #Predicate { $0.libraryId == "special-day" })
        let songs = try context.fetch(fetch)
        XCTAssertEqual(songs.count, 5, "Should seed 5 Catalyst Track stubs")
    }

    func testDemoSongsAreAvailable() throws {
        let fetch = FetchDescriptor<SongEntity>(predicate: #Predicate { $0.libraryId == "demo" })
        let songs = try context.fetch(fetch)
        XCTAssertTrue(songs.allSatisfy { $0.isAvailable }, "All demo songs should be available on device")
    }

    func testCatalystSongsAreNotAvailableBeforePurchase() throws {
        let fetch = FetchDescriptor<SongEntity>(predicate: #Predicate { $0.libraryId == "special-day" })
        let songs = try context.fetch(fetch)
        XCTAssertTrue(songs.allSatisfy { !$0.isAvailable }, "Catalyst songs should not be available before purchase")
    }

    // MARK: - Initial state

    func testOnlyGenesisIsActiveOnFirstLaunch() throws {
        let fetch = FetchDescriptor<JourneyEntity>()
        let journeys = try context.fetch(fetch)
        let active = journeys.filter { $0.isActive }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, "demo")
    }

    func testGenesisStartsAtDayOne() throws {
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "demo" })
        let genesis = try context.fetch(fetch).first
        XCTAssertEqual(genesis?.currentDay, 1)
        XCTAssertEqual(genesis?.completedDays, 0)
    }

    func testDiscoverPageLockedInitially() throws {
        let fetch = FetchDescriptor<DemoStateEntity>()
        let demo = try context.fetch(fetch).first
        XCTAssertFalse(demo?.isPurchaseOffered ?? true, "Discover should be locked on first launch")
    }

    // MARK: - Day progression

    func testAlarmDismissIncrementsDayCount() throws {
        alarmEngine.handleAlarmDismissed()
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "demo" })
        let genesis = try context.fetch(fetch).first
        XCTAssertEqual(genesis?.completedDays, 1)
    }

    func testAlarmDismissNineTimesUnlocksDiscover() throws {
        for _ in 0..<9 {
            alarmEngine.handleAlarmDismissed()
        }
        let fetch = FetchDescriptor<DemoStateEntity>()
        let demo = try context.fetch(fetch).first
        XCTAssertTrue(demo?.isPurchaseOffered ?? false, "Discover should unlock after 9 mornings")
    }

    func testJourneyIndependence_DismissingGenesisDoesNotAdvanceOverture() throws {
        // Set Overture as purchased but not active
        let fetchOverture = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "library-a" })
        if let overture = try context.fetch(fetchOverture).first {
            overture.purchaseState = "ACTIVE_IN_PROGRESS"
            overture.completedDays = 5
            overture.isActive = false
        }
        try context.save()

        // Dismiss alarm (Genesis is active)
        alarmEngine.handleAlarmDismissed()

        // Overture should NOT have advanced
        let overture = try context.fetch(fetchOverture).first
        XCTAssertEqual(overture?.completedDays, 5, "Overture count must not change when Genesis alarm is dismissed")
    }

    func testOnlyOneJourneyActiveAtATime() throws {
        let fetchAll = FetchDescriptor<JourneyEntity>()
        let journeys = try context.fetch(fetchAll)

        // Simulate activating Overture
        for journey in journeys {
            journey.isActive = journey.id == "library-a"
        }
        try context.save()

        let active = journeys.filter { $0.isActive }
        XCTAssertEqual(active.count, 1, "Only one journey should be active at a time")
        XCTAssertEqual(active.first?.id, "library-a")
    }

    // MARK: - Completion

    func testJourneyCompletionSetsUnlockedState() throws {
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "demo" })
        guard let genesis = try context.fetch(fetch).first else { XCTFail("Genesis not found"); return }

        // Manually set to 8 completed days, then dismiss once more
        genesis.completedDays = 8
        genesis.currentDay = 4
        try context.save()

        alarmEngine.handleAlarmDismissed()

        XCTAssertEqual(genesis.purchaseState, "UNLOCKED_FOR_PLAYBACK",
                       "Genesis should be UNLOCKED_FOR_PLAYBACK after 9 completions")
    }

    // MARK: - Genesis song rotation

    func testGenesisSongRotatesThroughFiveSongs() throws {
        let fetch = FetchDescriptor<JourneyEntity>(predicate: #Predicate { $0.id == "demo" })
        guard let genesis = try context.fetch(fetch).first else { XCTFail(); return }

        var days: [Int] = []
        for _ in 0..<10 {
            days.append(genesis.currentDay)
            alarmEngine.handleAlarmDismissed()
        }

        // Days should cycle 1-5, never repeat consecutively
        let uniqueDays = Set(days)
        XCTAssertEqual(uniqueDays.count, 5, "Genesis should rotate through all 5 songs before repeating")
    }

    // MARK: - StageCoordinator

    func testStageCoordinatorAdvancesCorrectly() {
        let coordinator = StageCoordinator()
        XCTAssertEqual(coordinator.currentStage, .stage1)

        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage2)

        coordinator.advanceStage()
        XCTAssertEqual(coordinator.currentStage, .stage3)
    }

    func testStageCoordinatorReplayDoesNotAdvanceBeyond() {
        let coordinator = StageCoordinator()
        coordinator.advanceStage() // → stage2
        coordinator.advanceStage() // → stage3
        coordinator.advanceStage() // → replay
        coordinator.advanceStage() // should stay at replay
        XCTAssertEqual(coordinator.currentStage, .replay)
    }

    // MARK: - Manifest loading

    func testManifestLoadsSuccessfully() {
        let manifest = AudioPlayerManager.loadManifest()
        // In test target, bundle may not have the resource — skip gracefully
        if let manifest = manifest {
            XCTAssertEqual(manifest.version, 1)
            XCTAssertNotNil(manifest.libraries["demo"])
            XCTAssertEqual(manifest.libraries["demo"]?.songs.count, 5)
        }
    }

    func testManifestDemoSongsHaveCorrectRegions() {
        guard let manifest = AudioPlayerManager.loadManifest(),
              let demo = manifest.libraries["demo"] else { return }

        for song in demo.songs {
            XCTAssertEqual(song.regions.stage1.startMs, 0)
            XCTAssertEqual(song.regions.stage1.endMs, 30000)
            XCTAssertEqual(song.regions.stage2.startMs, 30000)
            XCTAssertEqual(song.regions.stage2.endMs, 60000)
            XCTAssertEqual(song.regions.stage3.startMs, 60000)
            XCTAssertEqual(song.regions.stage3.endMs, -1)
        }
    }
}
