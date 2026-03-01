import Foundation

// MARK: - Current Alerts

struct AlertResponse: Decodable {
    let id: String?
    let cat: String?
    let title: String?
    let data: [String]
    let desc: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decodeIfPresent(String.self, forKey: .id)
        cat   = try c.decodeIfPresent(String.self, forKey: .cat)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        data  = (try? c.decodeIfPresent([String].self, forKey: .data)) ?? []
        desc  = try c.decodeIfPresent(String.self, forKey: .desc)
    }

    enum CodingKeys: String, CodingKey {
        case id, cat, title, data, desc
    }
}

// MARK: - History

struct HistoryItem: Decodable, Identifiable {
    let id = UUID()
    let alertDate: String?
    let title: String?
    let data: String?
    let category: Int?
    let category_desc: String?

    enum CodingKeys: String, CodingKey {
        case alertDate, title, data, category, category_desc
    }

    var formattedDate: String {
        guard let raw = alertDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm"] {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: raw) {
                formatter.dateFormat = "HH:mm dd/MM"
                return formatter.string(from: date)
            }
        }
        return raw
    }
}
