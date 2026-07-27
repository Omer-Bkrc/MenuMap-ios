import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        MainTabView(authViewModel: authViewModel)
    }
}
