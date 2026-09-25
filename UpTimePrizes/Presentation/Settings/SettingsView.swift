import SwiftUI
import SwiftData

// MARK: - SettingsView
//
// The machine room (Android screen map §5): set the alarm, and the
// machinery around it. It never lists a song and never sells anything.
// Sections that point at owned things are absent until the ninth counted
// Genesis morning. Copy is the shipping Android wording from the screen map.
//
// Not yet here, pending their own passes: the Catalyst card and Special Day
// scheduler (the Catalyst cannot be owned on iOS until product ids exist),
// the permissions rows, and the "next sounds in …" line.

struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Query private var journeys: [JourneyEntity]
    @Query private var alarms: [AlarmEntity]
    @Query private var demoStates: [DemoStateEntity]

    @ObservedObject var alarmEngine: AlarmEngine

    @State private var pickerTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var selectedRepeatDays: Set<Int> = []
    @State private var showJourneySelector: Bool = false
    @State private var showDebug: Bool = false

    private var alarm: AlarmEntity? { alarms.first }
    private var activeJourney: JourneyEntity? { journeys.first(where: { $0.isActive }) }
    private var catalogOpen: Bool {
        CatalogRules.isCatalogOpen(genesisCompletedDays: demoStates.first?.completedDays ?? 0)
    }

    var body: some View {
        NavigationStack {
            List {
                newAlarmSection
                activeAlarmsSection
                snoozeSection
                if catalogOpen, let journey = activeJourney {
                    yourCatalogSection(journey)
                }
                aboutSection
                #if DEBUG
                Section("Developer") {
                    Button("Open Debug Tools") { showDebug = true }
                        .foregroundColor(Color("brass"))
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color("paper").ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear(perform: loadAlarm)
        .sheet(isPresented: $showJourneySelector) {
            JourneySelectorView()
        }
        .sheet(isPresented: $showDebug) {
            DebugView(alarmEngine: alarmEngine)
        }
    }

    // MARK: - ✦ NEW ALARM ✦

    private var newAlarmSection: some View {
        Section {
            DatePicker("", selection: $pickerTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("REPEAT")
                    .font(.custom("PlayfairDisplay-SemiBold", size: 12))
                    .tracking(2)
                    .foregroundColor(Color("ink").opacity(0.6))
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        Button { toggleRepeatDay(day) } label: {
                            Text(dayAbbreviation(day))
                                .font(.custom("PlayfairDisplay-Regular", size: 12))
                                .foregroundColor(selectedRepeatDays.contains(day) ? Color("paper") : Color("ink").opacity(0.6))
                                .frame(width: 34, height: 34)
                                .background(selectedRepeatDays.contains(day) ? Color("brass") : Color("ink").opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)

            Button(action: setAlarm) {
                Text("SET ALARM")
                    .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                    .tracking(2)
                    .foregroundColor(Color("paper"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("brass"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
        } header: {
            Text("✦ NEW ALARM ✦")
        }
    }

    // MARK: - ACTIVE ALARMS

    private var activeAlarmsSection: some View {
        Section {
            if let alarm, alarm.isEnabled {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeString(hour: alarm.hour, minute: alarm.minute))
                            .font(.custom("PlayfairDisplay-SemiBold", size: 22))
                            .foregroundColor(Color("ink"))
                        if !alarm.repeatDays.isEmpty {
                            Text(alarm.repeatDays.sorted().map(dayAbbreviation).joined(separator: " "))
                                .font(.custom("PlayfairDisplay-Regular", size: 13))
                                .foregroundColor(Color("ink").opacity(0.6))
                        }
                    }
                    Spacer()
                    Button("Delete", role: .destructive, action: deleteAlarm)
                        .buttonStyle(.borderless)
                }
            } else {
                Text("No alarms set yet. Your first alarm will live here.")
                    .font(.custom("PlayfairDisplay-Regular", size: 14))
                    .foregroundColor(Color("ink").opacity(0.6))
            }
        } header: {
            Text("ACTIVE ALARMS")
        }
    }

    // MARK: - Snooze Duration

    private var snoozeSection: some View {
        Section {
            Picker("Snooze Duration", selection: Binding(
                get: { alarm?.snoozeMinutes ?? AlarmEngine.defaultSnoozeMinutes },
                set: { newValue in
                    alarm?.snoozeMinutes = newValue
                    try? context.save()
                }
            )) {
                ForEach(AlarmEngine.snoozeOptions, id: \.self) { minutes in
                    Text("\(minutes) minutes").tag(minutes)
                }
            }
        } footer: {
            Text(CuratorCopy.snoozeSubtitle)
        }
    }

    // MARK: - YOUR CATALOG

    private func yourCatalogSection(_ journey: JourneyEntity) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active work")
                        .font(.custom("PlayfairDisplay-Regular", size: 12))
                        .foregroundColor(Color("ink").opacity(0.6))
                    Text(journey.title)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                        .foregroundColor(Color("ink"))
                }
                Spacer()
                Button("Switch →") { showJourneySelector = true }
                    .buttonStyle(.borderless)
                    .foregroundColor(Color("brass"))
            }
        } header: {
            Text("YOUR CATALOG")
        }
    }

    // MARK: - ABOUT

    private var aboutSection: some View {
        Section {
            LabeledContent("UpTime Prizes", value: appVersion)
            Link("Privacy Policy", destination: URL(string: "https://uptimeprizes.com/privacy")!)
            Link("Support", destination: URL(string: "https://uptimeprizes.com/support")!)
        } header: {
            Text("ABOUT")
        }
    }

    // MARK: - Actions

    private func loadAlarm() {
        guard let alarm else { return }
        pickerTime = Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute)) ?? pickerTime
        selectedRepeatDays = Set(alarm.repeatDays)
    }

    private func setAlarm() {
        guard let alarm else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: pickerTime)
        alarm.hour = parts.hour ?? 7
        alarm.minute = parts.minute ?? 0
        alarm.repeatDays = selectedRepeatDays.sorted()
        alarm.isEnabled = true
        try? context.save()
        alarmEngine.scheduleAlarm(hour: alarm.hour, minute: alarm.minute, repeatDays: alarm.repeatDays)
    }

    private func deleteAlarm() {
        guard let alarm else { return }
        alarm.isEnabled = false
        try? context.save()
        alarmEngine.cancelAlarm()
    }

    private func toggleRepeatDay(_ day: Int) {
        if selectedRepeatDays.contains(day) {
            selectedRepeatDays.remove(day)
        } else {
            selectedRepeatDays.insert(day)
        }
    }

    // MARK: - Formatting

    private func dayAbbreviation(_ day: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][day - 1]
    }

    private func timeString(hour: Int, minute: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):\(String(format: "%02d", minute)) \(hour < 12 ? "AM" : "PM")"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(version) (\(build))"
    }
}

