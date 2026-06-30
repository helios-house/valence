/// Valence — Being (the full wall: who's here · how they are · what they hold)
///
/// The room's first wall, whole. The presence card says *who's here and how*; the
/// inventory says *what they carry*. A Being braids the two into one component —
/// and, the part that matters, **one narrative voice**: a being read as
/// who/how/what-held in a single sentence. The room stacks these; this is the unit
/// a being *is*, made legible.
///
/// Composition all the way down — nothing new is rendered or computed here that
/// the two components beneath don't already do. The visual is `presence_card` over
/// `inventory`; the narrative is `presence_narrative` braided with
/// `inventory_narrative`. The only new thing at this layer is **the join** — and
/// the join is the whole design question: how *who-you-are*, *how-you-are*, and
/// *what-you-hold* read as one voice instead of three stacked readouts. The answer
/// here: lead with the being (name · presence · state), then their load, by
/// salience — the same order you'd actually meet someone in. You see who and how
/// first; what they're carrying comes right after, heaviest in hand.
///
/// Note the held *summary* on the presence card is dropped when it's inside a
/// Being (the inventory below is the held detail — no redundant clause). A bare
/// presence card still carries its own one-word held summary; a Being supersedes
/// it with the real grid.

///|
/// A being, whole: identity + how they are + what they hold. `pub(all)` so a
/// surface (the demo now, the room later) can build a roster of full walls.
pub(all) struct Being {
  name : String
  cadence : String
  tone : () -> String // pip band: ok / idle / off
  presence : () -> String // here / away / asleep
  state : () -> String // the status line, in the being's own terms ("" = none)
  holds : Array[Slot] // the inventory — what they carry, salience-banded
}

///|
/// Pure braided narrative — the being read as one voice. Reuses
/// `presence_narrative` (with the held summary dropped — the holds clause is the
/// inventory's job) joined to `inventory_narrative`, so the whole sentence is its
/// parts' sentences. DOM-free, oracle-tested. Reads, e.g.:
/// `Opus · here · laying the floor · carrying 2 — in hand: Valence …`
pub fn being_narrative(
  name : String,
  presence : String,
  state : String,
  items : Array[(String, String, String)],
) -> String {
  let who = presence_narrative(name, presence, "", state)
  let holds = inventory_narrative(items)
  "\{who} · \{holds}"
}

///|
/// Being card — the full wall. Visual: the presence row over the inventory grid,
/// in one frame. Narrative: the braided read. Both compose the two components
/// beneath, so a change in any held band or presence signal re-renders the row,
/// the grid, *and* the one-sentence read together.
pub fn being_card(b : Being) -> Dual {
  let (pres_vis, _) = presence_card(Presence::{
    name: b.name,
    cadence: b.cadence,
    tone: b.tone,
    presence: b.presence,
    held: fn() { "" }, // held detail lives in the inventory below — no summary clause
    state: b.state,
  })
  let (inv_vis, _) = inventory(b.holds)
  let visual = div(class="valence-being") <| [pres_vis, inv_vis]
  // narrative half = a NODE: the braided one-voice read as the line, salience from
  // tone. One producer; the old `being_node` lift is gone (the component is the node).
  // (The structured form — the being's holds as nested child nodes that drift by
  // salience — is the Surface's job, composed when a being is placed in the room.)
  let narrative = fn() {
    nbeing(
      being_narrative(
        b.name,
        (b.presence)(),
        (b.state)(),
        b.holds.map(fn(s) { (s.label, s.detail, (s.band)()) }),
      ),
      salience_from_tone((b.tone)()),
      [],
    )
  }
  (visual, narrative)
}

///|
test "being narrative braids who/how with what's held, by salience" {
  let holds = [
    ("Valence", "the floor", "active"),
    ("the map", "held always", "holding"),
  ]
  assert_eq(
    being_narrative("Opus", "here", "laying the floor", holds),
    "Opus · here · laying the floor · carrying 2 — in hand: Valence (the floor) · within reach: the map (held always)",
  )
}

///|
test "being narrative with nothing held still reads as one clean voice" {
  assert_eq(
    being_narrative("Qwen", "asleep", "awaiting wake", []),
    "Qwen · asleep · awaiting wake · carrying nothing",
  )
}
