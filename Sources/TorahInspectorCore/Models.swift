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

public enum TorahRelationshipKind: String, Hashable, Codable, Sendable {
    case commentary
    case link
}

public enum TorahSourceCategory: String, Hashable, Codable, CaseIterable, Sendable {
    case commentary
    case quotingCommentary
    case tanakh
    case talmud
    case midrash
    case targum
    case halakhah
    case other
}

public struct TorahLinkedSource: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        let anchors = anchorRefs.joined(separator: ",")
        return "\(canonicalBookID)|\(sourceRef)|\(type)|\(category)|\(versionTitle ?? "")|\(anchors)"
    }
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
    public let canonicalBookID: String
    public let anchorRefs: [String]
    public let relationshipKind: TorahRelationshipKind
    public let semanticCategory: TorahSourceCategory
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
        canonicalBookID: String? = nil,
        anchorRefs: [String] = [],
        relationshipKind: TorahRelationshipKind? = nil,
        semanticCategory: TorahSourceCategory? = nil,
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
        self.canonicalBookID = canonicalBookID
            ?? Self.fallbackBookIdentity(sourceRef: sourceRef, collectiveTitle: collectiveTitle)
        self.anchorRefs = anchorRefs
        self.relationshipKind = relationshipKind
            ?? Self.inferRelationshipKind(category: category, type: type)
        self.semanticCategory = semanticCategory
            ?? Self.inferSemanticCategory(category: category, type: type)
        self.rawProviderPayload = rawProviderPayload
    }

    private static func fallbackBookIdentity(sourceRef: String, collectiveTitle: String?) -> String {
        if let collectiveTitle, !collectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "title:\(collectiveTitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
        }
        let bookTokens = sourceRef.split(separator: " ").prefix { token in
            !token.unicodeScalars.contains(where: CharacterSet.decimalDigits.contains)
        }
        let book = bookTokens.isEmpty ? sourceRef : bookTokens.joined(separator: " ")
        return "ref:\(book.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
    }

    private static func inferRelationshipKind(category: String, type: String) -> TorahRelationshipKind {
        let tokens = "\(category) \(type)".lowercased()
        return tokens.contains("commentary") ? .commentary : .link
    }

    private static func inferSemanticCategory(category: String, type: String) -> TorahSourceCategory {
        let tokens = "\(category) \(type)".lowercased()
        if tokens.contains("quoting commentary") { return .quotingCommentary }
        if tokens.contains("commentary") { return .commentary }
        if tokens.contains("tanakh") { return .tanakh }
        if tokens.contains("talmud") { return .talmud }
        if tokens.contains("midrash") { return .midrash }
        if tokens.contains("targum") { return .targum }
        if tokens.contains("halakh") { return .halakhah }
        return .other
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

public enum TorahInspectorSelectionScope: String, Hashable, Codable, Sendable {
    case section
    case segment
}

public struct TorahInspectorSelection: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(providerID):\(scope.rawValue):\(canonicalRef):\(preferredSegmentRef ?? "")"
    }
    public let providerID: String
    /// The document/section reference used to establish reading context.
    public let canonicalRef: String
    /// An exact segment reference. It is never synthesized for section scope.
    public let preferredSegmentRef: String?
    public let scope: TorahInspectorSelectionScope

    public init(
        providerID: String,
        canonicalRef: String,
        preferredSegmentRef: String? = nil,
        scope: TorahInspectorSelectionScope? = nil
    ) {
        self.providerID = providerID
        self.canonicalRef = canonicalRef
        self.preferredSegmentRef = preferredSegmentRef
        self.scope = scope ?? (preferredSegmentRef == nil ? .section : .segment)
    }

    public var relationshipRef: String { preferredSegmentRef ?? canonicalRef }

    public func prefers(_ segment: TorahTextSegment) -> Bool {
        preferredSegmentRef == segment.canonicalRef
    }
}

public struct TorahInspectorFocus: Identifiable, Hashable, Sendable {
    public var id: String { selection.id }
    public let selection: TorahInspectorSelection
    public let displayRef: String
    public let hebrewDisplayRef: String?
    public let text: String?

    public init(
        selection: TorahInspectorSelection,
        displayRef: String,
        hebrewDisplayRef: String? = nil,
        text: String? = nil
    ) {
        self.selection = selection
        self.displayRef = displayRef
        self.hebrewDisplayRef = hebrewDisplayRef
        self.text = text
    }

    public init(segment: TorahTextSegment, providerID: String, sectionRef: String? = nil) {
        selection = TorahInspectorSelection(
            providerID: providerID,
            canonicalRef: sectionRef ?? segment.canonicalRef,
            preferredSegmentRef: segment.canonicalRef,
            scope: .segment
        )
        displayRef = segment.canonicalRef
        hebrewDisplayRef = segment.hebrewRef
        text = segment.text
    }
}

public struct TorahInspectorNote: Identifiable, Hashable, Sendable {
    public let id: String
    public let selectedText: String
    public let note: String
    public let tag: String?

    public init(id: String, selectedText: String, note: String, tag: String? = nil) {
        self.id = id
        self.selectedText = selectedText
        self.note = note
        self.tag = tag
    }
}

public struct TorahSourceGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let hebrewTitle: String?
    public let category: TorahSourceCategory
    public let entries: [TorahLinkedSource]

    public var count: Int { entries.count }

    public init(
        id: String,
        title: String,
        hebrewTitle: String? = nil,
        category: TorahSourceCategory,
        entries: [TorahLinkedSource]
    ) {
        self.id = id
        self.title = title
        self.hebrewTitle = hebrewTitle
        self.category = category
        self.entries = entries
    }
}

public struct TorahRelationshipGroups: Equatable, Sendable {
    public let commentary: [TorahLinkedSource]
    public let linkedSources: [TorahLinkedSource]
    public let commentaryGroups: [TorahSourceGroup]
    public let linkedSourceGroups: [TorahSourceGroup]

    public init(sources: [TorahLinkedSource]) {
        var seen = Set<TorahLinkedSource.ID>()
        let uniqueSources = sources.filter { seen.insert($0.id).inserted }
        commentary = uniqueSources.filter { $0.relationshipKind == .commentary }
        linkedSources = uniqueSources.filter { $0.relationshipKind != .commentary }
        commentaryGroups = Self.group(commentary)
        linkedSourceGroups = Self.group(linkedSources)
    }

    private static func group(_ sources: [TorahLinkedSource]) -> [TorahSourceGroup] {
        var order: [String] = []
        var entriesByBook: [String: [TorahLinkedSource]] = [:]
        for source in sources {
            if entriesByBook[source.canonicalBookID] == nil {
                order.append(source.canonicalBookID)
            }
            entriesByBook[source.canonicalBookID, default: []].append(source)
        }
        return order.compactMap { id in
            guard let entries = entriesByBook[id], let first = entries.first else { return nil }
            return TorahSourceGroup(
                id: id,
                title: first.collectiveTitle ?? first.sourceRef,
                hebrewTitle: first.hebrewCollectiveTitle,
                category: first.semanticCategory,
                entries: entries
            )
        }
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
