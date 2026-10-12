# Pure decision logic for herdr-tab-titles. Sourced by bin/sync-tab-title
# (which gathers the inputs from herdr) and by tests/decide_test.sh.
# No I/O beyond printing the result, so it can be tested without herdr.

# Title Claude Code shows before it has named the session.
CLAUDE_DEFAULT_TITLE="Claude Code"

# decide_label: work out the label a tab should get from one of its panes.
#
# Arguments:
#   $1 agent            agent kind in the pane ("claude", "codex", or empty)
#   $2 title            pane terminal title with status glyphs stripped
#   $3 pane_id          pane the event is about
#   $4 focused_pane_id  pane focused inside the pane's tab
#   $5 label            tab's current label
#   $6 number           tab's position; herdr's automatic label is this number
#   $7 last_set         label this plugin last gave the tab, or empty
#
# Prints the new label, or nothing when the tab should be left alone.
# Invariant: a tab whose label is neither herdr's automatic number nor the
# plugin's last label was renamed by the user and is never touched.
decide_label() {
	agent=$1 title=$2 pane_id=$3 focused_pane_id=$4
	label=$5 number=$6 last_set=$7

	[ "$agent" = "claude" ] || return 0
	[ -n "$title" ] || return 0
	[ "$title" != "$CLAUDE_DEFAULT_TITLE" ] || return 0
	# In a split tab only the focused pane names the tab.
	[ "$pane_id" = "$focused_pane_id" ] || return 0
	if [ "$label" != "$number" ] && [ "$label" != "$last_set" ]; then
		return 0
	fi
	[ "$label" != "$title" ] || return 0

	printf '%s\n' "$title"
}
