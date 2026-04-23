//
//  DrawingEditorView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Full-screen drawing sheet. On "Done":
//   1. Serialises PKDrawing → MediaAsset (.drawing)
//   2. Exports PNG at 2× scale → MediaAsset (.image)
//  Calls onSave(imageAssetID) so the editor can embed the img tag.
//  Drawing is iOS/iPadOS only — not available on macOS.
//

import SwiftUI
import SwiftData

#if os(iOS)
import PencilKit

struct DrawingEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let cardID: UUID
    /// Pass an existing drawing asset to re-edit it.
    var existingDrawingAsset: MediaAsset? = nil
    /// Called with the PNG image asset ID to embed in card HTML.
    let onSave: (UUID) -> Void

    @State private var drawing = PKDrawing()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            DrawingCanvasView(drawing: $drawing)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Drawing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Group {
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Done") { saveDrawing() }
                            }
                        }
                    }
                }
        }
        .onAppear(perform: loadExisting)
        .alert("Save Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Load existing

    private func loadExisting() {
        guard let asset = existingDrawingAsset else { return }
        Task {
            guard let data = try? await MediaService.shared.load(asset: asset),
                  let loaded = try? PKDrawing(data: data)
            else { return }
            await MainActor.run { drawing = loaded }
        }
    }

    // MARK: - Save

    private func saveDrawing() {
        guard !drawing.strokes.isEmpty else { dismiss(); return }
        isSaving = true

        Task {
            do {
                // 1. Save raw PKDrawing data
                let drawingData = drawing.dataRepresentation()
                let drawingAsset = try await MediaService.shared.save(
                    data: drawingData,
                    type: .drawing,
                    mimeType: "application/octet-stream",
                    for: cardID
                )
                modelContext.insert(drawingAsset)

                // 2. Export PNG at 2× scale
                let bounds = drawing.bounds.isEmpty
                    ? CGRect(x: 0, y: 0, width: 400, height: 300)
                    : drawing.bounds.insetBy(dx: -8, dy: -8)
                let image  = drawing.image(from: bounds, scale: 2.0)

                guard let pngData = image.pngData() else {
                    throw MediaServiceError.unsupportedFormat
                }

                let imageAsset = try await MediaService.shared.save(
                    data: pngData,
                    type: .image,
                    mimeType: "image/png",
                    for: cardID
                )
                modelContext.insert(imageAsset)
                try? modelContext.save()

                let imageID = imageAsset.id
                await MainActor.run {
                    onSave(imageID)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
#endif
