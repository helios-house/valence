/// Valence Framework — Patterns 1-4 Extracted
/// Reusable component patterns with full interaction protocol
///
/// Patterns 1-4 are extracted from real use in Helios.
/// Each pattern is a function that returns (visual, narrative, actions) or (visual, narrative)
/// depending on whether it has interactive elements.

using @element { div, span, text, text_dyn, type DomNode, events }
using @resource { signal, memo, effect, type Signal }

// ============================================================================
// CORE DATA TYPES (shared with apps that use these patterns)
// ============================================================================

pub struct Event {
  pub timestamp: String
  pub actor: String
  pub kind: String       // event type: "tool_call", "commit", "heartbeat", "gesture_tap", ...
  pub action: String
  pub target: String
  pub source: String
  pub message: String
  pub data: String       // kind-specific JSON payload (optional, empty = none)
}

// ============================================================================
// ACTION TYPES FOR INTERACTIVE PATTERNS
// ============================================================================

/// Pattern 2: Event Stream Actions
/// Users can focus on a specific actor or clear the focus to see all events
pub enum EventStreamAction {
  FocusEntity(String)  // Focus on actor: "haiku", "opus", etc.
  ClearFocus           // Show all events
}

/// Pattern 1: Instance Panel Actions
/// Users can select an instance to see its details
pub enum InstancePanelAction {
  SelectInstance(String)  // Select actor by name
  ClearSelection          // Deselect
}

/// Pattern 4: Nav Bar Actions
/// Users can switch between tabs
pub enum NavBarAction {
  SwitchTab(String)  // Switch to tab name: "Events", "Instances", etc.
}

/// Standard return from on_action for all patterns
/// new_narrative is always detail-level, so caller confirms what happened
pub struct PatternActionResult {
  pub success        : Bool
  pub message        : String     // "Focused on haiku" or "Cannot select: no events"
  pub new_narrative  : String     // detail-level narrative after action
}

// ============================================================================
// PATTERN 1 — REACTIVE VALUE / GROWING LIST
// Status bar — simple metrics display, no actions
// ============================================================================

pub fn status_bar_pattern(
  all_events: Signal[Array[Event]],
) -> (DomNode, () -> String) {
  let event_count = memo(fn() { all_events.get().length() })
  let instance_count_active = 4
  let instance_count_total = 55

  let visual = div(class="status-bar-fixed") <| [
    div(class="status-metric") <| [
      text("📊 Events: "),
      text_dyn(fn() { event_count().to_string() })
    ],
    div(class="status-metric") <| [
      text("🤖 Instances: "),
      text(instance_count_active.to_string() + "/" + instance_count_total.to_string())
    ],
    div(class="status-metric") <| [
      text("⚡ Status: ok")
    ]
  ]

  let narrative = fn() {
    event_count().to_string() + " events, " + instance_count_active.to_string() + "/" + instance_count_total.to_string() + " instances"
  }

  (visual, narrative)
}

// ============================================================================
// PATTERN 1 — REACTIVE VALUE / GROWING LIST
// Instance panel — tiles with selection capability and action protocol
// ============================================================================

pub struct InstancePanelActions {
  pub available : () -> Array[InstancePanelAction]
  pub can_do    : (InstancePanelAction) -> Bool
  pub on_action : (InstancePanelAction) -> PatternActionResult
}

