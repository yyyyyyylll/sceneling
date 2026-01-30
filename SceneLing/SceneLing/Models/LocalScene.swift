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

struct ObjectTag: Codable, Hashable, Sendable {
    let en: String
    let cn: String
    let phonetic: String
    let pos: String
}

struct Sentence: Codable, Hashable, Sendable {
    let en: String
    let cn: String
}

struct Role: Codable, Hashable, Sendable {
    let roleEn: String
    let roleCn: String
    let sentences: [Sentence]

    enum CodingKeys: String, CodingKey {
        case roleEn = "role_en"
        case roleCn = "role_cn"
        case sentences
    }
}

struct Expressions: Codable, Hashable, Sendable {
    var roles: [Role]

    init(roles: [Role]) {
        self.roles = roles
    }

    private enum CodingKeys: String, CodingKey {
        case roles
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roles = try container.decode([Role].self, forKey: .roles)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roles, forKey: .roles)
    }
}
