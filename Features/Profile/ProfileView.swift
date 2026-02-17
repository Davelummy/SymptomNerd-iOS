import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ProfileViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var photoError: String?
    @State private var newHistoryTitle: String = ""
    @State private var newHistoryDetails: String = ""
    @State private var newHistoryDate: Date = Date()
    @State private var isShowingDobPicker = false
    @State private var isEditingMedicalProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingL) {
                CardView {
                    HStack(spacing: Theme.spacingM) {
                        ZStack {
                            if let profileImage {
                                profileImage
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.accentDeep)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .background(Theme.accentSoft)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.glassStroke, lineWidth: 1))

                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text(authManager.displayName.isEmpty ? "Your Profile" : authManager.displayName)
                                .font(Typography.title2)
                            Text(authManager.email.isEmpty ? "Local profile" : authManager.email)
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Text("Stored on-device by default.")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(Theme.accent)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                if let photoError {
                    Text(photoError)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        HStack {
                            Text("Medical profile")
                                .font(Typography.headline)
                            Spacer()
                            Button(isEditingMedicalProfile ? "Cancel" : "Edit") {
                                UIApplication.shared.endEditing()
                                isShowingDobPicker = false
                                isEditingMedicalProfile.toggle()
                            }
                            .font(Typography.caption)
                            .buttonStyle(.plain)
                        }

                        if isEditingMedicalProfile {
                            HStack(spacing: Theme.spacingS) {
                                TextField("First name", text: Binding(
                                    get: { viewModel.medicalProfile.firstName },
                                    set: { viewModel.medicalProfile.firstName = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                TextField("Last name", text: Binding(
                                    get: { viewModel.medicalProfile.lastName },
                                    set: { viewModel.medicalProfile.lastName = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                isShowingDobPicker.toggle()
                            } label: {
                                HStack {
                                    Text("Date of birth")
                                    Spacer()
                                    Text(viewModel.medicalProfile.dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if isShowingDobPicker {
                                DatePicker(
                                    "Date of birth",
                                    selection: Binding(
                                        get: { viewModel.medicalProfile.dateOfBirth ?? Date(timeIntervalSince1970: 0) },
                                        set: { viewModel.medicalProfile.dateOfBirth = $0 }
                                    ),
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                            }

                            TextField("Sex at birth", text: Binding(
                                get: { viewModel.medicalProfile.sexAtBirth },
                                set: { viewModel.medicalProfile.sexAtBirth = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Blood group (e.g. O+)", text: Binding(
                                get: { viewModel.medicalProfile.bloodGroup },
                                set: { viewModel.medicalProfile.bloodGroup = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Allergies", text: Binding(
                                get: { viewModel.medicalProfile.allergies },
                                set: { viewModel.medicalProfile.allergies = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Chronic conditions", text: Binding(
                                get: { viewModel.medicalProfile.chronicConditions },
                                set: { viewModel.medicalProfile.chronicConditions = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Current medications", text: Binding(
                                get: { viewModel.medicalProfile.currentMedications },
                                set: { viewModel.medicalProfile.currentMedications = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Past surgeries", text: Binding(
                                get: { viewModel.medicalProfile.pastSurgeries },
                                set: { viewModel.medicalProfile.pastSurgeries = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Family history to note", text: Binding(
                                get: { viewModel.medicalProfile.familyHistory },
                                set: { viewModel.medicalProfile.familyHistory = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Notes for pharmacist/clinician", text: Binding(
                                get: { viewModel.medicalProfile.notesForCareTeam },
                                set: { viewModel.medicalProfile.notesForCareTeam = $0 }
                            ), axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                            PrimaryButton(title: "Save medical profile", systemImage: "checkmark.circle.fill") {
                                viewModel.saveMedicalProfile()
                                UIApplication.shared.endEditing()
                                isShowingDobPicker = false
                                isEditingMedicalProfile = false
                            }
                        } else {
                            profileSummaryRow(title: "Name", value: [viewModel.medicalProfile.firstName, viewModel.medicalProfile.lastName].joined(separator: " ").trimmingCharacters(in: .whitespaces))
                            profileSummaryRow(title: "Date of birth", value: viewModel.medicalProfile.dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "")
                            profileSummaryRow(title: "Sex at birth", value: viewModel.medicalProfile.sexAtBirth)
                            profileSummaryRow(title: "Blood group", value: viewModel.medicalProfile.bloodGroup)
                            profileSummaryRow(title: "Allergies", value: viewModel.medicalProfile.allergies)
                            profileSummaryRow(title: "Chronic conditions", value: viewModel.medicalProfile.chronicConditions)
                            profileSummaryRow(title: "Current medications", value: viewModel.medicalProfile.currentMedications)
                            profileSummaryRow(title: "Past surgeries", value: viewModel.medicalProfile.pastSurgeries)
                            profileSummaryRow(title: "Family history", value: viewModel.medicalProfile.familyHistory)
                            profileSummaryRow(title: "Care-team notes", value: viewModel.medicalProfile.notesForCareTeam)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Health history highlights")
                            .font(Typography.headline)

                        DatePicker("Date", selection: $newHistoryDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        TextField("Title (e.g. Asthma diagnosis)", text: $newHistoryTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Details", text: $newHistoryDetails, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        PrimaryButton(title: "Add history record", systemImage: "plus.circle.fill") {
                            viewModel.addHistoryRecord(title: newHistoryTitle, details: newHistoryDetails, date: newHistoryDate)
                            newHistoryTitle = ""
                            newHistoryDetails = ""
                            newHistoryDate = Date()
                            UIApplication.shared.endEditing()
                        }

                        if viewModel.healthHistory.isEmpty {
                            Text("No records yet.")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            VStack(alignment: .leading, spacing: Theme.spacingS) {
                                ForEach(viewModel.healthHistory.prefix(8)) { record in
                                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                        HStack {
                                            Text(record.title)
                                                .font(Typography.headline)
                                            Spacer()
                                            Button(role: .destructive) {
                                                viewModel.deleteHistoryRecord(id: record.id)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                        Text(record.details.isEmpty ? "No details added." : record.details)
                                            .font(Typography.body)
                                            .foregroundStyle(Theme.textSecondary)
                                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(Typography.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(.vertical, Theme.spacingXS)
                                    Divider()
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Health records")
                            .font(Typography.headline)
                        if let last = viewModel.lastEntry {
                            Text("Last log: \(last.symptomType.name) • \(last.severity)/10")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("No symptoms logged yet.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        HStack(spacing: Theme.spacingS) {
                            ChipView(title: "Logs \(viewModel.entries.count)")
                            ChipView(title: String(format: "Avg %.1f/10", viewModel.averageSeverity))
                            ChipView(title: "7d \(viewModel.last7DaysCount)")
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Highlights")
                            .font(Typography.headline)

                        HStack(spacing: Theme.spacingS) {
                            MetricCard(
                                title: "Most common",
                                value: viewModel.mostCommonSymptom,
                                systemImage: "star.fill",
                                tint: Theme.accent
                            )
                            MetricCard(
                                title: "Average severity",
                                value: String(format: "%.1f/10", viewModel.averageSeverity),
                                systemImage: "waveform.path.ecg",
                                tint: Theme.accentSecondary
                            )
                        }

                        if !viewModel.commonTriggers.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                Text("Common triggers")
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                HStack(spacing: Theme.spacingS) {
                                    ForEach(viewModel.commonTriggers, id: \.self) { trigger in
                                        ChipView(title: trigger)
                                    }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Last 7 days trend")
                            .font(Typography.headline)
                        if viewModel.entries.isEmpty {
                            Text("No logs yet.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Chart(viewModel.entries.suffix(14), id: \.id) { entry in
                                LineMark(
                                    x: .value("Date", entry.createdAt, unit: .day),
                                    y: .value("Severity", entry.severity)
                                )
                                .foregroundStyle(Theme.accent)
                                PointMark(
                                    x: .value("Date", entry.createdAt, unit: .day),
                                    y: .value("Severity", entry.severity)
                                )
                                .foregroundStyle(Theme.accentSecondary)
                            }
                            .frame(height: 150)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Recent entries")
                            .font(Typography.headline)

                        if viewModel.entries.isEmpty {
                            Text("Start logging to populate your records.")
                                .font(Typography.body)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(viewModel.entries.prefix(5)) { entry in
                                NavigationLink {
                                    TimelineEntryDetailView(entry: entry)
                                } label: {
                                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                        HStack {
                                            Text(entry.symptomType.name)
                                                .font(Typography.headline)
                                            Spacer()
                                            Text("\(entry.severity)/10")
                                                .font(Typography.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Text(DateHelpers.relativeDayString(for: entry.createdAt))
                                            .font(Typography.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(.vertical, Theme.spacingXS)
                                }
                                .buttonStyle(.plain)
                            }

                            NavigationLink {
                                TimelineView()
                            } label: {
                                Text("See full timeline")
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Settings")
                            .font(Typography.headline)
                        NavigationLink {
                            SettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundStyle(Theme.accent)
                                Text("App settings")
                                    .font(Typography.body)
                            }
                        }
                        .buttonStyle(.plain)
                        Text("Privacy, appearance, AI backend, and data controls.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                }
            }
            .screenPadding()
            .padding(.vertical, Theme.spacingL)
        }
        .navigationTitle("Profile")
        .dismissKeyboardOnTap()
        .task {
            viewModel.configure(client: SwiftDataStore(context: modelContext))
            await viewModel.load()
            await authManager.syncProfileImageFromCloud()
            if let image = authManager.loadProfileImage() {
                profileImage = Image(uiImage: image)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        try authManager.saveProfileImage(data: data)
                        profileImage = Image(uiImage: image)
                        photoError = nil
                    } else {
                        photoError = "Unable to load that photo."
                    }
                } catch {
                    photoError = "Photo upload failed."
                }
            }
        }
    }

    @ViewBuilder
    private func profileSummaryRow(title: String, value: String) -> some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(Typography.body)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, Theme.accentSoft)
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Typography.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingM)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthManager())
            .modelContainer(for: SymptomEntryRecord.self, inMemory: true)
    }
}
