import Foundation
import SwiftData

enum NoteType: String, Codable {
    case vocabulary
    case expression
}

@Model
final class LocalNote {
    var id: UUID
    var serverId: UUID?
    var sceneId: UUID?
    var type: NoteType
    var contentEn: String
    var contentCn: String
    var phonetic: String?
    var pos: String?
    var role: String?
    var reviewCount: Int
    var createdAt: Date
    var isSynced: Bool

    init(
        id: UUID = UUID(),
        serverId: UUID? = nil,
        sceneId: UUID? = nil,
        type: NoteType,
        contentEn: String,
        contentCn: String,
        phonetic: String? = nil,
        pos: String? = nil,
        role: String? = nil,
        reviewCount: Int = 0,
        createdAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.serverId = serverId
        self.sceneId = sceneId
        self.type = type
        self.contentEn = contentEn
        self.contentCn = contentCn
        self.phonetic = phonetic
        self.pos = pos
        self.role = role
        self.reviewCount = reviewCount
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}
