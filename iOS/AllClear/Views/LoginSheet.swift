import SwiftUI

/// 登录 / 注册弹窗（对齐鸿蒙端 pages/profile/index.tsx 里的 fixed 登录弹窗）
struct LoginModalView: View {
    var onClose: () -> Void

    @ObservedObject private var session = Session.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var isSubmitting = false
    @FocusState private var focus: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    focus = nil
                }

            GeometryReader { geo in
              ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        Text(isRegister ? "注册账号" : "登录账号")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ACColor.gray800)
                            .padding(.bottom, 20)

                        TextField("请输入邮箱", text: $email)
                            .accessibilityIdentifier("login.email")
                            .font(.system(size: 15))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focus, equals: .email)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(ACColor.gray100)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.bottom, 14)

                        SecureField("请输入密码", text: $password)
                            .accessibilityIdentifier("login.password")
                            .font(.system(size: 15))
                            .focused($focus, equals: .password)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(ACColor.gray100)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.bottom, 20)

                        Button {
                            submit()
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isRegister ? "注 册" : "登 录")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ACColor.blue600)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("login.submit")
                        .disabled(isSubmitting)

                        HStack {
                            Button("取消") {
                                focus = nil
                                onClose()
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(ACColor.gray500)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isRegister.toggle()
                                }
                            } label: {
                                Text(isRegister ? "已有账号?去登录" : "没有账号?去注册")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ACColor.blue500)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("login.toggle")
                        }
                        .padding(.top, 16)
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
              }
              .scrollDismissesKeyboard(.interactively)
            }
        }
        .transition(.opacity)
        .onAppear {
            email = ""
            password = ""
        }
    }

    private func submit() {
        focus = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            Toast.shared.show("请输入邮箱和密码")
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        LoadingCenter.shared.show("请稍候...")

        Task { @MainActor in
            defer {
                LoadingCenter.shared.hide()
                isSubmitting = false
            }
            do {
                if isRegister {
                    try await session.register(email: email, password: password)
                    Toast.shared.success("注册成功，请登录")
                    password = ""
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isRegister = false
                    }
                } else {
                    try await session.login(email: email, password: password)
                    Toast.shared.success("登录成功")
                    onClose()
                }
            } catch let error as APIError {
                Toast.shared.show(error.errorDescription ?? "网络错误")
            } catch {
                Toast.shared.show(error.localizedDescription.isEmpty ? "网络错误" : error.localizedDescription)
            }
        }
    }
}
