//
//  AudioPlayerService.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import AVFoundation

final class AudioPlayerService: NSObject, ObservableObject {
    private var player: AVAudioPlayer?

    func play(data: Data) throws {
        player = try AVAudioPlayer(data: data)
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}


