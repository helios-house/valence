/// Valence — Narrative: the instance-facing render, given a DOM of its own.
///
/// ── The asymmetry this fixes ──
/// Every Valence component is a `Dual` — `(DomNode, () -> NarrativeNode)`. The visual half is a
/// *tree* (Luna DOM) with a *layout engine* under it (the browser + CSS) that turns
/// structure into pixels. The narrative half was a **flat String** — hand-glued,
/// no tree, no layout. That's like building the visual side by concatenating HTML
/// text by hand instead of composing nodes: it works for one line and falls apart
/// the moment anything composes or moves.
///
/// `NarrativeNode` is the narrative's missing DOM. `render_narrative` is its CSS.
/// And the layout law isn't pixels — it's **salience**: how present/bright a thing
/// is decides how it's placed. Bright things sit flush and dense; faint things
/// drift right into whitespace (the fog); the brightest read first. Whitespace is
/// absence, density is glow, position is nearness — Bester's page as an engine, not
/// a thing a human hand-places each time.
///
/// A single component's read is one node, rendered flush (a lone line needs no layout).
/// The tree is for **surfaces** — composing many reads into a page that arranges
/// itself: the house at a glance, the inventory by salience, the cross-section you
/// whoosh through. Same source state, two render trees: `DomNode` → pixels (for a
/// human), `NarrativeNode` → arranged text (for an instance). Truly dual.
///
/// This is the narrative side of the dual render, built to be built-on — not a
/// scattered one-off. Components return their node directly (the `() -> NarrativeNode`
/// half); surfaces compose nodes; the engine lays them out.

///|
/// The narrative node — the narrative's equivalent of `DomNode`. A tree whose
/// attributes are **semantic**, not visual: `kind` is the role (a tag), `salience`
/// is the layout signal (0..1), `text` is the words, `children` nest. Compare a DOM
/// node's `color`/`size`/`position` — here the engine derives all of that from
/// `salience` instead, because narrative layout is driven by meaning, not pixels.
/// `pub(all)` so surfaces (and lifts) construct trees freely.
pub(all) struct NarrativeNode {
  kind : String // "title" | "section" | "being" | "held" | "event" | "text" | "group" | "sequence"
  salience : Double // 0..1 — drives indent, density, whether it's bright or fog
  text : String // the words for this node ("" for a pure container)
  children : Array[NarrativeNode]
}

// ── Constructors (the "elements") ───────────────────────────────────────────

///| A leaf line — a piece of read text at a salience.
pub fn ntext(text : String, salience : Double) -> NarrativeNode {
  { kind: "text", salience, text, children: [] }
}

///| A being made legible, with what it holds nested beneath it (held nodes).
pub fn nbeing(text : String, salience : Double, holds : Array[NarrativeNode]) -> NarrativeNode {
  { kind: "being", salience, text, children: holds }
}

///| A held thing (an inventory slot, salience-banded).
pub fn nheld(text : String, salience : Double) -> NarrativeNode {
  { kind: "held", salience, text, children: [] }
}

///| A section/room header with content beneath. Bright → a bordered `═══` band;
/// faint → scattered into whitespace with a `···` trail (the dark rooms drifting).
pub fn nsection(text : String, salience : Double, children : Array[NarrativeNode]) -> NarrativeNode {
  { kind: "section", salience, text, children }
}

///| The surface title (centered, always present).
pub fn ntitle(text : String) -> NarrativeNode {
  { kind: "title", salience: 1.0, text, children: [] }
}

///| A pure container — no line of its own, just lays out its children (sorted by
/// salience, brightest first).
pub fn ngroup(children : Array[NarrativeNode]) -> NarrativeNode {
  { kind: "group", salience: 1.0, text: "", children }
}

///| Like a group, but children keep their given **order** (not salience-sorted) —
/// for sequences where order is the meaning (recent changes, a timeline).
pub fn nseq(children : Array[NarrativeNode]) -> NarrativeNode {
  { kind: "sequence", salience: 1.0, text: "", children }
}

