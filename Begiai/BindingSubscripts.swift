// Labeled subscripts that a view binds through, as $value[label: condition], in place of a
// Binding(get:set:) made at each body.

extension Optional {
    /// This value while `shown`, else nil; a write while it shows passes through. A sheet bound
    /// this way presents the value only where it should show it.
    subscript(shownIf shown: Bool) -> Wrapped? {
        get { shown ? self : nil }
        set { if shown { self = newValue } }
    }
}

extension Bool {
    /// True while `allowed` and this flag, which says a thing was seen, is false: what is still
    /// to show. Setting it to false marks the thing seen.
    subscript(toShowIf allowed: Bool) -> Bool {
        get { allowed && !self }
        set { if !newValue { self = true } }
    }
}
