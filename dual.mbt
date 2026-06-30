/// Valence — the **Dual**: the component contract.
///
/// A Dual is one piece of state rendered twice, from the one source: **pixels** for
/// a human (a Luna `DomNode`) and a **narrative node** for an instance (a
/// `NarrativeNode`, not a flat string). That second half is the whole reason Valence
/// exists — and making it a *node* instead of a `String` is what lets components
/// compose into a Surface (the room) instead of each hand-gluing its own sentence.
///
/// ── The bundle (what a Dual *is*, conceptually) ──
/// A Dual is the read-surface of a four-facet bundle around one slice of state:
///   • **state**   — the one source, a signal the Dual closes over (`state.mbt`'s
///                   typed state where it carries its own meaning).
///   • **controls** — write state: the human's hands live in the `DomNode`'s event
///                   handlers; an instance `set`s the same signal. "One signal, two
///                   hands." (No third tuple slot — the write lives in the pixels.)
///   • **render**  — read state, twice: the `DomNode` (pixels) and the
///                   `() -> NarrativeNode` (text). Both derive from the one state, so
///                   a change from either hand moves both. The node's *text* comes
///                   from the state's own narrative; its *salience* from the state's
///                   own significance (see `narrative_state.mbt`) — one producer, no
///                   parallel string to drift.
///   • **events**  — state's change-log: wired alongside by the Surface via
///                   `track_control` / the `*_event` diffs (`events.mbt`), draining to
///                   a sink. Not a return value — a side-channel, like a log.
///
/// So the *returned* Dual is the two reads (pixels + narrative). State and controls
/// live in the closed-over signal; events are wired beside it. The 2-tuple is the
/// component's two faces, not the whole bundle — operate (me→you invoke) is still a
/// host wire (the open fork), not part of the contract yet.
///
/// ── Dual vs Surface ──
/// A **Dual** is the unit; a **Surface** is many Duals composed (arranged by salience
/// into the room/page — itself dual: a DOM tree + a NarrativeNode tree). You read one
/// Dual with `dual_read`; you read a Surface by composing its nodes and rendering the
/// whole tree (`render_narrative`).
pub typealias (DomNode, () -> NarrativeNode) as Dual

///|
/// Read one Dual as text — the lone-component read (the `window._narrative()` of a
/// single Dual): render its narrative node. A lone node renders flush (drift is a
/// Surface's sibling-relative grammar, not a single line's — see `render_narrative`),
/// so this returns just the component's own sentence. Inside a Surface, don't call
/// this per-component — compose the nodes and render the Surface once.
pub fn dual_read(d : Dual) -> String {
  let (_visual, narrative) = d
  render_narrative(narrative())
}
