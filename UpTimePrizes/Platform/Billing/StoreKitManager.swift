import Foundation
import StoreKit
import SwiftData

// MARK: - StoreKitManager

/// Manages StoreKit 2 product fetching, purchasing, and entitlement persistence.
///
/// Bug 2 fix: When a purchase is restored (e.g., after reinstall), applyEntitlement()
/// now also updates DemoStateEntity so the Discovery tab unlocks correctly — not just
/// the journey's purchaseState. This prevents the two state systems from getting out
/// of sync.
@MainActor
class StoreKitManager: ObservableObject {

    // MARK: - Product ID → Journey ID mapping
    //
    // Built from the manifest (single source of truth), never hand-written.
    // NOTE: the manifest currently carries Android's live Play product IDs.
    // App Store Connect is its own namespace; which IDs exist there — and
    // whether iOS follows journey_<name> — is the founder's open ruling.
    // Until then, no product will resolve on iOS; that is expected.

    static let productJourneyMap: [String: String] = {
        guard let manifest = UpTimeManifest.loadFromBundle() else { return [:] }
        var map: [String: String] = [:]
        for journey in manifest.journeys where !journey.productId.isEmpty {
            map[journey.productId] = journey.journeyId
        }
        return map
    }()

    // MARK: - Published state

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false

    // MARK: - Private

    private var context: ModelContext?
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init / Deinit

    init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Setup

    func configure(context: ModelContext) {
        self.context = context
        Task {
            await fetchProducts()
            await restorePurchases()
        }
    }

    // MARK: - Fetch products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let productIds = Array(Self.productJourneyMap.keys)
            products = try await Product.products(for: productIds)
        } catch {
            print("[StoreKitManager] Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await applyEntitlement(productID: product.id)
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Restore purchases

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await applyEntitlement(productID: transaction.productID)
            }
        }
    }

    // MARK: - Transaction listener (handles pending → completed)

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.applyEntitlement(productID: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Entitlement application

    /// Updates the JourneyEntity matching this product ID.
    /// Sets purchaseState to ACTIVE_IN_PROGRESS and activates the journey.
    /// Deactivates all other journeys.
    /// Catalyst Tracks (SPECIAL_DAY) are immediately UNLOCKED_FOR_PLAYBACK.
    ///
    /// Bug 2 fix: Also updates DemoStateEntity to unlock the Discovery tab
    /// when any purchase is restored. This ensures the two state systems
    /// (billing state and progression state) stay in sync on reinstall.
    private func applyEntitlement(productID: String) async {
        guard let journeyId = Self.productJourneyMap[productID],
              let context = context else { return }

        purchasedProductIDs.insert(productID)

        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys) else { return }

        // Find the purchased journey
        guard let purchased = journeys.first(where: { $0.id == journeyId }) else { return }

        // Determine new state. Identity is journeyId — never a journey "type".
        let newState: String
        if purchased.id == "catalyst" {
            // The Catalyst Tracks: playable immediately, no cycle
            newState = "UNLOCKED_FOR_PLAYBACK"
        } else {
            // Journeys with a morning cycle: begin (or resume) progression
            newState = purchased.completedDays >= purchased.totalDays
                ? "UNLOCKED_FOR_PLAYBACK"
                : "ACTIVE_IN_PROGRESS"
        }

        purchased.purchaseState = newState

        // Activate this journey, deactivate all others
        for journey in journeys {
            journey.isActive = journey.id == journeyId
        }

        // Bug 2 fix: Unlock the Discovery tab by advancing demo state past the gate.
        // The Discover tab is gated on demoState.completedDays >= 9.
        // When a purchase exists, the user has already earned access — unlock it.
        let fetchDemo = FetchDescriptor<DemoStateEntity>()
        if let demo = try? context.fetch(fetchDemo).first {
            if demo.completedDays < 9 {
                demo.completedDays = 9
                demo.isPurchaseOffered = true
                print("[StoreKitManager] Bug 2 fix: Advanced demo state to day 9 to unlock Discovery tab.")
            }
        }

        try? context.save()
    }

    // MARK: - Verification helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helpers

    func product(for journeyId: String) -> Product? {
        let productId = Self.productJourneyMap.first(where: { $0.value == journeyId })?.key
        return products.first(where: { $0.id == productId })
    }

    func isPurchased(_ journeyId: String) -> Bool {
        let productId = Self.productJourneyMap.first(where: { $0.value == journeyId })?.key ?? ""
        return purchasedProductIDs.contains(productId)
    }
}

// MARK: - StoreError

enum StoreError: Error {
    case failedVerification
}
