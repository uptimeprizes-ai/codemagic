import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query private var demoState: [DemoStateEntity]
    @StateObject private var storeKit = StoreKitManager()
    
    private var isLocked: Bool {
        guard let state = demoState.first else { return true }
        return state.completedDays < 9
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLocked {
                    LockedDiscoverView(daysRemaining: 9 - (demoState.first?.completedDays ?? 0))
                } else {
                    UnlockedDiscoverView(storeKit: storeKit)
                }
            }
            .background(DesignTokens.paper)
            .navigationTitle("Discover")
        }
        .task {
            await storeKit.fetchProducts()
        }
    }
}

struct LockedDiscoverView: View {
    let daysRemaining: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 80)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.brass)
            
            Text("The Catalog Awaits")
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 24))
                .foregroundColor(DesignTokens.ink)
            
            Text("Complete \(daysRemaining) more morning\(daysRemaining == 1 ? "" : "s") with The Genesis to unlock the full catalog.")
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 16))
                .foregroundColor(DesignTokens.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct UnlockedDiscoverView: View {
    @ObservedObject var storeKit: StoreKitManager
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(storeKit.products, id: \.id) { product in
                ProductCardView(product: product, storeKit: storeKit)
            }
        }
        .padding()
    }
}

struct ProductCardView: View {
    let product: StoreKit.Product
    @ObservedObject var storeKit: StoreKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(product.displayName)
                .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 20))
                .foregroundColor(DesignTokens.ink)
            
            Text(product.description)
                .font(.custom(DesignTokens.Typography.playfairDisplay, size: 14))
                .foregroundColor(DesignTokens.ink.opacity(0.7))
            
            Button {
                Task {
                    _ = try? await storeKit.purchase(product)
                }
            } label: {
                Text(product.displayPrice)
                    .font(.custom(DesignTokens.Typography.playfairDisplaySemiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DesignTokens.brass)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.6))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}
