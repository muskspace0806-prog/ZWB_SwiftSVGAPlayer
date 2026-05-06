// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Network/ZWB_SVGADownloader.swift

import Foundation

/// 远程下载协议
protocol SVGADownloading {
    func download(from url: URL) async throws -> Data
}

/// 基于 URLSession 的默认下载器
final class URLSessionSVGADownloader: SVGADownloading {
    static let shared = URLSessionSVGADownloader()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func download(from url: URL) async throws -> Data {
        svgaLogDebug("Downloading from \(url.absoluteString)")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SVGAError.downloadFailed("Invalid response")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw SVGAError.downloadFailed("HTTP \(httpResponse.statusCode)")
            }
            svgaLogDebug("Downloaded \(data.count) bytes")
            return data
        } catch let error as SVGAError {
            throw error
        } catch {
            throw SVGAError.downloadFailed(error.localizedDescription)
        }
    }
}
