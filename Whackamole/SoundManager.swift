//
//  Sound Manager.swift
//  Whackamole
//
//  Created by Diego Martinez on 9/25/24.
//

import Foundation
import AVFoundation
extension WhacAMoleGame {
    
    func playBackgroundMusic() {
         guard let url = Bundle.main.url(forResource: "halloween-soundtrack", withExtension: "mp3") else {
             print("Background music file not found")
             return
         }

         do {
             print("playing")
             audioPlayer = try AVAudioPlayer(contentsOf: url)
             audioPlayer?.numberOfLoops = -1 // Loop indefinitely
             audioPlayer?.volume = 0.05 // Set the volume
             audioPlayer?.play() // Start playback
         } catch {
             print("Error loading audio player: \(error)")
         }
     }
    func playHitSound() {
        guard let url = Bundle.main.url(forResource: "ghostly3", withExtension: "wav") else {
            print("Hit sound file not found")
            return
        }

        do {
            hitSoundPlayer = try AVAudioPlayer(contentsOf: url)
            hitSoundPlayer?.volume = 1.0 // Full volume
            hitSoundPlayer?.play()
        } catch {
            print("Error loading hit sound player: \(error)")
        }
    }
     // Call this to stop the music when the game ends
     func stopBackgroundMusic() {
         audioPlayer?.stop()
     }
    
    
    
}
