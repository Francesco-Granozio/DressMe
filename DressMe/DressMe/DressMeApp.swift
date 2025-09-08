//
//  DressMeApp.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import SwiftUI
import AVFoundation

@main
struct DressMeApp: App {
    init() {
        // Configure audio session for TTS playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        // Keep screen awake during demo recording
        UIApplication.shared.isIdleTimerDisabled = true
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack { ContentView() }
        }
    }
}
