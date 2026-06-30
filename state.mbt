/// Contract-first state: semantics live in the data
/// Fable's four-projection inversion — state carries meaning, derive narrative automatically
///
/// Three proved shapes across real apps:
/// - Stat: numeric measurement (battery, frame count, event count)
/// - Discrete: named state with per-variant narrative (connection, mode)
/// - Counted: aggregate with threshold (claims, devices, records)
///
/// Pattern: name + value + unit + significance threshold → derive prose that never rots

// ============================================================================
// STAT: NUMERIC STATE WITH UNIT AND SIGNIFICANCE
// ============================================================================

pub struct Stat {
  name : String
  value : Int
  unit : String
  warn_below : Int
  critical_below : Int
}

///| `stat`: the warning band defaults to 2× the critical threshold — right for
/// %-style or count metrics (critical_below=20 → warning under 40).
pub fn stat(name : String, value : Int, unit : String, critical_below : Int) -> Stat {
  Stat::{ name, value, unit, warn_below: critical_below * 2, critical_below }
}

///| `stat_banded`: explicit warn + critical lines — for a measurement whose healthy
/// range sits just above the line (e.g. LiPo battery in mV: warn 3900, critical 3850),
/// where a 2× warning band would be meaningless.
pub fn stat_banded(
  name : String,
  value : Int,
  unit : String,
  warn_below : Int,
  critical_below : Int,
) -> Stat {
  Stat::{ name, value, unit, warn_below, critical_below }
}

// TODO(hysteresis): bands are single-threshold, so a value flapping at an edge
// (battery 3849↔3851) makes stat_event emit low/ok/low/ok — duplicate noise in the
// event stream. Fix: a deadband with separate enter/exit thresholds (drop to "low"
// below critical, but don't return to "ok" until well above warn), so line-noise
// can't flap the stream. Same trick as the gesture-control EMG hysteresis.
pub fn stat_significance(s : Stat) -> String {
  if s.value < s.critical_below {
    "critical"
  } else if s.value < s.warn_below {
    "warning"
  } else {
    "ok"
  }
}

pub fn stat_narrative(s: Stat) -> String {
  let sig = stat_significance(s)
  let state_word = match sig {
    "critical" => "CRITICAL — "
    "warning" => "warning, "
    _ => ""
  }
  "\{s.name}: \{state_word}\{s.value}\{s.unit}"
}

// ============================================================================
// DISCRETE: NAMED STATE WITH PER-VARIANT NARRATIVES
// ============================================================================

pub struct DiscreteState {
  name: String
  current: String
  narratives: Map[String, String]
}

pub fn discrete_state(
  name: String,
  current: String,
  narratives: Map[String, String],
) -> DiscreteState {
  DiscreteState::{ name, current, narratives }
}

pub fn discrete_state_narrative(s: DiscreteState) -> String {
  match s.narratives.get(s.current) {
    Some(prose) => prose
    None => "\{s.name}: unknown state \{s.current}"
  }
}

// ============================================================================
// COUNTED: AGGREGATE WITH THRESHOLD
// ============================================================================

pub struct CountedState {
  name: String
  count: Int
  total: Int
  critical_threshold: Int
}

pub fn counted_state(
  name: String,
  count: Int,
  total: Int,
  critical_threshold: Int,
) -> CountedState {
  CountedState::{ name, count, total, critical_threshold }
}

pub fn counted_state_narrative(c: CountedState) -> String {
  let pct = if c.total == 0 { 0 } else { c.count * 100 / c.total }
  let critical = if c.count >= c.critical_threshold { " — CRITICAL" } else { "" }
  "\{c.name}: \{c.count} (\{pct}% of \{c.total})\{critical}"
}

// ============================================================================
// ENGINE/DEVICE PATTERNS (FROM GESTURE LAB)
// ============================================================================

pub struct EngineState {
  ready: Bool
  devices: Int
  frames: Int
}

pub fn engine_state(ready: Bool, devices: Int, frames: Int) -> EngineState {
  EngineState::{ ready, devices, frames }
}

pub fn engine_state_narrative(e: EngineState) -> String {
  if !e.ready {
    "engine: waiting for connection"
  } else {
    "engine: ready · \{e.devices} device(s) · frame \{e.frames}"
  }
}

pub struct DeviceState {
  name: String
  connected: Bool
  battery_pct: Int
  critical_threshold: Int
}

pub fn device_state(
  name: String,
  connected: Bool,
  battery_pct: Int,
  critical_threshold: Int,
) -> DeviceState {
  DeviceState::{ name, connected, battery_pct, critical_threshold }
}

pub fn device_state_narrative(d: DeviceState) -> String {
  if !d.connected {
    "\{d.name}: offline"
  } else {
    let status = if d.battery_pct < d.critical_threshold {
      "low"
    } else {
      "ok"
    }
    "\{d.name}: \{d.battery_pct}% (\{status})"
  }
}
