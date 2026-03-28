//
//  MediaService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Handles local file storage and CloudKit upload/download for card media.
//

import Foundation
import UIKit
import AVFoundation
import CryptoKit
import CloudKit

enum MediaServiceError: LocalizedError {
    case fileTooLarge(Int)
    case audioDurationExceeded(TimeInterval)
    case unsupportedFormat
    case fileNotFound
    case uploadFailed
    case downloadFailed

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
        case .uploadFailed:
            return "Failed to upload media to iCloud."
        case .downloadFailed:
            return "Failed to download media from iCloud."
        }
    }
}

actor MediaService {
    static let shared = MediaService()

    private let baseURL: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let ckContainerID = "iCloud.com.golackey.flasharoo"

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = appSupport.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true)
        thumbnailCache.countLimit = 200
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

    func thumbnail(
        for asset: MediaAsset,
        size: CGSize = CGSize(width: 80, height: 80)
    ) async throws -> UIImage {
        let cacheKey = "\(asset.id.uuidString)_\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }
        let data = try await load(asset: asset)
        guard let image = UIImage(data: data) else { throw MediaServiceError.unsupportedFormat }
        let thumb = image.preparingThumbnail(of: size) ?? image
        thumbnailCache.setObject(thumb, forKey: cacheKey)
        return thumb
    }

    // MARK: - Delete

    func delete(asset: MediaAsset) async throws {
        let url = fileURL(for: asset)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        thumbnailCache.removeObject(forKey: asset.id.uuidString as NSString)
        asset.deletedAt = Date()
    }

    // MARK: - Storage

    /// Total bytes used by all local media files.
    func totalStorageBytes() -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += size
        }
        return total
    }

    // MARK: - CloudKit Upload

    /// Uploads the local file for an asset to CloudKit.
    /// - Parameters:
    ///   - assetID: UUID of the asset (used as CKRecord name)
    ///   - cardID: UUID of the owning card
    ///   - mimeType: MIME type of the file
    ///   - localFilename: Relative filename under the media base directory
    /// - Returns: The CKRecord name (same as assetID.uuidString)
    func uploadToCloudKit(
        assetID: UUID,
        cardID: UUID,
        mimeType: String,
        localFilename: String
    ) async throws -> String {
        let fileURL = baseURL.appendingPathComponent(localFilename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MediaServiceError.fileNotFound
        }

        let ckAsset  = CKAsset(fileURL: fileURL)
        let recordID = CKRecord.ID(recordName: assetID.uuidString)
        let record   = CKRecord(recordType: "MediaBlob", recordID: recordID)
        record["assetID"]  = assetID.uuidString
        record["cardID"]   = cardID.uuidString
        record["mimeType"] = mimeType
        record["fileData"] = ckAsset

        let database = CKContainer(identifier: ckContainerID).privateCloudDatabase
        do {
            let saved = try await database.save(record)
            return saved.recordID.recordName
        } catch {
            throw MediaServiceError.uploadFailed
        }
    }

    // MARK: - CloudKit Download

    /// Downloads the file for an asset from CloudKit and writes it to local storage.
    /// - Parameters:
    ///   - recordName: CKRecord name (ckAssetRecordName stored on MediaAsset)
    ///   - localFilename: Relative path to write the file under the media base directory
    func downloadFromCloudKit(recordName: String, to localFilename: String) async throws {
        let database = CKContainer(identifier: ckContainerID).privateCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName)

        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            throw MediaServiceError.downloadFailed
        }

        guard let ckAsset = record["fileData"] as? CKAsset,
              let assetFileURL = ckAsset.fileURL
        else {
            throw MediaServiceError.downloadFailed
        }

        let data = try Data(contentsOf: assetFileURL)
        let destURL = baseURL.appendingPathComponent(localFilename)
        try FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: destURL)
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
