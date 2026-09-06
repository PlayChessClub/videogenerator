import Foundation
import SwiftUI

// MARK: - 固定模型标识（不可更换）

enum FixedModel {
    static let tts = "cosyvoice-v3.5-plus"
    static let voiceEnrollment = "voice-enrollment"
    static let videoI2V = "wan2.6-i2v"
}

enum DashScope {
    static let httpBase = "https://dashscope.aliyuncs.com/api/v1"
    static let wsBase = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
}

// MARK: - 应用设置（API Key 可换，存 Keychain）

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var apiKey: String = ""
    @Published var voicePrefix: String = "myvoice"
    @Published var lastSaved: Date? = nil

    private let keyAccount = "clipforge.dashscope.apikey"
    private let serviceName = "ClipForge"

    private init() {
        apiKey = Keychain.read(service: serviceName, account: keyAccount) ?? ""
    }

    func save() {
        Keychain.write(service: serviceName, account: keyAccount, value: apiKey)
        lastSaved = Date()
    }

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
}

enum Keychain {
    static func read(service: String, account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(service: String, account: String, value: String) {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

// MARK: - 素材库

struct MediaClip: Identifiable, Hashable {
    enum Kind: String { case video, audio, image
        var symbol: String {
            switch self {
            case .video: return "film"
            case .audio: return "waveform"
            case .image: return "photo"
            }
        }
        var label: String {
            switch self {
            case .video: return "视频"
            case .audio: return "音频"
            case .image: return "图片"
            }
        }
    }
    let id: UUID
    var kind: Kind
    var name: String
    var url: URL
    var addedAt: Date

    init(id: UUID = UUID(), kind: Kind, name: String, url: URL, addedAt: Date = .now) {
        self.id = id; self.kind = kind; self.name = name; self.url = url; self.addedAt = addedAt
    }
}

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()
    @Published var clips: [MediaClip] = []
    @Published var order: [UUID] = []

    private init() {}

    func add(_ clip: MediaClip) {
        clips.insert(clip, at: 0)
        order.append(clip.id)
    }

    func remove(_ id: UUID) {
        clips.removeAll { $0.id == id }
        order.removeAll { $0 == id }
    }

    func clip(_ id: UUID) -> MediaClip? { clips.first { $0.id == id } }
}
