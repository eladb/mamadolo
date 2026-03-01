import SwiftUI

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var manager = AlertsManager()
    @State private var progressValue: Double = 1.0
    @State private var dotOpacity: Double = 1.0
    @State private var borderPulse: Double = 1.0

    private var isAlert: Bool { manager.cityInAlert }
    private var hasAnyAlert: Bool { !(manager.currentAlert?.data.isEmpty ?? true) }

    var body: some View {
        ZStack {
            Color(hex: "0f1117").ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 0) {
                        progressBarView

                        VStack(spacing: 20) {
                            liveAlertCard
                            historySection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
        .onAppear {
            // Blinking status dot
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                dotOpacity = 0.3
            }
            // Pulsing alert border
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                borderPulse = 0.4
            }
            // Progress bar tied to 5s alert poll
            resetProgress()
        }
        .onChange(of: manager.lastUpdate) { _ in
            resetProgress()
        }
    }

    // MARK: - Header

    var headerView: some View {
        HStack(spacing: 14) {
            Text("🛡️").font(.system(size: 34))
            VStack(alignment: .trailing, spacing: 2) {
                Text("התרעות פיקוד העורף — אבן יהודה")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text("עדכון בזמן אמת מאתר פיקוד העורף הרשמי")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8892b0"))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "1a1d2e"))
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(Color(hex: "2d3148")),
            alignment: .bottom
        )
    }

    // MARK: - Progress bar

    var progressBarView: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().foregroundColor(Color(hex: "2d3148"))
                Rectangle()
                    .foregroundColor(Color(hex: "7986cb"))
                    .frame(width: geo.size.width * progressValue)
                    .animation(.linear(duration: 5), value: progressValue)
            }
        }
        .frame(height: 3)
        .padding(.bottom, 20)
    }

    func resetProgress() {
        progressValue = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            progressValue = 0.0
        }
    }

    // MARK: - Live alert card

    var liveAlertCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Card header row
            HStack {
                if let update = manager.lastUpdate {
                    Text("עודכן: \(timeString(update))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "525f7f"))
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(manager.lastUpdate != nil ? Color(hex: "2ecc71") : Color(hex: "f39c12"))
                        .opacity(manager.lastUpdate != nil ? dotOpacity : 1)
                    Text("התרעה פעילה כעת")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "8892b0"))
                        .textCase(.uppercase)
                }
            }

            // Card body
            Group {
                if manager.isLoadingAlerts {
                    ProgressView().tint(Color(hex: "7986cb")).frame(maxWidth: .infinity).padding(.vertical, 16)
                } else if manager.alertsError {
                    Text("⚠️ שגיאה בטעינת נתונים")
                        .foregroundColor(Color(hex: "f0c040"))
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else if isAlert {
                    alertActiveBody
                } else if hasAnyAlert {
                    otherAreaAlertBody
                } else {
                    safeBody
                }
            }
        }
        .padding(20)
        .background(isAlert ? Color(hex: "2a0a0a") : Color(hex: "12261e"))
        .overlay(
            ZStack {
                // Base border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAlert ? Color(hex: "c0392b") : Color(hex: "1e6b45"), lineWidth: 2)
                // Pulsing overlay when alert
                if isAlert {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "e74c3c"), lineWidth: 2)
                        .opacity(borderPulse)
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: isAlert ? Color(hex: "e74c3c").opacity(borderPulse * 0.4) : .clear, radius: 12)
    }

    var alertActiveBody: some View {
        let cities = manager.currentAlert?.data.filter { c in
            c.contains(AlertsManager.city) || AlertsManager.city.contains(c)
        } ?? []
        return VStack(alignment: .trailing, spacing: 10) {
            Text("🚨 התרעה פעילה!")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(Color(hex: "e74c3c"))
            Text(manager.currentAlert?.title ?? "התרעה")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "aab4c4"))
            HStack(spacing: 8) {
                ForEach(cities, id: \.self) { city in
                    Text(city)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "e74c3c"))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color(hex: "e74c3c").opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "c0392b"), lineWidth: 1))
                        .cornerRadius(6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    var otherAreaAlertBody: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("אין התרעה עבור אבן יהודה")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(Color(hex: "2ecc71"))
            Text("ישנה התרעה פעילה באזורים אחרים (\(manager.currentAlert?.data.count ?? 0) ישובים).")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "aab4c4"))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    var safeBody: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("אין התרעה פעילה")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(Color(hex: "2ecc71"))
            Text("אין כרגע התרעה פעילה עבור אבן יהודה.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "aab4c4"))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - History

    var historySection: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Text("היסטוריית התרעות — 24 שעות אחרונות (אבן יהודה)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "c5cae9"))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 6)
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(Color(hex: "2d3148")),
                    alignment: .bottom
                )

            if manager.isLoadingHistory {
                ProgressView().tint(Color(hex: "7986cb")).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if manager.history.isEmpty {
                Text("לא נמצאו התרעות עבור אבן יהודה ב-24 השעות האחרונות.")
                    .foregroundColor(Color(hex: "525f7f"))
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            } else {
                ForEach(manager.history) { item in
                    historyRow(item: item)
                }
            }
        }
    }

    func historyRow(item: HistoryItem) -> some View {
        HStack(alignment: .top) {
            Text(item.formattedDate)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "525f7f"))
                .frame(width: 72, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.category_desc ?? "התרעה")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "e8eaf6"))
                Text(item.data ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "9fa8da"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(hex: "1a1d2e"))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "2d3148"), lineWidth: 1))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

#Preview {
    ContentView()
}
