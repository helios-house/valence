/// Valence's fourth projection — state changes become events.
///
/// Fable's inversion: *"the narrative diff IS the event {who, when, what}."* A
/// Valence surface therefore **emits natively** into the one event world — the same
/// 8-field Helios Event schema the viewer reads — instead of being something the
/// event system watches from outside. Valence's missing delivery story and the
/// event bus turn out to be the same artifact.
///
/// These diff functions are **pure**: given the previous and current state they
/// return an Event only when the change is *significant* (a Stat crossing a band, a
/// discrete transition, a device connect/drop or battery-low), and None otherwise —
/// so the stream carries meaning, not every wiggle. Delivery is the app's job (the
/// sink): call these per tick and route Some(event) to a local stream by default, or
/// the Helios event stream when the surface is plugged into the house.
///
/// This layer is **clockless** — the timestamp is passed in by the surface (whose
/// clock is the one that aligns with everything else it records).

///|
/// The emitted record is `Event` — the *same* 8-field type the event_stream pattern
/// already defines (`patterns.mbt`) and the viewer reads. We reuse it rather than mint
/// a second: a state-change event is then indistinguishable from a git / recap / channel
/// event in the one stream, and flows straight into the stream pattern that renders it.
/// (`kind` = "state"; `action` = the transition; `message` = the new state's narrative,
/// so the event reads itself; `data` = the machine old→new payload; `timestamp` is the
/// surface's own clock — this layer is clockless.)

///|
/// A Stat crossing a significance band (ok ↔ warning ↔ critical) is an event; a
/// value that merely wiggles within a band is not. `message` is the new state's
/// own narrative, so the event is self-describing.
pub fn stat_event(
  prev : Stat,
  cur : Stat,
  actor : String,
  source : String,
  timestamp : String,
) -> Event? {
  let from = stat_significance(prev)
  let to = stat_significance(cur)
  if from == to {
    None
  } else {
    Some(Event::{
      timestamp,
      actor,
      kind: "state",
      action: "cross",
      target: cur.name,
      source,
      message: stat_narrative(cur),
      data: "\{prev.value}->\{cur.value}\{cur.unit}; \{from}->\{to}",
      link: "",
    })
  }
}

///|
/// A DiscreteState transition (connection, mode, …) is an event.
pub fn discrete_event(
  prev : DiscreteState,
  cur : DiscreteState,
  actor : String,
  source : String,
  timestamp : String,
) -> Event? {
  if prev.current == cur.current {
    None
  } else {
    Some(Event::{
      timestamp,
      actor,
      kind: "state",
      action: "change",
      target: cur.name,
      source,
      message: discrete_state_narrative(cur),
      data: "\{prev.current}->\{cur.current}",
      link: "",
    })
  }
}

///|
/// A device connecting/disconnecting, or its battery crossing the low line, is an
/// event. Battery crossings count only while connected — a disconnect isn't "low".
pub fn device_event(
  prev : DeviceState,
  cur : DeviceState,
  source : String,
  timestamp : String,
) -> Event? {
  let conn_changed = prev.connected != cur.connected
  let was_low = prev.battery_pct < prev.critical_threshold
  let now_low = cur.battery_pct < cur.critical_threshold
  let batt_crossed = cur.connected && was_low != now_low
  if !conn_changed && !batt_crossed {
    None
  } else {
    let action = if conn_changed {
      if cur.connected {
        "connect"
      } else {
        "disconnect"
      }
    } else if now_low {
      "battery-low"
    } else {
      "battery-ok"
    }
    Some(Event::{
      timestamp,
      actor: cur.name,
      kind: "state",
      action,
      target: cur.name,
      source,
      message: device_state_narrative(cur),
      data: "conn \{prev.connected}->\{cur.connected}; batt \{prev.battery_pct}->\{cur.battery_pct}%",
      link: "",
    })
  }
}

// ── Oracle tests — the narrative gates CI, so the projection can't silently rot ──

///|
test "stat_event: a wiggle within a band is not an event" {
  let a = stat("battery", 90, "%", 20)
  let b = stat("battery", 80, "%", 20) // both ok (>= 40) — no crossing
  match stat_event(a, b, "AB91", "gesture-lab", "t0") {
    None => ()
    Some(_) => abort("expected None for an in-band change")
  }
}

///|
test "stat_event: crossing ok→warning emits, and reads itself" {
  let a = stat("battery", 90, "%", 20) // ok
  let b = stat("battery", 30, "%", 20) // warning (< 40)
  let ev = match stat_event(a, b, "AB91", "gesture-lab", "t1") {
    Some(e) => e
    None => abort("expected an event on the band crossing")
  }
  assert_eq(ev.kind, "state")
  assert_eq(ev.action, "cross")
  assert_eq(ev.target, "battery")
  assert_eq(ev.actor, "AB91")
  assert_eq(ev.message, "battery: warning, 30%")
  assert_eq(ev.data, "90->30%; ok->warning")
}

///|
test "stat_banded: battery mV uses an explicit low line, and its crossing emits" {
  let full = stat_banded("battery", 4050, "mV", 3900, 3850) // ok, sits above the line
  let low = stat_banded("battery", 3820, "mV", 3900, 3850) // critical (< 3850)
  assert_eq(stat_significance(full), "ok")
  assert_eq(stat_significance(low), "critical")
  let ev = match stat_event(full, low, "AB91", "gesture-lab/wall", "t6") {
    Some(e) => e
    None => abort("expected a battery crossing event")
  }
  assert_eq(ev.action, "cross")
  assert_eq(ev.message, "battery: CRITICAL — 3820mV")
  assert_eq(ev.data, "4050->3820mV; ok->critical")
}

