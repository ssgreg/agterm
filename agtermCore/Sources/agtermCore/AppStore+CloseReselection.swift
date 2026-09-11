import Foundation

extension AppStore {
    /// Picks the next selection after CLOSING the active session at `location`: the most-recently-active
    /// surviving session, else a positional walk.
    /// Recency is asked per level, narrowest first - the closing session's workspace ∩ the VISIBLE set
    /// (`navigableSessions`, so flagged and focus both apply), then that visible set - so a REMEMBERED
    /// local survivor wins, and a workspace that remembers nobody yields only when the visible set holds a
    /// remembered session elsewhere - under a single-workspace narrowing the two levels coincide, so the
    /// walk still takes it. The whole tree is asked only while nothing is visible, because outside the visible set a
    /// pick has no good end in either mode: in `.flagged` it sits off the navigation set with
    /// `disableFocusIfSelectionOutsideSet` returning early, and in `.tree` that same net drops the user's
    /// focus filter to reveal it.
    /// Remembering nobody anywhere falls to the positional walk - in-scope over `walkScope` while a
    /// narrowing applies (`narrowed` keys on the MODE, so it holds however wide `walkScope` ends up), else
    /// `reselectionTarget`. Every set here is built from the TREE, so a session already removed cannot come
    /// back while it survives in `sessionRecency` for undo.
    func closeReselectionTarget(after location: (workspaceIndex: Int, sessionIndex: Int)) -> UUID? {
        let visible = Set(navigableSessions.map(\.id))
        let everything = Set(workspaces.flatMap(\.sessions).map(\.id))
        let inWorkspace = Set(workspaces[location.workspaceIndex].sessions.map(\.id))
        let sameWorkspace = inWorkspace.intersection(visible)
        if let recent = sessionRecency.top(1, in: sameWorkspace).first { return recent }
        if let recent = sessionRecency.top(1, in: visible).first { return recent }
        if visible.isEmpty, let recent = sessionRecency.top(1, in: everything).first { return recent }
        // reachable with recency that names nothing at any level, e.g. the first close after a restore.
        let narrowed = sidebarMode == .flagged || focusEnabled
        let walkScope = sameWorkspace.isEmpty ? (visible.isEmpty ? everything : visible) : sameWorkspace
        if narrowed, let inScope = nearestInScopeTarget(after: location, scope: walkScope) {
            return inScope
        }
        return reselectionTarget(after: location)
    }

    /// `reselectionTarget`'s walk restricted to `scope`, over the tree FLATTENED in sidebar order: the
    /// in-scope session that shifted into the removed slot, else the nearest one before it. It spans
    /// workspaces because the scope can — the flagged sidebar renders one flat cross-workspace list, so the
    /// adjacent row there may live elsewhere; a same-workspace scope collapses it back.
    private func nearestInScopeTarget(after location: (workspaceIndex: Int, sessionIndex: Int),
                                      scope: Set<UUID>) -> UUID? {
        let sessions = workspaces[location.workspaceIndex].sessions
        let before = workspaces[..<location.workspaceIndex].reduce(0) { $0 + $1.sessions.count }
        let removedSlot = before + min(location.sessionIndex, sessions.count)
        let flattened = workspaces.flatMap(\.sessions)
        if let next = flattened[removedSlot...].first(where: { scope.contains($0.id) }) { return next.id }
        return flattened[..<removedSlot].last { scope.contains($0.id) }?.id
    }
}
