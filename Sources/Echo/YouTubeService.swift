import Foundation

struct SearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let thumbnailURL: URL?
}

class YouTubeService {
    static let shared = YouTubeService()
    private init() {}

    private let apiKey = "YOUR_API_KEY"

    func search(query: String) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoCategoryId=10&maxResults=25&q=\(encoded)&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item -> SearchResult? in
            guard let videoId = (item["id"] as? [String: Any])?["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { return nil }
            let channel = snippet["channelTitle"] as? String ?? ""
            let thumbStr = ((snippet["thumbnails"] as? [String: Any])?["high"] as? [String: Any])?["url"] as? String
            return SearchResult(id: videoId, title: title, artist: channel, thumbnailURL: thumbStr.flatMap { URL(string: $0) })
        }
    }

    // Piped public instances — tried in order until one works
    private let pipedInstances = [
        "https://pipedapi.kavin.rocks",
        "https://piped-api.garudalinux.org",
        "https://api.piped.projectsegfau.lt",
    ]

    func streamURL(videoId: String) async throws -> URL {
        var lastError: Error = URLError(.cannotFindHost)

        for instance in pipedInstances {
            guard let url = URL(string: "\(instance)/streams/\(videoId)") else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let streams = json["audioStreams"] as? [[String: Any]] else { continue }

                let best = streams
                    .filter { $0["url"] is String }
                    .sorted { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }
                    .first

                if let urlString = best?["url"] as? String, let streamURL = URL(string: urlString) {
                    return streamURL
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
