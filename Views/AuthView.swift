import SwiftUI
import AuthenticationServices
struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var username = ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    enum AuthMode {
        case login, register
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                Text(mode == .login ? "Giriş Yap" : "Kayıt Ol")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.top, 40)
                
                if mode == .register {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ad Soyad").font(.subheadline).foregroundColor(.gray)
                        TextField("Ad Soyad", text: $fullName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kullanıcı Adı").font(.subheadline).foregroundColor(.gray)
                        TextField("kullaniciadi", text: $username)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("E-posta").font(.subheadline).foregroundColor(.gray)
                    TextField("ornek@mail.com", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Şifre").font(.subheadline).foregroundColor(.gray)
                    SecureField("******", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                if let err = authViewModel.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                VStack(spacing: 12) {
                    HStack {
                        VStack { Divider() }
                        Text("veya").font(.caption).foregroundColor(.gray)
                        VStack { Divider() }
                    }
                    .padding(.vertical, 10)

                    //  Apple Sign-In Butonu
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    authViewModel.signInWithApple(credential: appleIDCredential, rawNonce: "")
                                }
                            case .failure(let error):
                                print("Apple Sign-In Hatalı: \(error.localizedDescription)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                Button(action: handleAction) {
                    HStack {
                        Spacer()
                        if authViewModel.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(mode == .login ? "Giriş Yap" : "Kayıt Ol")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .disabled(authViewModel.isLoading)
                .padding(.top, 10)
                
                HStack {
                    Spacer()
                    Text(mode == .login ? "Hesabınız yok mu?" : "Zaten hesabınız var mı?")
                        .foregroundColor(.gray)
                    Button(action: {
                        mode = (mode == .login) ? .register : .login
                        authViewModel.errorMessage = nil
                    }) {
                        Text(mode == .login ? "Kayıt ol" : "Giriş yap")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Bilgi"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("Tamam")))
        }
    }
    
    private func handleAction() {
        if mode == .login {
            authViewModel.signIn(email: email, password: password) { success in
                if !success && authViewModel.errorMessage == nil {
                    alertMessage = "Giriş yapılamadı."
                    showAlert = true
                }
            }
        } else {
            authViewModel.signUp(fullName: fullName, username: username, email: email, password: password) { success in
                if success {
                    alertMessage = "Kayıt başarılı! Lütfen e-posta adresinize gelen linke tıklayıp doğruladıktan sonra giriş yapın."
                    showAlert = true
                    mode = .login
                }
            }
        }
    }
}
