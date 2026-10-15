import PencilKit
import SwiftUI
import UIKit

enum InkToolkit {
    private static var picker: PKToolPicker?
    private static weak var canvas: PKCanvasView?

    static func show(on canvas: PKCanvasView) {
        if self.canvas === canvas, picker?.isVisible == true { return }
        hide()
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        canvas.becomeFirstResponder()
        picker = toolPicker
        self.canvas = canvas
    }

    static func hide(from canvas: PKCanvasView? = nil) {
        let target = canvas ?? self.canvas
        if let target {
            picker?.setVisible(false, forFirstResponder: target)
            picker?.removeObserver(target)
            if target.isFirstResponder {
                target.resignFirstResponder()
            }
        }
        picker = nil
        self.canvas = nil
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var toolkitActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: UIColor.black, width: 6)
        canvas.alwaysBounceVertical = false
        canvas.overrideUserInterfaceStyle = .light
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.drawing = $drawing
        if canvas.drawing != drawing, !context.coordinator.isDrawing {
            canvas.drawing = drawing
        }
        if toolkitActive {
            InkToolkit.show(on: canvas)
        } else {
            InkToolkit.hide(from: canvas)
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        InkToolkit.hide(from: canvas)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        var isDrawing = false

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.drawing.wrappedValue = canvasView.drawing
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = false
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

struct HandwrittenStudio: View {
    @Binding var drawing: PKDrawing
    @Binding var caption: String
    var toolkitActive: Bool

    /// Apple's pen palette covers the bottom of the screen, Send included.
    /// This puts it away when the drawing is done.
    @State private var showPenTools = true

    var body: some View {
        StudioLayout {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.14, blue: 0.06), Color(red: 0.42, green: 0.32, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                PencilCanvas(drawing: $drawing, toolkitActive: toolkitActive && showPenTools)
                    .padding(8)
            }
            .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous))
        } controls: {
            VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    showPenTools.toggle()
                } label: {
                    Label(showPenTools ? "Done drawing" : "Pen tools",
                          systemImage: showPenTools ? "checkmark" : "pencil.tip")
                        .font(WinkFont.label(13))
                        .foregroundStyle(WinkColor.night)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Capsule().fill(WinkColor.volt))
                }
                .accessibilityHint(showPenTools ? "Puts the pen palette away so you can send" : "Shows the pen palette")

                Button("Clear") { drawing = PKDrawing() }
                    .font(WinkFont.label(13))
                    .foregroundStyle(WinkColor.volt)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(Color.white.opacity(0.09)))

                Spacer()
            }
            .padding(.horizontal, 24)

            TextField("Caption this WINK", text: $caption)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .winkWritingTools()
                .onChange(of: caption) { _, newValue in
                    if newValue.count > 48 {
                        caption = String(newValue.prefix(48))
                    }
                }

            SuggestLinesRow(composerName: "Handwritten", target: $caption)
            }
        }
        .onAppear {
            if toolkitActive == false {
                InkToolkit.hide()
            }
        }
        .onDisappear {
            InkToolkit.hide()
        }
    }
}
