import Foundation
import AVFoundation

class AudioPlayerManager: ObservableObject {
    private var player: AVAudioPlayer?
    
    func play(filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "m4a") else { return }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
    }
}
