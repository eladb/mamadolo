import Foundation

@MainActor
class AlertsManager: ObservableObject {

    static let city = "אבן יהודה"

    @Published var currentAlert: AlertResponse? = nil
    @Published var cityInAlert = false
    @Published var history: [HistoryItem] = []
    @Published var lastUpdate: Date? = nil
    @Published var alertsError = false
    @Published var historyError = false
    @Published var isLoadingAlerts = true
    @Published var isLoadingHistory = true

    private let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Referer": "https://www.oref.org.il/",
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "he-IL,he;q=0.9,en-US;q=0.8,en;q=0.7",
    ]

    private var alertsTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    func startPolling() {
        Task { await fetchAlerts() }
        Task { await fetchHistory() }

        alertsTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                await fetchAlerts()
            }
        }

        historyTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                await fetchHistory()
            }
        }
    }

    // MARK: - Fetch current alerts

    func fetchAlerts() async {
        guard let url = URL(string: "https://www.oref.org.il/WarningMessages/alert/alerts.json") else { return }

        var req = URLRequest(url: url, timeoutInterval: 10)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200

            if status == 204 || data.isEmpty {
                currentAlert = nil
                cityInAlert = false
                lastUpdate = Date()
                alertsError = false
                isLoadingAlerts = false
                return
            }

            let jsonData = stripBOM(data)
            let text = String(data: jsonData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if text.isEmpty {
                currentAlert = nil
                cityInAlert = false
            } else {
                let alert = try JSONDecoder().decode(AlertResponse.self, from: Data(text.utf8))
                currentAlert = alert
                cityInAlert = alert.data.contains { c in
                    c.contains(Self.city) || Self.city.contains(c)
                }
            }
            lastUpdate = Date()
            alertsError = false
        } catch {
            alertsError = true
        }
        isLoadingAlerts = false
    }

    // MARK: - Fetch history

    func fetchHistory() async {
        let endpoints = [
            "https://alerts-history.oref.org.il/Shared/Ajax/GetAlarmsHistory.aspx?lang=he&mode=1",
            "https://www.oref.org.il/warningMessages/alert/History/AlertsHistory.json",
        ]

        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }

            var req = URLRequest(url: url, timeoutInterval: 15)
            headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                if data.isEmpty { continue }

                let jsonData = stripBOM(data)
                let text = String(data: jsonData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if text.isEmpty { continue }

                let items = try JSONDecoder().decode([HistoryItem].self, from: Data(text.utf8))
                if items.isEmpty { continue }

                history = items.filter { item in
                    guard let d = item.data else { return false }
                    return d.contains(Self.city) || Self.city.contains(d)
                }
                historyError = false
                isLoadingHistory = false
                return
            } catch {
                continue
            }
        }

        historyError = true
        isLoadingHistory = false
    }

    // MARK: - Helpers

    private func stripBOM(_ data: Data) -> Data {
        data.prefix(3) == Data([0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    }
}
