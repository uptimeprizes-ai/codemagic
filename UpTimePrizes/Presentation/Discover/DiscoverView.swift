import SwiftUI
import SwiftData
import StoreKit

// MARK: - DiscoverView

/// Shows purchasable journeys. Locked until the user completes 9 days of The Genesis.
struct DiscoverView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var demoStates: [DemoStateEntity]

    // MARK: - Observed

    @ObservedObject var storeKit: StoreKitManager

    // MARK: - State

    @State private var purchaseError: String? = nil
    @State private var showError: Bool = false
    @State private var isPurchasing: Bool = false

    // MARK: - Computed

    private var demoState: DemoStateEntity? { demoStates.first }

    private var isUnlocked: Bool {
        (demoState?.completedDays ?? 0) >= 9
    }

    private var purchasableJourneys: [JourneyEntity] {
        journeys.filter { $0.isPurchaseOffered && $0.purchaseState == "NOT_OWNED" }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isUnlocked {
                        unlockedContent
                    } else {
                        lockedContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color("paper").ignoresSafeArea())
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Locked content

    private var lockedContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(Color("brass"))

            Text("Your morning experience is just beginning.")
                .font(.custom("PlayfairDisplay-SemiBold", size: 20))
                .foregroundColor(Color("ink"))
                .multilineTextAlignment(.center)

            let completed = demoState?.completedDays ?? 0
            let remaining = max(0, 9 - completed)

            Text("Complete \(remaining) more morning\(remaining == 1 ? "" : "s") with The Genesis to unlock the full catalog.")
                .font(.custom("PlayfairDisplay-Regular", size: 15))
                .foregroundColor(Color("ink").opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            ProgressView(value: Double(completed), total: 9)
                .tint(Color("brass"))
                .padding(.horizontal, 32)

            Text("\(completed) of 9 mornings")
                .font(.custom("PlayfairDisplay-Regular", size: 13))
                .foregroundColor(Color("ink").opacity(0.5))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Unlocked content

    private var unlockedContent: some View {
        VStack(spacing: 16) {
            if purchasableJourneys.isEmpty {
                Text("You own everything in the catalog. Thank you.")
                    .font(.custom("PlayfairDisplay-Regular", size: 16))
                    .foregroundColor(Color("ink").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
            } else {
                ForEach(purchasableJourneys, id: \.id) { journey in
                    journeyCard(journey: journey)
                }
            }
        }
    }

    // MARK: - Journey card

    private func journeyCard(journey: JourneyEntity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(journey.title)
                .font(.custom("PlayfairDisplay-SemiBold", size: 20))
                .foregroundColor(Color("ink"))

            Text(journey.descriptionText)
                .font(.custom("PlayfairDisplay-Regular", size: 14))
                .foregroundColor(Color("ink").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let product = storeKit.product(for: journey.id) {
                    Text(product.displayPrice)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                        .foregroundColor(Color("brass"))
                }

                Spacer()

                Button {
                    Task { await buyJourney(journey) }
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .tint(Color("paper"))
                            .frame(width: 80, height: 36)
                    } else {
                        Text("Get It")
                            .font(.custom("PlayfairDisplay-SemiBold", size: 15))
                            .foregroundColor(Color("paper"))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color("brass"))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .disabled(isPurchasing)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color("ink").opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Purchase action

    private func buyJourney(_ journey: JourneyEntity) async {
        guard let product = storeKit.product(for: journey.id) else {
            purchaseError = "This item is not available right now."
            showError = true
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await storeKit.purchase(product)
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
    }
}
