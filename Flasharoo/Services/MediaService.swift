//
//  MediaService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Handles local file storage for card media (images, audio, drawings).
//  CloudKit upload/download wired in Phase 8.
//

import Foundation
import UIKit
import AVFoundation
import CryptoKit

enum MediaServiceError: LocalizedError {
    case fileTooLarge(Int)
    case audioDurationExceeded(TimeInterval)
    case unsupportedFormat
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let mb):
            return "File is \(mb) MB — maximum is 5 MB."
        case .audioDurationExceeded(let s):
            return "Audio is \(Int(s / 60))m \(Int(s) % 60)s — maximum is 5 minutes."
        case .unsupportedFormat:
            return "Unsupported file format."
        case .fileNotFound:
            return "Media file not found on this device."
        }
    }
}

actor MediaService {
    static let shared = MediaService()

    private let baseURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = appSupport.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Saves raw data as a MediaAsset. Returns the model and (possibly recompressed) data.
    func save(
        data: Data,
        type: MediaType,
        mimeType: String,
        for cardID: UUID
    ) async throws -> MediaAsset {
        var finalData = data
        var finalMime = mimeType

        switch type {
        case .image:
            (finalData, finalMime) = try compressImageIfNeeded(data: data, mimeType: mimeType)
        case .audio:
            try await validateAudioDuration(data: data, mimeType: mimeType)
        case .drawing:
            break
        }

        let ext      = fileExtension(for: finalMime)
        let assetID  = UUID()
        let filename = "\(cardID.uuidString)/\(assetID.uuidString).\(ext)"
        let fileURL  = baseURL.appendingPathComponent(filename)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try finalData.write(to: fileURL)

        let checksum = sha256(finalData)

        return MediaAsset(
            id: assetID,
            cardID: cardID,
            type: type,
            localFilename: filename,
            mimeType: finalMime,
            fileSizeBytes: finalData.count,
            checksum: checksum
        )
    }

    // MARK: - Load

    func load(asset: MediaAsset) async throws -> Data {
        let url = fileURL(for: asset)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaServiceError.fileNotFound
        }
        return try Data(contentsOf: url)
    }

    func thumbnail(for asset: MediaAsset, size: CGSize = CGSize(width: 80, height: 80)) async throws -> UIImage {
        let data = try await load(asset: asset)
        guard let image = UIImage(data: data) else { throw MediaServiceError.unsupportedFormat }
        return image.preparingThumbnail(of: size) ?? image
    }

    // MARK: - Delete

    func delete(asset: MediaAsset) async throws {
        let url = fileURL(for: asset)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        asset.deletedAt = Date()
    }

    // MARK: - Helpers

    func fileURL(for asset: MediaAsset) -> URL {
        baseURL.appendingPathComponent(asset.localFilename)
    }

    private func compressImageIfNeeded(data: Data, mimeType: String) throws -> (Data, String) {
        let limit = 5 * 1024 * 1024
        if data.count <= limit { return (data, mimeType) }

        guard let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.85)
        else { throw MediaServiceError.fileTooLarge(data.count / 1_048_576) }

        if compressed.count > limit {
            throw MediaServiceError.fileTooLarge(data.count / 1_048_576)
        }
        return (compressed, "image/jpeg")
    }

    private func validateAudioDuration(data: Data, mimeType: String) async throws {
        let ext     = fileExtension(for: mimeType)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let avAsset  = AVURLAsset(url: tempURL)
        let duration = try await avAsset.load(.duration)
        let seconds  = CMTimeGetSeconds(duration)
        if seconds > 300 { throw MediaServiceError.audioDurationExceeded(seconds) }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg":        return "jpg"
        case "image/png":         return "png"
        case "image/heic":        return "heic"
        case "image/webp":        return "webp"
        case "audio/m4a",
             "audio/mp4",
             "audio/x-m4a":      return "m4a"
        case "audio/mpeg":        return "mp3"
        case "audio/wav",
             "audio/x-wav":      return "wav"
        case "audio/aac":         return "aac"
        default:                  return "bin"
        }
    }
}
