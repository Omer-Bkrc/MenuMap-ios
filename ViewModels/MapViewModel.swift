import Foundation
import CoreLocation
import MapKit
import FirebaseFirestore

class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var places: [Place] = []
    @Published var selectedCity: String = "İstanbul"
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var locationManager = CLLocationManager()
    private var db = Firestore.firestore()
    private let lastCityKey = "@menu_map_last_city"
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Kayıtlı şehri yükle
        if let savedCity = UserDefaults.standard.string(forKey: lastCityKey) {
            self.selectedCity = savedCity
        }
        
        listenToPlaces()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
    }
    
    // MARK: - Aktif Mekanları Dinle
    func listenToPlaces() {
        db.collection("places")
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let list: [Place] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let lat = data["latitude"] as? Double,
                          let lon = data["longitude"] as? Double,
                          let menuUrl = data["menuUrl"] as? String,
                          let status = data["status"] as? String else { return nil }
                    
                    let city = data["city"] as? String
                    let createdBy = data["createdBy"] as? String
                    
                    var categories: [String]? = nil
                    if let arr = data["category"] as? [String] {
                        categories = arr
                    } else if let str = data["category"] as? String {
                        categories = [str]
                    }
                    
                    return Place(
                        id: doc.documentID,
                        name: name,
                        latitude: lat,
                        longitude: lon,
                        menuUrl: menuUrl,
                        status: status,
                        city: city,
                        category: categories,
                        createdBy: createdBy
                    )
                }
                DispatchQueue.main.async { self?.places = list }
            }
    }
    
    func selectCity(_ city: String) {
        self.selectedCity = city
        UserDefaults.standard.set(city, forKey: lastCityKey)
        
        // O şehirdeki ilk mekana haritayı odakla
        if let firstPlace = places.first(where: { ($0.city ?? "").lowercased() == city.lowercased() }) {
            self.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: firstPlace.latitude, longitude: firstPlace.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }
    
    // MARK: - Koordinattan Şehir İsmi Tespiti
    func getCityFromCoords(lat: Double, lon: Double, completion: @escaping (String) -> Void) {
        let location = CLLocation(latitude: lat, longitude: lon)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let city = placemark.administrativeArea ?? placemark.locality ?? "Bilinmiyor"
                completion(city)
            } else {
                completion("Bilinmiyor")
            }
        }
    }
    
    // MARK: - Yeni Mekan Önerisi Gönder
    func submitPlace(name: String, menuUrl: String, categories: [String], coord: CLLocationCoordinate2D, userUid: String, completion: @escaping (Bool) -> Void) {
        getCityFromCoords(lat: coord.latitude, lon: coord.longitude) { [weak self] detectedCity in
            let submissionData: [String: Any] = [
                "name": name,
                "menuUrl": menuUrl,
                "category": categories,
                "city": detectedCity,
                "latitude": coord.latitude,
                "longitude": coord.longitude,
                "status": "pending",
                "submittedAt": FieldValue.serverTimestamp(),
                "submittedByUid": userUid
            ]
            
            self?.db.collection("placeSubmissions").addDocument(data: submissionData) { error in
                DispatchQueue.main.async {
                    completion(error == nil)
                }
            }
        }
    }
    
    // MARK: - Mekan Konumunu Güncelle
    func updatePlaceLocation(placeId: String, newCoord: CLLocationCoordinate2D, completion: @escaping (Bool) -> Void) {
        getCityFromCoords(lat: newCoord.latitude, lon: newCoord.longitude) { detectedCity in
            let db = Firestore.firestore()
            db.collection("places").document(placeId).updateData([
                "latitude": newCoord.latitude,
                "longitude": newCoord.longitude,
                "city": detectedCity,
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    completion(error == nil)
                }
            }
        }
    }
    
    // MARK: - Mekan Detaylarını Güncelle
    func updatePlaceDetails(placeId: String, name: String, menuUrl: String, categories: [String], completion: @escaping (Bool) -> Void) {
        db.collection("places").document(placeId).updateData([
            "name": name,
            "menuUrl": menuUrl,
            "category": categories,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
    
    // MARK: - Mekan Sil
    func deletePlace(placeId: String, completion: @escaping (Bool) -> Void) {
        db.collection("places").document(placeId).delete { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
}