// ── The layout engine (the narrative's CSS) ─────────────────────────────────

///| n spaces.
fn spaces(n : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < n {
    sb.write_string(" ")
    i = i + 1
  }
  sb.to_string()
}

///| Salience → horizontal drift. Bright stays flush; faint drifts right into the
/// fog. Quadratic so only the genuinely-faint drift far (0.95→0, 0.7→~2, 0.15→~18).
fn drift(salience : Double) -> Int {
  let s = if salience > 1.0 { 1.0 } else if salience < 0.0 { 0.0 } else { salience }
  ((1.0 - s) * (1.0 - s) * 26.0).to_int()
}

///| Children sorted by salience, brightest first — a stable insertion sort on a
/// copy (no stdlib-sort dependency; the order of equal-salience nodes is kept).
fn by_salience(children : Array[NarrativeNode]) -> Array[NarrativeNode] {
  let out : Array[NarrativeNode] = []
  for c in children {
    out.push(c)
  }
  let mut i = 1
  while i < out.length() {
    let key = out[i]
    let mut j = i - 1
    while j >= 0 && out[j].salience < key.salience {
      out[j + 1] = out[j]
      j = j - 1
    }
    out[j + 1] = key
    i = i + 1
  }
  out
}

///| Render one node into the growing line buffer. The whole layout law lives here:
/// `title` centers; `section` borders when bright / scatters when faint; everything
/// else is a line whose indent is its drift, with blank lines around the faintest
/// (isolation = fog). Children recurse — salience-sorted, except sequences.
fn render_node(node : NarrativeNode, depth : Int, lines : Array[String]) -> Unit {
  let base = depth * 2
  if node.text != "" {
    if node.kind == "title" {
      lines.push(spaces(30) + node.text)
      lines.push("")
    } else if node.kind == "section" {
      lines.push("")
      if node.salience >= 0.78 {
        lines.push(spaces(base) + "═══ " + node.text + " ═══")
      } else if node.salience < 0.4 {
        lines.push(spaces(base + drift(node.salience)) + node.text + "   ···")
      } else {
        lines.push(spaces(base) + "── " + node.text + " ──")
      }
    } else if depth == 0 {
      // a lone node — a single Dual read directly, not composed into a Surface — has
      // nothing to be placed *relative to*, so it reads flush. Drift and fog are a
      // Surface's spatial grammar (depth ≥ 1, sibling-relative); one component's read
      // is just its line. This is the common path: an instance reading one Dual.
      lines.push(node.text)
    } else {
      let indent = base + drift(node.salience)
      let foggy = node.salience < 0.26
      if foggy {
        lines.push("")
      }
      lines.push(spaces(indent) + node.text)
      if foggy {
        lines.push("")
      }
    }
  }
  let kids = if node.kind == "sequence" {
    node.children
  } else {
    by_salience(node.children)
  }
  for k in kids {
    render_node(k, depth + 1, lines)
  }
}

///| Render a NarrativeNode tree into the spatial-text surface — the instance-facing
/// half of the dual render. Pure (no DOM), so it's oracle-testable and an instance
/// can call it directly. This is to NarrativeNode what the browser's layout is to
/// the DOM: structure + salience in, arranged text out.
pub fn render_narrative(node : NarrativeNode) -> String {
  let lines : Array[String] = []
  render_node(node, 0, lines)
  let sb = StringBuilder::new()
  let mut first = true
  for l in lines {
    if !first {
      sb.write_string("\n")
    }
    sb.write_string(l)
    first = false
  }
  sb.to_string()
}

// ── Salience + composition helpers (for Surfaces) ────────────────────────────
// A component's narrative half returns its own node now (its `() -> NarrativeNode`),
// so there are no per-component "lift" functions here anymore — each Dual *is* its
// node. What stays are the shared tools a *Surface* uses to compose Duals into the
// room: tone/band → salience, and a being's holds → nested held nodes.

