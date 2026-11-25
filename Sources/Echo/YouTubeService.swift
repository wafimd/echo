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

    private let baseURL = "https://www.youtube.com/youtubei/v1"
    private var context: [String: Any] {
        ["client": [
            "clientName": "WEB",
            "clientVersion": "2.20231121.08.00",
            "hl": "en",
            "gl": "US"
        ]]
    }

    func search(query: String) async throws -> [SearchResult] {
        guard let url = URL(string: "\(baseURL)/search") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": context,
            "query": query,
            "params": "EgIQAQ=="
        ])

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        let twoCol = (json["contents"] as? [String: Any])?["twoColumnSearchResultsRenderer"] as? [String: Any]
        let primary = twoCol?["primaryContents"] as? [String: Any]
        let sectionList = primary?["sectionListRenderer"] as? [String: Any]
        let contents = sectionList?["contents"] as? [[String: Any]] ?? []

        var results: [SearchResult] = []
        for section in contents {
            let sectionRenderer = section["itemSectionRenderer"] as? [String: Any]
            let items = sectionRenderer?["contents"] as? [[String: Any]] ?? []
            for item in items {
                guard let vr = item["videoRenderer"] as? [String: Any] else { continue }
                guard let videoId = vr["videoId"] as? String else { continue }
                let titleRuns = (vr["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                guard let title = titleRuns?.first?["text"] as? String else { continue }
                let ownerRuns = (vr["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]]
                let artist = ownerRuns?.first?["text"] as? String ?? ""
                let thumbList = (vr["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
                let thumbStr = thumbList?.last?["url"] as? String
                let thumbURL = thumbStr.flatMap { URL(string: $0) }
                results.append(SearchResult(id: videoId, title: title, artist: artist, thumbnailURL: thumbURL))
            }
        }
        return results
    }

    func streamURL(videoId: String) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/player") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("https://www.youtube.com/watch?v=\(videoId)", forHTTPHeaderField: "Referer")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "context": context,
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streaming = json["streamingData"] as? [String: Any],
              let formats = streaming["adaptiveFormats"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        // audio/mp4 (AAC) only — iOS does not support audio/webm (Opus)
        let best = formats
            .filter { ($0["mimeType"] as? String)?.contains("audio/mp4") == true }
            .filter { $0["url"] is String }
            .sorted { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }
            .first

        guard let urlStr = best?["url"] as? String, let streamURL = URL(string: urlStr) else {
            throw URLError(.cannotFindHost)
        }
        return streamURL
    }
}
