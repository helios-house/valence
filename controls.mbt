/// Valence — Coupled Controls
///
/// The owned form controls the DOM never had. Each control is **one signal with
/// two hands on it**: a human operates it (click/drag), and an instance reads its
/// state in the narrative and sets the *same* signal. Both the pixels and the
/// narrative render from that one signal, so a change from either side is seen by
/// both. A self-narrating, self-operating control does not exist anywhere to
/// import — this is the body the dual-render contract was always missing.
///
/// Every control returns a `Dual` — `(DomNode, () -> NarrativeNode)`: the visual
/// for a human, a callable narrative for an instance (evaluated on demand, so it
/// never goes stale). The control sets the signal and nothing else; how an
/// instance *invokes* a control from outside (the operate-channel) is a host
/// binding, deliberately not baked in here — the signal is the only channel the
/// component knows about.
///
/// Styling is via semantic classes (`valence-*`), never hard-coded colors, so a
/// consuming surface (the gesture lab, the dashboard, a uMyo dev's own app)
/// themes them. A default stylesheet ships alongside; the classes are the seam.
///
/// Extracted from the gesture-lab setup screen, where these were proven by
/// running (the first owned, coupled controls — Jun 18). Locked by use, then
/// lifted, per the framework's own law.

// Note: `div`, `text`, `DomNode`, `events`, `signal`, `Signal` are already in
// scope package-wide (the `using` declarations in patterns.mbt are package-scoped),
// so this file uses them directly without re-importing.

///|
/// A control's narrative as a node — the Dual contract. A control's value carries no
/// *intrinsic* salience: a slider is load-bearing in one room and fog in another, and
/// only the room knows which. So every control reads at a neutral mid-presence by
/// default, and a composing Surface re-weights it by context (the focus model's job —
/// the single place to change it is here). The text stays the control's own read.
fn control_node(text : String) -> NarrativeNode {
  ntext(text, 0.6)
}

///|
/// Pure narrative for a segmented selection — the selected option's label, or the
/// raw value if the current value isn't in the list. Separated from the visual so
/// the oracle tests it with no DOM (building a component touches `document`; a
/// pure narrative doesn't). An instance can also call it directly.
pub fn segmented_narrative(
  current : String,
  options : Array[(String, String)],
) -> String {
  let mut label = current
  for opt in options {
    if opt.0 == current {
      label = opt.1
    }
  }
  label
}

///|
/// Segmented control — pick exactly one of N options. `options` is a list of
/// `(value, label)`: `value` is what's stored in the signal, `label` is shown.
/// Clicking an option sets the signal; the selected option carries the
/// `is-selected` class. The narrative reads back the *selected option's label*
/// (falling back to the raw value if the signal holds something not in the list).
///
/// One component, every pick-one need: L/R arm (2 options), muscle face
/// (extensor/flexor/radial/ulnar), mode (stream/record/replay), theme, …
///
/// ```
/// let side = signal("ext")
/// let (vis, narrate) = segmented(side, [("ext", "Extensor"), ("flex", "Flexor")])
/// // human clicks "Flexor" → side == "flex"; narrate() == "Flexor"
/// // instance: side.set("ext") → the human's control moves to Extensor
/// ```
pub fn segmented(
  sig : Signal[String],
  options : Array[(String, String)],
) -> Dual {
  let visual = div(class="valence-segmented") <| options.map(fn(opt) {
    let value = opt.0
    div(
      dyn_class=fn() {
        if sig.get() == value {
          "valence-segmented-option is-selected"
        } else {
          "valence-segmented-option"
        }
      },
      on=events().click(fn(_) { sig.set(value) }),
    )
    <| [text(opt.1)]
  })
  let narrative = fn() { control_node(segmented_narrative(sig.get(), options)) }
  (visual, narrative)
}

// ── Oracle — the narrative is the test (SPEC §10) ──

///|
test "segmented narrative reads back the selected option's label" {
  let opts = [("ext", "Extensor"), ("flex", "Flexor"), ("rad", "Radial")]
  assert_eq(segmented_narrative("ext", opts), "Extensor")
  assert_eq(segmented_narrative("flex", opts), "Flexor")
}

///|
test "segmented narrative falls back to the raw value when off-list" {
  assert_eq(segmented_narrative("paused", [("on", "On"), ("off", "Off")]), "paused")
}

///|
/// Pure narrative for a toggle — the active label. `on_label`/`off_label` are the
/// words an instance reads (e.g. "recording"/"idle", "wire"/"skin"), so the state
/// reads as meaning, not a bare boolean.
pub fn toggle_narrative(on : Bool, on_label : String, off_label : String) -> String {
  if on {
    on_label
  } else {
    off_label
  }
}

