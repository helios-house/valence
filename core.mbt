/// Valence Core Framework
///
/// Reexports Luna substrate + provides FFI helpers for structural mutations
/// Every component is a Dual: (DomNode, () -> NarrativeNode) — pixels, and a narrative node

// ============================================================================
// VALENCE CORE: FFI HELPERS FOR STRUCTURAL MUTATIONS
// ============================================================================

/// Update element innerHTML — the core pattern for efficient structural mutations
/// Used when re-rendering large filtered tables or lists
extern "js" fn update_element_html_impl(elem_id: String, html: String) -> Unit =
  "(elem_id, html) => { let e = document.getElementById(elem_id); if (e) e.innerHTML = html; }"

pub fn update_element_html(elem_id: String, html: String) -> Unit {
  update_element_html_impl(elem_id, html)
}

/// Query whether element exists (useful for checking render state)
extern "js" fn element_exists_impl(elem_id: String) -> Bool =
  "(elem_id) => !!document.getElementById(elem_id)"

pub fn element_exists(elem_id: String) -> Bool {
  element_exists_impl(elem_id)
}

// ============================================================================
// THE COMPONENT CONTRACT
// ============================================================================
//
// The old flat contract lived here — `Component = (DomNode, () -> String)` plus
// component()/get_narrative()/get_visual(). It's retired. A component is now a
// **Dual** = `(DomNode, () -> NarrativeNode)` (see dual.mbt): the narrative half is a
// composable *node*, not a flat string. Read one with `dual_read`; compose many into a
// `Surface`. The String form had no consumers left; it's gone.

// ============================================================================
// ZOOM LEVELS (for Event Stream and other zoom-aware components)
// ============================================================================

/// Three density levels for rendering data
pub enum ZoomLevel {
  ZoomedOut    // dense, minimal — many items visible, sparse detail
  Default      // summary — one line per item, standard view
  ZoomedIn     // detail — expanded single item, full information
}

/// Helper: Create default zoom level
pub fn zoom_default() -> ZoomLevel {
  Default
}

/// Helper: Create zoomed out level
pub fn zoom_out() -> ZoomLevel {
  ZoomedOut
}

/// Helper: Create zoomed in level
pub fn zoom_in() -> ZoomLevel {
  ZoomedIn
}

/// Helper: Convert zoom level to CSS class name
pub fn zoom_to_css_class(zoom: ZoomLevel) -> String {
  match zoom {
    ZoomedOut => "zoom-out"
    Default => ""
    ZoomedIn => "zoom-in"
  }
}

// ============================================================================
// NARRATIVE RENDERING (for complex components with zoom-aware narrative)
// ============================================================================

/// Narrative with three zoom levels — matching visual zoom levels
/// Used by complex components like event_stream, knowledge view, memory graph
pub struct NarrativeRender {
  pub summary: () -> String    // zoomed out: strategic summary
  pub detail: () -> String     // default: detailed but scannable
  pub full: () -> String       // zoomed in: everything
}

/// Helper: Get narrative at zoom level
pub fn get_narrative_at_zoom(narrative: NarrativeRender, zoom: ZoomLevel) -> String {
  match zoom {
    ZoomedOut => (narrative.summary)()
    Default => (narrative.detail)()
    ZoomedIn => (narrative.full)()
  }
}

// ============================================================================
// ACTION DEFINITIONS (for self-documenting interactive components)
// ============================================================================

/// Declaration of an action a component can accept
/// Used for AI-readability (instance can read what's possible)
/// and for URL hash mapping (camera targets to actions)
pub struct ActionDef {
  pub name: String           // "focus_entity", "expand_event", "zoom_in"
  pub description: String    // human/AI readable explanation
  pub param_type: String     // type of parameter: "String", "Int", "EventId", "" if no param
}
