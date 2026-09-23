import SwiftUI
import UIKit

// MARK: - Agreement gate

/// Hard gate shown before any content can be created or received.
/// Guideline 1.2: users must agree to terms that make clear there is no
/// tolerance for objectionable content or abusive users.
struct AgreementGateView: View {
    @Binding var acceptedVersion: String
    var onAccept: () -> Void

    @State private var confirmsAge = false
    @State private var acceptsTerms = false
    @State private var showDeclined = false

    private var canContinue: Bool { confirmsAge && acceptsTerms }

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WINK")
                        .font(WinkFont.brand(38))
                        .tracking(5)
                        .foregroundStyle(WinkColor.volt)
                    Text("Before you send anything")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(WinkAgreement.summary)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(WinkColor.volt.opacity(0.9))
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOUSE RULES")
                                .font(WinkFont.label(11))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.5))
                            ForEach(WinkAgreement.houseRules, id: \.self) { rule in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "xmark.octagon.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(WinkColor.ember)
                                        .padding(.top, 2)
                                    Text(rule)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Divider().overlay(Color.white.opacity(0.15))

                        Text(WinkAgreement.text)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("App Store age rating: \(WinkAgreement.appStoreAgeRating)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(WinkColor.volt.opacity(0.9))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Divider().overlay(Color.white.opacity(0.15))

                    consentRow(
                        isOn: $confirmsAge,
                        text: "I am \(WinkAgreement.minimumAge) years of age or older."
                    )
                    consentRow(
                        isOn: $acceptsTerms,
                        text: "I agree to the Terms and understand there is zero tolerance for objectionable content or abusive users."
                    )

                    Button {
                        acceptedVersion = WinkAgreement.version
                        onAccept()
                    } label: {
                        Text("I AGREE")
                            .font(WinkFont.label(14))
                            .tracking(1.6)
                            .foregroundStyle(WinkColor.night)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(canContinue ? WinkColor.volt : WinkColor.volt.opacity(0.28))
                    }
                    .disabled(!canContinue)

                    Button("Decline") { showDeclined = true }
                        .font(WinkFont.label(12))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)

                    Text("Report content or abuse: \(WinkAgreement.supportEmail) — answered within \(WinkAgreement.responseWindowHours) hours.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .alert("You can't use WINK without agreeing", isPresented: $showDeclined) {
            Button("Back to Terms", role: .cancel) {}
        } message: {
            Text("WINK sends content between people, so everyone has to accept the content policy first. Questions: \(WinkAgreement.supportEmail)")
        }
    }

    private func consentRow(isOn: Binding<Bool>, text: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? WinkColor.volt : .white.opacity(0.4))
                Text(text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityAddTraits(isOn.wrappedValue ? [.isSelected] : [])
    }
}

// MARK: - Safety Center

/// Always reachable from the main screen. Holds reporting, blocking, removal,
/// the content policy, and developer contact information.
struct SafetyCenterView: View {
    @ObservedObject var moderation: ModerationStore
    var onDismiss: () -> Void

