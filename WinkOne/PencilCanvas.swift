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
            drawing.wrappedValue = canvasView.drawing
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

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.14, blue: 0.06), Color(red: 0.42, green: 0.32, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                PencilCanvas(drawing: $drawing, toolkitActive: toolkitActive)
                    .padding(8)
            }
            .aspectRatio(InviteCard.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: InviteCard.cornerRadius, style: .continuous))
            .padding(.horizontal, 36)

            HStack {
                Button("Clear") { drawing = PKDrawing() }
                    .font(WinkFont.label(12))
                    .foregroundStyle(WinkColor.volt)
                Spacer()
                Text("Pencil or finger")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 36)

            TextField("Caption this WINK", text: $caption)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(WinkColor.volt)
                .padding(.horizontal, 36)
                .onChange(of: caption) { _, newValue in
                    if newValue.count > 48 {
                        caption = String(newValue.prefix(48))
                    }
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
