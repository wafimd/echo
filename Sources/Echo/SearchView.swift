import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List(results) { result in
                    ResultRow(result: result)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .onTapGesture { player.play(result) }
                }
                .listStyle(.plain)
                .background(Color.black)

                if player.currentTrack != nil {
                    VStack(spacing: 0) {
                        if let err = player.errorMessage {
                            Text(err)
                                .foregroundStyle(.white)
                                .font(.caption)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.8))
                        }
                        MiniPlayer()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Echo")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .searchable(text: $query, prompt: "Artists, songs")
        .onSubmit(of: .search) { Task { await performSearch() } }
        .overlay {
            if isSearching {
                ProgressView().tint(.white)
            }
        }
    }

    private func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        results = (try? await YouTubeService.shared.search(query: query)) ?? []
        isSearching = false
    }
}

struct ResultRow: View {
    let result: SearchResult
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4).foregroundStyle(.white.opacity(0.08))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .foregroundStyle(player.currentTrack == result ? Color(red: 0.98, green: 0.3, blue: 0.3) : .white)
                    .lineLimit(1)
                    .font(.system(size: 15, weight: .medium))
                Text(result.artist)
                    .foregroundStyle(.gray)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            Spacer()

            if player.currentTrack == result && player.isLoading {
                ProgressView().tint(.gray).scaleEffect(0.8)
            } else if player.currentTrack == result && player.isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(Color(red: 0.98, green: 0.3, blue: 0.3))
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 2)
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: player.currentTrack?.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4).foregroundStyle(.white.opacity(0.1))
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrack?.title ?? "")
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .font(.system(size: 14, weight: .medium))
                Text(player.currentTrack?.artist ?? "")
                    .foregroundStyle(.gray)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isLoading ? "ellipsis" : (player.isPlaying ? "pause.fill" : "play.fill"))
                    .foregroundStyle(.white)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.4), radius: 12)
    }
}
