# Pure decision logic for herdr-tab-titles. Sourced by bin/sync-tab-title
# (which gathers the inputs from herdr) and by tests/decide_test.sh.
# No I/O beyond printing the result, so it can be tested without herdr.
# Variables are prefixed with an underscore so they can't clobber the
# caller's when a function runs outside a subshell.

# Title Claude Code shows before it has named the session.
CLAUDE_DEFAULT_TITLE="Claude Code"

# usable_title AGENT TITLE: succeed when a Claude pane has a real title.
usable_title() {
	[ "$1" = "claude" ] && [ -n "$2" ] && [ "$2" != "$CLAUDE_DEFAULT_TITLE" ]
}

# is_auto_tab_label LABEL: succeed when LABEL is herdr's automatic tab label.
# herdr numbers unnamed tabs by position and treats a tab renamed back to a
# number as unnamed, so any all-digit label counts.
is_auto_tab_label() {
	case $1 in
	'' | *[!0-9]*) return 1 ;;
	*) return 0 ;;
	esac
}

# decide_label: work out the label a tab should get from one of its panes.
#
# Arguments:
#   $1 agent            agent kind in the pane ("claude", "codex", or empty)
#   $2 title            pane terminal title with status glyphs stripped
#   $3 pane_id          pane the event is about
#   $4 focused_pane_id  pane focused inside the pane's tab
#   $5 label            tab's current label
#   $6 last_set         label this plugin last gave the tab, or empty
#
# Prints the new label, or nothing when the tab should be left alone.
# Invariant: a tab whose label is neither automatic nor the plugin's last
# label was renamed by the user and is never touched.
decide_label() {
	_agent=$1 _title=$2 _pane=$3 _focused=$4 _label=$5 _last_set=$6

	usable_title "$_agent" "$_title" || return 0
	# In a split tab only the focused pane names the tab.
	[ "$_pane" = "$_focused" ] || return 0
	if ! is_auto_tab_label "$_label" && [ "$_label" != "$_last_set" ]; then
		return 0
	fi
	[ "$_label" != "$_title" ] || return 0

	printf '%s\n' "$_title"
}

# decide_workspace_token: work out what the workspace's sidebar title token
# should do. The workspace shows the focused pane of its active tab.
#
# Arguments:
#   $1 agent        agent kind in the pane
#   $2 title        pane terminal title with status glyphs stripped
#   $3 pane_id      pane the event is about
#   $4 naming_pane  focused pane of the workspace's active tab, or empty
#
# Prints "set:<title>", "clear" when the shown pane has no usable Claude
# title, or nothing when this pane isn't the one the workspace shows.
decide_workspace_token() {
	_agent=$1 _title=$2 _pane=$3 _naming=$4

	[ "$_pane" = "$_naming" ] || return 0
	if usable_title "$_agent" "$_title"; then
		printf 'set:%s\n' "$_title"
	else
		printf 'clear\n'
	fi
}