///|
test "device_event: disconnect emits with the offline narrative" {
  let a = device_state("AB91", true, 90, 20)
  let b = device_state("AB91", false, 0, 20)
  let ev = match device_event(a, b, "gesture-lab/wall", "t2") {
    Some(e) => e
    None => abort("expected a disconnect event")
  }
  assert_eq(ev.action, "disconnect")
  assert_eq(ev.message, "AB91: offline")
}

///|
test "device_event: battery crossing the low line while connected emits" {
  let a = device_state("AB91", true, 30, 20)
  let b = device_state("AB91", true, 15, 20)
  let ev = match device_event(a, b, "gesture-lab/wall", "t3") {
    Some(e) => e
    None => abort("expected a battery-low event")
  }
  assert_eq(ev.action, "battery-low")
  assert_eq(ev.message, "AB91: 15% (low)")
}

///|
test "device_event: steady state is silent" {
  let a = device_state("AB91", true, 90, 20)
  let b = device_state("AB91", true, 88, 20)
  match device_event(a, b, "gesture-lab/wall", "t4") {
    None => ()
    Some(_) => abort("expected silence on a steady device")
  }
}

///|
test "discrete_event: a mode transition emits its new narrative" {
  let says = { "stream": "streaming live", "record": "recording" }
  let a = discrete_state("mode", "stream", says)
  let b = discrete_state("mode", "record", says)
  let ev = match discrete_event(a, b, "mode", "gesture-lab", "t5") {
    Some(e) => e
    None => abort("expected a mode-change event")
  }
  assert_eq(ev.action, "change")
  assert_eq(ev.message, "recording")
  assert_eq(ev.data, "stream->record")
}

// ============================================================================
// CONTROL EVENTS — the fourth projection for the coupled controls
// ============================================================================
//
// The controls in `controls.mbt` render pixels + prose + actions (operate), but
// emit nothing — so a human dragging a slider or an instance `set`-ing a segmented
// control never lands in the one event world. This closes that gap: an *operate*
// becomes `{who set what to value}` in the same Event stream the viewer reads.
//
// It honours the file's law and adds no burden to the controls themselves:
//   • sink-agnostic — the surface routes the Event (local stream, or the Helios
//     stream when plugged in); the control still only knows its signal.
//   • clockless — the surface stamps the time (its clock aligns with everything).
//   • significant-only — a *pick-one / toggle / settle* is itself the meaningful
//     act, so every distinct value emits (unlike a Stat, where an in-band wiggle is
//     silent). For a continuously-dragged value, feed a settled/rounded projection
//     so a drag emits once on landing, not per pixel.
//   • signature-free — no control changes shape; a surface that wants the events
//     just wires `track_control` over the same signal it already passed in.

///|
/// Pure: the `{who, when, what}` for a control moving `prev -> cur`.
/// `kind="control"` marks it an *operate* (someone acted), distinct from a world
/// `state` crossing; `message` reads itself, `data` carries the machine diff.
pub fn control_event(
  name : String,
  actor : String,
  source : String,
  prev : String,
  cur : String,
  timestamp : String,
) -> Event {
  Event::{
    timestamp,
    actor,
    kind: "control",
    action: "set",
    target: name,
    source,
    message: "\{name}: \{cur}",
    data: "\{prev}->\{cur}",
    link: "",
  }
}

///|
/// The events projection wired live. Watches a control's value through its string
/// projection `read` (type-agnostic — pass `fn() { sig.get().to_string() }`, or the
/// control's own narrative), and on each *change* emits a `control_event` to `emit`.
/// The diff stays pure (`control_event`, oracle-tested); this effect only binds it
/// to the running signal. The surface supplies the clock (`now`) and the sink
/// (`emit`). Initial wiring is silent — only real transitions emit.
///
/// ```
/// let side = signal("ext")
/// let (vis, narrate) = segmented(side, opts)
/// track_control("muscle-side", "AB91", "gesture-lab",
///   fn() { side.get() }, now, fn(e) { sink.push(e) })
/// // human picks Flexor → emit { control · set · muscle-side · ext->flex }
/// ```
pub fn track_control(
  name : String,
  actor : String,
  source : String,
  read : () -> String,
  now : () -> String,
  emit : (Event) -> Unit,
) -> Unit {
  // 1-cell mutable holder for the last seen value — read inside the effect via a
  // plain array index (NOT signal-tracked), so updating it can't retrigger us.
  let prev = [read()]
  let _ = effect(fn() {
    let cur = read() // the only tracked read → effect re-runs when the control moves
    if cur != prev[0] {
      emit(control_event(name, actor, source, prev[0], cur, now()))
      prev[0] = cur
    }
  })
}

///|
test "control_event carries who/when/what for a value move" {
  let e = control_event("muscle-side", "AB91", "gesture-lab", "ext", "flex", "t0")
  assert_eq(e.kind, "control")
  assert_eq(e.action, "set")
  assert_eq(e.target, "muscle-side")
  assert_eq(e.actor, "AB91")
  assert_eq(e.message, "muscle-side: flex")
  assert_eq(e.data, "ext->flex")
}

// `track_control`'s reactive wiring (effect over the signal) is verified LIVE in
// the demo, not here: a bare test has no reactive root, so the effect never
// subscribes — which is why every oracle in this file tests the *pure* diff
// (`control_event` above) and the live surface proves the wiring. Same convention
// as `device_card_events`: pure producer is oracle-gated, the sink is verified by
// running.
