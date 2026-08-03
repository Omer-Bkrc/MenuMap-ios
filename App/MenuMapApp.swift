import SwiftUI
import FirebaseCore
import GoogleMaps

@main
struct MenuMapApp: App {
    
    init() {
        // 1. Firebase Başlatma
        FirebaseApp.configure()
        
        // 2. Google Maps API Key Başlatma
        GMSServices.provideAPIKey("AIzaSyBUfKBgqhBl4I4f0M-l41ZOmqb1lnjRTYM")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
