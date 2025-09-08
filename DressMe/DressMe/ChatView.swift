//
//  ChatView.swift
//  DressMe
//
//  Created by Assistant on 08/09/25.
//

import SwiftUI

/// Minimal chat screen that lets the user send/receive short messages
/// from the OpenAI model. This is not production-ready; it's a demo.

struct ChatView: View {
    let openAIClient: OpenAIClient?
    var onClose: (() -> Void)? = nil

    /// Conversation history. Starts with a short English system prompt for tone/style.
    @State private var messages: [OpenAIClient.ChatMessage] = [
        .init(role: "system", content: "You are a friendly fashion assistant. Be concise and practical.")
    ]
    @State private var input: String = ""
    @State private var isSending: Bool = false

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack {
            // Conversation list. Very simple bubble layout.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages.indices, id: \.self) { idx in
                        let msg = messages[idx]
                        if msg.role != "system" {
                            let bubbleColor: Color = (msg.role == "user") ? Color.blue.opacity(0.15) : Color.green.opacity(0.15)
                            HStack {
                                if msg.role == "assistant" { Spacer() }
                                Text(msg.content)
                                    .padding(10)
                                    .background(bubbleColor)
                                    .cornerRadius(10)
                                if msg.role == "user" { Spacer() }
                            }
                        }
                    }
                }
                .padding()
            }

            // Input bar
            HStack {
                TextField("Type a message…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .disabled(isSending)
                Button(action: send) {
                    if isSending { ProgressView() } else { Text("Send") }
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || openAIClient == nil || isSending)
            }
            .padding()
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { onClose?() }
            }
        }
        .onAppear { inputFocused = true }
    }

    private func send() {
        guard let openAI = openAIClient else { return }
        let userText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        input = ""
        isSending = true

        Task {
            var convo = messages
            convo.append(.init(role: "user", content: userText))
            do {
                let reply = try await openAI.chatResponse(messages: convo)
                await MainActor.run {
                    messages = convo + [.init(role: "assistant", content: reply)]
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages = convo + [.init(role: "assistant", content: "Error: \(error.localizedDescription)")]
                    isSending = false
                }
            }
        }
    }
}


