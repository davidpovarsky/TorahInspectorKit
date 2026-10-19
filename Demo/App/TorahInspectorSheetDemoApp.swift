import SwiftUI
import TorahInspectorCore
import TorahInspectorUI

@main
struct TorahInspectorSheetDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TorahInspectorSheetDemoView()
                .environment(\.locale, Locale(identifier: "he_IL"))
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

@MainActor
struct TorahInspectorSheetDemoView: View {
    @State private var selection: TorahInspectorSelection?
    @State private var selectedTool: TorahStudyTool = .commentaries
    @State private var selectedDetent: TorahInspectorSheetDetent
    @State private var status = "מוכן לקריאה"

    private let repository = TorahInspectorRepository(
        textFetcher: { _, _ in TorahInspectorSheetDemoFixture.document },
        linksFetcher: { _, _ in TorahInspectorSheetDemoFixture.links },
        topicsFetcher: { _, _ in TorahInspectorSheetDemoFixture.topics },
        notesFetcher: { _ in TorahInspectorSheetDemoFixture.notes }
    )

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let detent: TorahInspectorSheetDetent
        if let index = arguments.firstIndex(of: "--detent"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "peek": detent = .peek
            case "large": detent = .large
            default: detent = .medium
            }
        } else {
            detent = .medium
        }
        _selectedDetent = State(initialValue: detent)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("מסמך חידושים")
                    .font(.largeTitle.bold())
                Text("בראשית ברא אלהים את השמים ואת הארץ")
                    .font(.title3)
                    .textSelection(.enabled)
                Divider()
                Text("ה־Side Sheet משתמש ב־TorahInspectorView האמיתי ושומר את המסמך גלוי מאחוריו.")
                    .foregroundStyle(.secondary)
                Button("תורה / מקורות") {
                    selection = TorahInspectorSheetDemoFixture.selection
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("open-torah-inspector")
                Spacer()
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("host-action-status")
            }
            .padding(24)
            .navigationTitle("Pinkha")
        }
        .torahInspectorSheet(
            selection: $selection,
            repository: repository,
            selectedTool: $selectedTool,
            selectedDetent: $selectedDetent,
            actions: hostActions
        )
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            selection = TorahInspectorSheetDemoFixture.selection
        }
    }

    private var hostActions: TorahInspectorHostActions {
        TorahInspectorHostActions(
            onClose: { status = "ה־Inspector נסגר" },
            onInsertSegment: { transfer in status = "נוסף: \(transfer.hebrewRef ?? transfer.canonicalRef)" },
            onOpenInNewTab: { nextSelection in selection = nextSelection },
            onAddNote: { _, notesDidChange in
                status = "נוצרה הערה"
                notesDidChange()
            },
            onOpenNote: { note, _, _ in status = "נפתחה הערה: \(note.note)" },
            onDeleteNote: { _, _, notesDidChange in
                status = "הקישור להערה הוסר"
                notesDidChange()
            }
        )
    }
}

enum TorahInspectorSheetDemoFixture {
    static let selection = TorahInspectorSelection(
        providerID: "sefaria",
        canonicalRef: "Genesis 1",
        preferredSegmentRef: "Genesis 1:1",
        scope: .segment
    )

    static let document = TorahTextDocument(
        providerID: "sefaria",
        requestedRef: "Genesis 1:1",
        canonicalRef: "Genesis 1:1",
        hebrewRef: "בראשית א׳:א׳",
        sectionRef: "Genesis 1",
        hebrewSectionRef: "בראשית א׳",
        segments: [
            TorahTextSegment(
                canonicalRef: "Genesis 1:1",
                hebrewRef: "בראשית א׳:א׳",
                text: "בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ׃",
                ordinal: 1
            ),
            TorahTextSegment(
                canonicalRef: "Genesis 1:2",
                hebrewRef: "בראשית א׳:ב׳",
                text: "וְהָאָרֶץ הָיְתָה תֹהוּ וָבֹהוּ וְחֹשֶׁךְ עַל־פְּנֵי תְהוֹם׃",
                ordinal: 2
            ),
        ],
        nextSectionRef: "Genesis 2",
        version: TorahTextVersionMetadata(
            language: "he",
            actualLanguage: "he",
            versionTitle: "מקרא על פי המסורה",
            license: "Public Domain",
            direction: "rtl"
        ),
        rawProviderPayload: "{\"source\":\"sefaria-demo\"}"
    )

    static let links = [
        TorahLinkedSource(
            sourceRef: "Rashi on Genesis 1:1:1",
            sourceHebrewRef: "רש״י על בראשית א׳:א׳",
            category: "Commentary",
            type: "commentary",
            commentatorID: "rashi",
            commentatorName: "Rashi",
            hebrewCommentatorName: "רש״י",
            workTitle: "Rashi on Genesis",
            hebrewWorkTitle: "רש״י על בראשית",
            hebrewText: "אמר רבי יצחק: לא היה צריך להתחיל את התורה אלא מהחודש הזה לכם.",
            englishText: "Rabbi Isaac said: The Torah should have begun with this month shall be unto you.",
            canonicalBookID: "Rashi on Genesis",
            anchorRefs: ["Genesis 1:1"],
            relationshipKind: .commentary,
            semanticCategory: .commentary
        ),
        TorahLinkedSource(
            sourceRef: "Isaiah 40:26",
            sourceHebrewRef: "ישעיהו מ׳:כ״ו",
            category: "Tanakh",
            type: "quotation",
            hebrewText: "שְׂאוּ מָרוֹם עֵינֵיכֶם וּרְאוּ מִי־בָרָא אֵלֶּה",
            canonicalBookID: "Isaiah",
            anchorRefs: ["Genesis 1:1"],
            relationshipKind: .link,
            semanticCategory: .tanakh
        ),
    ]

    static let topics = [
        TorahLinkedTopic(slug: "creation", titleHe: "בריאת העולם", titleEn: "Creation")
    ]

    static let notes = [
        TorahInspectorNote(
            id: "demo-note",
            selectedText: "בראשית ברא",
            note: "פתיחת התורה בבריאת העולם",
            tag: "חידוש"
        )
    ]
}
