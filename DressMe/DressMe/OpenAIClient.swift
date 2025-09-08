//
//  OpenAIClient.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import Foundation
import UIKit

/// A thin client for OpenAI APIs used in this demo.
/// Provides: Vision (image understanding), TTS (natural voice), and simple chat.
final class OpenAIClient {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Vision: analyze clothing and return short fashion advice (EN)
    func analyzeClothing(image: UIImage) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "OpenAIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
        }

        let base64 = jpegData.base64EncodedString()

        // OpenAI Chat Completions with vision
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        struct Request: Encodable {
            struct Message: Encodable {
                let role: String
                let content: [Content]
            }
            struct Content: Encodable {
                let type: String
                let text: String?
                let image_url: ImageURL?
            }
            struct ImageURL: Encodable {
                let url: String
            }
            let model: String
            let messages: [Message]
            let temperature: Double
        }

        let systemPrompt = "You are a fashion assistant. The user points the camera at a garment. Identify the garment and provide a short, practical styling tip in English (colors, shoes, accessories). Reply in at most 2 sentences."

        let req = Request(
            model: "gpt-4o-mini", // vision-capable lightweight model for demo
            messages: [
                .init(role: "system", content: [.init(type: "text", text: systemPrompt, image_url: nil)]),
                .init(role: "user", content: [
                    .init(type: "text", text: "Analyze the garment in the image and give a styling tip.", image_url: nil),
                    .init(type: "image_url", text: nil, image_url: .init(url: "data:image/jpeg;base64,\(base64)"))
                ])
            ],
            temperature: 0.7
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "?"
            throw NSError(domain: "OpenAIClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI error: \(body)"])
        }

        struct CompletionResponse: Decodable {
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Text to Speech (natural English voice)
    /// Synthesizes natural-sounding English speech audio from text.
    func synthesizeEnglishVoice(text: String, voice: String = "alloy", format: String = "mp3") async throws -> Data {
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!

        struct TTSRequest: Encodable {
            let model: String
            let input: String
            let voice: String
            let format: String
        }

        let req = TTSRequest(model: "gpt-4o-mini-tts", input: text, voice: voice, format: format)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "?"
            throw NSError(domain: "OpenAIClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI TTS error: \(body)"])
        }
        return data
    }

    // MARK: - Text Chat (simple)
    struct ChatMessage: Codable {
        let role: String  // "user" | "assistant" | "system"
        let content: String
    }

    func chatResponse(messages: [ChatMessage], model: String = "gpt-4o-mini", temperature: Double = 0.7) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        struct Request: Encodable {
            struct Message: Encodable { let role: String; let content: String }
            let model: String
            let messages: [Message]
            let temperature: Double
        }

        let req = Request(
            model: model,
            messages: messages.map { .init(role: $0.role, content: $0.content) },
            temperature: temperature
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "?"
            throw NSError(domain: "OpenAIClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI chat error: \(body)"])
        }

        struct CompletionResponse: Decodable {
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(CompletionResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}


