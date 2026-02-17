import SwiftUI
import SwiftData

struct LogSymptomFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

                Section("Severity") {
                    HStack {
                        Text("\(Int(severity))/10")
                            .font(Typography.headline)
                        Spacer()
                    }
                    Slider(value: $severity, in: 0...10, step: 1)
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
            periodTag: nil,
            medsTaken: meds
        )

        let entry = SymptomEntry(
            symptomType: symptomType,
            symptomNameOverride: symptomType.isCustom ? symptomType.name : nil,
            bodyLocation: nil,
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

#Preview {
    LogSymptomFlowView()
        .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
}
