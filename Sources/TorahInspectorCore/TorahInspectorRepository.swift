import Foundation

@MainActor
public final class TorahInspectorRepository {
    public typealias TextFetcher = @Sendable (String, String?) async throws -> TorahTextDocument
    public typealias LinksFetcher = @Sendable (String, String?) async throws -> [TorahLinkedSource]
    public typealias TopicsFetcher = @Sendable (String, String?) async throws -> [TorahLinkedTopic]

    private let textFetcher: TextFetcher
    private let linksFetcher: LinksFetcher
    private let topicsFetcher: TopicsFetcher
    public let documentCapacity: Int
    public let relationshipCapacity: Int

    private var documentCache: [String: TorahTextDocument] = [:]
    private var documentLRU: [String] = []
    private var canonicalAliases: [String: Set<String>] = [:]
    private var inFlightDocuments: [String: Task<TorahTextDocument, Error>] = [:]
    private var linksCache: [String: [TorahLinkedSource]] = [:]
    private var linksLRU: [String] = []
    private var inFlightLinks: [String: Task<[TorahLinkedSource], Error>] = [:]
    private var topicsCache: [String: [TorahLinkedTopic]] = [:]
    private var topicsLRU: [String] = []
    private var inFlightTopics: [String: Task<[TorahLinkedTopic], Error>] = [:]

    public init(
        documentCapacity: Int = 30,
        relationshipCapacity: Int = 50,
        textFetcher: @escaping TextFetcher,
        linksFetcher: @escaping LinksFetcher = { _, _ in [] },
        topicsFetcher: @escaping TopicsFetcher = { _, _ in [] }
    ) {
        self.textFetcher = textFetcher
        self.linksFetcher = linksFetcher
        self.topicsFetcher = topicsFetcher
        self.documentCapacity = max(0, documentCapacity)
        self.relationshipCapacity = max(0, relationshipCapacity)
    }

    public convenience init(
        provider: any TorahInspectorProvider,
        documentCapacity: Int = 30,
        relationshipCapacity: Int = 50
    ) {
        let providerID = provider.providerID
        self.init(
            documentCapacity: documentCapacity,
            relationshipCapacity: relationshipCapacity,
            textFetcher: { reference, requestedProviderID in
                guard requestedProviderID == nil || requestedProviderID == providerID else {
                    throw TorahError.missingProvider
                }
                return try await provider.fetchText(reference: reference, request: TorahTextRequest())
            },
            linksFetcher: { reference, requestedProviderID in
                guard requestedProviderID == nil || requestedProviderID == providerID else {
                    throw TorahError.missingProvider
                }
                return try await provider.links(for: reference)
            },
            topicsFetcher: { reference, requestedProviderID in
                guard requestedProviderID == nil || requestedProviderID == providerID else {
                    throw TorahError.missingProvider
                }
                return try await provider.topics(for: reference)
            }
        )
    }

    private func normalizedKey(providerID: String?, reference: String) -> String {
        "\(providerID ?? ""):\(reference)"
    }

    public func cachedDocument(for reference: String, providerID: String? = nil) -> TorahTextDocument? {
        let key = normalizedKey(providerID: providerID, reference: reference)
        guard let document = documentCache[key] else { return nil }
        touchDocument(canonicalKey: normalizedKey(providerID: document.providerID, reference: document.canonicalRef))
        return document
    }

    public func document(for reference: String, providerID: String? = nil) async throws -> TorahTextDocument {
        if let cached = cachedDocument(for: reference, providerID: providerID) { return cached }
        let key = normalizedKey(providerID: providerID, reference: reference)
        if let inFlight = inFlightDocuments[key] { return try await inFlight.value }

        let fetcher = textFetcher
        let task = Task<TorahTextDocument, Error> { try await fetcher(reference, providerID) }
        inFlightDocuments[key] = task
        do {
            let document = try await task.value
            inFlightDocuments.removeValue(forKey: key)
            storeDocument(document, requestedRef: reference, providerID: providerID)
            return document
        } catch {
            inFlightDocuments.removeValue(forKey: key)
            throw error
        }
    }

