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
            Group {
                if isUnlocked {
                    ScrollView {
                        VStack(spacing: 24) {
                            unlockedContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                } else {
                    lockedContent
                }
            }
            .background(PaperBackground())
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(isUnlocked ? .visible : .hidden, for: .navigationBar)
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Locked content

    private var lockedContent: some View {
        // Android DiscoverLockedPlaceholder: before the ninth counted Genesis
        // morning, three lines and nothing else — never a price, a product
        // name, or a track count.
        VStack(spacing: 20) {
            Text("The catalog opens on day nine.")
                .font(.playfair(22, semibold: true))
                .foregroundColor(BrassPaper.ink)
                .lineSpacing(8)
                .shadow(color: Color.white.opacity(0.6), radius: 1, x: 0, y: 1.5)
            Text(Self.countdownLine(currentDay: demoState?.currentDay ?? 1))
                .font(.playfair(16))
                .foregroundColor(BrassPaper.inkSoft)
                .lineSpacing(8)
            Text("Until then, the genesis songs are yours, and we hope you enjoy them.")
                .font(.playfair(14))
                .foregroundColor(BrassPaper.inkSoft)
                .lineSpacing(10)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The middle line, keyed on the Genesis morning the person is on —
    /// Android's wording, day for day.
    nonisolated static func countdownLine(currentDay: Int) -> String {
        switch currentDay {
        case 1: return "Eight more mornings until you meet the rest of UpTime Prizes."
        case 2: return "Seven more mornings until you meet the rest of UpTime Prizes."
        case 3: return "Six more mornings until you meet the rest of UpTime Prizes."
        case 4: return "Five more mornings until you meet the rest of UpTime Prizes."
        case 5: return "Four more mornings until you meet the rest of UpTime Prizes."
        case 6: return "Three more mornings until you meet the rest of UpTime Prizes."
        case 7: return "Two more mornings until you meet the rest of UpTime Prizes."
        case 8: return "Tomorrow."
        case 9: return "Today."
        default: return ""
        }
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

            // The price AND the buy affordance exist only when the store can
            // actually sell this journey. A card whose product is not in App
            // Store Connect shows neither — never an unpriced button that
            // errors on tap, never a figure the store will not charge.
            // Invisible-to-buy is never invisible-to-see-or-own: the card,
            // and any owned journey, are untouched.
            if let product = storeKit.product(for: journey.id) {
                HStack {
                    Text(product.displayPrice)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                        .foregroundColor(Color("brass"))

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
