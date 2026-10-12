#!/bin/sh
# Tests for lib/decide.sh: the rules for when a tab is renamed and what the
# workspace title token does.
# Run with: sh tests/decide_test.sh

set -u

# shellcheck source=lib/decide.sh
. "$(dirname "$0")/../lib/decide.sh"

failures=0

# check NAME EXPECTED ACTUAL: compare and report one case.
check() {
	if [ "$3" = "$2" ]; then
		echo "ok   $1"
	else
		echo "FAIL $1: expected '$2', got '$3'"
		failures=$((failures + 1))
	fi
}

# expect NAME EXPECTED ARGS... : check decide_label's output.
expect() {
	name=$1 expected=$2
	shift 2
	check "$name" "$expected" "$(decide_label "$@")"
}

# expect_ws NAME EXPECTED ARGS... : check decide_workspace_token's output.
expect_ws() {
	name=$1 expected=$2
	shift 2
	check "$name" "$expected" "$(decide_workspace_token "$@")"
}

#      name                                  expected     agent  title        pane  focused label        last_set
expect "auto-named tab takes Claude title" "Fix login" claude "Fix login" w1:p1 w1:p1 "1" ""
expect "number label after earlier tab closed" "Fix login" claude "Fix login" w1:p1 w1:p1 "2" ""
expect "follows Claude retitling" "Add tests" claude "Add tests" w1:p1 w1:p1 "Fix login" "Fix login"
expect "keeps a manual rename" "" claude "Fix login" w1:p1 w1:p1 "logs" "Old title"
expect "keeps a manual rename with no history" "" claude "Fix login" w1:p1 w1:p1 "logs" ""
expect "label with digits and text is manual" "" claude "Fix login" w1:p1 w1:p1 "v2" ""
expect "ignores non-Claude agents" "" codex "Fix login" w1:p1 w1:p1 "1" ""
expect "ignores panes without an agent" "" "" "zsh" w1:p1 w1:p1 "1" ""
expect "ignores an empty title" "" claude "" w1:p1 w1:p1 "1" ""
expect "ignores Claude's default title" "" claude "Claude Code" w1:p1 w1:p1 "1" ""
expect "ignores unfocused pane in split tab" "" claude "Fix login" w1:p2 w1:p1 "1" ""
expect "no-op when label already matches" "" claude "Fix login" w1:p1 w1:p1 "Fix login" "Fix login"

#         name                                   expected         agent  title         pane  naming_pane
expect_ws "workspace shows active pane's title" "set:Fix login" claude "Fix login" w1:p1 w1:p1
expect_ws "workspace ignores other panes" "" claude "Fix login" w1:p2 w1:p1
expect_ws "workspace ignores inactive tabs" "" claude "Fix login" w1:p2 ""
expect_ws "workspace clears for non-Claude pane" "clear" "" "zsh" w1:p1 w1:p1
expect_ws "workspace clears for other agents" "clear" codex "Fix login" w1:p1 w1:p1
expect_ws "workspace clears for empty title" "clear" claude "" w1:p1 w1:p1
expect_ws "workspace clears for Claude's default title" "clear" claude "Claude Code" w1:p1 w1:p1

if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
