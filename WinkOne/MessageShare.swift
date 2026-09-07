import SwiftUI
import UIKit

enum CardRenderer {
    @MainActor
    static func image(for message: WinkMessage, fromName: String?) -> UIImage? {
        let card = WinkCardView(message: message, fromName: fromName)
            .frame(width: InviteCard.renderWidth, height: InviteCard.renderHeight)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage
    }
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]
    var nearbyTitle: String
    var nearbyEnabled: Bool
    var onNearby: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let nearby = NearbyWinkActivity(title: nearbyTitle, enabled: nearbyEnabled) {
            onNearby()
        }
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: [nearby]
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .markupAsPDF
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class NearbyWinkActivity: UIActivity {
    private let title: String
    private let enabled: Bool
    private let action: () -> Void

    init(title: String, enabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
        super.init()
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.cprater.wink.nearby")
    }

    override var activityTitle: String? { title }

    override var activityImage: UIImage? {
        UIImage(systemName: WinkSymbol.nearby)
    }

    override class var activityCategory: UIActivity.Category { .action }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        enabled
    }

    override func perform() {
        action()
        activityDidFinish(true)
    }
}
