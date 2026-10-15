import SwiftUI

struct OnboardingView: View {
    @Binding var name: String
    var onFinish: () -> Void

    @State private var page = 0
    @State private var draft = ""
    @State private var acceptedPolicies = false

    private let lastPage = 6

    var body: some View {
        ZStack {
            WinkColor.night.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    summaryPage.tag(1)
                    namePage.tag(2)
                    sendPage.tag(3)
                    drawPage.tag(4)
                    locationPage.tag(5)
                    rulesPage.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: advance) {
                    Text(page == lastPage ? "LET'S GO" : "CONTINUE")
                        .font(WinkFont.label(14))
                        .tracking(1.6)
                        .foregroundStyle(WinkColor.night)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canAdvance ? WinkColor.volt : WinkColor.volt.opacity(0.35))
                }
                .disabled(!canAdvance)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear { draft = name }
    }

    private var canAdvance: Bool {
        switch page {
        case 1:
            return acceptedPolicies
        case 2:
            return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func advance() {
        switch page {
        case 1:
            // summary page, no draft update, just proceed if acceptedPolicies true
            if !acceptedPolicies {
                return
            }
        case 2:
            name = draft
        case 6:
            name = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : draft
            WinkNotify.shared.configure()
            onFinish()
            return
        default:
            break
        }
        withAnimation { page += 1 }
    }

    /// New Summary Page with Apple-required policies
    private var summaryPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(WinkColor.volt)
                Text("18+ Age Requirement")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text("You must be 18 years or older to use WINK. By continuing, you agree to the End User License Agreement (EULA) and Terms of Service.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                policyRow("No tolerance for objectionable content or abusive behavior.")
                policyRow("Every card is filtered before sending and before you see it.")
                policyRow("You can report, block, and remove any card instantly.")
                policyRow("We review all reports within 24 hours.")
                policyRow("Contact support anytime via the in-app help section.")
            }
            .padding(.top, 4)

            Toggle(isOn: $acceptedPolicies) {
                Text("I have read and agree to the policies above.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: WinkColor.volt))
            .padding(.top, 20)

            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private func policyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
                .frame(width: 24)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toolRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("WINK")
                .font(WinkFont.brand(56))
                .tracking(6)
                .foregroundStyle(WinkColor.volt)
            Text("Real Life. Unmuted.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Send a card to someone in the room, or anywhere your share sheet can reach.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your name")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("This is what people see on a WINK. Scribble it with Apple Pencil if you want.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            TextField("First name or handle", text: $draft)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.top, 12)
            Rectangle()
                .fill(WinkColor.volt)
                .frame(height: 2)
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private var sendPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: WinkSymbol.send)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
            Text("Hit Send.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Pick iMessage, Mail, AirDrop, or Nearby. Same card, wherever they are.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            VStack(alignment: .leading, spacing: 14) {
                methodRow("message.fill", "iMessage")
                methodRow("envelope.fill", "Mail")
                methodRow("square.and.arrow.up", "AirDrop")
                methodRow(WinkSymbol.nearby, "Nearby (peer to peer)")
            }
            .padding(.top, 12)
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private var drawPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
            Text("Write it by hand.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Apple Pencil or a finger. Scribble into captions. The card renders like an invite.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private var locationPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "mappin")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
            Text("Location is a toggle.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Off by default. When you want them to find you, pin the place on the card.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    /// Guideline 1.2: the zero-tolerance policy and the reporting, blocking and
    /// removal tools are shown before the user ever composes a card.
    private var rulesPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
            Text("Zero tolerance.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("No objectionable content and no abusive users on WINK. Every card is filtered before it sends and before you see it.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                toolRow("exclamationmark.triangle.fill", "Report any card you receive")
                toolRow("hand.raised.fill", "Block anyone, permanently")
                toolRow("trash.fill", "Remove any card instantly")
            }
            .padding(.top, 4)

            Text("We act on reports within \(WinkAgreement.responseWindowHours) hours. Content removed, sender ejected. Blocking and deleting content happens instantly. Reach us at \(WinkAgreement.supportEmail).")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Spacer()
        }
        .padding(28)
        .padding(.top, 40)
    }

    private func methodRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WinkColor.volt)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
