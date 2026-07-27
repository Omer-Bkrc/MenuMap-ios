import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var showFeedbackModal = false
    @State private var feedbackText = ""
    @State private var isSendingFeedback = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showDeleteAccountAlert = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        Group {
            // 🔒 1. Giriş Yapan ve E-postasını Doğrulayan Kullanıcı Görünümü
            if authViewModel.userSession != nil && authViewModel.isEmailVerified {
                loggedInProfileView
            } else {
                // 🔑 2. Giriş Yapmayan Kullanıcı İçin Giriş/Kayıt Ekranı
                AuthView(authViewModel: authViewModel)
            }
        }
    }
    
    // MARK: - GİRİŞ YAPMIŞ KULLANICI PROFİL GÖRÜNÜMÜ
    private var loggedInProfileView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - ⚠️ Admin Düzeltme İsteği Bildirim Kartı (Tip Güvenli)
                    if !authViewModel.fixRequestsTyped.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("⚠️ Önerileriniz Hakkında Bildirim")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.96, green: 0.5, blue: 0.09))
                            
                            ForEach(authViewModel.fixRequestsTyped) { req in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(req.name) (\(req.city))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Admin Notu: \(req.adminNote)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        authViewModel.dismissFixRequest(subId: req.id)
                                    }) {
                                        Text("Kapat")
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(6)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 1.0, green: 0.88, blue: 0.51), lineWidth: 1)
                                )
                            }
                        }
                        .padding(12)
                        .background(Color(red: 1.0, green: 0.97, blue: 0.88))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 1.0, green: 0.88, blue: 0.51), lineWidth: 1)
                        )
                    }
                    
                    // MARK: - Hesap Bilgileri Kartı
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hesap Bilgileri")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Divider()
                        
                        HStack {
                            Text("Ad Soyad:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(authViewModel.fullName)
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                        
                        HStack {
                            Text("Kullanıcı Adı:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("@\(authViewModel.username)")
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                        
                        HStack {
                            Text("E-posta:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(authViewModel.email)
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                        
                        // MARK: - İstatistikler
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eklediğin Mekanlar")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.top, 6)
                            
                            HStack {
                                Text("Onaylanmış:")
                                Spacer()
                                Text("\(authViewModel.approvedCount)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .font(.footnote)
                            
                            HStack {
                                Text("Beklemede:")
                                Spacer()
                                Text("\(authViewModel.pendingCount)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .font(.footnote)
                        }
                        .padding(.top, 6)
                        
                        // MARK: - Geri Bildirim Butonu
                        Button(action: { showFeedbackModal = true }) {
                            Text("Öneri ve Geri Bildirim")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                        }
                        .padding(.top, 10)
                        
                        // MARK: - Çıkış Yap Butonu
                        Button(action: { authViewModel.signOut() }) {
                            Text("Çıkış Yap")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // MARK: - Tehlikeli Bölge & Gizlilik
                    VStack(spacing: 12) {
                        Button(action: { showDeleteAccountAlert = true }) {
                            Text("Hesabı Kalıcı Olarak Sil")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .underline()
                        }
                        
                        Link("Gizlilik Politikası ve Kullanım Şartları", destination: URL(string: "https://gist.github.com/Omer-Bkrc/49907af2a2ed91126d5d3d522b92d176")!)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .underline()
                    }
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .navigationTitle("Profil")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                // 🚀 HER EKRAN AÇILIŞINDA SAYAÇLARI VE BİLDİRİMLERİ TAZELE
                if let uid = authViewModel.userSession?.uid {
                    authViewModel.fetchUserProfile(uid: uid)
                    authViewModel.fetchUserStatsAndFixes(uid: uid)
                }
            }
        }
        // MARK: - Öneri / Geri Bildirim Modalı
        .sheet(isPresented: $showFeedbackModal) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("MenuMap'i Birlikte Geliştirelim")
                        .font(.headline)
                    
                    Text("Uygulama hakkındaki önerilerini veya karşılaştığın sorunları yazabilirsin.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    TextEditor(text: $feedbackText)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .frame(height: 140)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button("İptal") {
                            showFeedbackModal = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                        .foregroundColor(.primary)
                        
                        Button(action: sendFeedback) {
                            if isSendingFeedback {
                                ProgressView()
                            } else {
                                Text("Gönder")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                        .disabled(isSendingFeedback)
                    }
                }
                .padding(20)
                .navigationBarTitle("Geri Bildirim", displayMode: .inline)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Bilgi"), message: Text(alertMessage), dismissButton: .default(Text("Tamam")))
        }
        .alert(isPresented: $showDeleteAccountAlert) {
            Alert(
                title: Text("Hesabı Kalıcı Olarak Sil"),
                message: Text("Hesabınızı ve tüm verilerinizi silmek istediğinize emin misiniz?"),
                primaryButton: .destructive(Text("Evet, Sil"), action: deleteAccount),
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // Geri Bildirim Gönderme Fonksiyonu
    private func sendFeedback() {
        guard feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 else {
            alertMessage = "Lütfen biraz daha detaylı bir mesaj yazın."
            showAlert = true
            return
        }
        
        isSendingFeedback = true
        
        let feedbackData: [String: Any] = [
            "uid": authViewModel.userSession?.uid ?? "",
            "email": authViewModel.email,
            "username": authViewModel.username,
            "message": feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("feedbacks").addDocument(data: feedbackData) { error in
            isSendingFeedback = false
            if error == nil {
                feedbackText = ""
                showFeedbackModal = false
                alertMessage = "Geri bildiriminiz alındı, teşekkürler!"
                showAlert = true
            } else {
                alertMessage = "Geri bildirim gönderilemedi."
                showAlert = true
            }
        }
    }
    
    // Hesabı Silme Fonksiyonu
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        user.delete { error in
            if let error = error {
                alertMessage = "Hesap silinirken bir sorun oluştu: \(error.localizedDescription)"
                showAlert = true
            } else {
                authViewModel.signOut()
            }
        }
    }
}
