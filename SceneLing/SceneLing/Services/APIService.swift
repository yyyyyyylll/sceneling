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

class APIService {
    static let shared = APIService()

    private let baseURL = "http://127.0.0.1:8000/api"  // 开发环境（iOS 模拟器用 127.0.0.1）
    // private let baseURL = "https://api.sceneling.com/api"  // 生产环境

    private var token: String? {
        UserDefaults.standard.string(forKey: "auth_token")
    }

    private init() {}

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

    // MARK: - User

    func getUserStats() async throws -> UserStats {
        return try await get("/users/stats")
    }

    // MARK: - Chat

    func chat(
        message: String,
        sceneContext: SceneAnalyzeResponse,
        history: [(String, Bool)]
    ) async throws -> String {
        let request = ChatRequest(
            message: message,
            sceneTag: sceneContext.sceneTag,
            sceneTagCn: sceneContext.sceneTagCn,
            category: sceneContext.category,
            roles: sceneContext.expressions.roles.map { "\($0.roleEn) (\($0.roleCn))" },
            history: history.map { ChatMessage(content: $0.0, isUser: $0.1) }
        )
        let response: ChatResponse = try await post("/chat", body: request)
        return response.reply
    }

    func chatStream(
        message: String,
        sceneContext: SceneAnalyzeResponse,
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
