import Foundation

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largev2 = "large-v2"
    case largev3 = "large-v3"
    case largev3turbo = "large-v3-turbo"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .largev2: return "Large v2"
        case .largev3: return "Large v3"
        case .largev3turbo: return "Large v3 Turbo"
        }
    }
    
    var description: String {
        switch self {
        case .tiny: return "Fastest, ~75 MB — good for quick drafts"
        case .base: return "Fast, ~142 MB — reasonable quality"
        case .small: return "Balanced, ~466 MB — good accuracy"
        case .medium: return "Accurate, ~1.5 GB — high quality"
        case .largev2: return "Very accurate, ~2.9 GB — near best"
        case .largev3: return "Best accuracy, ~2.9 GB — highest quality"
        case .largev3turbo: return "Best accuracy + faster, ~1.6 GB — recommended"
        }
    }
    
    var modelFileName: String {
        return "ggml-\(rawValue).bin"
    }
    
    /// Approximate VRAM usage in GB
    var vramUsage: Double {
        switch self {
        case .tiny: return 0.4
        case .base: return 0.5
        case .small: return 1.0
        case .medium: return 2.5
        case .largev2: return 4.0
        case .largev3: return 4.0
        case .largev3turbo: return 2.5
        }
    }
    
    /// Speed rating 1-5 (5 = fastest)
    var speedRating: Int {
        switch self {
        case .tiny: return 5
        case .base: return 4
        case .small: return 3
        case .medium: return 2
        case .largev2: return 1
        case .largev3: return 1
        case .largev3turbo: return 2
        }
    }
    
    /// Accuracy rating 1-5 (5 = best)
    var accuracyRating: Int {
        switch self {
        case .tiny: return 1
        case .base: return 2
        case .small: return 3
        case .medium: return 4
        case .largev2: return 4
        case .largev3: return 5
        case .largev3turbo: return 5
        }
    }
}
