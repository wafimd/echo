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

    func streamURL(videoId: String) async throws -> URL {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "videoId": videoId,
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.29.1",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone OS",
                    "osVersion": "17.5.1"
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streaming = json["streamingData"] as? [String: Any],
              let formats = streaming["adaptiveFormats"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let audioFormats = formats
            .filter { ($0["mimeType"] as? String ?? "").hasPrefix("audio/") }
            .filter { $0["url"] is String }
            .sorted { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }

        guard let best = audioFormats.first,
              let urlString = best["url"] as? String,
              let streamURL = URL(string: urlString) else {
            throw URLError(.cannotFindHost)
        }
        return streamURL
    }
}
