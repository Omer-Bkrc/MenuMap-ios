import SwiftUI
import MapKit
import GoogleMaps

// MARK: - URL Wrapper
struct IdentifiableMapURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Google Maps SwiftUI Wrapper
struct GoogleMapView: UIViewRepresentable {
    @Binding var cameraTarget: CLLocationCoordinate2D?
    @Binding var cameraZoom: Float?
    @Binding var centerCoordinate: CLLocationCoordinate2D?
    var places: [Place]
    @Binding var selectedPlace: Place?
    var isAddOrEditMode: Bool
    
    func makeUIView(context: Context) -> GMSMapView {
        let defaultCoord = cameraTarget ?? CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
        let camera = GMSCameraPosition.camera(withLatitude: defaultCoord.latitude, longitude: defaultCoord.longitude, zoom: 10.5)
        
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        uiView.clear()
        
        // Dinamik kamera yakınlaştırması (Şehir için 10.5, Mekan/Konum için 15.0)
        if let target = cameraTarget {
            let zoomLevel = cameraZoom ?? 10.5
            let camera = GMSCameraPosition.camera(withLatitude: target.latitude, longitude: target.longitude, zoom: zoomLevel)
            uiView.animate(to: camera)
            DispatchQueue.main.async {
                self.cameraTarget = nil
                self.cameraZoom = nil
            }
        }
        
        // Ekleme veya düzenleme modunda değilsek pini haritada göster
        if !isAddOrEditMode {
            for place in places {
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                marker.title = place.name
                marker.icon = GMSMarker.markerImage(with: .orange)
                marker.userData = place
                marker.map = uiView
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            DispatchQueue.main.async {
                self.parent.centerCoordinate = position.target
            }
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let place = marker.userData as? Place {
                DispatchQueue.main.async {
                    self.parent.selectedPlace = place
                }
            }
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if !parent.isAddOrEditMode {
                DispatchQueue.main.async {
                    self.parent.selectedPlace = nil
                }
            }
        }
    }
}

// MARK: - MAIN MAP VIEW
struct MapView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var mapViewModel = MapViewModel()
    
    @State private var selectedPlace: Place?
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var cameraTarget: CLLocationCoordinate2D?
    @State private var cameraZoom: Float? = nil
    @State private var centerCoordinate: CLLocationCoordinate2D?
    
    // Modlar
    @State private var isAddMode = false
    @State private var isEditMode = false
    
    // Modallar
    @State private var showAddModal = false
    @State private var showEditModal = false
    @State private var showCitySheet = false
    @State private var showQRScanner = false
    @State private var menuSafariUrlItem: IdentifiableMapURL?
    
    // Form State'leri
    @State private var formName = ""
    @State private var formMenuUrl = ""
    @State private var formCategories: [String] = ["kafe"]
    
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    // MARK: - Güvenlik Kontrolü (Admin veya Mekan Sahibi mi?)
    private func canEditPlace(_ place: Place) -> Bool {
        // 1. Admin ise her yeri düzenleyebilir
        if authViewModel.isAdmin { return true }
        
        // 2. Kullanıcı oturum açmamışsa veya mekanın sahibi yoksa kesinlikle düzenleyemez
        guard let currentUid = authViewModel.userSession?.uid,
              let createdBy = place.createdBy,
              !currentUid.isEmpty,
              !createdBy.isEmpty else {
            return false
        }
        
        // 3. Sadece mekanın sahibi ise düzenleyebilir
        return createdBy == currentUid
    }

    
    var cityPlaces: [Place] {
        mapViewModel.places.filter { ($0.city ?? "Bilinmiyor").lowercased() == mapViewModel.selectedCity.lowercased() }
    }
    
