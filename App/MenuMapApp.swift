import SwiftUI
import FirebaseCore
import GoogleMaps

@main
struct MenuMapApp: App {
    
    init() {
        // 1. Firebase Başlatma
        FirebaseApp.configure()
        
        // 2. Google Maps API Key Başlatma
        // "BURAYA_GOOGLE_MAPS_API_KEY_YAZIN" kısmına Google Cloud Console'dan aldığın anahtarı koy
        GMSServices.provideAPIKey("AIzaSyBUNlTisLIMTXuhnDgtn9-G17AKSmnrM0w")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
