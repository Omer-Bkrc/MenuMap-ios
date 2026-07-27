import Foundation

struct Place: Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let menuUrl: String
    let status: String
    let city: String?
    let category: [String]?
    let createdBy: String?
}