    var filteredPlaces: [Place] {
        if searchQuery.isEmpty { return cityPlaces }
        return cityPlaces.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        ZStack {
            // 1. Google Maps
            GoogleMapView(
                cameraTarget: $cameraTarget,
                cameraZoom: $cameraZoom,
                centerCoordinate: $centerCoordinate,
                places: cityPlaces,
                selectedPlace: $selectedPlace,
                isAddOrEditMode: isAddMode || isEditMode
            )
            .ignoresSafeArea()
            .onTapGesture {
                isSearching = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            
            // 2. Merkez Noktası (Mekan Ekle / Düzenle Modu)
            if isAddMode || isEditMode {
                Circle()
                    .fill(isEditMode ? Color.orange : Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 3)
                    .allowsHitTesting(false)
            }
            
            // 3. Üst Arama & Alt Kart Katmanları
            VStack {
                if !isAddMode && !isEditMode {
                    topSearchHeader
                    if isSearching && !filteredPlaces.isEmpty {
                        searchResultsOverlay
                    }
                }
                
                Spacer()
                
                if !isAddMode && !isEditMode, let place = selectedPlace {
                    bottomPlaceCard(place: place)
                }
                
                if !isAddMode && !isEditMode && selectedPlace == nil {
                    bottomFloatingButtons
                }
                
                if isAddMode || isEditMode {
                    modeActionBar
                }
            }
        }
        .sheet(item: $menuSafariUrlItem) { item in SafariView(url: item.url) }
        .sheet(isPresented: $showCitySheet) {
            CityListView(mapViewModel: mapViewModel, showSheet: $showCitySheet, onCitySelected: { newCity in
                if let firstPlace = mapViewModel.places.first(where: { ($0.city ?? "").lowercased() == newCity.lowercased() }) {
                    cameraZoom = 10.5 // Şehir seçiminde KUŞBAKIŞI UZAKLAŞMA
                    cameraTarget = CLLocationCoordinate2D(latitude: firstPlace.latitude, longitude: firstPlace.longitude)
                }
            })
        }
        .sheet(isPresented: $showAddModal) { addModalView }
        .sheet(isPresented: $showEditModal) { editModalView }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedUrl in formMenuUrl = scannedUrl }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Bilgi"), message: Text(alertMessage), dismissButton: .default(Text("Tamam")))
        }
    }
    
    // MARK: - SUBVIEWS
    
    @ViewBuilder
    private var topSearchHeader: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("\(mapViewModel.selectedCity) için ara...", text: $searchQuery, onEditingChanged: { active in
                    isSearching = active
                })
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
            
            Button(action: {
                showCitySheet = true
                isSearching = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }) {
                Text(mapViewModel.selectedCity)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var searchResultsOverlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(filteredPlaces) { place in
                    Button(action: {
                        selectedPlace = place
                        isSearching = false
                        searchQuery = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
                        cameraZoom = 15.0 // Arama sonucunda YAKINLAŞMA
                        cameraTarget = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    }) {
                        Text(place.name)
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .frame(maxHeight: 180)
    }
    
    @ViewBuilder
    private func bottomPlaceCard(place: Place) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text("Menüyü görmek için dokunun 📖")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if let url = URL(string: place.menuUrl) {
                    menuSafariUrlItem = IdentifiableMapURL(url: url)
                }
            }
            
            if canEditPlace(place) {
                        Button("Düzenle") {
                            formName = place.name
                            formMenuUrl = place.menuUrl
                            formCategories = place.category ?? ["kafe"]
                            showEditModal = true
                }
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var bottomFloatingButtons: some View {
        HStack {
            Button(action: {
                if authViewModel.userSession == nil || !authViewModel.isEmailVerified {
                    alertMessage = "Mekan ekleyebilmek için lütfen Profil sekmesinden giriş yapın."
                    showAlert = true
                } else {
                    isAddMode = true
                    selectedPlace = nil
                }
            }) {
                Image(systemName: "plus")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            
            Spacer()
            
            Button(action: {
                mapViewModel.requestLocationPermission()
                if let userLoc = mapViewModel.userLocation {
                    cameraZoom = 15.0 // Konumuma basınca YAKINLAŞMA
                    cameraTarget = userLoc
                }
            }) {
                Text("Konumum")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .shadow(radius: 2)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var modeActionBar: some View {
        HStack(spacing: 12) {
            Button("İptal") {
                isAddMode = false
                isEditMode = false
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            Button(isEditMode ? "Konumu Güncelle" : "Onayla") {
                if isEditMode, let place = selectedPlace {
                    let targetCoord = centerCoordinate ?? CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    mapViewModel.updatePlaceLocation(placeId: place.id, newCoord: targetCoord) { success in
                        isEditMode = false
                        selectedPlace = nil
                        alertMessage = success ? "Konum güncellendi." : "Hata oluştu."
                        showAlert = true
                    }
                } else {
                    formName = ""
                    formMenuUrl = ""
                    formCategories = ["kafe"]
                    showAddModal = true
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .fontWeight(.bold)
            .cornerRadius(12)
        }
        .padding()
    }
    
    private var addModalView: some View {
        PlaceFormModal(
            title: "Mekan Bilgileri",
            name: $formName,
            menuUrl: $formMenuUrl,
            categories: $formCategories,
            showQRScanner: $showQRScanner,
            onSave: {
                guard let uid = authViewModel.userSession?.uid else { return }
                let targetCoord = centerCoordinate ?? CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
                mapViewModel.submitPlace(name: formName, menuUrl: formMenuUrl, categories: formCategories, coord: targetCoord, userUid: uid) { success in
                    showAddModal = false
                    isAddMode = false
                    alertMessage = success ? "Mekan öneriniz onay için gönderildi!" : "Hata oluştu."
                    showAlert = true
                }
            }
        )
    }
    
    private var editModalView: some View {
        PlaceFormModal(
            title: "Mekanı Düzenle",
            name: $formName,
            menuUrl: $formMenuUrl,
            categories: $formCategories,
            showQRScanner: $showQRScanner,
            isEditModeTrigger: true,
            onChangeLocationTrigger: {
                showEditModal = false
                isEditMode = true
                
                if let place = selectedPlace {
                    cameraZoom = 15.0 // Konum değiştirmek için açıldığında YAKINLAŞMA
                    cameraTarget = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                }
            },
            onDelete: authViewModel.isAdmin ? {
                if let place = selectedPlace {
                    mapViewModel.deletePlace(placeId: place.id) { success in
                        showEditModal = false
                        selectedPlace = nil
                        alertMessage = success ? "Mekan silindi." : "Hata oluştu."
                        showAlert = true
                    }
                }
            } : nil,
            onSave: {
                if let place = selectedPlace {
                    mapViewModel.updatePlaceDetails(placeId: place.id, name: formName, menuUrl: formMenuUrl, categories: formCategories) { success in
                        showEditModal = false
                        selectedPlace = nil
                        alertMessage = success ? "Bilgiler güncellendi." : "Hata oluştu."
                        showAlert = true
                    }
                }
            }
        )
    }
}

// MARK: - Şehir Seçim Modalı
struct CityListView: View {
    @ObservedObject var mapViewModel: MapViewModel
    @Binding var showSheet: Bool
    var onCitySelected: (String) -> Void
    
    var availableCities: [String] {
        Array(Set(mapViewModel.places.compactMap { $0.city }))
    }
    
    var body: some View {
        NavigationView {
            List(availableCities, id: \.self) { city in
                Button(action: {
                    mapViewModel.selectCity(city)
                    onCitySelected(city)
                    showSheet = false
                }) {
                    HStack {
                        Text(city)
                        Spacer()
                        if city == mapViewModel.selectedCity {
                            Image(systemName: "checkmark").foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationBarTitle("Şehirler", displayMode: .inline)
        }
    }
}

// MARK: - Mekan Form Modalı (Ekleme / Düzenleme)
struct PlaceFormModal: View {
    let title: String
    @Binding var name: String
    @Binding var menuUrl: String
    @Binding var categories: [String]
    @Binding var showQRScanner: Bool
    var isEditModeTrigger: Bool = false
    var onChangeLocationTrigger: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mekan Adı")) {
                    TextField("Örn: X Cafe", text: $name)
                }
                
                Section(header: Text("Menü URL")) {
                    HStack {
                        TextField("https://...", text: $menuUrl)
                            .autocapitalization(.none)
                        Button(action: { showQRScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section(header: Text("Kategori")) {
                    HStack {
                        Toggle("Kafe", isOn: Binding(
                            get: { categories.contains("kafe") },
                            set: { newValue in
                                if newValue {
                                    if !categories.contains("kafe") { categories.append("kafe") }
                                } else {
                                    categories.removeAll { $0 == "kafe" }
                                }
                            }
                        ))
                        Toggle("Restoran", isOn: Binding(
                            get: { categories.contains("restoran") },
                            set: { newValue in
                                if newValue {
                                    if !categories.contains("restoran") { categories.append("restoran") }
                                } else {
                                    categories.removeAll { $0 == "restoran" }
                                }
                            }
                        ))
                    }
                }
                
                if isEditModeTrigger {
                    Section {
                        Button("Konumu Değiştirmek İçin Tıkla") {
                            onChangeLocationTrigger?()
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if let deleteAction = onDelete {
                        Section {
                            Button("Mekanı Sil", role: .destructive, action: deleteAction)
                        }
                    }
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button("Kaydet", action: onSave).fontWeight(.bold))
        }
    }
}

