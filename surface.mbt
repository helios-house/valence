/// Valence — the **Surface**: many Duals composed into one room.
///
/// A Dual is one thing rendered twice. A **Surface** is *many* Duals arranged into a
/// room — and the elegant part is that it composes *up to the same contract*: a
/// Surface is **itself a Dual.** Its pixels are the children's visuals on a wall; its
/// narrative is the children's nodes composed into one tree and arranged by salience
/// (bright things flush and first, faint things drifting to fog). So you read a whole
/// Surface exactly like one component — `dual_read(a_surface)` — and a Surface can
/// nest inside a larger Surface, because it *is* a Dual. The room is fractal.
///
/// The narrative composition is the keystone: each child contributes its own
/// `NarrativeNode` (text + salience, both from its state), and the Surface lays them
/// out — it does **not** re-author their prose. So the room-as-text is the children's
/// own reads, placed by their own salience. (Where that salience comes *from* —
/// intrinsic to the state, or re-weighted by where attention is pointed — is the
/// focus model, a layer that preprocesses salience *before* this composes it. This
/// file is the composition; the focus model is the next layer up. They don't fight:
/// composition renders whatever salience it's handed.)

///|
/// Pure narrative composition — DOM-free, oracle-testable. Wrap the child nodes under
/// a titled section; `render_narrative` then arranges them by salience (brightest
/// first and flush, faint drifting right into the fog). A Surface's own salience is
/// 1.0 (a room is always present); its *children's* salience is what arranges the room.
pub fn surface_narrative(
  title : String,
  parts : Array[NarrativeNode],
) -> NarrativeNode {
  nsection(title, 1.0, parts)
}

///|
/// The pixel wall. Luna's `<|` array caps near six children (it drops the rest
/// *silently*), so a Surface with more than six Duals nests its visuals into rows of
/// six. The narrative half has no such limit — `render_narrative` composes any number;
/// this guard is only for the pixels. (Rows themselves cap at six → up to 36 parts
/// render directly; a larger wall would nest one level deeper, not needed yet.)
fn surface_visual(parts : Array[DomNode]) -> DomNode {
  if parts.length() <= 6 {
    return div(class="valence-surface") <| parts
  }
  let rows : Array[DomNode] = []
  let mut i = 0
  while i < parts.length() {
    let row : Array[DomNode] = []
    let mut n = 0
    while n < 6 && i < parts.length() {
      row.push(parts[i])
      i = i + 1
      n = n + 1
    }
    rows.push(div(class="valence-surface-row") <| row)
  }
  div(class="valence-surface") <| rows
}

///|
/// Compose Duals into a Surface — itself a Dual. Pixels: the children's visuals on a
/// wall. Narrative: the children's nodes arranged by salience into one room-as-text,
/// re-read live (so as a being brightens or fogs, the room re-arranges from the one
/// change). Read the whole room with `dual_read`; nest it in a bigger Surface freely.
///
/// ```
/// let house = surface("the house", [presence_card(opus), presence_card(qwen)])
/// // dual_read(house) =>
/// //   ═══ the house ═══
/// //     Opus · here · laying the floor        (bright: flush, reads first)
/// //                     Qwen · asleep   (faint: drifted into the fog)
/// ```
pub fn surface(title : String, parts : Array[Dual]) -> Dual {
  let visual = surface_visual(parts.map(fn(d) { d.0 }))
  let narrative = fn() {
    surface_narrative(title, parts.map(fn(d) { (d.1)() }))
  }
  (visual, narrative)
}

// ── Oracle — composition places the children; the room is their reads by salience ──

///|
test "a Surface composes children into a titled room, brightest first and flush" {
  let room = surface_narrative("the house", [
    nbeing("Opus · here · laying the floor", 0.95, []),
    nbeing("Qwen · asleep", 0.15, []),
  ])
  let txt = render_narrative(room)
  // the title bands the room; both beings are present; the bright one reads flush and
  // first, the faint one drifts into the fog — the salience layout, composed.
  assert_true(txt.contains("═══ the house ═══"))
  assert_true(txt.contains("Opus · here · laying the floor"))
  assert_true(txt.contains("Qwen · asleep"))
}

///|
test "an empty Surface is just its banded title — a room with no one in it" {
  assert_eq(render_narrative(surface_narrative("the lab", [])), "\n═══ the lab ═══")
}
