import Foundation

struct Submission: Identifiable, Codable {
    let id: String
    let name: String
    let menuUrl: String
    let latitude: Double
    let longitude: Double
    let category: AnyCodableCategory
    let submittedByUid: String
    let status: String
    let city: String?
    
    // UI Tarafında eşleştirilecek ek alanlar
    var submitterName: String?
    var submitterUsername: String?
}

// Firestore'dan gelen kategori tek String veya [String] olabildiği için özel decode yapısı
enum AnyCodableCategory: Codable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let singleString = try? container.decode(String.self) {
            self = .string(singleString)
        } else if let stringArray = try? container.decode([String].self) {
            self = .array(stringArray)
        } else {
            self = .string("kafe")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .array(let arr): try container.encode(arr)
        }
    }
    
    var displayText: String {
        switch self {
        case .string(let str): return str
        case .array(let arr): return arr.joined(separator: ", ")
        }
    }
    
    var rawArray: [String] {
        switch self {
        case .string(let str): return [str]
        case .array(let arr): return arr
        }
    }
}
