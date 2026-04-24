import Foundation
import UniformTypeIdentifiers

struct AppSettings: Codable {
    var selectedModel: WhisperModel = .largev3turbo
    var whisperPath: String = "/opt/homebrew/bin/whisper-cli"
    var modelsDirectory: String = ""
    var outputDirectory: URL? = nil
    var language: TranscriptionLanguage = .auto
    var autoCleanup: Bool = true
    var enableLightFormatting: Bool = false
    var threads: Int = 0 // 0 = auto
    
    private static let settingsKey = "VideoTranscribeSettings"
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            let defaults = AppSettings()
            defaults.save()
            return defaults
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppSettings.settingsKey)
        }
    }
    
    /// Common whisper.cpp install locations
    static let commonWhisperPaths: [String] = [
        "/opt/homebrew/bin/whisper-cli",
        "/usr/local/bin/whisper-cli",
        "/opt/homebrew/bin/whisper-cpp",
        "/usr/local/bin/whisper-cpp",
        "/opt/homebrew/bin/main",
        "/usr/local/bin/main"
    ]
    
    static func applicationSupportDirectory() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("VideoTranscribe/Models")
        return appDir.path
    }
    
    /// Common model directories
    static let commonModelPaths: [String] = [
        applicationSupportDirectory(),
        NSHomeDirectory() + "/.cache/whisper",
        NSHomeDirectory() + "/whisper.cpp/models",
        "/usr/local/share/whisper/models",
        "/opt/homebrew/share/whisper/models",
    ]
    
    func resolvedWhisperPath() -> String? {
        // 1. Check App Bundle
        if let bundlePath = Bundle.main.path(forResource: "whisper-cli", ofType: nil, inDirectory: "bin") {
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        
        // 2. Check configured path
        if FileManager.default.isExecutableFile(atPath: whisperPath) {
            return whisperPath
        }
        
        // 3. Check common paths
        for path in Self.commonWhisperPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // 4. Check PATH via `which`
        return findInPath("whisper-cli") ?? findInPath("whisper-cpp") ?? findInPath("main")
    }
    
    private func findInPath(_ name: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env
        
        try? process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        return nil
    }

    func resolvedModelsDirectory() -> String? {
        // 1. Check App Bundle
        if let bundleModelsPath = Bundle.main.resourceURL?.appendingPathComponent("models").path {
            if FileManager.default.fileExists(atPath: bundleModelsPath) {
                // Check if the specific model exists in bundle
                let modelFile = selectedModel.modelFileName
                let fullPath = (bundleModelsPath as NSString).appendingPathComponent(modelFile)
                if FileManager.default.fileExists(atPath: fullPath) {
                    return bundleModelsPath
                }
            }
        }
        
        // 2. Check configured path
        if !modelsDirectory.isEmpty && FileManager.default.fileExists(atPath: modelsDirectory) {
            return modelsDirectory
        }
        
        // 3. Check common paths
        for path in Self.commonModelPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case swedish = "sv"
    case czech = "cs"
    case danish = "da"
    case finnish = "fi"
    case greek = "el"
    case hungarian = "hu"
    case indonesian = "id"
    case malay = "ms"
    case norwegian = "no"
    case romanian = "ro"
    case slovak = "sk"
    case thai = "th"
    case ukrainian = "uk"
    case vietnamese = "vi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto-Detect"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .swedish: return "Swedish"
        case .czech: return "Czech"
        case .danish: return "Danish"
        case .finnish: return "Finnish"
        case .greek: return "Greek"
        case .hungarian: return "Hungarian"
        case .indonesian: return "Indonesian"
        case .malay: return "Malay"
        case .norwegian: return "Norwegian"
        case .romanian: return "Romanian"
        case .slovak: return "Slovak"
        case .thai: return "Thai"
        case .ukrainian: return "Ukrainian"
        case .vietnamese: return "Vietnamese"
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case txt = "Plain Text"
    case srt = "SRT Subtitles"
    case json = "JSON"
    case doc = "Word Document (.doc)"
    
    var fileExtension: String {
        switch self {
        case .txt: return ".txt"
        case .srt: return ".srt"
        case .json: return ".json"
        case .doc: return ".doc"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .txt: return .plainText
        case .srt: return UTType(filenameExtension: "srt") ?? .plainText
        case .json: return .json
        case .doc: return UTType(filenameExtension: "doc") ?? .plainText
        }
    }
    
    var icon: String {
        switch self {
        case .txt: return "doc.text"
        case .srt: return "captions.bubble"
        case .json: return "curlybraces"
        case .doc: return "doc.richtext"
        }
    }
}

import UniformTypeIdentifiers
