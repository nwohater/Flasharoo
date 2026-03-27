//
//  DrawingCanvasView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  UIViewRepresentable wrapping PKCanvasView with PKToolPicker.
//  Input policy: .anyInput — supports Pencil, finger, and mouse/trackpad.
//

import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing          = drawing
        canvas.drawingPolicy    = .anyInput
        canvas.backgroundColor  = .systemBackground
        canvas.isOpaque         = true
        canvas.delegate         = context.coordinator

        // Attach tool picker
        let picker = PKToolPicker()
        context.coordinator.toolPicker = picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)

        // Must be first responder for the picker to appear
        DispatchQueue.main.async { canvas.becomeFirstResponder() }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Sync drawing if changed externally (e.g. loading existing drawing)
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        /// Strong reference keeps the picker alive for the canvas lifetime.
        var toolPicker: PKToolPicker?

        init(_ parent: DrawingCanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
