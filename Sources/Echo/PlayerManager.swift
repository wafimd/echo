import AVFoundation
import MediaPlayer
import Combine

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()

    private var player: AVPlayer?

    @Published var currentTrack: SearchResult?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ result: SearchResult) {
        currentTrack = result
        isLoading = true
        isPlaying = false
        errorMessage = nil
        player?.pause()
        player = nil

        Task {
            do {
                let url = try await YouTubeService.shared.streamURL(videoId: result.id)
                let item = AVPlayerItem(url: url)
                self.player = AVPlayer(playerItem: item)
                self.player?.play()
                self.isPlaying = true
                self.isLoading = false
                self.updateNowPlaying(result)
            } catch {
                self.errorMessage = "Could not load stream."
                self.isLoading = false
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func updateNowPlaying(_ result: SearchResult) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: result.title,
            MPMediaItemPropertyArtist: result.artist,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
    }
}