///|
/// Toggle / switch — one boolean, two hands. A human clicks it; an instance reads
/// the labeled state and sets the same signal. Clicking flips the signal (via
/// `peek`, so the handler doesn't subscribe). The `is-on` class carries the state
/// to the theme.
///
/// ```
/// let rec = signal(false)
/// let (vis, narrate) = toggle(rec, "recording", "idle")
/// // human clicks → rec == true; narrate() == "recording"
/// // instance: rec.set(false) → the switch slides off on the human's screen
/// ```
pub fn toggle(
  sig : Signal[Bool],
  on_label : String,
  off_label : String,
) -> Dual {
  let visual = div(
    dyn_class=fn() { if sig.get() { "valence-toggle is-on" } else { "valence-toggle" } },
    on=events().click(fn(_) { sig.set(!sig.peek()) }),
  )
  <| [div(class="valence-toggle-knob") <| []]
  let narrative = fn() { control_node(toggle_narrative(sig.get(), on_label, off_label)) }
  (visual, narrative)
}

///|
test "toggle narrative reads the labeled state, not a bare bool" {
  assert_eq(toggle_narrative(true, "recording", "idle"), "recording")
  assert_eq(toggle_narrative(false, "recording", "idle"), "idle")
}

///|
/// Pure narrative for a slider value within `[lo, hi]` — the value with its unit,
/// plus a position hint at the extremes ("near min"/"near max") so an instance
/// reads *where* it sits, not just the number.
pub fn slider_narrative(
  value : Double,
  lo : Double,
  hi : Double,
  unit : String,
) -> String {
  let span = hi - lo
  let frac = if span <= 0.0 { 0.0 } else { (value - lo) / span }
  let hint = if frac <= 0.12 {
    " (near min)"
  } else if frac >= 0.88 {
    " (near max)"
  } else {
    ""
  }
  "\{value}\{unit}\{hint}"
}

// Tiny value-accessor FFIs — pull numbers out of DOM objects (the mizchi binding
// doesn't surface clientX or the element rect). These read a coordinate; they
// never build markup, so they're legitimate FFI, not the HTML-string disease.
// They're what lets the slider own its own drag.
extern "js" fn pe_client_x(e : @dom.PointerEvent) -> Double = "(e) => e.clientX"

extern "js" fn pe_pointer_id(e : @dom.PointerEvent) -> Int = "(e) => e.pointerId"

extern "js" fn el_rect_left(el : @dom.Element) -> Double =
  "(el) => el.getBoundingClientRect().left"

extern "js" fn el_rect_width(el : @dom.Element) -> Double =
  "(el) => el.getBoundingClientRect().width"

extern "js" fn el_capture_pointer(el : @dom.Element, id : Int) -> Unit =
  "(el, id) => { try { el.setPointerCapture(id) } catch (_e) {} }"

///|
/// Coupled slider — a numeric value on a track. One signal, two hands, and it
/// **slides**: press or drag anywhere on the track and the value follows the
/// pointer, snapped to `step`. An instance reads the value in the narrative and
/// `set`s the same signal to move the thumb the other way — same state, both
/// directions.
///
/// The drag is owned by the component via Luna pointer events, with pointer
/// capture so a fast drag doesn't slip off the track. This works in a browser AND
/// in the WebKitGTK webview — the lab's own pointer-drag proves pointer events
/// fire there; the lab only polls because its arm SVG is JS-string-rendered, not
/// Luna. `id` is a stable element id (useful for tests / external hooks).
pub fn slider(
  id : String,
  label : String,
  sig : Signal[Double],
  lo : Double,
  hi : Double,
  step : Double,
  unit : String,
) -> Dual {
  let frac = fn() {
    let f = (sig.get() - lo) / (hi - lo)
    if f < 0.0 {
      0.0
    } else if f > 1.0 {
      1.0
    } else {
      f
    }
  }
  let dragging = signal(false)
  // pointer position over the track → value snapped to `step`, onto the signal
  fn set_from(e : @dom.PointerEvent) -> Unit {
    let track = e.currentTarget()
    let width = el_rect_width(track)
    if width > 0.0 {
      let raw = (pe_client_x(e) - el_rect_left(track)) / width
      let f = if raw < 0.0 { 0.0 } else if raw > 1.0 { 1.0 } else { raw }
      let value = lo + f * (hi - lo)
      let steps = ((value - lo) / step + 0.5).to_int()
      sig.set(lo + steps.to_double() * step)
    }
  }

  let visual = div(class="valence-slider")
    <| [
      div(class="valence-slider-head")
      <| [
        span(class="valence-slider-label") <| [text(label)],
        span(class="valence-slider-value")
        <| [text_dyn(fn() { "\{sig.get()}\{unit}" })],
      ],
      div(
        class="valence-slider-track",
        id=id,
        on=events()
          .pointerdown(fn(e) {
            dragging.set(true)
            el_capture_pointer(e.currentTarget(), pe_pointer_id(e))
            e.preventDefault()
            set_from(e)
          })
          .pointermove(fn(e) { if dragging.peek() { set_from(e) } })
          .pointerup(fn(_e) { dragging.set(false) })
          .pointercancel(fn(_e) { dragging.set(false) }),
      )
      <| [
        div(
          class="valence-slider-fill",
          dyn_style=fn() { "width:\{frac() * 100.0}%" },
        )
        <| [],
        div(
          class="valence-slider-thumb",
          dyn_style=fn() { "left:\{frac() * 100.0}%" },
        )
        <| [],
      ],
    ]
  let narrative = fn() { control_node(slider_narrative(sig.get(), lo, hi, unit)) }
  (visual, narrative)
}

