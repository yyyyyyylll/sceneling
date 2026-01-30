import Foundation

// MARK: - API Response Wrapper

struct APIResponse<T: Codable>: Codable {
    let code: Int
    let data: T?
    let message: String?
}

// MARK: - Common

struct EmptyBody: Codable {}

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

/// 完整的场景分析响应
struct SceneAnalyzeResponse: Codable {
    let sceneTag: String
    let sceneTagCn: String
    let objectTags: [ObjectTag]
    let description: Description
    var expressions: Expressions
    let category: String

    enum CodingKeys: String, CodingKey {
        case sceneTag = "scene_tag"
        case sceneTagCn = "scene_tag_cn"
        case objectTags = "object_tags"
        case description
        case expressions
        case category
    }

    /// 从基础结果创建，表达式为空
    static func fromBasic(_ basic: SceneAnalyzeBasicResult) -> SceneAnalyzeResponse {
        SceneAnalyzeResponse(
            sceneTag: basic.sceneTag,
            sceneTagCn: basic.sceneTagCn,
            objectTags: basic.objectTags,
            description: basic.description,
            expressions: Expressions(roles: []),
            category: basic.category
        )
    }
}

/// 第一阶段：基础场景分析结果（不含口语例句）
struct SceneAnalyzeBasicResult: Codable {
    let sceneTag: String
    let sceneTagCn: String
    let objectTags: [ObjectTag]
    let description: Description
    let category: String

    enum CodingKeys: String, CodingKey {
        case sceneTag = "scene_tag"
        case sceneTagCn = "scene_tag_cn"
        case objectTags = "object_tags"
        case description
        case category
    }

    /// 从字典解析
    static func fromDict(_ dict: [String: Any]) -> SceneAnalyzeBasicResult? {
        guard let sceneTag = dict["scene_tag"] as? String,
              let sceneTagCn = dict["scene_tag_cn"] as? String,
              let category = dict["category"] as? String,
              let descDict = dict["description"] as? [String: String],
              let descEn = descDict["en"],
              let descCn = descDict["cn"],
              let tagsArray = dict["object_tags"] as? [[String: String]] else {
            return nil
        }

        let objectTags = tagsArray.compactMap { tagDict -> ObjectTag? in
            guard let en = tagDict["en"],
                  let cn = tagDict["cn"],
                  let phonetic = tagDict["phonetic"],
                  let pos = tagDict["pos"] else {
                return nil
            }
            return ObjectTag(en: en, cn: cn, phonetic: phonetic, pos: pos)
        }

        return SceneAnalyzeBasicResult(
            sceneTag: sceneTag,
            sceneTagCn: sceneTagCn,
            objectTags: objectTags,
            description: Description(en: descEn, cn: descCn),
            category: category
        )
    }
}

/// 从字典解析 Expressions
extension Expressions {
    static func fromDict(_ dict: [String: Any]) -> Expressions? {
        guard let rolesArray = dict["roles"] as? [[String: Any]] else {
            return nil
        }

        let roles = rolesArray.compactMap { roleDict -> Role? in
            guard let roleEn = roleDict["role_en"] as? String,
                  let roleCn = roleDict["role_cn"] as? String,
                  let sentencesArray = roleDict["sentences"] as? [[String: String]] else {
                return nil
            }

            let sentences = sentencesArray.compactMap { sentDict -> Sentence? in
                guard let en = sentDict["en"],
                      let cn = sentDict["cn"] else {
                    return nil
                }
                return Sentence(en: en, cn: cn)
            }

            return Role(roleEn: roleEn, roleCn: roleCn, sentences: sentences)
        }

        return Expressions(roles: roles)
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
    let totalDialogues: Int
    let learningDays: Int

    enum CodingKeys: String, CodingKey {
        case totalScenes = "total_scenes"
        case totalDialogues = "total_dialogues"
        case learningDays = "learning_days"
    }
}

// MARK: - Chat

struct ChatMessage: Codable {
    let content: String
    let isUser: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isUser = "is_user"
    }
}

struct ChatRequest: Codable {
    let message: String
    let sceneTag: String
    let sceneTagCn: String
    let category: String
    let roles: [String]
    let userRole: String
    let aiRole: String
    let history: [ChatMessage]
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case sceneTag = "scene_tag"
        case sceneTagCn = "scene_tag_cn"
        case category
        case roles
        case userRole = "user_role"
        case aiRole = "ai_role"
        case history
        case sessionId = "session_id"
    }
}

struct ChatResponse: Codable {
    let reply: String
    let translation: String?
}

struct FreeChatRequest: Codable {
    let message: String
    let history: [ChatMessage]
    let sessionId: String?
}

// MARK: - ASR (语音识别 / 标点分句)

struct PunctuationRequest: Codable {
    let text: String
    let language: String
}

struct ASRResponse: Codable {
    let text: String
    let success: Bool
}
