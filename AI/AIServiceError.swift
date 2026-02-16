import Foundation

enum AIServiceError: LocalizedError {
    case offline
    case serverError
    case timeout
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You appear to be offline."
        case .serverError:
            return "The AI service is temporarily unavailable."
        case .timeout:
            return "The AI service took too long to respond."
        case .rateLimited:
            return "Too many requests. Please try again in a moment."
        }
    }
}
