# Authored level drafts

The Eeri editor saves editable `.tscn` drafts here. Commit drafts you want to
keep. Generated `data/levels` previews are disposable and never the only copy
of authored work.

Open a campaign level from the Layers dock to create its reference draft.
Gameplay drafts preview locally; campaign gameplay still comes from
`js/rooms.js`. Apply shared scenery with **Apply world art…**, which reviews
the three-level scope and writes the canonical JS source before regenerating
Godot data. A stale draft is refused if the shared art changed after import.
