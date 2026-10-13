#!/bin/sh
# End-to-end tests for bin/sync-tab-title. Runs the hook against a fake herdr
# CLI that serves canned JSON from a temp directory and logs every call, so
# the state file, the herdr calls and the early exits are checked without a
# real herdr server.
# Run with: sh tests/hook_test.sh

set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
failures=0
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

# setup: fresh temp dir with a fake herdr and an empty plugin state dir.
setup() {
	dir=$(mktemp -d "$tmp_root/case.XXXXXX")
	mkdir "$dir/state"
	cat >"$dir/herdr" <<'FAKE'
#!/bin/sh
dir=$(dirname "$0")
printf '%s\n' "$*" >>"$dir/calls.log"
case "$1 $2" in
"pane get") cat "$dir/pane.json" ;;
"pane layout") cat "$dir/layout.json" ;;
"tab get") cat "$dir/tab.json" ;;
"workspace get") cat "$dir/workspace.json" ;;
"pane list") cat "$dir/panes.json" ;;
"tab rename") jq -n --arg l "$4" '{result: {tab: {label: $l}}}' ;;
esac
FAKE
	chmod +x "$dir/herdr"
}

# given AGENT TITLE PANE FOCUSED TAB_LABEL TOKEN: write the canned responses
# for a workspace w1 with one tab w1:t1 that is active.
given() {
	jq -n --arg a "$1" --arg t "$2" --arg p "$3" \
		'{result: {pane: {agent: $a, terminal_title_stripped: $t, pane_id: $p,
		  tab_id: "w1:t1", workspace_id: "w1",
		  agent_session: {value: "thread-1"}}}}' >"$dir/pane.json"
	jq -n --arg f "$4" '{result: {layout: {focused_pane_id: $f}}}' >"$dir/layout.json"
	jq -n --arg p "$3" '{result: {panes: [{pane_id: $p, tab_id: "w1:t1"}]}}' >"$dir/panes.json"
	jq -n --arg l "$5" '{result: {tab: {label: $l}}}' >"$dir/tab.json"
	jq -n --arg v "$6" '{result: {workspace: {active_tab_id: "w1:t1",
		tokens: (if $v == "" then {} else {session_title: $v} end)}}}' >"$dir/workspace.json"
}

# codex_names NAME...: write a Codex session index where thread-1 was named
# each NAME in turn, plus an unrelated thread.
codex_names() {
	mkdir -p "$dir/codex"
	jq -nc '{id: "thread-2", thread_name: "Other thread"}' >"$dir/codex/session_index.jsonl"
	for name in "$@"; do
		jq -nc --arg n "$name" '{id: "thread-1", thread_name: $n}' >>"$dir/codex/session_index.jsonl"
	done
}

# run_hook PANE: run the hook as herdr would for an event on PANE.
run_hook() {
	HERDR_BIN_PATH="$dir/herdr" HERDR_PANE_ID=$1 HERDR_PLUGIN_STATE_DIR="$dir/state" \
		CODEX_HOME="$dir/codex" sh "$repo/bin/sync-tab-title"
}

# run_tab_closed: run the hook as herdr would for tab.closed in w1, which
# carries a workspace id but no pane id.
run_tab_closed() {
	HERDR_BIN_PATH="$dir/herdr" HERDR_PANE_ID="" HERDR_WORKSPACE_ID=w1 HERDR_PLUGIN_STATE_DIR="$dir/state" \
		CODEX_HOME="$dir/codex" sh "$repo/bin/sync-tab-title"
}

# check NAME CONDITION...: report whether the condition command succeeds.
check() {
	name=$1
	shift
	if "$@"; then
		echo "ok   $name"
	else
		echo "FAIL $name"
		failures=$((failures + 1))
	fi
}

called() { grep -Fxq -- "$1" "$dir/calls.log"; }
not_called() { ! grep -q -- "$1" "$dir/calls.log"; }
state_is() { [ "$(cat "$dir/state/w1_t1" 2>/dev/null)" = "$1" ]; }

setup
given claude "Fix login" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "renames an auto-named tab" called "tab rename w1:t1 Fix login"
check "remembers the label it set" state_is "Fix login"
check "sets the workspace token" \
	called "workspace report-metadata w1 --source herdr-tab-titles --token session_title=Fix login"

setup
given claude "Fix login" w1:p1 w1:p1 "logs" ""
run_hook w1:p1
check "keeps a manual tab rename" not_called "tab rename"

setup
printf '%s' "Fix login" >"$dir/state/w1_t1"
given claude "Add tests" w1:p1 w1:p1 "Fix login" "Fix login"
run_hook w1:p1
check "follows its own earlier label" called "tab rename w1:t1 Add tests"

setup
given "" "zsh" w1:p1 w1:p1 "Fix login" "Fix login"
run_hook w1:p1
check "clears the token when a shell is shown" \
	called "workspace report-metadata w1 --source herdr-tab-titles --clear-token session_title"
check "leaves the tab alone for a shell" not_called "tab rename"

setup
given "" "zsh" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "skips clearing an absent token" not_called "report-metadata"

setup
given claude "Fix login" w1:p2 w1:p1 "1" ""
run_hook w1:p2
check "ignores an unfocused pane" not_called "rename\|report-metadata"

setup
given claude "$(printf 'Fix\a login')" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "strips control characters from titles" called "tab rename w1:t1 Fix login"

setup
codex_names "Draft name" "Export PDF pages"
given codex "codex" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "renames a tab from the latest Codex thread name" called "tab rename w1:t1 Export PDF pages"

setup
codex_names
given codex "codex" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "ignores the terminal title of an unnamed Codex thread" not_called "tab rename"

setup
given pi "π - repo" w1:p1 w1:p1 "1" "Fix login"
run_hook w1:p1
check "clears the token when Pi is shown" \
	called "workspace report-metadata w1 --source herdr-tab-titles --clear-token session_title"
check "leaves a Pi tab alone" not_called "tab rename"

setup
given pi "π - repo" w1:p2 w1:p2 "1" "Fix login"
run_tab_closed
check "tab.closed clears the token when the newly shown pane has no title" \
	called "workspace report-metadata w1 --source herdr-tab-titles --clear-token session_title"

setup
given claude "Add tests" w1:p2 w1:p2 "1" "Fix login"
run_tab_closed
check "tab.closed shows the newly shown pane's title" \
	called "workspace report-metadata w1 --source herdr-tab-titles --token session_title=Add tests"

setup
given claude "Fix login" w1:p1 w1:p1 "1" ""
run_hook w1:p1
check "releases the lock" test ! -e "$dir/state/.lock"

if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
