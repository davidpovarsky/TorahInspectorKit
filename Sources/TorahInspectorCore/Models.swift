import Foundation

public struct TorahTextRequest: Hashable, Sendable {
    public var language: String
    public var fillInMissingSegments: Bool

    public init(language: String = "hebrew", fillInMissingSegments: Bool = true) {
        self.language = language
        self.fillInMissingSegments = fillInMissingSegments
    }
}

public struct TorahTextVersionMetadata: Hashable, Codable, Sendable {
    public let language: String
    public let actualLanguage: String?
    public let languageFamilyName: String?
    public let versionTitle: String
    public let versionTitleInHebrew: String?
    public let license: String?
    public let direction: String?

    public init(
        language: String,
        actualLanguage: String? = nil,
        languageFamilyName: String? = nil,
        versionTitle: String,
        versionTitleInHebrew: String? = nil,
        license: String? = nil,
        direction: String? = nil
    ) {
        self.language = language
        self.actualLanguage = actualLanguage
        self.languageFamilyName = languageFamilyName
        self.versionTitle = versionTitle
        self.versionTitleInHebrew = versionTitleInHebrew
        self.license = license
        self.direction = direction
    }
}

public struct TorahTextSegment: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let canonicalRef: String
    public let hebrewRef: String?
    public let text: String
    public let ordinal: Int

    public init(canonicalRef: String, hebrewRef: String? = nil, text: String, ordinal: Int) {
        self.id = canonicalRef
        self.canonicalRef = canonicalRef
        self.hebrewRef = hebrewRef
        self.text = text
        self.ordinal = ordinal
    }
}

public struct TorahTextDocument: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(providerID):\(canonicalRef)" }
    public let providerID: String
    public let requestedRef: String
    public let canonicalRef: String
    public let hebrewRef: String?
    public let sectionRef: String
    public let hebrewSectionRef: String?
    public let segments: [TorahTextSegment]
    public let previousSectionRef: String?
    public let nextSectionRef: String?
    public let version: TorahTextVersionMetadata
    public let rawProviderPayload: String

    public init(
        providerID: String,
        requestedRef: String,
        canonicalRef: String,
        hebrewRef: String? = nil,
        sectionRef: String,
        hebrewSectionRef: String? = nil,
        segments: [TorahTextSegment],
        previousSectionRef: String? = nil,
        nextSectionRef: String? = nil,
        version: TorahTextVersionMetadata,
        rawProviderPayload: String = "{}"
    ) {
        self.providerID = providerID
        self.requestedRef = requestedRef
        self.canonicalRef = canonicalRef
        self.hebrewRef = hebrewRef
        self.sectionRef = sectionRef
        self.hebrewSectionRef = hebrewSectionRef
        self.segments = segments
        self.previousSectionRef = previousSectionRef
        self.nextSectionRef = nextSectionRef
        self.version = version
        self.rawProviderPayload = rawProviderPayload
    }
}

public struct TorahLinkedSource: Identifiable, Hashable, Codable, Sendable {
    public var id: String { "\(sourceRef)|\(type)|\(category)" }
    public let sourceRef: String
    public let sourceHebrewRef: String?
    public let category: String
    public let type: String
    public let collectiveTitle: String?
    public let hebrewCollectiveTitle: String?
    public let hebrewText: String?
    public let englishText: String?
    public let versionTitle: String?
    public let hebrewVersionTitle: String?
    public let license: String?
    public let rawProviderPayload: String

    public init(
        sourceRef: String,
        sourceHebrewRef: String? = nil,
        category: String,
        type: String,
        collectiveTitle: String? = nil,
        hebrewCollectiveTitle: String? = nil,
        hebrewText: String? = nil,
        englishText: String? = nil,
        versionTitle: String? = nil,
        hebrewVersionTitle: String? = nil,
        license: String? = nil,
        rawProviderPayload: String = "{}"
    ) {
        self.sourceRef = sourceRef
        self.sourceHebrewRef = sourceHebrewRef
        self.category = category
        self.type = type
        self.collectiveTitle = collectiveTitle
        self.hebrewCollectiveTitle = hebrewCollectiveTitle
        self.hebrewText = hebrewText
        self.englishText = englishText
        self.versionTitle = versionTitle
        self.hebrewVersionTitle = hebrewVersionTitle
        self.license = license
        self.rawProviderPayload = rawProviderPayload
    }
}

public struct TorahLinkedTopic: Identifiable, Hashable, Codable, Sendable {
    public var id: String { slug }
    public let slug: String
    public let titleHe: String?
    public let titleEn: String?
    public let rawProviderPayload: String

    public init(slug: String, titleHe: String? = nil, titleEn: String? = nil, rawProviderPayload: String = "{}") {
        self.slug = slug
        self.titleHe = titleHe
        self.titleEn = titleEn
        self.rawProviderPayload = rawProviderPayload
    }
}

public struct TorahInspectorSelection: Identifiable, Hashable, Sendable {
    public var id: String { "\(providerID):\(canonicalRef):\(preferredSegmentRef ?? "")" }
    public let providerID: String
    public let canonicalRef: String
    public let preferredSegmentRef: String?

    public init(providerID: String, canonicalRef: String, preferredSegmentRef: String? = nil) {
        self.providerID = providerID
        self.canonicalRef = canonicalRef
        self.preferredSegmentRef = preferredSegmentRef
    }

    public func prefers(_ segment: TorahTextSegment) -> Bool {
        preferredSegmentRef == segment.canonicalRef
    }
}

public struct TorahRelationshipGroups: Equatable, Sendable {
    public let commentary: [TorahLinkedSource]
    public let linkedSources: [TorahLinkedSource]

    public init(sources: [TorahLinkedSource]) {
        commentary = sources.filter(Self.isCommentary)
        linkedSources = sources.filter { !Self.isCommentary($0) }
    }

    private static func isCommentary(_ source: TorahLinkedSource) -> Bool {
        source.category.caseInsensitiveCompare("Commentary") == .orderedSame
            || source.type.caseInsensitiveCompare("Commentary") == .orderedSame
    }
}

public enum TorahError: LocalizedError, Equatable {
    case invalidReference
    case referenceTooBroad
    case missingProvider
    case noResults
    case noText
    case malformedResponse
    case storage(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .invalidReference: "The reference is not valid."
        case .referenceTooBroad: "Choose a more specific source."
        case .missingProvider: "No Torah provider is available."
        case .noResults: "No matching result was found."
        case .noText: "No text is available for this source."
        case .malformedResponse: "The provider returned an unexpected response."
        case .storage(let message), .network(let message): message
        }
    }
}
