#!/bin/sh
# Tests for lib/decide.sh: the rules for when a tab is renamed and to what.
# Run with: sh tests/decide_test.sh

set -u

# shellcheck source=lib/decide.sh
. "$(dirname "$0")/../lib/decide.sh"

failures=0

# expect NAME EXPECTED ARGS... : run decide_label and compare its output.
expect() {
	name=$1 expected=$2
	shift 2
	actual=$(decide_label "$@")
	if [ "$actual" = "$expected" ]; then
		echo "ok   $name"
	else
		echo "FAIL $name: expected '$expected', got '$actual'"
		failures=$((failures + 1))
	fi
}

#      name                                  expected      agent  title         pane   focused label         number last_set
expect "auto-named tab takes Claude title" "Fix login" claude "Fix login" w1:p1 w1:p1 "2" 2 ""
expect "follows Claude retitling" "Add tests" claude "Add tests" w1:p1 w1:p1 "Fix login" 1 "Fix login"
expect "keeps a manual rename" "" claude "Fix login" w1:p1 w1:p1 "logs" 1 "Old title"
expect "keeps a manual rename with no history" "" claude "Fix login" w1:p1 w1:p1 "logs" 1 ""
expect "ignores non-Claude agents" "" codex "Fix login" w1:p1 w1:p1 "1" 1 ""
expect "ignores panes without an agent" "" "" "zsh" w1:p1 w1:p1 "1" 1 ""
expect "ignores an empty title" "" claude "" w1:p1 w1:p1 "1" 1 ""
expect "ignores Claude's default title" "" claude "Claude Code" w1:p1 w1:p1 "1" 1 ""
expect "ignores unfocused pane in split tab" "" claude "Fix login" w1:p2 w1:p1 "1" 1 ""
expect "no-op when label already matches" "" claude "Fix login" w1:p1 w1:p1 "Fix login" 1 "Fix login"

if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
