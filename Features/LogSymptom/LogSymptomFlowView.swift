import SwiftUI
import SwiftData

struct LogSymptomFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitClient.self) private var healthKit

    var onSaved: (() -> Void)? = nil

    @State private var selectedSymptom: SymptomType = SymptomType.presets.first ?? SymptomType(name: "Other", isCustom: true)
    @State private var customSymptomName: String = ""
    @State private var severity: Double = 4
    @State private var onset: Date = Date()
    @State private var durationMinutes: String = ""
    @State private var notes: String = ""
    @State private var medsText: String = ""
    @State private var sleepHours: String = ""
    @State private var hydrationLiters: String = ""
    @State private var caffeineMg: String = ""
    @State private var alcoholUnits: String = ""

    @State private var bodyLocation: BodyLocation? = nil
    @State private var selectedPeriodTag: PeriodTag = .none
    @State private var selectedQualities: Set<SymptomQuality> = []
    @State private var selectedAssociated: Set<AssociatedSymptom> = []
    @State private var selectedTriggers: Set<Trigger> = []
    @State private var selectedRedFlags: Set<RedFlag> = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let otherSymptom = SymptomType(name: "Other", category: "Custom", isCustom: true)

    var body: some View {
        NavigationStack {
            Form {
                Section("Symptom type") {
                    Picker("Type", selection: $selectedSymptom) {
                        ForEach(SymptomType.presets + [otherSymptom], id: \.id) { type in
                            Text(type.name).tag(type)
                        }
                    }

                    if selectedSymptom.id == otherSymptom.id {
                        TextField("Describe symptom", text: $customSymptomName)
                    }
                }

                Section {
                    BodyLocationPicker(location: $bodyLocation)
                }

                Section("Severity") {
                    LogSeveritySlider(value: $severity)
                        .padding(.vertical, Theme.spacingXS)
                }

                Section("Onset & duration") {
                    DatePicker("Onset", selection: $onset, displayedComponents: [.date, .hourAndMinute])
                    TextField("Duration (minutes)", text: $durationMinutes)
                        .keyboardType(.numberPad)
                }

                Section("Qualities") {
                    ForEach(SymptomQuality.allCases, id: \.self) { quality in
                        Toggle(quality.displayName, isOn: binding(for: quality))
                    }
                }

                Section("Associated symptoms") {
                    ForEach(AssociatedSymptom.allCases, id: \.self) { symptom in
                        Toggle(symptom.displayName, isOn: binding(for: symptom))
                    }
                }

                Section("Possible triggers") {
                    ForEach(Trigger.allCases, id: \.self) { trigger in
                        Toggle(trigger.displayName, isOn: binding(for: trigger))
                    }
                }

                Section("Context") {
                    TextField("Sleep hours", text: $sleepHours)
                        .keyboardType(.decimalPad)
                    TextField("Hydration liters", text: $hydrationLiters)
                        .keyboardType(.decimalPad)
                    TextField("Caffeine (mg)", text: $caffeineMg)
                        .keyboardType(.numberPad)
                    TextField("Alcohol units", text: $alcoholUnits)
                        .keyboardType(.numberPad)
                    TextField("Meds taken (comma separated)", text: $medsText)
                    Picker("Cycle phase", selection: $selectedPeriodTag) {
                        ForEach(PeriodTag.allCases, id: \.self) { tag in
                            Text(tag.displayName).tag(tag)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }

                Section("Red flags (optional)") {
                    ForEach(RedFlag.allCases, id: \.self) { flag in
                        Toggle(flag.displayName, isOn: binding(for: flag))
                    }
                    Text("If you think this may be an emergency, call your local emergency number.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Log Symptom")
            .task {
                if healthKit.isAuthorized {
                    if sleepHours.isEmpty, let hours = await healthKit.fetchLastNightSleepHours() {
                        sleepHours = String(hours)
                    }
                    if hydrationLiters.isEmpty, let liters = await healthKit.fetchTodayWaterLiters() {
                        hydrationLiters = String(liters)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await saveEntry() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func binding(for quality: SymptomQuality) -> Binding<Bool> {
        Binding(
            get: { selectedQualities.contains(quality) },
            set: { isOn in
                if isOn { selectedQualities.insert(quality) } else { selectedQualities.remove(quality) }
            }
        )
    }

    private func binding(for symptom: AssociatedSymptom) -> Binding<Bool> {
        Binding(
            get: { selectedAssociated.contains(symptom) },
            set: { isOn in
                if isOn { selectedAssociated.insert(symptom) } else { selectedAssociated.remove(symptom) }
            }
        )
    }

    private func binding(for trigger: Trigger) -> Binding<Bool> {
        Binding(
            get: { selectedTriggers.contains(trigger) },
            set: { isOn in
                if isOn { selectedTriggers.insert(trigger) } else { selectedTriggers.remove(trigger) }
            }
        )
    }

    private func binding(for redFlag: RedFlag) -> Binding<Bool> {
        Binding(
            get: { selectedRedFlags.contains(redFlag) },
            set: { isOn in
                if isOn { selectedRedFlags.insert(redFlag) } else { selectedRedFlags.remove(redFlag) }
            }
        )
    }

    private func saveEntry() async {
        isSaving = true
        errorMessage = nil

        let symptomType: SymptomType
        if selectedSymptom.id == otherSymptom.id {
            let trimmed = customSymptomName.trimmingCharacters(in: .whitespacesAndNewlines)
            symptomType = SymptomType(name: trimmed.isEmpty ? "Other" : trimmed, category: "Custom", isCustom: true)
        } else {
            symptomType = selectedSymptom
        }

        let duration = Int(durationMinutes)
        let sleep = Double(sleepHours)
        let hydration = Double(hydrationLiters)
        let caffeine = Int(caffeineMg)
        let alcohol = Int(alcoholUnits)

        let meds = medsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let context = SymptomContext(
            sleepHours: sleep,
            hydrationLiters: hydration,
            caffeineMg: caffeine,
            alcoholUnits: alcohol,
            periodTag: selectedPeriodTag == .none ? nil : selectedPeriodTag,
            medsTaken: meds
        )

        let entry = SymptomEntry(
            symptomType: symptomType,
            symptomNameOverride: symptomType.isCustom ? symptomType.name : nil,
            bodyLocation: bodyLocation,
            severity: Int(severity),
            onset: onset,
            durationMinutes: duration,
            qualities: Array(selectedQualities),
            associatedSymptoms: Array(selectedAssociated),
            possibleTriggers: Array(selectedTriggers),
            context: context,
            notes: notes,
            attachmentIDs: [],
            redFlags: Array(selectedRedFlags)
        )

        do {
            try await SwiftDataStore(context: modelContext).save(entry: entry)
            isSaving = false
            onSaved?()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "Failed to save entry."
        }
    }
}

private struct LogSeveritySlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            HStack(alignment: .lastTextBaseline, spacing: Theme.spacingS) {
                Text("\(Int(value))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(severityColor)

                Text("/ 10")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(severityEmoji)
                        .font(.system(size: 28))
                    Text(severityLabel)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(severityColor)
                }
            }

            Slider(value: $value, in: 0...10, step: 1)
                .tint(severityColor)

            HStack {
                Text("0")
                Spacer()
                Text("5")
                Spacer()
                Text("10")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var severityColor: Color {
        Theme.severityColor(for: Int(value))
    }

    private var severityLabel: String {
        switch Int(value) {
        case 0: return "None"
        case 1...3: return "Mild"
        case 4...5: return "Moderate"
        case 6...7: return "Severe"
        case 8...9: return "Very severe"
        default: return "Unbearable"
        }
    }

    private var severityEmoji: String {
        switch Int(value) {
        case 0: return "😊"
        case 1...3: return "🙂"
        case 4...5: return "😐"
        case 6...7: return "😖"
        case 8...9: return "😣"
        default: return "😫"
        }
    }
}

#Preview {
    LogSymptomFlowView()
        .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
}
