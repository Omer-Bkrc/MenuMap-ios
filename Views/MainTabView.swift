import SwiftUI

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            // 📍 1. Harita Sekmesi
            MapView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Harita")
                }
            
            // 👑 2. Admin Sekmesi (Sadece Admin yetkisi varsa görünür)
            if authViewModel.isAdmin {
                AdminView(authViewModel: authViewModel)
                    .tabItem {
                        Image(systemName: "shield.checkmark.fill")
                        Text("Admin")
                    }
            }
            
            // 👤 3. Profil Sekmesi
            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profil")
                }
        }
        .accentColor(.orange)
    }
}
