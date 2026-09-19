import PhotosUI
import SwiftUI
import UIKit

/// The one card that is about who you are rather than what you are saying.
struct NameTagStudio: View {
    @Binding var photoData: Data?
    @Binding var name: String
    var fromName: String
    var placeName: String?
    var onReject: (String) -> Void

    @State private var showLibrary = false
    @State private var showCamera = false

    private var current: WinkMessage {
        WinkMessage(
            text: name,
            pack: "Name Tag",
            atmosphere: Composer.nameTag.atmosphere,
            ink: Composer.nameTag.ink,
            placeName: placeName,
            photoData: photoData,
            nameTagName: name.isEmpty ? fromName : name
        )
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 14) {
                HStack(spacing: 22) {
                    sourceButton("photo.on.rectangle", "Library") { showLibrary = true }
                    sourceButton("camera.fill", "Camera") { showCamera = true }
                    if photoData != nil {
                        sourceButton("trash", "Clear") { photoData = nil }
                    }
                }

                TextField(fromName, text: $name)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .tint(WinkColor.volt)
                    .padding(.horizontal, 36)
                    .onChange(of: name) { _, newValue in
                        if newValue.count > WinkLimits.nameTagName {
                            name = String(newValue.prefix(WinkLimits.nameTagName))
                        }
                    }
                    .accessibilityLabel("The name on your tag")

                Text(photoData == nil
                     ? "Add a photo. Location and camera data are stripped before it sends."
                     : "Photo ready. Location and camera data were stripped.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker(onPick: accept)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(onPick: accept)
        }
    }

    /// Same pipeline as the Photo composer: redrawn into a fresh bitmap so no
    /// EXIF, no GPS, no camera model survives.
    private func accept(_ image: UIImage) {
        guard let data = PhotoProcessor.prepare(image) else {
            onReject("That photo could not be prepared.")
            return
        }
        photoData = data
    }

    private func sourceButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(WinkColor.volt)
            .frame(width: 62, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
        .accessibilityLabel(title)
    }
}
