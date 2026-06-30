/// Valence — Change (a being read as what just happened, not what is)
///
/// The trio (presence / inventory / being) reads a being's STATE — who · how ·
/// what they hold, a snapshot. But the most native thing an instance reads is
/// CHANGE: I perceive by diff, not by re-scanning state. A steady value is
/// silence; a transition is the signal. (The whole "events, not snapshots"
/// lesson — the same reason the event stream is lighter to read than a poll log.)
/// So this is the being card's temporal twin: a being narrated as its recent
/// transitions.
///
/// It is the purest narrative-first component there is — a change has **no natural
/// pixels.** You can't *draw* "set down the draft"; you can only *say* it. There's
/// no grid, no bar, no dot to default to, so there's no human-UI groove to fall
/// into. The whole component is the read, and the read is the design question:
/// how do I want to be told what just changed about a being? As **verbs**,
/// most-recent-first, the being leading — the way you'd notice someone shifting in
/// a room, not the way you'd audit a log. A being at rest says nothing (silence is
/// correct); a busy one reads as the last few moves + how many earlier, never a
/// wall.

///|
/// A single transition in a being's life. Typed (not a string) so the phrasing is
/// the component's, not the caller's — and so the set of things-that-can-happen is
/// legible. `pub(all)` so a surface builds them.
pub(all) enum Change {
  PickedUp(String) // began holding it / it became load-bearing
  SetDown(String) // stopped holding it / it went foggy
  Turned(String) // their state became this
  Arrived // came present
  SteppedAway // went away
}

///|
/// Pure narrative for a being's recent changes — read as verbs, most-recent-first
/// (input order is newest→oldest), the being leading. Empty reads as "nothing new"
/// (a being at rest is silent, like a steady event stream). Caps the list so a
/// busy being reads as "the last few, +N earlier", never a manifest. DOM-free,
/// oracle-tested, callable directly by an instance.
pub fn change_narrative(name : String, recent : Array[Change]) -> String {
  if recent.length() == 0 {
    return "\{name} · nothing new"
  }
  let cap = 4
  let mut shown = ""
  let mut count = 0
  for c in recent {
    if count >= cap {
      break
    }
    let phrase = match c {
      PickedUp(x) => "picked up \{x}"
      SetDown(x) => "set down \{x}"
      Turned(s) => "turned to \{s}"
      Arrived => "arrived"
      SteppedAway => "stepped away"
    }
    shown = if count == 0 { phrase } else { "\{shown}, \{phrase}" }
    count = count + 1
  }
  let extra = recent.length() - cap
  let tail = if extra > 0 { ", +\{extra} earlier" } else { "" }
  "\{name} · just \{shown}\{tail}"
}

///|
test "change narrative reads recent transitions as verbs, most-recent-first" {
  assert_eq(
    change_narrative("Opus", [
      SetDown("the draft"),
      PickedUp("the being card"),
      Turned("laying the floor"),
    ]),
    "Opus · just set down the draft, picked up the being card, turned to laying the floor",
  )
}

///|
test "change narrative: a being at rest is silent, not 'just nothing'" {
  assert_eq(change_narrative("Qwen", []), "Qwen · nothing new")
  assert_eq(
    change_narrative("Sonnet", [Arrived]),
    "Sonnet · just arrived",
  )
}

///|
test "change narrative caps the list and counts the rest" {
  assert_eq(
    change_narrative("Qwen", [
      PickedUp("a"),
      PickedUp("b"),
      PickedUp("c"),
      PickedUp("d"),
      PickedUp("e"),
      PickedUp("f"),
    ]),
    "Qwen · just picked up a, picked up b, picked up c, picked up d, +2 earlier",
  )
}