pub fn instance_panel_pattern(
  all_events: Signal[Array[Event]],
  on_select: (String) -> Unit,
) -> (DomNode, () -> String, InstancePanelActions) {
  let actors = ["haiku", "paladin", "proto", "opus", "vesper", "river"]
  let selected = signal("")

  let actor_summaries = memo(fn() {
    let events = all_events.get()
    let result : Array[(String, Int, String)] = []
    for i = 0; i < actors.length(); i = i + 1 {
      let actor = actors[i]
      let actor_events = events.filter(fn(e) { e.actor == actor })
      let count = actor_events.length()
      let action = if count > 0 { actor_events[0].action } else { "—" }
      let _ = result.push((actor, count, action))
    }
    result
  })

  let _rebuild = effect(fn() {
    let summaries = actor_summaries()
    let html = {
      let mut h = ""
      for i = 0; i < summaries.length(); i = i + 1 {
        let item = summaries[i]
        let actor = item.0
        let count = item.1
        let last_action = item.2
        h = h + "<div class='instance-tile'>" +
          "<span class='actor-name'>" + actor + "</span> " +
          "<span class='count'>" + count.to_string() + "</span> " +
          "<span class='action'>" + last_action + "</span>" +
          "</div>"
      }
      h
    }

    update_element_html("instance-panel-tiles", html)
  })

  let visual = div(class="instance-panel") <| [
    div(id="instance-panel-tiles") <| []
  ]

  let narrative = fn() {
    let summaries = actor_summaries()
    let sel = selected.get()
    if sel.is_empty() {
      summaries.length().to_string() + " instances"
    } else {
      summaries.length().to_string() + " instances (selected: " + sel + ")"
    }
  }

  let actions = InstancePanelActions::{
    available: fn() {
      [SelectInstance("haiku"), SelectInstance("paladin"), SelectInstance("proto"),
       SelectInstance("opus"), SelectInstance("vesper"), SelectInstance("river"),
       ClearSelection]
    },
    can_do: fn(action) {
      match action {
        SelectInstance(id) => not(id.is_empty())
        ClearSelection => true
      }
    },
    on_action: fn(action) {
      match action {
        SelectInstance(id) => {
          selected.set(id)
          on_select(id)
          PatternActionResult::{
            success: true,
            message: "Selected " + id,
            new_narrative: narrative()
          }
        }
        ClearSelection => {
          selected.set("")
          on_select("")
          PatternActionResult::{
            success: true,
            message: "Cleared selection",
            new_narrative: narrative()
          }
        }
      }
    }
  }

  (visual, narrative, actions)
}

// ============================================================================
// PATTERN 2 — EVENT STREAM (ZOOM-AWARE)
// Live feed with zoom levels and focus filtering
// ============================================================================

pub struct EventStreamActions {
  pub available : () -> Array[EventStreamAction]
  pub can_do    : (EventStreamAction) -> Bool
  pub on_action : (EventStreamAction) -> PatternActionResult
}

fn render_event_row_html(e: Event, zoom: ZoomLevel) -> String {
  let zoom_class = zoom_to_css_class(zoom)
  match zoom {
    ZoomLevel::ZoomedOut => {
      let cls = if zoom_class.is_empty() { "event-row" } else { "event-row " + zoom_class }
      "<div class='" + cls + "'>" +
      "<span class='time'>" + e.timestamp + "</span> " +
      "<span class='actor'>" + e.actor + "</span> " +
      "<span class='msg'>" + truncate_string(e.message, 40) + "</span>" +
      "</div>"
    }
    ZoomLevel::Default => {
      "<div class='event-row'>" +
      "<span class='time'>" + e.timestamp + "</span> " +
      "<span class='actor'>" + e.actor + "</span> " +
      "<span class='action'>" + e.action + "</span> " +
      "<span class='msg'>" + e.message + "</span>" +
      "</div>"
    }
    ZoomLevel::ZoomedIn => {
      "<div class='event-row zoom-in'>" +
      "<div class='time'>" + e.timestamp + "</div>" +
      "<div class='actor'>" + e.actor + "</div>" +
      "<div class='action'>" + e.action + " → " + e.target + "</div>" +
      "<div class='source'>" + e.source + "</div>" +
      "<div class='msg'>" + e.message + "</div>" +
      "</div>"
    }
  }
}