///|
test "slider narrative carries a position hint only at the extremes" {
  assert_true(slider_narrative(20.0, 20.0, 32.0, " cm").contains("near min"))
  assert_true(slider_narrative(32.0, 20.0, 32.0, " cm").contains("near max"))
  assert_false(slider_narrative(26.0, 20.0, 32.0, " cm").contains("near"))
  assert_true(slider_narrative(26.0, 20.0, 32.0, " cm").contains("cm"))
}

///|
/// Pure narrative for a listbox — the selected option's label and the count, so
/// an instance reads what's chosen and how many it could pick.
pub fn listbox_narrative(
  current : String,
  options : Array[(String, String)],
) -> String {
  let mut label = current
  for opt in options {
    if opt.0 == current {
      label = opt.1
    }
  }
  "\{label} · \{options.length()} options"
}

///|
/// Listbox / dropdown — pick one from many. One signal, two hands. A custom
/// **div-listbox** (NOT a native `<select>`): native form-control events are
/// unreliable in the WebKitGTK webview, so this is built from static divs +
/// `events().click`, the one interaction confirmed to fire there. That's the
/// reason this component has to exist — the dropdown Luna couldn't give us.
///
/// A trigger shows the selected option's label; clicking it toggles the panel;
/// clicking an option sets the signal and closes. Options are static here; a
/// dynamic-options variant (device pickers) is a later extension. An instance
/// reads the selection in the narrative and `set`s the same signal.
pub fn listbox(
  selected : Signal[String],
  options : Array[(String, String)],
) -> Dual {
  let open = signal(false)
  let trigger_label = fn() {
    let cur = selected.get()
    let mut label = cur
    for opt in options {
      if opt.0 == cur {
        label = opt.1
      }
    }
    label
  }
  let visual = div(class="valence-listbox")
    <| [
      div(
        class="valence-listbox-trigger",
        on=events().click(fn(_) { open.set(!open.peek()) }),
      )
      <| [
        span(class="valence-listbox-value") <| [text_dyn(trigger_label)],
        span(class="valence-listbox-caret") <| [text("▾")],
      ],
      div(
        dyn_class=fn() {
          if open.get() {
            "valence-listbox-panel is-open"
          } else {
            "valence-listbox-panel"
          }
        },
      )
      <| options.map(fn(opt) {
        let value = opt.0
        div(
          dyn_class=fn() {
            if selected.get() == value {
              "valence-listbox-option is-selected"
            } else {
              "valence-listbox-option"
            }
          },
          on=events().click(fn(_) {
            selected.set(value)
            open.set(false)
          }),
        )
        <| [text(opt.1)]
      }),
    ]
  let narrative = fn() { control_node(listbox_narrative(selected.get(), options)) }
  (visual, narrative)
}

///|
test "listbox narrative shows the selected label and the option count" {
  let opts = [("a", "Mic A"), ("b", "Mic B"), ("c", "Mic C")]
  assert_eq(listbox_narrative("b", opts), "Mic B · 3 options")
  assert_eq(listbox_narrative("z", opts), "z · 3 options")
}

///|
/// Pure narrative for a swatch picker — which of N is chosen, and its value.
pub fn swatch_narrative(selected : Int, colors : Array[String]) -> String {
  let n = colors.length()
  if selected >= 0 && selected < n {
    "swatch \{selected + 1} of \{n} (\{colors[selected]})"
  } else {
    "swatch (none of \{n})"
  }
}

