//
//  MediaAsset.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

@Model
final class MediaAsset {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var cardID: UUID
    var type: MediaType
    var localFilename: String           // relative to Application Support/media/
    var mimeType: String
    var fileSizeBytes: Int
    var checksum: String                // SHA-256 of file contents
    var ckAssetRecordName: String?      // CloudKit record name after upload
    @Attribute(.indexed) var syncState: MediaSyncState
    var createdAt: Date
    var deletedAt: Date?
    var card: Card?

    init(
        id: UUID = UUID(),
        cardID: UUID,
        type: MediaType,
        localFilename: String,
        mimeType: String,
        fileSizeBytes: Int,
        checksum: String,
        ckAssetRecordName: String? = nil,
        syncState: MediaSyncState = .local
    ) {
        self.id = id
        self.cardID = cardID
        self.type = type
        self.localFilename = localFilename
        self.mimeType = mimeType
        self.fileSizeBytes = fileSizeBytes
        self.checksum = checksum
        self.ckAssetRecordName = ckAssetRecordName
        self.syncState = syncState
        self.createdAt = Date()
        self.deletedAt = nil
    }
}
