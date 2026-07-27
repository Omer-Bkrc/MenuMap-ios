import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

// MARK: - Admin Düzeltme İsteği Modeli
struct FixRequestItem: Identifiable, Hashable {
    let id: String
    let name: String
    let adminNote: String
    let city: String
}

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var isEmailVerified = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var fixRequestsTyped: [FixRequestItem] = []
    
    // Kullanıcı Profil Verileri
    @Published var fullName: String = ""
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var isAdmin: Bool = false
    
    // Sayaçlar ve Bildirimler
    @Published var approvedCount: Int = 0
    @Published var pendingCount: Int = 0
    @Published var fixRequests: [[String: Any]] = []
    
    private var db = Firestore.firestore()
    
    init() {
        self.userSession = Auth.auth().currentUser
        checkEmailVerification()
    }
    
    func checkEmailVerification() {
        guard let user = Auth.auth().currentUser else {
            self.isEmailVerified = false
            return
        }
        
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.isEmailVerified = user.isEmailVerified
                    self?.userSession = user
                    if user.isEmailVerified {
                        self?.fetchUserProfile(uid: user.uid)
                        self?.fetchUserStatsAndFixes(uid: user.uid)
                    }
                }
            }
        }
    }
    
    // MARK: - Giriş Yap (SignIn)
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = self?.authErrorMessageTR(error)
                    completion(false)
                    return
                }
                
                guard let user = result?.user else { return }
                
                // E-posta Doğrulama Kontrolü
                if !user.isEmailVerified {
                    self?.errorMessage = "Lütfen e-postanızı doğrulayıp tekrar giriş yapın."
                    try? Auth.auth().signOut()
                    completion(false)
                } else {
                    self?.userSession = user
                    self?.isEmailVerified = true
                    self?.fetchUserProfile(uid: user.uid)
                    self?.fetchUserStatsAndFixes(uid: user.uid)
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Kayıt Ol (SignUp)
    func signUp(fullName: String, username: String, email: String, password: String, completion: @escaping (Bool) -> Void) {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        errorMessage = nil
        
        // 1. Kullanıcı adı benzersiz mi kontrol et
        db.collection("users").whereField("username", isEqualTo: cleanUsername).getDocuments { [weak self] snapshot, error in
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Bu kullanıcı adı zaten alınmış."
                    completion(false)
                }
                return
            }
            
            // 2. Kullanıcıyı Firebase Auth ile oluştur
            Auth.auth().createUser(withEmail: cleanEmail, password: password) { result, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = self?.authErrorMessageTR(error)
                        completion(false)
                    }
                    return
                }
                
                guard let user = result?.user else { return }
                
                // 3. E-posta doğrulama linki gönder
                user.sendEmailVerification(completion: nil)
                
                // 4. Firestore'a kullanıcı profil verisini yaz
                let userData: [String: Any] = [
                    "fullName": cleanFullName,
                    "username": cleanUsername,
                    "email": cleanEmail,
                    "emailVerified": false,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                self?.db.collection("users").document(user.uid).setData(userData) { _ in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        try? Auth.auth().signOut() // Doğrulanana kadar oturumu kapat
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Kullanıcı Profilini Çek
    func fetchUserProfile(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            if let data = snapshot?.data() {
                DispatchQueue.main.async {
                    self?.fullName = data["fullName"] as? String ?? ""
                    self?.username = data["username"] as? String ?? ""
                    self?.email = data["email"] as? String ?? ""
                    self?.isAdmin = data["isAdmin"] as? Bool ?? false
                }
            }
        }
    }
    
    // MARK: - Sayaçları ve Düzeltme Notlarını Çek
    func fetchUserStatsAndFixes(uid: String) {
        let db = Firestore.firestore()
        
        // 1. Onaylanmış Mekanlar (places -> createdBy)
        db.collection("places")
            .whereField("createdBy", isEqualTo: uid)
            .whereField("status", isEqualTo: "active")
            .getDocuments { [weak self] snap, _ in
                DispatchQueue.main.async {
                    self?.approvedCount = snap?.documents.count ?? 0
                }
            }
        
        // 2. Bekleyen Mekanlar (placeSubmissions -> submittedByUid)
        db.collection("placeSubmissions")
            .whereField("submittedByUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snap, _ in
                DispatchQueue.main.async {
                    self?.pendingCount = snap?.documents.count ?? 0
                }
            }
        
        // 3. Admin Düzeltme İsteği Bildirimleri (placeSubmissions -> submittedByUid & fix_requested)
        db.collection("placeSubmissions")
            .whereField("submittedByUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "fix_requested")
            .getDocuments { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                
                let fixes = docs.map { doc -> FixRequestItem in
                    let data = doc.data()
                    return FixRequestItem(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "İsimsiz Mekan",
                        adminNote: data["adminNote"] as? String ?? "Not belirtilmedi.",
                        city: data["city"] as? String ?? "Bilinmiyor"
                    )
                }
                
                DispatchQueue.main.async {
                    self?.fixRequestsTyped = fixes
                }
            }
    }
    
    // MARK: - Düzeltme Bildirimini Kapat
    func dismissFixRequest(subId: String) {
        let db = Firestore.firestore()
        db.collection("placeSubmissions").document(subId).updateData(["status": "dismissed_fix"]) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.fixRequestsTyped.removeAll { $0.id == subId }
                }
            }
        }
    }
    
    // MARK: - Çıkış Yap
    func signOut() {
        try? Auth.auth().signOut()
        self.userSession = nil
        self.isEmailVerified = false
        self.isAdmin = false
    }
    
    // MARK: - Hata Mesajları Çevirici
    private func authErrorMessageTR(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.invalidCredential.rawValue, AuthErrorCode.wrongPassword.rawValue:
            return "E-posta veya şifre hatalı."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Geçerli bir e-posta girin."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Bu e-posta ile zaten kayıtlı bir hesap var."
        case AuthErrorCode.weakPassword.rawValue:
            return "Şifreniz çok zayıf."
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - APPLE SIGN-IN EXTENSIONS
extension AuthViewModel {
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
        
        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: rawNonce
        )
        
        Auth.auth().signIn(with: firebaseCredential) { [weak self] authResult, error in
            if let user = authResult?.user {
                DispatchQueue.main.async {
                    self?.userSession = user
                    self?.isEmailVerified = true
                    
                    // Firestore'da Kullanıcı Kontrolü & Kaydı
                    let db = Firestore.firestore()
                    let userRef = db.collection("users").document(user.uid)
                    
                    userRef.getDocument { snapshot, _ in
                        if snapshot?.exists != true {
                            var name = "Apple Kullanıcısı"
                            if let firstName = credential.fullName?.givenName {
                                name = firstName
                                if let lastName = credential.fullName?.familyName {
                                    name += " \(lastName)"
                                }
                            }
                            
                            let userData: [String: Any] = [
                                "fullName": name,
                                "username": "apple_\(user.uid.prefix(6))",
                                "email": user.email ?? "",
                                "createdAt": FieldValue.serverTimestamp()
                            ]
                            
                            userRef.setData(userData) { _ in
                                self?.fetchUserProfile(uid: user.uid)
                            }
                        } else {
                            self?.fetchUserProfile(uid: user.uid)
                            self?.fetchUserStatsAndFixes(uid: user.uid)
                        }
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
