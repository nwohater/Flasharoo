//
//  MediaAttachmentView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SwiftData

struct MediaAttachmentView: View {
    let cardID: UUID
    @Binding var assets: [MediaAsset]
    /// Called after a new image asset is saved, so the caller can insert an <img> tag.
    var onImageAdded: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    @State private var photoItem: PhotosPickerItem?
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isProcessing = false

    private static let audioTypes: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !assets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(assets) { asset in
                            AssetThumbnailView(asset: asset) {
                                removeAsset(asset)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Image", systemImage: "photo")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Audio", systemImage: "waveform")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.audioTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await importAudio(url: url) }
            }
        }
        .alert("Media Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Import

    private func importPhoto(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let mimeType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            let asset = try await MediaService.shared.save(
                data: data, type: .image, mimeType: mimeType, for: cardID)
            modelContext.insert(asset)
            try? modelContext.save()
            assets.append(asset)
            onImageAdded?(asset.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        photoItem = nil
    }

    private func importAudio(url: URL) async {
        isProcessing = true
        defer { isProcessing = false }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data     = try Data(contentsOf: url)
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "audio/m4a"
            let asset    = try await MediaService.shared.save(
                data: data, type: .audio, mimeType: mimeType, for: cardID)
            modelContext.insert(asset)
            try? modelContext.save()
            assets.append(asset)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Delete

    private func removeAsset(_ asset: MediaAsset) {
        assets.removeAll { $0.id == asset.id }
        Task {
            try? await MediaService.shared.delete(asset: asset)
            try? modelContext.save()
        }
    }
}

// MARK: - Thumbnail cell

private struct AssetThumbnailView: View {
    let asset: MediaAsset
    let onDelete: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if asset.type == .audio {
                    audioPlaceholder
                } else if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
        .task {
            guard asset.type == .image else { return }
            thumbnail = try? await MediaService.shared.thumbnail(for: asset)
        }
    }

    private var audioPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Audio")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