// MARK: - JourneySelectorView
//
// Choose the active journey (screen map §6). Only one is active at a time;
// switching preserves every journey's progress exactly — activation changes
// which is active, nothing else. The Catalyst Tracks are not a journey and
// are not listed.

struct JourneySelectorView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JourneyEntity.sortOrder) private var journeys: [JourneyEntity]

    private var ownedJourneys: [JourneyEntity] {
        journeys.filter { $0.id != CatalogRules.catalystId && $0.purchaseState != "NOT_OWNED" }
    }

    var body: some View {
        NavigationStack {
            List {
                if ownedJourneys.isEmpty {
                    Text("No purchased works yet. The catalog opens on day nine.")
                        .foregroundColor(Color("ink").opacity(0.6))
                } else {
                    Section {
                        ForEach(ownedJourneys, id: \.id) { journey in
                            Button { activate(journey) } label: {
                                HStack {
                                    Text(journey.title)
                                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                                        .foregroundColor(Color("ink"))
                                    Spacer()
                                    if journey.isActive {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color("brass"))
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("Only one journey can be active at a time. Your progress is saved when switching.")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color("brass"))
                }
            }
        }
    }

    private func activate(_ chosen: JourneyEntity) {
        for journey in journeys {
            journey.isActive = journey.id == chosen.id
        }
        try? context.save()
    }
}
