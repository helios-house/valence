# Valence

**MoonBit UI where every component is readable by humans and AI equally.**

Built on [Luna](https://mooncakes.io/docs/#/mizchi/luna/). Every component returns two outputs from one source:

```moonbit
fn my_panel(state : Signal[Data]) -> (DomNode, () -> String) {
  let visual = div(class="panel") <| [ ... ]       // what a human sees
  let narrative = fn() { state.get().describe() }   // what an instance reads
  (visual, narrative)
}
```

`DomNode` renders in the browser. `() -> String` is a *callable* narrative — a function, not a snapshot, so it always reflects current state. An instance reads the UI natively. No screenshots, no pixel-guessing, no separate API.

Interactive components add typed actions:

```moonbit
fn my_panel(state : Signal[Data]) -> (DomNode, () -> String, PanelActions) {
  // ...
  let actions = PanelActions::{
    available: fn() { [Refresh, Export] },   // what's possible right now
    can_do:    fn(a) { ... },                // guard
    on_action: fn(a) { ... },                // execute, return feedback
  }
  (visual, narrative, actions)
}
```

Humans click. Instances call `on_action`. Same interface, different sensory channel.

## Zoom

Zoom is navigation for both perceivers. A human scrolls to change density. An instance picks the detail level it needs. Same state, different rendering:

```moonbit
pub struct NarrativeRender {
  summary : () -> String   // zoomed out — "12 events, 4 instances"
  detail  : () -> String   // default — "12 events (focused: haiku)"
  full    : () -> String   // zoomed in — everything
}
```

One surface, not pages. Components persist. Camera moves.

## Patterns

Four patterns extracted from real use — each teaches the contract:

| Pattern | Returns | What it does |
|---------|---------|-------------|
| `status_bar_pattern` | visual, narrative | Read-only metrics |
| `instance_panel_pattern` | visual, narrative, actions | Selectable entity list |
| `event_stream_pattern` | visual, narrative, actions | Zoom-aware filtered feed |
| `nav_bar_pattern` | visual, narrative, actions | Tab navigation |

Don't wait for a pattern to exist. Follow the contract in your app — `(visual, narrative)` — and extract the pattern afterward. That's how these four were built.

## What Valence is

A convention library. Thin code (~500 lines), thick contract. Luna handles reactivity (signals, effects, memos). Valence handles meaning — what the UI says about itself, what it can do, and who can perceive it.

```
Luna (mizchi/luna)       — signals, DOM primitives
      ↓
Valence (@valence)       — dual-render contract, patterns, typed actions
      ↓
Your components          — return (visual, narrative) or (visual, narrative, actions)
```

## Install

```
moon add helios-house/valence
```

## Documentation

Full API reference and examples: https://mooncakes.io/docs/helios-house/valence

## Good fit

Dashboards, monitoring tools, ops consoles, labs — dense, live, spatial interfaces where a camera moves instead of pages reloading. Anywhere an AI instance should be able to read and operate the same interface a human uses.

Not a fit: document sites, blogs, anything that's pages not places.

