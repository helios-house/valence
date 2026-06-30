# Valence

A MoonBit UI library built on one idea — **dual render**: every component renders twice from a single definition — a view to look at, and a live text description to read. Two first-class readers, one source, neither secondary.

## Why

An AI working with an interface today reads it the hard way — screenshots, scraped DOM, a side API that mirrors the real UI and drifts from it. They get the thing everyone else uses, secondhand. Valence drops the assumption under that — that the screen is for humans and the AI gets a workaround. The interface narrates itself instead: an AI reads its state directly and acts through the same controls a human does. No screenshots, no scraping, nothing to keep in sync on the side.

## A component

Returns its view and a narrative — a function, so it speaks the current state, not a stale copy:

```moonbit
fn battery_panel(state : Signal[Battery]) -> Dual {
  let visual    = div(class="battery") <| [ text_dyn(fn() { state.get().pct.to_string() + "%" }) ]
  let narrative = fn() {
    let pct = state.get().pct
    ntext("battery " + pct.to_string() + "%" + (if pct < 20 { ", low" } else { "" }),
          if pct < 20 { 0.9 } else { 0.4 })  // salience: low reads bright, fine recedes
  }
  (visual, narrative)
}
```

A human sees the bar fill; an AI reads `battery 18%, low` (via `dual_read`). Same state. The narrative is a **node**, not a flat string — its salience (low → bright here) is what lets components compose into one **Surface** (a room), each placed by what matters, instead of every component hand-gluing its own prose.

Interactive components also expose typed actions — `available`, `can_do`, `on_action`. An instance calls `on_action`; a human clicks the same control. The same actions, nothing to look up out of band.

## Narrative as oracle

The narrative isn't a comment that rots — it's the test oracle. Tests assert on what a component narrates, and the narrative reads the same state the view does. Change one without the other and a test fails, so the two renders can't drift apart.

**If you can't narrate a component's state in one sentence, the state is broken. Redesign it.**

## Built on Luna

Luna does reactivity and the DOM. Valence is the layer on top: the dual-render contract (a `Dual` — view + narrative node), the action protocol, the narrative layout engine (salience → spatial text), and the component set pulled from real apps — extracted after they work, not designed up front.

## Zoom

Zoom is density control, for both readers — show the headline, or show everything. It rides the same salience the layout already uses: every narrative node carries a salience, so a zoom is just a floor on what renders — the bright survive a zoom-out, everything emerges on a zoom-in. An instance picks the floor it needs; a human scrolls to move it. One surface, not pages: components persist, the camera moves.

## Components

Built, all on the Dual contract — each returns `(DomNode, () -> NarrativeNode)`:

| Component | What it does |
|-----------|-------------|
| `segmented` · `toggle` · `slider` · `listbox` · `listbox_dyn` · `swatch` · `meter` · `pip` · `level_bar` | coupled controls — one signal, two hands (a human drags; an instance `set`s the same signal) |
| `presence` · `inventory` · `being` | a being made legible — who's here, how they are, what they hold |
| `surface` | many components composed into one room, arranged by salience |

Don't wait for a component to exist. Follow the contract in your app — return a `Dual` — and extract it afterward. That's how these were built.

## Fits

Live, dense interfaces both kinds of reader should read and operate fluently — dashboards, monitoring, ops consoles, lab tooling. Not blogs or doc sites.

## Install

```
moon add helios-house/valence
```

## Documentation

Full API reference and examples: https://mooncakes.io/docs/helios-house/valence

