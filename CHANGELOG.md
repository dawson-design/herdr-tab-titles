# Changelog

## 0.1.0

First public release.

- Names each herdr tab after the session running in it: Claude Code's
  terminal title, or the thread name Codex generates.
- Follows the agent when it retitles the session, and never overwrites a tab
  you renamed yourself.
- Publishes the title as a `$session_title` token on each workspace, for a
  second line in the sidebar, and clears it when the shown pane has no
  session title.
- Requires herdr 0.9.1 or later and `jq`, on macOS or Linux.
