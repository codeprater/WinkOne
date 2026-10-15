import PhotosUI
import SwiftUI
#if canImport(ImagePlayground)
import ImagePlayground
#endif
import UIKit

// MARK: - Processing

enum PhotoProcessor {
    /// Re-encodes to JPEG at `WinkLimits.photoLongEdge` on the long edge.
    ///
    /// Redrawing into a fresh bitmap context is what strips the metadata: the
    /// output carries only the pixels, so EXIF, GPS, device and timestamps are
    /// gone. Orientation survives because `UIImage.draw(in:)` bakes it into the
    /// pixels before encoding.
    static func prepare(_ image: UIImage) -> Data? {
        let normalized = resized(image)
        guard var data = normalized.jpegData(compressionQuality: WinkLimits.photoQuality) else {
            return nil
        }
        // Step the quality down rather than failing outright on a dense photo.
        var quality = WinkLimits.photoQuality
        while data.count > WinkLimits.maxPhotoBytes, quality > 0.35 {
            quality -= 0.1
            guard let retry = normalized.jpegData(compressionQuality: quality) else { break }
            data = retry
        }
        return data.count <= WinkLimits.maxPhotoBytes ? data : nil
    }

    private static func resized(_ image: UIImage) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        let scale = longEdge > WinkLimits.photoLongEdge ? WinkLimits.photoLongEdge / longEdge : 1
        let target = CGSize(width: (image.size.width * scale).rounded(),
                            height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Pickers

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in self.parent.onPick(image) }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage else { return }
            parent.onPick(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Studio

struct PhotoStudio: View {
    @Binding var photoData: Data?
    @Binding var caption: String
    @Binding var overlaySymbol: String?
    var fromName: String
    var placeName: String?
    var onReject: (String) -> Void

    @State private var showPlayground = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showSymbolPicker = false
    @State private var symbolQuery = ""

    private var current: WinkMessage {
        WinkMessage(
            text: caption,
            pack: "Photo",
            atmosphere: Composer.photo.atmosphere,
            ink: Composer.photo.ink,
            placeName: placeName,
            photoData: photoData,
            photoCaption: caption.isEmpty ? nil : caption,
            photoSymbolName: overlaySymbol
        )
    }

    var body: some View {
        StudioLayout {
            WinkCardView(message: current, fromName: fromName)
        } controls: {
            VStack(spacing: 14) {
            HStack(spacing: 8) {
                sourceButton("photo.on.rectangle", "Library", isSelected: false) { showLibrary = true }
                sourceButton("camera.fill", "Camera", isSelected: false) { showCamera = true }
                sourceButton(
                    overlaySymbol == nil ? "face.smiling" : "checkmark.seal.fill",
                    overlaySymbol == nil ? "Symbol" : "Change",
                    isSelected: overlaySymbol != nil
                ) { showSymbolPicker.toggle() }
                if WinkAI.makesImages {
                    sourceButton("apple.intelligence", "Imagine", isSelected: false) { showPlayground = true }
                }
                if photoData != nil {
                    sourceButton("trash", "Clear", isSelected: false) {
                        photoData = nil
                        overlaySymbol = nil
                    }
                }
            }

            TextField("Caption", text: $caption)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .winkWritingTools()
                .onChange(of: caption) { _, newValue in
                    if newValue.count > WinkLimits.photoCaption {
                        caption = String(newValue.prefix(WinkLimits.photoCaption))
                    }
                }
                .accessibilityLabel("Caption for your photo")

            SuggestLinesRow(composerName: "Photo", target: $caption)

            if showSymbolPicker {
                symbolStrip
            } else {
                Text(photoData == nil
                     ? "Pick a photo. Location and camera data are stripped before it sends."
                     : "Metadata stripped. Ready to send.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .fixedSize(horizontal: false, vertical: true)
            }
            }
        }
        .modifier(PlaygroundSheet(isPresented: $showPlayground, concept: caption, onImage: acceptURL))
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker(onPick: accept)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(onPick: accept)
        }
    }

    private func acceptURL(_ url: URL) {
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            onReject("That image could not be read.")
            return
        }
        accept(image)
    }

    private func accept(_ image: UIImage) {
        guard let data = PhotoProcessor.prepare(image) else {
            onReject("That photo is too large to send. Try another.")
            return
        }
        photoData = data
    }

    private func sourceButton(_ icon: String, _ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? WinkColor.night : WinkColor.volt)
            .frame(width: 62, height: 68)
        }
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var symbolStrip: some View {
        VStack(spacing: 8) {
            TextField("Search symbols", text: $symbolQuery)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .accessibilityLabel("Search symbols to overlay")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        overlaySymbol = nil
                    } label: {
                        Image(systemName: "nosign")
                            .font(.system(size: 26))
                            .foregroundStyle(overlaySymbol == nil ? WinkColor.night : .white.opacity(0.8))
                            .frame(minWidth: 54, minHeight: 54)
                            .background(overlaySymbol == nil ? WinkColor.volt : Color.white.opacity(0.08))
                    }
                    .accessibilityLabel("No overlay symbol")
                    .accessibilityAddTraits(.isButton)

                    ForEach(SFSymbolCatalog.matches(symbolQuery, category: "").prefix(60)) { record in
                        Button {
                            overlaySymbol = record.name
                        } label: {
                            Image(systemName: record.name)
                                .font(.system(size: 26))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(overlaySymbol == record.name ? WinkColor.night : .white.opacity(0.85))
                                .frame(minWidth: 54, minHeight: 54)
                                .background(overlaySymbol == record.name ? WinkColor.volt : Color.white.opacity(0.06))
                        }
                        .accessibilityLabel(SFSymbolCatalog.spokenLabel(for: record))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 52)
        }
    }
}


/// Image Playground only exists on iOS 18.4 and up, and only runs on Apple
/// Intelligence hardware. Wrapping it in a modifier keeps the availability
/// check out of the studio's body.
private struct PlaygroundSheet: ViewModifier {
    @Binding var isPresented: Bool
    var concept: String
    var onImage: (URL) -> Void

    func body(content: Content) -> some View {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, *) {
            content.imagePlaygroundSheet(
                isPresented: $isPresented,
                concept: concept.isEmpty ? "a friendly greeting card" : concept
            ) { url in
                onImage(url)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
