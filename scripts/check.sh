#!/bin/sh
# Lint, format-check and test the plugin. Used locally and by CI.
set -eu
cd "$(dirname "$0")/.."
files="bin/sync-tab-title lib/decide.sh tests/decide_test.sh tests/hook_test.sh scripts/check.sh"
# shellcheck disable=SC2086
shellcheck -s sh -x $files
# shellcheck disable=SC2086
shfmt -d $files
sh tests/decide_test.sh
sh tests/hook_test.sh
