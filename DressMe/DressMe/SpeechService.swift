//
//  SpeechService.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import AVFoundation

/// Simple wrapper around AVSpeechSynthesizer for on-device fallback speech.
/// This does not require network connectivity and uses the system's TTS voices.
final class SpeechService: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    /// Speaks a short English sentence using the default en-US voice.
    /// Used as a fallback when remote TTS is not available.
    func speakEnglish(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    /// Stops playback immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}


