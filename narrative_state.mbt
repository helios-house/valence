/// Valence — state → NarrativeNode (the coupling primitives).
///
/// The narrative half of the dual render, derived *directly* from typed state — not
/// a hand-written flat string, and not a second structure wrapping one. A `Stat`,
/// a `DeviceState`, … each becomes a `NarrativeNode` whose text is the state's own
/// derived narrative (`stat_narrative`, …) and whose salience comes from the state's
/// own significance. One source (the state), one narrative (the node).
///
/// This is the seed of the converged component contract — `(DomNode, () -> NarrativeNode)`
/// instead of `(DomNode, () -> String)`: a component returns one of these, a surface
/// composes them by salience into the room, and a single instance-read is just
/// `render_narrative(node)`. And it is exactly what the gesture lab needs: route a
/// device/signal state through `device_node` / `stat_node` and the instance reads
/// "E14A: 4070mV" / "E14A: offline" — Format B — instead of raw ADC frames.

///|
/// A significance band → salience. critical sits bright and flush; ok drifts back.
pub fn salience_from_significance(sig : String) -> Double {
  match sig {
    "critical" => 0.95
    "warning" => 0.6
    _ => 0.35
  }
}

///|
/// A numeric measurement (battery, frame count, …) as a narrative node — placed by
/// its own significance, so a critical reading sits bright and an ok one recedes.
pub fn stat_node(s : Stat) -> NarrativeNode {
  ntext(stat_narrative(s), salience_from_significance(stat_significance(s)))
}

///|
/// A device as a narrative node: offline drifts to fog; battery-low burns bright;
/// connected-and-fine sits mid. The lab reads its sensors through this.
pub fn device_node(d : DeviceState) -> NarrativeNode {
  let sal = if !d.connected {
    0.2
  } else if d.battery_pct < d.critical_threshold {
    0.9
  } else {
    0.55
  }
  ntext(device_state_narrative(d), sal)
}

///|
/// A named/discrete state (mode, connection, …) as a narrative node.
pub fn discrete_node(s : DiscreteState) -> NarrativeNode {
  ntext(discrete_state_narrative(s), 0.6)
}

///|
/// A counted aggregate as a narrative node — bright when it's crossed its line.
pub fn counted_node(c : CountedState) -> NarrativeNode {
  let sal = if c.count >= c.critical_threshold { 0.9 } else { 0.5 }
  ntext(counted_state_narrative(c), sal)
}

// ── Oracle — the coupling itself: text comes from the state's own narrative, salience
// from its own significance. (render_narrative's spatial layout is the engine's job,
// pinned in narrative.mbt; here we assert only that the node is *derived from state* —
// which is the whole point: one producer, no parallel hand-written string to drift.) ──

///|
test "stat_node couples the stat's own narrative to a significance-driven salience" {
  let ok = stat_banded("battery", 4070, "mV", 3900, 3850) // ok band
  let n = stat_node(ok)
  assert_eq(n.text, "battery: 4070mV")
  assert_eq(n.salience, 0.35) // "ok" → recedes
}

///|
test "device_node: offline reads as offline and sinks toward fog" {
  let n = device_node(device_state("E14A", false, 0, 20))
  assert_eq(n.text, "E14A: offline")
  assert_eq(n.salience, 0.2) // disconnected → near-fog
}

///|
test "a state node flows through the narrative engine as its own line" {
  // end to end: state → node → surface. Exact indentation is the engine's (and is
  // pinned in narrative.mbt); here we assert only that the state's own words survive.
  let low = device_state("E14A", true, 5, 20)
  assert_true(render_narrative(device_node(low)).contains("E14A: 5% (low)"))
}

///|
test "a lone Dual read renders flush — drift is a Surface's grammar, not a line's" {
  // stat_node's "ok" salience (0.35) would drift it right *inside a Surface*; read
  // alone — the common path, an instance reading one Dual — it's just its line.
  let ok = stat_banded("battery", 4070, "mV", 3900, 3850)
  assert_eq(render_narrative(stat_node(ok)), "battery: 4070mV")
}
