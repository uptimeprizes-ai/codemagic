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
    /// One card open at a time (Android: six journeys was six screens).
    @State private var expandedJourneyId: String?

    // MARK: - Computed

    private var demoState: DemoStateEntity? { demoStates.first }

    private var isUnlocked: Bool {
        (demoState?.completedDays ?? 0) >= 9
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isUnlocked {
                    ScrollView {
                        unlockedContent
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                } else {
                    lockedContent
                }
            }
            .background(PaperBackground())
            .toolbar(.hidden, for: .navigationBar)
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
    //
    // Android DiscoverPage: a masthead, then one card per SOLD journey in
    // manifest sortOrder — owned ones included, with an Owned pill. Cards
    // collapse to title · pill · framing line; one opens at a time.

    private var soldJourneys: [JourneyEntity] {
        journeys.filter { !$0.productId.isEmpty }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// "JOURNEYS FROM …" in the store's own lowest price — never a figure the
    /// store has not quoted (App Builder, 2026-09-26). Absent until it does.
    private var fromPriceLine: String? {
        guard let cheapest = storeKit.products.min(by: { $0.price < $1.price }) else { return nil }
        return "JOURNEYS FROM \(cheapest.displayPrice)"
    }

    private var unlockedContent: some View {
        VStack(spacing: 14) {
            masthead
            ForEach(soldJourneys, id: \.id) { journey in
                productCard(journey)
            }
            Spacer().frame(height: 24)
        }
    }

    private var masthead: some View {
        VStack(spacing: 0) {
            HStack {
                Text("✦").font(.system(size: 14)).foregroundColor(BrassPaper.brass3)
                Spacer()
                Text("Discover")
                    .font(.playfair(32, semibold: true))
                    .tracking(1.6)
                    .foregroundColor(BrassPaper.ink)
                    .shadow(color: Color.white.opacity(0.6), radius: 1, x: 0, y: 1.5)
                Spacer()
                Text("✦").font(.system(size: 14)).foregroundColor(BrassPaper.brass3)
            }
            Spacer().frame(height: 6)
            Text("EST · MMXXVI")
                .font(.mono(9))
                .tracking(2.7)
                .foregroundColor(BrassPaper.inkSoft)
            if let line = fromPriceLine {
                Spacer().frame(height: 4)
                Text(line)
                    .font(.mono(9))
                    .tracking(2.25)
                    .foregroundColor(BrassPaper.brass3.opacity(0.75))
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func productCard(_ journey: JourneyEntity) -> some View {
        let owned = journey.purchaseState != "NOT_OWNED"
        let product = owned ? nil : storeKit.product(for: journey.id)
        let expanded = expandedJourneyId == journey.id
        let canExpand = !journey.descriptionText.isEmpty
        return PlaqueCard {
            HStack(alignment: .center) {
                Text(journey.title)
                    .font(.playfair(19, semibold: true))
                    .foregroundColor(BrassPaper.brassHighlight.opacity(0.9))
                    .plaqueTextShadow()
                Spacer(minLength: 10)
                // No pill until there is something true to put in it: the
                // store's price for an unowned journey, Owned otherwise.
                if owned {
                    OwnedPillLabel(text: "Owned")
                } else if let product {
                    Button {
                        Task { await buy(product) }
                    } label: {
                        BrassPillLabel(text: product.displayPrice)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                    .accessibilityLabel("Buy \(journey.title) for \(product.displayPrice)")
                }
            }
            if !journey.framingLine.isEmpty || canExpand {
                Spacer().frame(height: 8)
                HStack(alignment: .firstTextBaseline) {
                    Text(journey.framingLine)
                        .font(.playfair(13))
                        .lineSpacing(7)
                        .foregroundColor(BrassPaper.brass2.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                    if canExpand {
                        Text(expanded ? "▴" : "▾")
                            .font(.playfair(14))
                            .foregroundColor(BrassPaper.brass2.opacity(0.7))
                    }
                }
            }
            if canExpand && expanded {
                Spacer().frame(height: 10)
                Text(journey.descriptionText)
                    .font(.playfair(14))
                    .lineSpacing(8)
                    .foregroundColor(BrassPaper.brassHighlight.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedJourneyId = expanded ? nil : journey.id
            }
        }
    }

    // MARK: - Purchase action

    private func buy(_ product: Product) async {
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
