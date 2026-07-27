import Foundation
import FirebaseFirestore
import FirebaseAuth

struct PlaceSubmission: Identifiable {
    let id: String
    let name: String
    let menuUrl: String
    let latitude: Double
    let longitude: Double
    let category: [String]
    let city: String
    let submittedByUid: String
    var submitterName: String = "Yükleniyor..."
    var submitterUsername: String = "user"
}

class AdminViewModel: ObservableObject {
    @Published var submissions: [PlaceSubmission] = []
    @Published var isLoading = false
    @Published var actionLoadingId: String? = nil // Sadece tıklanan karta özel loading
    
    private let db = Firestore.firestore()
    
    func fetchSubmissions() {
        isLoading = true
        db.collection("placeSubmissions")
            .whereField("status", in: ["pending", "fix_requested"])
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else {
                    self?.isLoading = false
                    return
                }
                
                let rawList = docs.compactMap { doc -> PlaceSubmission? in
                    let data = doc.data()
                    let cat = data["category"] as? [String] ?? [(data["category"] as? String ?? "kafe")]
                    return PlaceSubmission(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "",
                        menuUrl: data["menuUrl"] as? String ?? "",
                        latitude: data["latitude"] as? Double ?? 0.0,
                        longitude: data["longitude"] as? Double ?? 0.0,
                        category: cat,
                        city: data["city"] as? String ?? "Bilinmiyor",
                        submittedByUid: data["submittedByUid"] as? String ?? ""
                    )
                }
                
                let group = DispatchGroup()
                var enrichedList = rawList
                
                for i in 0..<enrichedList.count {
                    let uid = enrichedList[i].submittedByUid
                    if !uid.isEmpty {
                        group.enter()
                        self?.db.collection("users").document(uid).getDocument { userSnap, _ in
                            if let uData = userSnap?.data() {
                                enrichedList[i].submitterName = uData["fullName"] as? String ?? "Bilinmeyen"
                                enrichedList[i].submitterUsername = uData["username"] as? String ?? "user"
                            }
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    self?.submissions = enrichedList
                    self?.isLoading = false
                }
            }
    }
    
    // MARK: - ONAYLA (Places Koleksiyonuna Yazar & Live Yapar)
    func approve(sub: PlaceSubmission, adminUid: String, completion: @escaping (Bool) -> Void) {
        actionLoadingId = sub.id
        
        let submissionRef = db.collection("placeSubmissions").document(sub.id)
        let newPlaceRef = db.collection("places").document()
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // 1. Live Places koleksiyonuna ekle
            transaction.setData([
                "name": sub.name,
                "category": sub.category,
                "city": sub.city,
                "latitude": sub.latitude,
                "longitude": sub.longitude,
                "menuUrl": sub.menuUrl,
                "status": "active",
                "createdAt": FieldValue.serverTimestamp(),
                "createdBy": sub.submittedByUid,
                "verified": true
            ], forDocument: newPlaceRef)
            
            // 2. Submission durumunu güncelle
            transaction.updateData([
                "status": "approved",
                "reviewedByUid": adminUid,
                "reviewedAt": FieldValue.serverTimestamp(),
                "approvedPlaceId": newPlaceRef.documentID
            ], forDocument: submissionRef)
            
            return nil
        }) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.actionLoadingId = nil
                completion(error == nil)
            }
        }
    }
    
    // MARK: - REDDET VEYA DÜZELTME İSTE
    func rejectOrRequestFix(sub: PlaceSubmission, isFix: Bool, reason: String, adminUid: String, completion: @escaping (Bool) -> Void) {
        actionLoadingId = sub.id
        let statusType = isFix ? "fix_requested" : "rejected"
        let submissionRef = db.collection("placeSubmissions").document(sub.id)
        
        submissionRef.updateData([
            "status": statusType,
            "adminNote": reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Belirtilmedi." : reason,
            "reviewedByUid": adminUid,
            "reviewedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.actionLoadingId = nil
                completion(error == nil)
            }
        }
    }
}
