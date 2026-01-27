import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo & Branding
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("SceneLing")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("生活随手拍，地道学英语")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Login Button
            VStack(spacing: 20) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            await authManager.handleAppleSignIn(authorization)
                        }
                    case .failure(let error):
                        print("Apple Sign In failed: \(error)")
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .frame(maxWidth: 280)

                if authManager.isLoading {
                    ProgressView()
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Terms
            VStack(spacing: 8) {
                Text("登录即表示同意")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Button("用户协议") {
                        // TODO: 打开用户协议
                    }
                    Text("和")
                    Button("隐私政策") {
                        // TODO: 打开隐私政策
                    }
                }
                .font(.caption)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
