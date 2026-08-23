# GitHub orgs for Omarchy

Bar widget that glances at:

- `jordanpartridge` (user)
- `the-shit`
- `conduit-ui`
- `synapse-sentinel`

Click the GitHub icon for counts (issues, PRs, night-ready, agent-ready, parked) and a ranked list: night-ready, review-needed PRs, agent-ready, then recent activity. Enter or click opens the item in the browser.

| Input | Action |
|---|---|
| Left click | Toggle panel |
| Middle click | Refresh now |
| Right click | Open github.com |
| Super+Shift+G | Toggle panel |
| h/l or arrows | Switch org |
| j/k or arrows | Move through items |
| Enter / Space | Open selected item |
| r | Refresh |

Data comes from `gh` GraphQL into `~/.local/state/omarchy/github-orgs.json` every 10 minutes, and again when the panel opens if the snapshot is stale.
