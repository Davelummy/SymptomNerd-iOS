import Foundation

struct RemoteAIProvider: AIProvider {
    let baseURLString: String

    func analyze(request: AIRequest) async throws -> AIResponse {
        try await post(path: "/ai/analyze", body: AnalyzePayload(request: request))
    }

    func chat(messages: [AIChatMessage], request: AIRequest) async throws -> AIResponse {
        try await post(path: "/ai/chat", body: ChatPayload(request: request, messages: messages))
    }

    private func post<Response: Decodable, Body: Encodable>(path: String, body: Body) async throws -> Response {
        guard let url = URL(string: baseURLString)?.appendingPathComponent(path) else {
            throw AIServiceError.serverError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIServiceError.serverError
            }

            switch http.statusCode {
            case 200...299:
                return try JSONDecoder().decode(Response.self, from: data)
            case 408, 504:
                throw AIServiceError.timeout
            case 429:
                throw AIServiceError.rateLimited
            default:
                if let message = extractErrorMessage(from: data) {
                    throw AIServiceError.serverMessage(message)
                }
                throw AIServiceError.serverError
            }
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw AIServiceError.offline
            }
            throw AIServiceError.serverError
        }
    }
}

private struct BackendErrorResponse: Decodable {
    let error: String?
}

private func extractErrorMessage(from data: Data) -> String? {
    if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data),
       let message = backendError.error,
       !message.isEmpty {
        return message
    }
    return nil
}

private struct AnalyzePayload: Encodable {
    let request: AIRequest
}

private struct ChatPayload: Encodable {
    let request: AIRequest
    let messages: [AIChatMessage]
}
