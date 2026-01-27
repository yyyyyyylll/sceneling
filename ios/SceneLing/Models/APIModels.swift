import Foundation

// MARK: - API Response Wrapper

struct APIResponse<T: Codable>: Codable {
    let code: Int
    let data: T?
    let message: String?
}

// MARK: - Auth

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case fullName = "full_name"
        case email
    }
}

struct TokenResponse: Codable {
    let token: String
    let user: UserBrief
}

struct UserBrief: Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let isNewUser: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case isNewUser = "is_new_user"
    }
}

// MARK: - Scene

struct SceneAnalyzeResponse: Codable {
    let sceneTag: String
    let sceneTagCn: String
    let objectTags: [ObjectTag]
    let description: Description
    let expressions: Expressions
    let category: String

    enum CodingKeys: String, CodingKey {
        case sceneTag = "scene_tag"
        case sceneTagCn = "scene_tag_cn"
        case objectTags = "object_tags"
        case description
        case expressions
        case category
    }
}

struct Description: Codable {
    let en: String
    let cn: String
}

struct SceneCreateRequest: Codable {
    let localPhotoId: String
    let sceneTag: String
    let sceneTagCn: String
    let objectTags: [ObjectTag]
    let descriptionEn: String
    let descriptionCn: String
    let expressions: Expressions
    let category: String

    enum CodingKeys: String, CodingKey {
        case localPhotoId = "local_photo_id"
        case sceneTag = "scene_tag"
        case sceneTagCn = "scene_tag_cn"
        case objectTags = "object_tags"
        case descriptionEn = "description_en"
        case descriptionCn = "description_cn"
        case expressions
        case category
    }
}

// MARK: - Note

struct NoteCreateRequest: Codable {
    let sceneId: UUID?
    let type: String
    let contentEn: String
    let contentCn: String
    let phonetic: String?
    let pos: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case type
        case contentEn = "content_en"
        case contentCn = "content_cn"
        case phonetic
        case pos
        case role
    }
}

// MARK: - TTS

struct TTSRequest: Codable {
    let text: String
    let voice: String
}

struct TTSResponse: Codable {
    let audioUrl: String

    enum CodingKeys: String, CodingKey {
        case audioUrl = "audio_url"
    }
}

// MARK: - User Stats

struct UserStats: Codable {
    let totalScenes: Int
    let totalWords: Int
    let learningDays: Int

    enum CodingKeys: String, CodingKey {
        case totalScenes = "total_scenes"
        case totalWords = "total_words"
        case learningDays = "learning_days"
    }
}
