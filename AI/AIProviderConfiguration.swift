import Foundation

enum AIProviderMode {
    case mock
    case remote
}

struct AIProviderConfiguration {
    var mode: AIProviderMode
    var baseURLString: String

    static let `default` = AIProviderConfiguration(mode: .mock, baseURLString: \"http://localhost:3001\")
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
