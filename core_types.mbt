/// Valence — core shared types + package imports.
///
/// This file used to be `patterns.mbt`, holding "Patterns 1–4" — the *pre-Valence*
/// word for components (status_bar / instance_panel / event_stream / nav_bar). Those
/// four were dead code (no consumers), and "pattern" is no longer a Valence concept:
/// a component is a **Dual** (`dual.mbt`), components live in their own files, and
/// recurring *compositions* would be Surfaces. So the patterns are retired. What
/// stays here is genuinely shared and load-bearing: the package's `using` imports
/// (package-scoped — the rest of the package leans on them), the one `Event` type
/// every projection emits, and the seed of the operate protocol.
///
/// ("pattern" the word goes in the back pocket — it likely returns later for a named,
/// recurring *composed* shape, a level above Dual. Not now.)

using @element { div, span, text, text_dyn, type DomNode, events }

using @resource { signal, memo, effect, type Signal }

///|
/// The one event record — the 8-field Helios Event schema. Every projection emits this
/// (events.mbt's state/control diffs; the collectors; the viewer reads it), so a
/// state-change event is indistinguishable from a git / recap / channel event in the
/// one stream and flows straight into whatever renders the stream. `pub(all)` so
/// surfaces and apps construct it freely.
pub(all) struct Event {
  timestamp : String
  actor : String
  kind : String //      event type: "state", "control", "commit", "heartbeat", …
  action : String
  target : String
  source : String
  message : String //   summary — the thin index entry (one line; often a narrative)
  data : String //      kind-specific payload (optional, empty = none)
  link : String //      pointer to full content: file path, line, message ID.
  //                     the event indexes; the content lives where it lives.
  //                     empty = the message IS the full content (backward-compatible).
}

///|
/// The operate-protocol seed — the future **Bond** (the write/invoke channel). The
/// retired patterns carried a full interaction protocol: `available()` / `can_do()` /
/// `on_action()` returning a result like this. The pattern-specific specifics went
/// with them; this is kept as the shape the operate channel takes when an instance can
/// *invoke* a Dual (move a control, fire an action), not just read it. That's still
/// the open fork — a Dual is fully *readable*, not yet instance-*writable*. Here so
/// the design isn't lost when we build the Bond.
pub(all) struct ActionResult {
  success : Bool
  message : String
}
