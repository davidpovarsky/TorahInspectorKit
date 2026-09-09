import TorahInspectorCore

public enum TorahInspectorRoute: Hashable, Sendable {
    case segment(TorahTextSegment)
    case source(TorahInspectorSelection)
}

/// Controls the initial view shown by ``TorahInspectorView``.
public enum TorahInspectorEntryMode: Sendable {
    /// Open the scrollable text reader for the whole section (default).
    case sourceReader
    /// Jump directly to the segment-level relationships view.
    /// Requires ``TorahInspectorSelection/preferredSegmentRef`` to be non-nil;
    /// falls back to ``sourceReader`` otherwise.
    case segmentRelationships
}
