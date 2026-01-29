import Foundation
import SwiftData

@Model
final class LocalScene {
    var id: UUID
    var serverId: UUID?
    var localPhotoId: String
    var photoData: Data?
    var sceneTag: String
    var sceneTagCn: String
    var objectTags: [ObjectTag]
    var descriptionEn: String
    var descriptionCn: String
    var expressions: Expressions
    var category: String
    var createdAt: Date
    var isSynced: Bool
    var dialogueCount: Int  // 对话次数

    init(
        id: UUID = UUID(),
        serverId: UUID? = nil,
        localPhotoId: String,
        photoData: Data? = nil,
        sceneTag: String,
        sceneTagCn: String,
        objectTags: [ObjectTag],
        descriptionEn: String,
        descriptionCn: String,
        expressions: Expressions,
        category: String,
        createdAt: Date = Date(),
        isSynced: Bool = false,
        dialogueCount: Int = 0
    ) {
        self.id = id
        self.serverId = serverId
        self.localPhotoId = localPhotoId
        self.photoData = photoData
        self.sceneTag = sceneTag
        self.sceneTagCn = sceneTagCn
        self.objectTags = objectTags
        self.descriptionEn = descriptionEn
        self.descriptionCn = descriptionCn
        self.expressions = expressions
        self.category = category
        self.createdAt = createdAt
        self.isSynced = isSynced
        self.dialogueCount = dialogueCount
    }

    /// 增加对话次数
    func incrementDialogueCount() {
        dialogueCount += 1
    }
}

// MARK: - Supporting Types

struct ObjectTag: Codable, Hashable {
    let en: String
    let cn: String
    let phonetic: String
    let pos: String
}

struct Sentence: Codable, Hashable {
    let en: String
    let cn: String
}

struct Role: Codable, Hashable {
    let roleEn: String
    let roleCn: String
    let sentences: [Sentence]

    enum CodingKeys: String, CodingKey {
        case roleEn = "role_en"
        case roleCn = "role_cn"
        case sentences
    }
}

struct Expressions: Codable, Hashable {
    let roles: [Role]
}
