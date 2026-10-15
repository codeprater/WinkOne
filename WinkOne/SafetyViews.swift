import Combine
import MessageUI
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

                    Text("Report content or abuse: \(WinkAgreement.supportEmail). Answered within \(WinkAgreement.responseWindowHours) hours.")
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
    @State private var delivering: WinkReport?
    @ObservedObject private var outbox = ReportOutbox.shared

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
                    Button {
                        SupportMail.open(subject: "WINK Help request")
                    } label: {
                        Label("Contact the developer", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("Get help")
                } footer: {
                    Text("\(WinkAgreement.supportEmail)\nEvery report of objectionable content is reviewed and acted on within \(WinkAgreement.responseWindowHours) hours. Offending content is removed and the user who sent it is ejected from WINK: their device is removed for everyone, not just for you.")
                }

                if !outbox.pending.isEmpty {
                    Section {
                        ForEach(outbox.pending) { report in
                            Button {
                                delivering = report
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Label("Send report: \(report.reportedName)", systemImage: "paperplane.fill")
                                    Text(report.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Reports waiting to send")
                    } footer: {
                        Text("These reports have not reached the developer yet. Tap one to send it.")
                    }
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
                                        key: wink.senderKey ?? ""
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
                                Text("\(report.reportedName), \(report.date, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Terms & content policy") { showTerms = true }
                    LabeledContent("Your WINK ID") {
                        Text(EjectionList.localKey)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } footer: {
                    Text("WINK \(WinkAgreement.supportEmail)\nInclude your WINK ID if you write to us about your own account.")
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
            .sheet(item: $delivering) { report in
                ReportDeliverySheet(report: report) { sent in
                    if sent { outbox.markSent(report) }
                }
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
    /// The sender's WINK ID when known. Goes in the report so the developer
    /// can eject that exact device.
    var key: String = ""
}

struct ReportSheet: View {
    @ObservedObject var moderation: ModerationStore
    let target: ReportTarget

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var reason: ReportReason = .sexual
    @State private var details = ""
    @State private var submitted = false
    @State private var delivery: WinkReport?

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
                    Text("Submitting immediately removes this content from your device and blocks the sender. We review every report and act within \(WinkAgreement.responseWindowHours) hours, removing the content and ejecting the user who sent it. Reports go to \(WinkAgreement.supportEmail).")
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
            .sheet(item: $delivery, onDismiss: { submitted = true }) { report in
                ReportDeliverySheet(report: report) { sent in
                    // Not sent (cancelled, or no mail account): keep it in the
                    // Safety Center outbox so it still reaches the developer.
                    if !sent { ReportOutbox.shared.add(report) }
                }
            }
            .alert("Report filed", isPresented: $submitted) {
                Button("OK") { dismiss() }
            } message: {
                Text("The content is removed and \(name.isEmpty ? "the sender" : name) is blocked on this device. We act on every report within \(WinkAgreement.responseWindowHours) hours, removing the content and ejecting the user from WINK.")
            }
        }
    }

    private func submit() {
        let report = moderation.report(
            name: name,
            key: target.key,
            reason: reason,
            details: details,
            evidence: target.evidence
        )
        // Hand the report to the developer: Mail inside the app, or a
        // copyable report when this device has no mail account.
        delivery = report
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

    static func subject(for report: WinkReport) -> String {
        "WINK report: \(report.reason)"
    }

    /// Everything the developer needs to act: the sender's WINK ID is what
    /// goes on the ejection list.
    static func body(for report: WinkReport) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return """
        WINK content report

        Report ID: \(report.id.uuidString)
        Date: \(report.date.formatted())
        Reported user: \(report.reportedName)
        Reported WINK ID: \(report.reportedKey ?? "unknown (sender on an older build)")
        Reason: \(report.reason)
        Reporter WINK ID: \(report.reporterKey ?? EjectionList.localKey)
        App: \(version) (\(build))

        Details:
        \(report.details.isEmpty ? "(none)" : report.details)

        Content:
        \(report.evidence.isEmpty ? "(none)" : report.evidence)
        """
    }

    static func send(report: WinkReport) {
        open(subject: subject(for: report), body: body(for: report))
    }
}

// MARK: - Report delivery

/// Gets a report to the developer. Mail inside the app when the device has a
/// mail account; otherwise the full report, ready to copy, with the address.
/// Never a silent no-op: a report that is not sent waits in the outbox.
struct ReportDeliverySheet: View {
    let report: WinkReport
    var onFinish: (Bool) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        if MailComposer.canSend {
            MailComposer(
                to: WinkAgreement.supportEmail,
                subject: SupportMail.subject(for: report),
                body: SupportMail.body(for: report)
            ) { sent in
                finish(sent)
            }
            .ignoresSafeArea()
        } else {
            fallback
        }
    }

    private var fallback: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Send this report to \(WinkAgreement.supportEmail)")
                        .font(.headline)
                    Text("This device has no Mail account set up. Copy the report and send it from any email app. We act on it within \(WinkAgreement.responseWindowHours) hours.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = "To: \(WinkAgreement.supportEmail)\nSubject: \(SupportMail.subject(for: report))\n\n\(SupportMail.body(for: report))"
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy report", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(SupportMail.body(for: report))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.12)))
                }
                .padding(20)
            }
            .navigationTitle("Send report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish(copied) }
                }
            }
        }
    }

    private func finish(_ sent: Bool) {
        onFinish(sent)
        dismiss()
    }
}

struct MailComposer: UIViewControllerRepresentable {
    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    let to: String
    let subject: String
    let body: String
    var onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([to])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let sent = result == .sent || result == .saved
            Task { @MainActor in self.onFinish(sent) }
        }
    }
}

/// Reports that have not reached the developer yet: cancelled mail, no mail
/// account, or filed from Apple Watch. Shown in Safety Center until sent.
final class ReportOutbox: ObservableObject {
    static let shared = ReportOutbox()

    @Published private(set) var pending: [WinkReport] = []

    private let storageKey = "wink.reportOutbox.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WinkReport].self, from: data) {
            pending = saved
        }
    }

    func add(_ report: WinkReport) {
        guard !pending.contains(where: { $0.id == report.id }) else { return }
        pending.insert(report, at: 0)
        save()
    }

    func markSent(_ report: WinkReport) {
        pending.removeAll { $0.id == report.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Ejected device

/// Shown when the developer has ejected this device. Nothing can be sent or
/// received; the only way forward is the appeal address.
struct EjectedView: View {
    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(WinkColor.ember)
                Text("Removed from WINK")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("This device was removed after a report of objectionable content, under the WINK terms. It can no longer send or receive winks.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button {
                    SupportMail.open(
                        subject: "WINK appeal",
                        body: "WINK ID: \(EjectionList.localKey)\n\n"
                    )
                } label: {
                    Text("Appeal: \(WinkAgreement.supportEmail)")
                        .font(WinkFont.label(13))
                        .foregroundStyle(WinkColor.night)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(WinkColor.volt))
                }
                Text(EjectionList.localKey)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .textSelection(.enabled)
            }
            .padding(32)
        }
    }
}
