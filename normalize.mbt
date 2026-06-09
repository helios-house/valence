/// Valence Normalization Boundary
///
/// Clean JSON-LD from Fluree before it enters components.
/// Components work with native MoonBit types only.

/// Convert Fluree URI to DOM-safe key (for element IDs, CSS classes)
///
/// Example:
///   "http://helios.local/schema/Heartbeat" → "Heartbeat"
///   "ex:ev-001" → "ev-001"
pub fn uri_to_key(uri: String) -> String {
  uri
    .replace(old="http://helios.local/schema/", new="")
    .replace(old="http://helios.local/", new="")
    .replace(old="https://helios.local/", new="")
    .replace(old="ex:", new="")
    .replace(old="/", new="-")
    .replace(old=":", new="-")
    .replace(old="#", new="-")
    .replace(old=".", new="-")
}

/// Normalize instance name for use in CSS classes and IDs
///
/// Example: "Claude Code Opus" → "claude-code-opus"
pub fn normalize_instance_name(name: String) -> String {
  name
    .to_lower()
    .replace(old=" ", new="-")
    .replace(old="_", new="-")
    .replace(old=".", new="-")
}

/// Truncate message to max length with ellipsis
pub fn truncate_string(s: String, max_len: Int) -> String {
  if s.length() > max_len {
    s[0:max_len - 3].to_owned() + "..."
  } else {
    s
  }
}

/// Format relative time from ISO timestamp
/// Example: "2026-05-24 14:30:00" with load_time "2026-05-24 14:35:00" → "5 min ago"
pub fn format_relative_time(timestamp: String, load_time: String) -> String {
  // Simplified: just return timestamp for now
  // Full implementation: parse ISO, compute delta, format as "X min/hour/day ago"
  timestamp
}