///|
/// Swatch picker — pick one of N colors (skin tone, palette). One signal (the
/// index), two hands: click a dot to select; an instance reads the index/value in
/// the narrative and `set`s it. The chosen dot gets a ring (`is-selected`); the
/// dot's fill is its color (inline, since it's data, not theme).
pub fn swatch(
  selected : Signal[Int],
  colors : Array[String],
) -> Dual {
  let visual = div(class="valence-swatch")
    <| colors.mapi(fn(i, col) {
      div(
        style="background:\{col}",
        dyn_class=fn() {
          if selected.get() == i {
            "valence-swatch-dot is-selected"
          } else {
            "valence-swatch-dot"
          }
        },
        on=events().click(fn(_) { selected.set(i) }),
      )
      <| []
    })
  let narrative = fn() { control_node(swatch_narrative(selected.get(), colors)) }
  (visual, narrative)
}

///|
/// Pure narrative for a meter — a clamped percentage.
pub fn meter_narrative(level : Double) -> String {
  let pct = (level * 100.0).to_int()
  let p = if pct < 0 { 0 } else if pct > 100 { 100 } else { pct }
  "\{p}%"
}

///|
/// Meter / level bar — read-mostly indicator driven by a `[0,1]` level signal (mic
/// level, progress, fill). No actions hand: it's data, not a control. Pixels = a
/// fill bar; narrative = the percentage. The fill width is data (inline style);
/// the look is themed via the class.
pub fn meter(level : Signal[Double]) -> Dual {
  let visual = div(class="valence-meter")
    <| [
      div(
        class="valence-meter-fill",
        dyn_style=fn() {
          let pct = level.get() * 100.0
          let p = if pct < 0.0 { 0.0 } else if pct > 100.0 { 100.0 } else { pct }
          "width:\{p}%"
        },
      )
      <| [],
    ]
  let narrative = fn() { control_node(meter_narrative(level.get())) }
  (visual, narrative)
}

///|
test "swatch narrative names the chosen index and value" {
  let cols = ["#F1C9A5", "#D9A878", "#A9764B"]
  assert_eq(swatch_narrative(1, cols), "swatch 2 of 3 (#D9A878)")
  assert_eq(swatch_narrative(-1, cols), "swatch (none of 3)")
}

///|
test "meter narrative clamps to a percentage" {
  assert_eq(meter_narrative(0.62), "62%")
  assert_eq(meter_narrative(1.5), "100%")
  assert_eq(meter_narrative(-0.2), "0%")
}

///|
/// Dynamic listbox — the device/source picker. Same div-listbox as `listbox`, but
/// for the lab's real shape: a **changing** option list (mic/cam sources that
/// connect & drop), **coordinated** open state (opening one closes its siblings),
/// a **custom trigger label**, and a **side-effecting select** (switching the
/// actual device / messaging the host, not just storing a value). So instead of a
/// `selected` signal it takes:
///
/// - `label` — what the trigger shows; the consumer formats it (the caret is added
///   here, so don't include one).
/// - `options` — a `Signal[Array]` (up to 8 shown — fixed slots, the
///   webview-reliable way to render a changing list without a reactive `<|`).
/// - `open` / `siblings` — open state the consumer holds; opening closes siblings.
/// - `on_select` — what a pick *does* (set a signal, message the host, switch a
///   device — the consumer decides).
///
/// Ported from the gesture-lab feeds dropdowns (proven in the WebKitGTK webview).
pub fn listbox_dyn(
  label : () -> String,
  options : Signal[Array[(String, String)]],
  open : Signal[Bool],
  siblings : Array[Signal[Bool]],
  on_select : (String) -> Unit,
) -> Dual {
  // one fixed option slot, shown only when the list reaches it
  let option_slot = fn(idx : Int) -> DomNode {
    div(
      dyn_class=fn() {
        if idx >= options.get().length() {
          "valence-listbox-option is-hidden"
        } else {
          "valence-listbox-option"
        }
      },
      on=events().click(fn(_) {
        let opts = options.peek()
        if idx < opts.length() {
          on_select(opts[idx].0)
          open.set(false)
        }
      }),
    )
    <| [
      text_dyn(fn() {
        let opts = options.get()
        if idx < opts.length() {
          opts[idx].1
        } else {
          ""
        }
      }),
    ]
  }
  let visual = div(class="valence-listbox")
    <| [
      div(
        class="valence-listbox-trigger",
        on=events().click(fn(_) {
          let opening = !open.peek()
          if opening {
            for s in siblings {
              s.set(false)
            }
          }
          open.set(opening)
        }),
      )
      <| [
        span(class="valence-listbox-value") <| [text_dyn(label)],
        span(class="valence-listbox-caret") <| [text("▾")],
      ],
      div(
        dyn_class=fn() {
          if open.get() {
            "valence-listbox-panel is-open"
          } else {
            "valence-listbox-panel"
          }
        },
      )
      <| [
        option_slot(0),
        option_slot(1),
        option_slot(2),
        option_slot(3),
        option_slot(4),
        option_slot(5),
        option_slot(6),
        option_slot(7),
        div(
          dyn_class=fn() {
            if options.get().length() == 0 {
              "valence-listbox-empty"
            } else {
              "valence-listbox-empty is-hidden"
            }
          },
        )
        <| [text("no options")],
      ],
    ]
  let narrative = fn() {
    control_node("\{label()} · \{options.get().length()} options")
  }
  (visual, narrative)
}

