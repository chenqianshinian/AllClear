import SwiftUI

/// 登录（后端 /api/login，邮箱 + 密码）
struct LoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var onSuccess: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("登录") {
                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoggingIn {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("登录").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                }

                Section {
                    // 预留：等 Apple 开发者账号开通并配置 Sign in with Apple 后启用
                    Button {
                        Toast.shared.show("Apple 登录待开通")
                    } label: {
                        Label("通过 Apple 登录", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(true)
                    Text("Apple 登录将在开发者账号开通后启用")
                        .font(.system(size: 12))
                        .foregroundStyle(ACColor.secondary)
                }
            }
            .navigationTitle("账号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func login() async {
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }
        do {
            try await Session.shared.login(email: email, password: password)
            Toast.shared.show("登录成功")
            onSuccess()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
