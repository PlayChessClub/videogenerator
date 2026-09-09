import SwiftUI
import ClipForgeCore

@main
struct ClipForgeiOSApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
                ImageView()
                    .tabItem { Label("图片", systemImage: "photo") }
                VoiceView()
                    .tabItem { Label("语音", systemImage: "waveform") }
                BillingView()
                    .tabItem { Label("账本", systemImage: "receipt") }
            }
            .environmentObject(settings)
        }
    }
}