    @State private var reportTarget: ReportTarget?
    @State private var showTerms = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        reportTarget = ReportTarget(name: "", evidence: "")
                    } label: {
                        Label("Report content or a user", systemImage: "exclamationmark.bubble.fill")
                            .foregroundStyle(.red)
                    }

                    Section {
                        Text("This device keeps the review record and deadline locally. Reports are also prepared for the developer by email. Because WINK uses direct peer-to-peer delivery, local actions cannot guarantee removal from another device or remote ejection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if moderation.reports.filter({ !$0.isResolved }).isEmpty {
                            Text("No open reports.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(moderation.reports.filter { !$0.isResolved }) { report in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(report.reason)
                                            .font(.system(size: 15, weight: .semibold))
                                        Spacer()
                                        Text(report.status.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(report.deadline < Date() ? .red : .secondary)
                                    }
                                    Text("Target: \(report.reportedName) • reported \(report.date, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Review by \(report.deadline, style: .date) at \(report.deadline, style: .time)")
                                        .font(.caption)
                                        .foregroundStyle(report.deadline < Date() ? .red : .secondary)
                                    HStack {
                                        Button("Mark under review") {
                                            moderation.markUnderReview(report)
                                        }
                                        .buttonStyle(.borderless)
                                        Button("Remove & eject", role: .destructive) {
                                            moderation.resolve(report, removeAndEject: true)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Developer review queue")
                    } footer: {
                        Text("Developer handling contract: each report includes its reason, private sender/content IDs, timestamp, 24-hour deadline, removal state, and ejection timestamp. Remote enforcement requires the future moderation service described in UGC_SAFETY.md.")
                    }
                    Button {
                        SupportMail.open(subject: "WINK — Help request")
                    } label: {
                        Label("Contact the developer", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("Get help")
                } footer: {
                    Text("\(WinkAgreement.supportEmail)\nEvery report is reviewed within \(WinkAgreement.responseWindowHours) hours. Reported content is removed and its sender is blocked on this device immediately; remote ejection requires the future moderation service.")
                }

                Section {
                    HStack {
                        Label("Objectionable content filter", systemImage: "line.3.horizontal.decrease.circle.fill")
                        Spacer()
                        Text("ON")
                            .font(WinkFont.label(12))
                            .foregroundStyle(.green)
                    }
                    if moderation.filteredCount > 0 {
                        HStack {
                            Text("Blocked on this device")
                            Spacer()
                            Text("\(moderation.filteredCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Filtering")
                } footer: {
                    Text("Every card is screened before it is sent and again before it is shown to you. Matches are blocked and never delivered.")
                }

                Section {
                    if moderation.received.isEmpty {
                        Text("Nothing here yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(moderation.received) { wink in
                            ReceivedRow(
                                wink: wink,
                                onReport: {
                                    reportTarget = ReportTarget(
                                        name: wink.fromName,
                                        evidence: evidence(for: wink),
                                        contentID: wink.id,
                                        senderModerationID: wink.payload.senderModerationID
                                    )
                                },
                                onRemove: { moderation.remove(wink) }
                            )
                        }
                        .onDelete { moderation.removeReceived(at: $0) }

                        Button("Remove all", role: .destructive) {
                            moderation.removeAllReceived()
                        }
                    }
                } header: {
                    Text("Winks you've received")
                } footer: {
                    Text("Swipe any card to remove it immediately. Removal is instant and permanent on this device.")
                }

                Section {
                    if moderation.blocked.isEmpty {
                        Text("You haven't blocked anyone.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(moderation.blocked) { user in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                    Text(user.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Unblock") { moderation.unblock(user) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("Blocked users")
                } footer: {
                    Text("Blocked users can't find you, connect to you, or send you anything.")
                }

                if !moderation.reports.isEmpty {
                    Section("Your reports") {
                        ForEach(moderation.reports) { report in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(report.reason)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("\(report.reportedName) — \(report.date, style: .date) at \(report.date, style: .time)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(report.status.rawValue) • review by \(report.deadline, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(report.isResolved ? .green : .secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Terms & content policy") { showTerms = true }
                } footer: {
                    Text("WINK — \(WinkAgreement.supportEmail)")
                }
            }
            .navigationTitle("Safety Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportSheet(moderation: moderation, target: target)
            }
            .sheet(isPresented: $showTerms) {
                TermsView()
            }
        }
    }

    private func evidence(for wink: ReceivedWink) -> String {
        var parts: [String] = []
        if !wink.payload.text.isEmpty { parts.append(wink.payload.text) }
        if let symbol = wink.payload.symbolName { parts.append("symbol: \(symbol)") }
        if let place = wink.payload.placeName { parts.append("place: \(place)") }
        parts.append("pack: \(wink.payload.pack) / \(wink.payload.atmosphere)")
        return parts.joined(separator: " • ")
    }
}

private struct ReceivedRow: View {
    let wink: ReceivedWink
    var onReport: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wink.fromName)
                .font(.system(size: 15, weight: .semibold))
            Text(wink.payload.text.isEmpty ? (wink.payload.symbolName ?? "Card") : wink.payload.text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(wink.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Remove", role: .destructive, action: onRemove)
            Button("Report", action: onReport).tint(.orange)
        }
    }
}

// MARK: - Reporting

struct ReportTarget: Identifiable {
    let id = UUID()
    var name: String
    var evidence: String
    var contentID: UUID? = nil
    var senderModerationID: String? = nil
}

struct ReportSheet: View {
    @ObservedObject var moderation: ModerationStore
    let target: ReportTarget

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var reason: ReportReason = .sexual
    @State private var details = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Who sent it?") {
                    TextField("Display name on the card", text: $name)
                        .autocorrectionDisabled()
                }

                Section("What's wrong with it?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Anything else? (optional)") {
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Text("Submit report & block this user")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Submitting immediately removes this content from your device and blocks the sender. We review every report within \(WinkAgreement.responseWindowHours) hours. Reports are prepared for \(WinkAgreement.supportEmail); remote ejection requires the future moderation service.")
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { name = target.name }
            .alert("Report sent", isPresented: $submitted) {
                Button("OK") { dismiss() }
            } message: {
                Text("The content is removed and \(name.isEmpty ? "the sender" : name) is blocked on this device. We'll review this within \(WinkAgreement.responseWindowHours) hours.")
            }
        }
    }

    private func submit() {
        let report = moderation.report(
            name: name,
            reason: reason,
            details: details,
            evidence: target.evidence,
            targetContentID: target.contentID,
            reportedModerationID: target.senderModerationID
        )
        SupportMail.send(report: report)
        submitted = true
    }
}

// MARK: - Terms

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(WinkAgreement.text)
                    .font(.system(size: 14, design: .rounded))
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Support mail

enum SupportMail {
    static func open(subject: String, body: String = "") {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = WinkAgreement.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    static func send(report: WinkReport) {
        let body = """
        WINK content report

        Report ID: \(report.id.uuidString)
        Date: \(report.date.formatted())
        Reported user: \(report.reportedName)
        Internal sender ID: \(report.reportedModerationID ?? "(legacy report)")
        Content ID: \(report.targetContentID?.uuidString ?? "(not captured)")
        Reason: \(report.reason)

        Details:
        \(report.details.isEmpty ? "(none)" : report.details)

        Content:
        \(report.evidence.isEmpty ? "(none)" : report.evidence)
        """
        open(subject: "WINK report — \(report.reason)", body: body)
    }
}
