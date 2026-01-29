import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String?)
    case decodingError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .invalidResponse:
            return "服务器响应异常"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .serverError(_, let message):
            return message ?? "服务器错误"
        case .decodingError:
            return "数据解析失败"
        case .unauthorized:
            return "登录已过期，请重新登录"
        }
    }
}

// MARK: - API Environment Configuration
enum APIEnvironment {
    case development  // 模拟器
    case localDevice  // 真机测试（局域网）
    case production   // 生产环境

    var baseURL: String {
        switch self {
        case .development:
            return "http://127.0.0.1:8000/api"
        case .localDevice:
            // ⚠️ 真机测试时，使用 Cloudflare Tunnel（校园网环境）
            return "https://realistic-belly-romance-graduated.trycloudflare.com/api"
        case .production:
            // ⚠️ 上线时，改成你的生产服务器地址
            return "https://api.sceneling.com/api"
        }
    }

    static var current: APIEnvironment {
        #if DEBUG
            #if targetEnvironment(simulator)
                return .development
            #else
                return .localDevice
            #endif
        #else
            return .production
        #endif
    }
}

class APIService {
    static let shared = APIService()

    private var baseURL: String {
        APIEnvironment.current.baseURL
    }

    private var token: String? {
        UserDefaults.standard.string(forKey: "auth_token")
    }

    private init() {
        print("🌐 API Environment: \(APIEnvironment.current), URL: \(baseURL)")
    }

    // MARK: - Auth

    func appleLogin(
        identityToken: String,
        authorizationCode: String,
        fullName: String?,
        email: String?
    ) async throws -> TokenResponse {
        let request = AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName,
            email: email
        )
        return try await post("/auth/apple", body: request)
    }

    func getMe() async throws -> UserBrief {
        return try await get("/auth/me")
    }

    /// 演示模式登录（仅开发测试）
    func demoLogin() async throws -> TokenResponse {
        return try await post("/auth/demo", body: EmptyBody())
    }

    // MARK: - Scenes

    func analyzeImage(_ imageData: Data, cefrLevel: String = "B1") async throws -> SceneAnalyzeResponse {
        let url = URL(string: "\(baseURL)/scenes/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        // Image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // CEFR Level
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cefr_level\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cefrLevel)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        return try JSONDecoder().decode(SceneAnalyzeResponse.self, from: data)
    }

    func createScene(_ request: SceneCreateRequest) async throws -> LocalScene {
        // TODO: 实现场景保存
        fatalError("Not implemented")
    }

    func getScenes(category: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [LocalScene] {
        // TODO: 实现场景列表获取
        fatalError("Not implemented")
    }

    // MARK: - Notes

    func createNote(_ request: NoteCreateRequest) async throws -> LocalNote {
        // TODO: 实现笔记保存
        fatalError("Not implemented")
    }

    func getNotes(type: String? = nil, search: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [LocalNote] {
        // TODO: 实现笔记列表获取
        fatalError("Not implemented")
    }

    // MARK: - TTS

    func textToSpeech(text: String, voice: String = "en-US-female") async throws -> URL {
        let request = TTSRequest(text: text, voice: voice)
        let response: TTSResponse = try await post("/tts", body: request)
        guard let url = URL(string: response.audioUrl) else {
            throw APIError.invalidURL
        }
        return url
    }

    func textToSpeechDataURL(text: String, voice: String = "en-US-female") async throws -> String {
        let request = TTSRequest(text: text, voice: voice)
        let response: TTSResponse = try await post("/tts", body: request)
        return response.audioUrl
    }

    // MARK: - ASR (语音识别)

    /// 使用后端 Paraformer 进行语音识别（带标点分句）
    func speechToText(audioData: Data, language: String = "en") async throws -> String {
        let url = URL(string: "\(baseURL)/asr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Language parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        let asrResponse = try JSONDecoder().decode(ASRResponse.self, from: data)
        return asrResponse.text
    }

    // MARK: - User

    func getUserStats() async throws -> UserStats {
        return try await get("/users/stats")
    }

    // MARK: - Chat

    func chat(
        message: String,
        sceneContext: SceneAnalyzeResponse,
        userRole: Role,
        aiRole: Role,
        history: [(String, Bool)]
    ) async throws -> String {
        let request = ChatRequest(
            message: message,
            sceneTag: sceneContext.sceneTag,
            sceneTagCn: sceneContext.sceneTagCn,
            category: sceneContext.category,
            roles: sceneContext.expressions.roles.map { "\($0.roleEn) (\($0.roleCn))" },
            userRole: "\(userRole.roleEn) (\(userRole.roleCn))",
            aiRole: "\(aiRole.roleEn) (\(aiRole.roleCn))",
            history: history.map { ChatMessage(content: $0.0, isUser: $0.1) }
        )
        let response: ChatResponse = try await post("/chat", body: request)
        return response.reply
    }

    func chatStream(
        message: String,
        sceneContext: SceneAnalyzeResponse,
        userRole: Role,
        aiRole: Role,
        history: [(String, Bool)],
        onEvent: @escaping (SSEEvent) -> Void,
        onComplete: @escaping () -> Void
    ) -> SSEClient {
        let request = ChatRequest(
            message: message,
            sceneTag: sceneContext.sceneTag,
            sceneTagCn: sceneContext.sceneTagCn,
            category: sceneContext.category,
            roles: sceneContext.expressions.roles.map { "\($0.roleEn) (\($0.roleCn))" },
            userRole: "\(userRole.roleEn) (\(userRole.roleCn))",
            aiRole: "\(aiRole.roleEn) (\(aiRole.roleCn))",
            history: history.map { ChatMessage(content: $0.0, isUser: $0.1) }
        )

        let url = URL(string: "\(baseURL)/chat/stream")!
        let body = try! JSONEncoder().encode(request)

        let client = SSEClient()
        client.connect(
            url: url,
            body: body,
            token: token,
            onEvent: onEvent,
            onComplete: onComplete
        )

        return client
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func handleResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard 200...299 ~= httpResponse.statusCode else {
            let message = try? JSONDecoder().decode([String: String].self, from: data)["detail"]
            throw APIError.serverError(httpResponse.statusCode, message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
