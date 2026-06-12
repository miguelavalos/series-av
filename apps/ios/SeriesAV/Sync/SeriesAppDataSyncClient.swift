import Foundation

struct SeriesAppDataSyncClient: Sendable {
    typealias Request = @Sendable (_ path: String, _ method: String, _ body: Data?, _ headers: [String: String]) async throws -> (Data, String?)

    private let deviceId: String
    private let request: Request
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(deviceId: String, request: @escaping Request) {
        self.deviceId = deviceId
        self.request = request

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func pullLibrary() async throws -> SeriesLibraryDocument {
        let (data, etag) = try await request("/v1/apps/seriesav/data/seriesLibrary", "GET", nil, [:])
        var document = try decoder.decode(SeriesLibraryDocument.self, from: data)
        if document.etag == nil {
            document.etag = etag
        }
        return document
    }

    func pushLibrary(entries: [SeriesLibraryEntry], expectedETag: String?) async throws -> SeriesLibraryDocument {
        let envelope = SeriesLibraryEnvelope(
            appId: "seriesav",
            resource: "seriesLibrary",
            deviceId: deviceId,
            sentAt: Date(),
            entries: entries
        )
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let expectedETag {
            headers["If-Match"] = expectedETag
        }
        let body = try encoder.encode(envelope)
        let (data, etag) = try await request("/v1/apps/seriesav/data/seriesLibrary", "PUT", body, headers)
        var document = try decoder.decode(SeriesLibraryDocument.self, from: data)
        if document.etag == nil {
            document.etag = etag
        }
        return document
    }
}