    private func storeDocument(_ document: TorahTextDocument, requestedRef: String, providerID: String?) {
        let effectiveProviderID = providerID ?? document.providerID
        let canonicalKey = normalizedKey(providerID: effectiveProviderID, reference: document.canonicalRef)
        var aliases: Set<String> = [
            canonicalKey,
            normalizedKey(providerID: effectiveProviderID, reference: requestedRef),
            normalizedKey(providerID: effectiveProviderID, reference: document.sectionRef),
            normalizedKey(providerID: effectiveProviderID, reference: document.requestedRef)
        ]
        if let existing = canonicalAliases[canonicalKey] { aliases.formUnion(existing) }
        canonicalAliases[canonicalKey] = aliases
        for alias in aliases { documentCache[alias] = document }
        touchDocument(canonicalKey: canonicalKey)
        while documentLRU.count > documentCapacity {
            let oldest = documentLRU.removeFirst()
            for alias in canonicalAliases.removeValue(forKey: oldest) ?? [] {
                documentCache.removeValue(forKey: alias)
            }
        }
    }

    private func touchDocument(canonicalKey: String) {
        documentLRU.removeAll { $0 == canonicalKey }
        documentLRU.append(canonicalKey)
    }

    public func cachedLinks(for reference: String, providerID: String? = nil) -> [TorahLinkedSource]? {
        linksCache[normalizedKey(providerID: providerID, reference: reference)]
    }

    public func links(for reference: String, providerID: String? = nil) async throws -> [TorahLinkedSource] {
        let key = normalizedKey(providerID: providerID, reference: reference)
        if let cached = linksCache[key] { Self.touchRelationship(key, lru: &linksLRU); return cached }
        if let inFlight = inFlightLinks[key] { return try await inFlight.value }
        let fetcher = linksFetcher
        let task = Task<[TorahLinkedSource], Error> { try await fetcher(reference, providerID) }
        inFlightLinks[key] = task
        do {
            let values = try await task.value
            inFlightLinks.removeValue(forKey: key)
            linksCache[key] = values
            Self.touchRelationship(key, lru: &linksLRU)
            Self.evictRelationships(cache: &linksCache, lru: &linksLRU, capacity: relationshipCapacity)
            return values
        } catch {
            inFlightLinks.removeValue(forKey: key)
            throw error
        }
    }

    public func cachedTopics(for reference: String, providerID: String? = nil) -> [TorahLinkedTopic]? {
        topicsCache[normalizedKey(providerID: providerID, reference: reference)]
    }

    public func topics(for reference: String, providerID: String? = nil) async throws -> [TorahLinkedTopic] {
        let key = normalizedKey(providerID: providerID, reference: reference)
        if let cached = topicsCache[key] { Self.touchRelationship(key, lru: &topicsLRU); return cached }
        if let inFlight = inFlightTopics[key] { return try await inFlight.value }
        let fetcher = topicsFetcher
        let task = Task<[TorahLinkedTopic], Error> { try await fetcher(reference, providerID) }
        inFlightTopics[key] = task
        do {
            let values = try await task.value
            inFlightTopics.removeValue(forKey: key)
            topicsCache[key] = values
            Self.touchRelationship(key, lru: &topicsLRU)
            Self.evictRelationships(cache: &topicsCache, lru: &topicsLRU, capacity: relationshipCapacity)
            return values
        } catch {
            inFlightTopics.removeValue(forKey: key)
            throw error
        }
    }

    private static func touchRelationship(_ key: String, lru: inout [String]) {
        lru.removeAll { $0 == key }
        lru.append(key)
    }

    private static func evictRelationships<Value>(cache: inout [String: Value], lru: inout [String], capacity: Int) {
        while lru.count > capacity {
            cache.removeValue(forKey: lru.removeFirst())
        }
    }
}