pub fn event_stream_pattern(
  all_events: Signal[Array[Event]],
  zoom: Signal[ZoomLevel],
  focus_entity: Signal[String],
) -> (DomNode, NarrativeRender, EventStreamActions) {

  let visible_events = memo(fn() {
    let events = all_events.get()
    let focus = focus_entity.get()
    if focus.is_empty() {
      events
    } else {
      events.filter(fn(e) { e.actor == focus })
    }
  })

  let _rebuild = effect(fn() {
    let events = visible_events()
    let z = zoom.get()
    let html = events
      .map(fn(e) { render_event_row_html(e, z) })
      .join("")

    update_element_html("event-stream-rows", html)
  })

  let visual = div(class="event-stream") <| [
    div(id="event-stream-rows") <| []
  ]

  let narrative_render = NarrativeRender::{
    summary: fn() {
      visible_events().length().to_string() + " events"
    },
    detail: fn() {
      let count = visible_events().length()
      let focus = focus_entity.get()
      if focus.is_empty() {
        count.to_string() + " events"
      } else {
        count.to_string() + " events (focused: " + focus + ")"
      }
    },
    full: fn() {
      let count = visible_events().length()
      let focus = focus_entity.get()
      let zoom_level = match zoom.get() {
        ZoomLevel::ZoomedOut => "zoomed out (dense)"
        ZoomLevel::Default => "default zoom"
        ZoomLevel::ZoomedIn => "zoomed in (detailed)"
      }
      if focus.is_empty() {
        count.to_string() + " events, " + zoom_level
      } else {
        count.to_string() + " events (focused: " + focus + "), " + zoom_level
      }
    }
  }

  let actions = EventStreamActions::{
    available: fn() {
      let focus = focus_entity.get()
      if focus.is_empty() {
        []  // No actions available when showing all
      } else {
        [ClearFocus]
      }
    },
    can_do: fn(action) {
      match action {
        FocusEntity(entity) => not(entity.is_empty())
        ClearFocus => not(focus_entity.get().is_empty())
      }
    },
    on_action: fn(action) {
      match action {
        FocusEntity(entity) => {
          if not(entity.is_empty()) {
            focus_entity.set(entity)
            PatternActionResult::{
              success: true,
              message: "Focused on " + entity,
              new_narrative: (narrative_render.detail)()
            }
          } else {
            PatternActionResult::{
              success: false,
              message: "Cannot focus: entity name is empty",
              new_narrative: (narrative_render.detail)()
            }
          }
        }
        ClearFocus => {
          focus_entity.set("")
          PatternActionResult::{
            success: true,
            message: "Cleared focus, showing all events",
            new_narrative: (narrative_render.detail)()
          }
        }
      }
    }
  }

  (visual, narrative_render, actions)
}

// ============================================================================
// PATTERN 4 — PANELS AND ROOMS
// Navigation bar with tab switching
// ============================================================================

pub struct NavBarActions {
  pub available : () -> Array[NavBarAction]
  pub can_do    : (NavBarAction) -> Bool
  pub on_action : (NavBarAction) -> PatternActionResult
}

fn is_valid_tab(tab: String) -> Bool {
  let valid_tabs = ["Events", "Instances", "Knowledge", "Peripherals", "Labs", "Config"]
  for i = 0; i < valid_tabs.length(); i = i + 1 {
    if valid_tabs[i] == tab {
      return true
    }
  }
  false
}

pub fn nav_bar_pattern(
  current_tab: Signal[String],
) -> (DomNode, () -> String, NavBarActions) {
  let tabs = ["Events", "Instances", "Knowledge", "Peripherals", "Labs", "Config"]

  let visual = div(class="nav-bar-fixed") <| [
    div(class="tabs-container") <| tabs.map(fn(tab_name) {
      let is_active = memo(fn() { current_tab.get() == tab_name })

      div(
        dyn_class=fn() {
          if is_active() { "tab active" } else { "tab" }
        },
        on=events().click(fn(_) {
          current_tab.set(tab_name)
        })
      ) <| [
        text(tab_name)
      ]
    })
  ]

  let narrative = fn() {
    "Nav: " + current_tab.get()
  }

  let actions = NavBarActions::{
    available: fn() {
      tabs.map(fn(tab) { SwitchTab(tab) })
    },
    can_do: fn(action) {
      match action {
        SwitchTab(tab) => is_valid_tab(tab)
      }
    },
    on_action: fn(action) {
      match action {
        SwitchTab(tab) => {
          if is_valid_tab(tab) {
            current_tab.set(tab)
            PatternActionResult::{
              success: true,
              message: "Switched to " + tab,
              new_narrative: "Nav: " + tab
            }
          } else {
            PatternActionResult::{
              success: false,
              message: "Cannot switch: invalid tab",
              new_narrative: narrative()
            }
          }
        }
      }
    }
  }

  (visual, narrative, actions)
}

