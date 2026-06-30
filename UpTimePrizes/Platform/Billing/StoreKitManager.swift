import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    
    func fetchProducts() async {
        do {
            let productIds = ["journey_overture", "journey_cast_prelude", "journey_catalyst"]
            products = try await Product.products(for: productIds)
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
