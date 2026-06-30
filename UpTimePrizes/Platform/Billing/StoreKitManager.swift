import Foundation
import StoreKit
import SwiftData

// MARK: - StoreKitManager

/// Manages StoreKit 2 product fetching, purchasing, and entitlement persistence.
/// After a successful purchase, updates the corresponding JourneyEntity's purchaseState
/// and sets it as the active journey (deactivating all others).
@MainActor
class StoreKitManager: ObservableObject {

    // MARK: - Product ID → Journey ID mapping

    static let productJourneyMap: [String: String] = [
        "journey_overture": "library-a",
        "journey_cast_prelude": "signature",
        "journey_catalyst": "special-day"
    ]

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
    /// Deactivates all other non-DEMO journeys.
    /// Catalyst Tracks (SPECIAL_DAY) are immediately UNLOCKED_FOR_PLAYBACK.
    private func applyEntitlement(productID: String) async {
        guard let journeyId = Self.productJourneyMap[productID],
              let context = context else { return }

        purchasedProductIDs.insert(productID)

        let fetchJourneys = FetchDescriptor<JourneyEntity>()
        guard let journeys = try? context.fetch(fetchJourneys) else { return }

        // Find the purchased journey
        guard let purchased = journeys.first(where: { $0.id == journeyId }) else { return }

        // Determine new state
        let newState: String
        if purchased.type == "SPECIAL_DAY" {
            // Catalyst Tracks: immediate full access
            newState = "UNLOCKED_FOR_PLAYBACK"
        } else {
            // Overture / Cast Prelude: begin daily progression
            newState = purchased.completedDays >= purchased.totalDays
                ? "UNLOCKED_FOR_PLAYBACK"
                : "ACTIVE_IN_PROGRESS"
        }

        purchased.purchaseState = newState

        // Activate this journey, deactivate all others (preserve DEMO as background)
        for journey in journeys {
            if journey.id == journeyId {
                journey.isActive = true
            } else if journey.type != "DEMO" {
                journey.isActive = false
            } else {
                // DEMO: deactivate since a paid journey is now active
                journey.isActive = false
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