///|
/// Pure narrative for a status pip — its label in words, with the severity tone
/// appended when it isn't "ok" (so an instance reads *what* and *how bad*).
pub fn pip_narrative(label : String, tone : String) -> String {
  if tone == "ok" || tone == "" {
    label
  } else {
    "\{label} (\{tone})"
  }
}

///|
/// Status pip — a small colored dot reporting one discrete state. The purest dual
/// render in the set: a human sees the dot's color; an instance, which can't see
/// color, reads the narrative — so the dot's *meaning* lives in the narrative, not
/// the pixels. Read-mostly, no actions hand.
///
/// `tone` is a **semantic** band, never a raw color — "ok" / "warn" / "off" / "idle"
/// — so the theme colors it (`--v-pip-*`) and every status dot in a surface agrees.
/// `label` is what the state *means* in words ("base connected", "streaming",
/// "offline"). One pip for every status dot: device streaming, base link, mute,
/// presence — and, later, a being's lit/dim in the world.
///
/// ```
/// let connected = signal(true)
/// let (vis, narrate) = pip(
///   fn() { if connected.get() { "base connected" } else { "base disconnected" } },
///   fn() { if connected.get() { "ok" } else { "off" } },
/// )
/// // human sees a green dot; instance reads "base connected"
/// ```
pub fn pip(label : () -> String, tone : () -> String) -> Dual {
  let visual = div(dyn_class=fn() { "valence-pip is-\{tone()}" }) <| []
  let narrative = fn() { control_node(pip_narrative(label(), tone())) }
  (visual, narrative)
}

///|
test "pip narrative reads the label, and the severity when not ok" {
  assert_eq(pip_narrative("streaming", "ok"), "streaming")
  assert_eq(pip_narrative("base disconnected", "off"), "base disconnected (off)")
  assert_eq(pip_narrative("battery", "warn"), "battery (warn)")
}

///|
/// Pure narrative for a level bar — the percentage, or "muted".
pub fn level_bar_narrative(level : Double, muted : Bool) -> String {
  if muted {
    "muted"
  } else {
    let pct = (level * 100.0).to_int()
    let p = if pct < 0 { 0 } else if pct > 100 { 100 } else { pct }
    "\{p}%"
  }
}

///|
/// Level bar — a `[0,1]` level on a green→amber→red gradient (mic level, a game
/// health/stress bar, anything where *where it sits* carries meaning). Unlike a plain
/// `meter` (one themed color — progress, confidence, where "high" isn't hot), the level
/// bar says *low is calm, high is hot*: it reveals through green into red as it fills.
/// `muted` empties it. Read-mostly, no actions hand.
///
/// The gradient lives in CSS (themeable via `--v-level-lo/mid/hi`); the bar reveals it
/// by covering the un-reached part from the right — so there's no per-tick color math.
pub fn level_bar(
  level : Signal[Double],
  muted : Signal[Bool],
) -> Dual {
  let visual = div(class="valence-level")
    <| [
      div(
        class="valence-level-cover",
        dyn_style=fn() {
          let lvl = if muted.get() {
            0.0
          } else {
            let l = level.get()
            if l < 0.0 { 0.0 } else if l > 1.0 { 1.0 } else { l }
          }
          "width:\{(1.0 - lvl) * 100.0}%"
        },
      )
      <| [],
    ]
  let narrative = fn() { control_node(level_bar_narrative(level.get(), muted.get())) }
  (visual, narrative)
}

///|
test "level bar narrative: percentage, or muted" {
  assert_eq(level_bar_narrative(0.62, false), "62%")
  assert_eq(level_bar_narrative(1.5, false), "100%")
  assert_eq(level_bar_narrative(0.62, true), "muted")
}
