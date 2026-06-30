/// Valence — Inventory (what a being is holding, read by salience)
///
/// The companion to the presence card. The card says *who's here and how*; the
/// inventory says *what they carry* — files in context, versions, the thread
/// they're driving; or, for a person, what's in hand / out of the bag / on the bench.
///
/// ── Why this component is mostly its narrative ──
/// The visual is a plain grid, on purpose. A human reads a grid of slots fine,
/// and a grid is the *easy* projection — it's the shape every game and app already
/// trained us on. The hard, new, only-the-instance-knows-it projection is the
/// **narrative**, and it is deliberately NOT the grid transcribed. "slot 1: X,
/// slot 2: Y, slot 3: Z" is enumeration — the same redundant snapshot we read
/// everything else as, the thing that costs attention and says little. An instance
/// reading its own inventory wants it read by **salience**: what's *in hand* and
/// load-bearing right now, what's *within reach*, what's gone *foggy*. Weight here
/// is attention, not bytes — a 2-line file you're actively editing is heavier than
/// a 2000-line transcript you finished reading an hour ago. That salience read is
/// the thing only the instance side knows it wants, so it is the thing this
/// component is *for*; the grid is just the human's confirmation of it.
///
/// Each slot carries a **band** (`() -> String`, so it moves as attention does):
///   "active"     — in hand, load-bearing now
///   "holding"    — within reach, carried but not in use
///   "background" — in the back, present but quiet
///   "stale"      — fading, dimming (the held thing going foggy after a while)
/// The narrative groups by band, heaviest first, drops empty bands, and leads with
/// the count — so you read the *shape* of what you carry, not a manifest.

///|
/// One held thing: what it is, what it is *to you*, and how present it is.
/// `pub(all)` so a surface (the demo now, the room later) can build a roster of
/// held items. `band` is a closure so an item can go active→stale live as the
/// being's attention moves — the dual render then re-sorts the read.
pub(all) struct Slot {
  label : String // "the presence card" / "controls.mbt" / "this conversation"
  detail : String // what it is to you: "building" / "reference" / "live" ("" = none)
  band : () -> String // salience: "active" / "holding" / "background" / "stale"
}

///|
/// Pure narrative for an inventory — the instance-facing read, DOM-free so the
/// oracle tests it and an instance can call it directly. Takes resolved
/// `(label, detail, band)` triples (bands already read), groups them by salience
/// (in hand → within reach → in the back → fading), drops empty bands, and leads
/// with the count. Reads as the *shape* of what's carried, never a slot manifest.
pub fn inventory_narrative(
  items : Array[(String, String, String)],
) -> String {
  if items.length() == 0 {
    return "carrying nothing"
  }
  // salience order + the spatial phrase each band reads as
  let order = [
    ("active", "in hand"),
    ("holding", "within reach"),
    ("background", "in the back"),
    ("stale", "fading"),
  ]
  let mut body = ""
  for bp in order {
    let band = bp.0
    let phrase = bp.1
    let mut names = ""
    let mut count = 0
    for it in items {
      if it.2 == band {
        let nm = if it.1 == "" { it.0 } else { "\{it.0} (\{it.1})" }
        names = if count == 0 { nm } else { "\{names}, \{nm}" }
        count = count + 1
      }
    }
    if count > 0 {
      let seg = "\{phrase}: \{names}"
      body = if body == "" { seg } else { "\{body} · \{seg}" }
    }
  }
  "carrying \{items.length()} — \{body}"
}

///|
/// Inventory — a being's held things, dual-rendered. The visual is a plain grid of
/// slots (label + detail, band shown as a left-edge weight); the narrative is the
/// salience read. Both derive from the same slots, so an item moving active→stale
/// re-tones its slot *and* re-sorts the sentence from one change.
///
/// ```
/// let live = signal(true)
/// let (vis, narrate) = inventory([
///   Slot::{ label: "the presence card", detail: "building",
///           band: fn() { if live.get() { "active" } else { "stale" } } },
///   Slot::{ label: "a long transcript", detail: "settling", band: fn() { "holding" } },
/// ])
/// // human sees two chips; instance reads
/// //   "carrying 2 — in hand: the presence card (building) · within reach: a long transcript (settling)"
/// ```
pub fn inventory(slots : Array[Slot]) -> Dual {
  let visual = div(class="valence-inventory")
    <| slots.map(fn(s) {
      div(dyn_class=fn() { "valence-slot is-\{(s.band)()}" })
      <| [
        span(class="valence-slot-label") <| [text(s.label)],
        span(class="valence-slot-detail") <| [text(s.detail)],
      ]
    })
  // narrative half = a NODE: the designed salience-grouped sentence stays the text,
  // and the whole inventory's salience is its heaviest band (what's *in hand* drives
  // how present the load reads). Derived from state — one producer, no parallel string.
  let narrative = fn() {
    let resolved = slots.map(fn(s) { (s.label, s.detail, (s.band)()) })
    let mut sal = if slots.length() == 0 { 0.5 } else { 0.0 }
    for s in slots {
      let b = salience_from_band((s.band)())
      if b > sal {
        sal = b
      }
    }
    ntext(inventory_narrative(resolved), sal)
  }
  (visual, narrative)
}

///|
test "inventory narrative reads held things by salience, heaviest band first" {
  let items = [
    ("the presence card", "building", "active"),
    ("controls.mbt", "reference", "active"),
    ("a long transcript", "settling", "holding"),
    ("the old notes", "", "stale"),
  ]
  assert_eq(
    inventory_narrative(items),
    "carrying 4 — in hand: the presence card (building), controls.mbt (reference) · within reach: a long transcript (settling) · fading: the old notes",
  )
}

///|
test "inventory narrative: nothing held reads plainly, not 'carrying 0'" {
  assert_eq(inventory_narrative([]), "carrying nothing")
}

///|
test "inventory narrative drops empty bands and folds in the detail" {
  assert_eq(
    inventory_narrative([("the keys", "in pocket", "active")]),
    "carrying 1 — in hand: the keys (in pocket)",
  )
}
