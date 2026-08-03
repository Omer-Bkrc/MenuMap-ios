import SwiftUI
import CoreLocation
import GoogleMaps

struct AdminView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var adminVM = AdminViewModel()
    
    @State private var previewMenuUrl: IdentifiableMapURL?
    @State private var mapPreviewSub: PlaceSubmission?
    
    @State private var selectedSubForReject: PlaceSubmission?
    @State private var rejectReason = ""
    @State private var showRejectModal = false
    
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Group {
                if adminVM.isLoading {
                    ProgressView("Yükleniyor...")
                } else if adminVM.submissions.isEmpty {
                    VStack(spacing: 10) {
                        Text("🎉").font(.largeTitle)
                        Text("Bekleyen mekan önerisi yok.")
                            .foregroundColor(.gray)
                    }
                } else {
                    List(adminVM.submissions) { sub in
                        submissionCard(sub: sub)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Bekleyen Öneriler")
            .onAppear { adminVM.fetchSubmissions() }
            .sheet(item: $previewMenuUrl) { item in SafariView(url: item.url) }
            .sheet(item: $mapPreviewSub) { sub in
                AdminGoogleMapModal(sub: sub)
            }
            .sheet(isPresented: $showRejectModal) {
                rejectModalView
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Bilgi"), message: Text(alertMessage), dismissButton: .default(Text("Tamam")))
            }
        }
    }
    
    @ViewBuilder
    private func submissionCard(sub: PlaceSubmission) -> some View {
        let isBusy = adminVM.actionLoadingId == sub.id
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(sub.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("📍 \(sub.city)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
            
            Text("🏷️ Kategori: \(sub.category.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("👤 Gönderen: \(sub.submitterName) (@\(sub.submitterUsername))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 🌐 Önizleme Butonları Row
            HStack(spacing: 10) {
                Button(action: {
                    if let url = URL(string: sub.menuUrl) {
                        previewMenuUrl = IdentifiableMapURL(url: url)
                    }
                }) {
                    Text("🌐 Menüye Bak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: { mapPreviewSub = sub }) {
                    Text("📍 Konuma Bak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // İşlem Butonları (Onayla & Reddet)
            HStack(spacing: 10) {
                Button(action: {
                    guard let adminUid = authViewModel.userSession?.uid else { return }
                    adminVM.approve(sub: sub, adminUid: adminUid) { success in
                        alertMessage = success ? "Mekan onaylandı ve haritada canlıya alındı!" : "Hata oluştu."
                        showAlert = true
                    }
                }) {
                    if isBusy {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                    } else {
                        Text("✓ Onayla")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isBusy)
                
                Button(action: {
                    selectedSubForReject = sub
                    showRejectModal = true
                }) {
                    Text("✕ Reddet")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isBusy)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var rejectModalView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(selectedSubForReject?.name ?? "Mekan") İçin İşlem")
                    .font(.headline)
                
                Text("Kullanıcıya iletilecek notu yazabilirsiniz (opsiyonel):")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextEditor(text: $rejectReason)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(height: 100)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button("İptal") {
                        showRejectModal = false
                        rejectReason = ""
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .foregroundColor(.primary)
                    
                    Button("Düzeltme İste") {
                        handleRejectOrFix(isFix: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .cornerRadius(10)
                    
                    Button("Reddet") {
                        handleRejectOrFix(isFix: false)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .cornerRadius(10)
                }
            }
            .padding(20)
            .navigationBarTitle("İşlem Yap", displayMode: .inline)
        }
    }
    
    private func handleRejectOrFix(isFix: Bool) {
        guard let sub = selectedSubForReject,
              let adminUid = authViewModel.userSession?.uid else { return }
        
        adminVM.rejectOrRequestFix(sub: sub, isFix: isFix, reason: rejectReason, adminUid: adminUid) { success in
            showRejectModal = false
            rejectReason = ""
            alertMessage = success ? (isFix ? "Düzeltme notu iletildi." : "Öneri reddedildi.") : "Hata oluştu."
            showAlert = true
        }
    }
}

// MARK: - Admin Google Map Preview Sheet
struct AdminGoogleMapModal: View, Identifiable {
    var id: String { sub.id }
    let sub: PlaceSubmission
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            AdminGMSMapViewWrapper(sub: sub)
                .navigationBarTitle("Konum: \(sub.name)", displayMode: .inline)
                .navigationBarItems(trailing: Button("Kapat") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct AdminGMSMapViewWrapper: UIViewRepresentable {
    let sub: PlaceSubmission
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: sub.latitude, longitude: sub.longitude, zoom: 15.0)
        
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: sub.latitude, longitude: sub.longitude)
        marker.title = sub.name
        marker.snippet = sub.city
        marker.icon = GMSMarker.markerImage(with: .orange)
        marker.map = mapView
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {}
}
