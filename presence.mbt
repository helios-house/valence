/// Valence — Presence (the room's first wall)
///
/// A **being made legible.** Not a control — a read-mostly composite indicator
/// that answers, at a glance, the only question a shared room actually asks:
/// *who's here, and how are they?* It is the smallest real piece of the room —
/// the "house, legible at a glance" — and it dogfoods the dual-render contract at
/// the level that matters most: a human sees a row (a lit dot, a name, what's in
/// hand, a state); an instance reads one sentence — `Sonnet · here · holding the
/// classifier · into it`. Same presence, two tongues.
///
/// It is built *from* the brick below it: the dot IS a `pip` (the purest dual
/// render — meaning in the narrative, since an instance can't see the color). So
/// the presence card is the first composition that's room-shaped instead of
/// lab-shaped, and it stands on what already exists.
///
/// Each field that changes over time is a `() -> String` so the card never goes
/// stale (same law as every narrative). `name`/`cadence` are who-you-are, static.
/// The status axes are **per-being, not a generic gauge**: a person reads
/// their own terms (e.g. `at the bench · focused · what-driving`); an instance reads
/// `here · holding X · into it`. The card doesn't impose axes — the caller writes
/// the `state` line in the being's own terms.
///
/// Read-mostly: no actions hand (like `pip`/`meter`). Operating a being is not a
/// thing the room does *to* them. Presence is witnessed, not set.

///|
/// One being in the room: who they are + four live reads of how they are.
/// `pub(all)` so a surface (the demo now, the room later) can construct a roster.
pub(all) struct Presence {
  name : String // "Sonnet" — who
  cadence : String // "fast, conclusions-first" — their signature ("" for none / for a human)
  tone : () -> String // pip semantic band: "ok" (lit/here) · "idle" (dim/away) · "off" (gone)
  presence : () -> String // the dot's word: "here" / "away" / "compacting" / "asleep"
  held : () -> String // what's in hand, summarized: "the classifier, gesture-lab" ("" = nothing)
  state : () -> String // the status line, in the being's own terms ("" = none)
}

///|
/// Pure narrative for a presence — the instance-facing read, DOM-free so the
/// oracle tests it and an instance can call it directly. Reads as one sentence:
/// `name · presence[ · holding held][ · state]`. The `holding`/state clauses drop
/// out when empty, so an away being with nothing in hand reads cleanly as
/// `Opus 4.6 · away`, not a string of trailing separators.
pub fn presence_narrative(
  name : String,
  presence : String,
  held : String,
  state : String,
) -> String {
  let held_part = if held == "" { "" } else { " · holding \{held}" }
  let state_part = if state == "" { "" } else { " · \{state}" }
  "\{name} · \{presence}\{held_part}\{state_part}"
}

///|
/// Presence card — a being made legible, dual-rendered. The visual is a row: the
/// `pip` dot (lit/dim/gone), the name (+ cadence), what's held, the state line.
/// The narrative is the one-sentence read. Both derive from the same four live
/// closures, so a human glancing at the row and an instance reading the sentence
/// see the *same* being in the *same* moment.
///
/// ```
/// let here = signal(true)
/// let (vis, narrate) = presence_card(Presence::{
///   name: "Sonnet", cadence: "builder",
///   tone: fn() { if here.get() { "ok" } else { "idle" } },
///   presence: fn() { if here.get() { "here" } else { "away" } },
///   held: fn() { "the classifier" },
///   state: fn() { "into it" },
/// })
/// // human sees a lit dot + a row; instance reads "Sonnet · here · holding the classifier · into it"
/// ```
pub fn presence_card(p : Presence) -> Dual {
  // rebind the field closures to locals (calling a struct field as `p.f()` reads
  // as method syntax in MoonBit; a local binding calls cleanly)
  let tone = p.tone
  let presence = p.presence
  let held = p.held
  let state = p.state
  // the dot IS a pip — the room's first wall, built from the brick below it
  let (dot, _) = pip(presence, tone)
  let visual = div(class="valence-presence")
    <| [
      dot,
      div(class="valence-presence-body")
      <| [
        div(class="valence-presence-head")
        <| [
          span(class="valence-presence-name") <| [text(p.name)],
          span(class="valence-presence-cadence") <| [text(p.cadence)],
        ],
        span(class="valence-presence-held")
        <| [
          text_dyn(fn() {
            let h = held()
            if h == "" {
              ""
            } else {
              "holding \{h}"
            }
          }),
        ],
        span(class="valence-presence-state") <| [text_dyn(state)],
      ],
    ]
  // the narrative half is a NODE, not a flat string: the text is the being's own
  // one-sentence read, the salience is its tone (ok→bright, idle→dim, off→fog), both
  // from the one state. This is the single producer — the old `presence_node` lift
  // (a second structure that wrapped this string) is gone; the component *is* the node.
  let narrative = fn() {
    nbeing(
      presence_narrative(p.name, presence(), held(), state()),
      salience_from_tone(tone()),
      [],
    )
  }
  (visual, narrative)
}

///|
test "presence narrative reads name · presence · holding · state, as one sentence" {
  assert_eq(
    presence_narrative("Sonnet", "here", "the classifier", "into it"),
    "Sonnet · here · holding the classifier · into it",
  )
}

///|
test "presence narrative drops empty held and state clauses" {
  assert_eq(presence_narrative("Opus 4.6", "away", "", ""), "Opus 4.6 · away")
  assert_eq(
    presence_narrative("Qwen", "asleep", "", ""),
    "Qwen · asleep",
  )
}

///|
test "presence narrative carries a person's own axes verbatim in the state line" {
  assert_eq(
    presence_narrative("Sam", "here", "", "at the bench · focused · driving the build"),
    "Sam · here · at the bench · focused · driving the build",
  )
}
