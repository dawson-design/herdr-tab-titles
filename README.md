# herdr-tab-titles

A [herdr](https://herdr.dev) plugin that names each tab after the work
happening in it, the way Claude Desktop titles its sessions.

Claude Code and Codex already have the model write a short title for each
session, for example `Fix flaky login test`. This plugin copies that title
into the herdr tab label. It makes no model calls of its own.

## Behaviour

- A tab running a [supported agent](#supported-agents) takes the session's
  title, and follows it when the agent retitles the session.
- In a split tab, the label follows the focused pane when it runs a supported
  agent.
- A tab you rename yourself is left alone. The plugin only replaces herdr's
  automatic number label (any all-digit label) or a label it set itself.
- Each workspace gets a `$session_title` sidebar token with the title of the
  pane it is showing: the focused pane of its active tab. When that pane has no
  session title, the token is cleared. The workspace name is left alone;
  see [Sidebar](#sidebar) to display the token.
- Other agents and plain shells never name a tab.

## Supported agents

| Agent | Setup |
|---|---|
| Claude Code | Works as installed. |
| Codex | Works as installed. The plugin reads the thread name Codex records in `~/.codex/session_index.jsonl` (or `$CODEX_HOME`), matched by the session id herdr reports. That file is internal to Codex; if its format changes, Codex tabs stop being named until the plugin is updated. |
| Pi, Antigravity and others | Not supported yet: they don't generate session titles. |

Each agent also needs its herdr integration, for example
`herdr integration install claude` or `herdr integration install codex`.

## Requirements

- herdr 0.9.1 or later, on macOS or Linux
- `jq` on `PATH`

## Install

```sh
herdr plugin install dawson-design/herdr-tab-titles
```

For local development, link a checkout instead:

```sh
herdr plugin link "$PWD"
```

## Sidebar

herdr only shows the `$session_title` token where your config places it. To
put it on the second line of each workspace entry, add this to
`~/.config/herdr/config.toml` and run `herdr server reload-config`:

```toml
[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace"],
  ["$session_title"],
  ["branch", "git_status"],
]
```

herdr cuts token values at 80 characters, so long titles are shortened in
the sidebar but not on the tab. Tokens don't survive a herdr server restart;
the line stays blank until the agent's next status change or focus change.

## How it works

`herdr-plugin.toml` runs `bin/sync-tab-title` on `pane.agent_status_changed`
and `pane.focused`. The script reads the pane, its tab and the tab's focused
pane through the herdr CLI, then calls `decide_label` and
`decide_workspace_token` in `lib/decide.sh`. Those functions hold every rule
above and have no I/O. The workspace title is published with
`herdr workspace report-metadata`. The last label the plugin set for each tab
is stored in `$HERDR_PLUGIN_STATE_DIR`, so the plugin can tell its own labels
apart from yours. herdr runs hooks concurrently, so the script takes a lock in
that directory to stop two runs from interleaving.

Because the title is read when the agent's status changes, a new title shows
up at the next status change rather than the instant the agent sets it.

## Tests

```sh
sh scripts/check.sh
```

This runs shellcheck, shfmt, the unit tests in `tests/decide_test.sh`, and
`tests/hook_test.sh`, which runs the hook against a fake `herdr` CLI. CI runs the same
script.
