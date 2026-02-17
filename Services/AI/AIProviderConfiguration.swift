import Foundation

enum AIProviderMode {
    case mock
    case remote
}

struct AIProviderConfiguration {
    var mode: AIProviderMode
    var baseURLString: String

    static let productionBaseURL = "https://symptomnerd-backend.onrender.com"
    static let `default` = AIProviderConfiguration(mode: .remote, baseURLString: productionBaseURL)

    static func normalizedBaseURL(from rawValue: String?) -> String {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return productionBaseURL
        }

        var candidate = trimmed
        if candidate.lowercased().hasPrefix("s://") {
            candidate = "https://" + candidate.dropFirst(4)
        } else if candidate.hasPrefix("//") {
            candidate = "https:" + candidate
        } else if !candidate.contains("://") {
            candidate = "https://" + candidate
        }

        guard var components = URLComponents(string: candidate),
              let host = components.host,
              !host.isEmpty else {
            return productionBaseURL
        }
        components.path = components.path.isEmpty ? "" : components.path
        components.query = nil
        components.fragment = nil

        let normalized = components.string ?? productionBaseURL
        return normalized.hasSuffix("/") ? String(normalized.dropLast()) : normalized
    }

    static func resolvedBaseURL(from rawValue: String?) -> URL? {
        URL(string: normalizedBaseURL(from: rawValue))
    }
}

struct AIProviderFactory {
    static func makeProvider(configuration: AIProviderConfiguration = .default) -> AIProvider {
        switch configuration.mode {
        case .mock:
            return MockAIProvider()
        case .remote:
            return RemoteAIProvider(baseURLString: configuration.baseURLString)
        }
    }
}
