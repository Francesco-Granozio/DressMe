//
//  ContentView.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraManager.shared
    @StateObject private var speech = SpeechService()
    @StateObject private var audioPlayer = AudioPlayerService()
    @State private var openAIClient: OpenAIClient? = nil
    @State private var lastAdvice: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var lastFrame: CGImage? = nil
    @State private var isChatPresented: Bool = false

    /// Main screen: shows camera preview, advice banner, and action buttons.
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Advice banner from the last analysis
                if !lastAdvice.isEmpty {
                    Text(lastAdvice)
                        .font(.headline)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    // Analyze current frame with Vision
                    Button(action: startScan) {
                        HStack {
                            if isAnalyzing { ProgressView().tint(.white) }
                            Text(isAnalyzing ? "Analyzing…" : "Scan garment")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)

                    // Stop speaking
                    Button(action: speech.stop) {
                        Image(systemName: "speaker.slash.fill")
                            .padding(12)
                    }
                    .background(Color.black.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(Circle())

                    // Open chat sheet
                    Button(action: { isChatPresented = true }) {
                        Image(systemName: "ellipsis.bubble")
                            .padding(12)
                    }
                    .background(Color.black.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            // Capture most recent frame for on-demand analysis
            camera.onFrame = { cg in
                lastFrame = cg
            }
            camera.startSession()
            if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty {
                openAIClient = OpenAIClient(apiKey: apiKey)
            }
        }
        .onDisappear { camera.stopSession() }
        .sheet(isPresented: $isChatPresented) {
            NavigationStack {
                ChatView(openAIClient: openAIClient, onClose: { isChatPresented = false })
            }
        }
    }

    private func startScan() {
        guard !isAnalyzing else { return }
        guard let openAI = openAIClient else {
            lastAdvice = "Set the OPENAI_API_KEY environment variable and relaunch."
            return
        }
        guard let cg = lastFrame else {
            lastAdvice = "No camera frame available. Grant camera permission and try again."
            return
        }
        isAnalyzing = true
        Task {
            let uiImage = UIImage(cgImage: cg)
            do {
                let advice = try await openAI.analyzeClothing(image: uiImage)
                await MainActor.run {
                    lastAdvice = advice
                    isAnalyzing = false
                }
                // Prefer natural OpenAI TTS when available, else fallback to system voice
                do {
                    let audioData = try await openAI.synthesizeEnglishVoice(text: advice)
                    try await MainActor.run { try? audioPlayer.play(data: audioData) }
                } catch {
                    await MainActor.run { speech.speakEnglish(advice) }
                }
            } catch {
                await MainActor.run {
                    lastAdvice = "Analysis error: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
