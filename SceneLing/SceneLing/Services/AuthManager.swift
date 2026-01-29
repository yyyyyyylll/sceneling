import Foundation
import AuthenticationServices
import Combine

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: UserBrief?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenKey = "auth_token"

    init() {
        // 检查本地存储的 token
        if let _ = UserDefaults.standard.string(forKey: tokenKey) {
            isLoggedIn = true
            Task {
                await validateToken()
            }
        }
    }

    var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    @MainActor
    func handleAppleSignIn(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = credential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            errorMessage = "无法获取 Apple 授权信息"
            return
        }

        let fullName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.appleLogin(
                identityToken: identityToken,
                authorizationCode: authCode,
                fullName: fullName.isEmpty ? nil : fullName,
                email: credential.email
            )

            // 保存 token
            UserDefaults.standard.set(response.token, forKey: tokenKey)
            currentUser = response.user
            isLoggedIn = true
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        currentUser = nil
        isLoggedIn = false
    }

    @MainActor
    func validateToken() async {
        guard UserDefaults.standard.string(forKey: tokenKey) != nil else { return }
        isLoading = true
        errorMessage = nil

        do {
            let user = try await APIService.shared.getMe()
            currentUser = user
            isLoggedIn = true
        } catch {
            logout()
        }

        isLoading = false
    }

    /// 演示模式登录（仅用于开发测试）
    /// 会在后端创建真实的演示用户，数据能正确关联
    @MainActor
    func loginAsDemo() {
        #if DEBUG
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIService.shared.demoLogin()
                UserDefaults.standard.set(response.token, forKey: tokenKey)
                currentUser = response.user
                isLoggedIn = true
            } catch {
                errorMessage = "演示登录失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
        #endif
    }
}