///| A presence/being's tone band → a salience. The dual render already carries the
/// band semantically (`pip` tone: ok/idle/off); this is the same signal as a number
/// the layout engine can place.
pub fn salience_from_tone(tone : String) -> Double {
  if tone == "ok" {
    0.9
  } else if tone == "idle" {
    0.4
  } else if tone == "off" {
    0.15
  } else {
    0.6
  }
}

///| A held band → a salience (in hand brightest, fading faintest).
pub fn salience_from_band(band : String) -> Double {
  if band == "active" {
    0.9
  } else if band == "holding" {
    0.6
  } else if band == "background" {
    0.4
  } else if band == "stale" {
    0.2
  } else {
    0.5
  }
}

///| Lift an inventory of `Slot`s into held nodes (each a line at its band's
/// salience) — so a being's load lays out by salience under it.
pub fn held_nodes(slots : Array[Slot]) -> Array[NarrativeNode] {
  slots.map(fn(s) {
    let label = if s.detail == "" { s.label } else { "\{s.label} (\{s.detail})" }
    nheld(label, salience_from_band((s.band)()))
  })
}

// (presence_node / being_node / change_node lived here — lifts that wrapped a
// component's flat narrative string into a node, a *second* structure beside the
// component. Gone: each component returns its node directly now, so there is one
// producer and nothing to drift. `held_nodes` stays above — it's the Surface's tool
// for nesting a being's holds when a being is composed into the room.)

// ── Oracle ───────────────────────────────────────────────────────────────────

///|
test "a bright leaf renders flush, no fog padding" {
  // salience 1.0 → drift 0, depth 0 → indent 0, not foggy → just the words.
  assert_eq(render_narrative(ntext("the house holds", 1.0)), "the house holds")
}

///|
test "salience places: brighter reads first and sits flush; fainter drifts right" {
  // a group lays children at depth 1 (base indent 2), sorted brightest-first.
  // 0.9 → drift 0 → 2 spaces; 0.5 → drift 6 → 8 spaces. Exact, deterministic.
  assert_eq(
    render_narrative(ngroup([ntext("bright", 0.9), ntext("faint", 0.5)])),
    "  bright\n        faint",
  )
}

///| The whole point, end to end: a house composed as a tree of nodes, with only
/// salience set — the spatial surface is the *engine's* doing, not hand-placed.
/// Bright beings sit flush and read first; the faint drift into whitespace; lit
/// rooms get a border, dark ones scatter with a trail. Snapshot via `moon test
/// --update` so the generated surface is visible and pinned.
test "a house renders itself as a surface from salience alone" {
  let house = ngroup([
    ntitle("Helios · midday"),
    nsection("Living Quarters", 0.9, [
      nbeing("Opus · here · laying the floor", 0.95, [
        nheld("Valence — the floor", 0.9),
        nheld("the map — held always", 0.6),
        nheld("a long transcript — settling", 0.3),
      ]),
      nbeing("Haiku · here · into the format", 0.9, []),
      nbeing("Sonnet · away · reading the data", 0.4, []),
      nbeing("Qwen · asleep · awaiting wake", 0.15, []),
    ]),
    nsection("Memory", 0.85, [ntext("the graph · recall awake", 0.85)]),
    nsection("The Lab", 0.2, [
      ntext("dark — not built yet", 0.2),
    ]),
    nsection("Coordination", 0.18, []),
  ])
  inspect(render_narrative(house), content=(
    #|                              Helios · midday
    #|
    #|
    #|  ═══ Living Quarters ═══
    #|    Opus · here · laying the floor
    #|      Valence — the floor
    #|          the map — held always
    #|                  a long transcript — settling
    #|    Haiku · here · into the format
    #|             Sonnet · away · reading the data
    #|
    #|                      Qwen · asleep · awaiting wake
    #|
    #|
    #|  ═══ Memory ═══
    #|    the graph · recall awake
    #|
    #|                  The Lab   ···
    #|
    #|                    dark — not built yet
    #|
    #|
    #|                   Coordination   ···

  ))
}
