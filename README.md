# agenticmastermind marketplace

Private Claude Code plugin marketplace by [agenticmastermind.ai](https://agenticmastermind.ai).

## Quick Start

```bash
# Add the marketplace
/plugin marketplace add JorgeMoreira-com/agenticmastermind-marketplace

# Install a plugin
/plugin install google-workspace@agenticmastermind
```

## Available Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| **google-workspace** | 93 | Gmail, Drive, Calendar, Sheets, Docs, Chat, Admin, Meet, Keep, Forms, Slides, Tasks — plus 10 personas, 40+ recipes, and workflow automations. Powered by the [`gws` CLI](https://github.com/googleworkspace/cli). |
| **marketplace-admin** | 1 | Maintenance skill for managing this marketplace — syncing, versioning, validating, releasing, and adding new plugins. |

## Plugin Components

Each plugin can contain any combination of these component types:

| Component | What it does |
|-----------|-------------|
| **Skills** | Reusable agent instructions (`SKILL.md`) — the core building block |
| **Commands** | Slash commands (`.md` files) for quick actions |
| **Agents** | Custom subagents with their own model, tools, and permissions |
| **Hooks** | Event handlers that fire on tool use, session start/end, etc. |
| **MCP Servers** | External tool integrations via Model Context Protocol |
| **LSP Servers** | Code intelligence — go-to-definition, diagnostics, hover |
| **Output Styles** | Custom formatting for agent responses |

## Repository Structure

```
agenticmastermind-marketplace/
├── .claude-plugin/
│   └── marketplace.json             # Marketplace catalog
├── plugins/
│   ├── google-workspace/            # 93 skills synced from upstream
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── dependencies.json
│   │   └── skills/
│   └── marketplace-admin/           # Marketplace maintenance
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
├── scripts/
│   ├── setup.sh                     # Check/install dependencies
│   └── sync.sh                      # Pull upstream skill updates
├── sources.json                     # Upstream source tracking
└── .gitignore
```

## Scripts

### `setup.sh` — Environment Setup

Reads a plugin's `dependencies.json` and checks/installs everything needed.

```bash
./scripts/setup.sh --plugin google-workspace           # Check and install
./scripts/setup.sh --plugin google-workspace --check    # Check only
```

### `sync.sh` — Upstream Sync

Pulls latest skills from upstream repos while protecting your customizations.

```bash
./scripts/sync.sh                                         # Sync all sources
./scripts/sync.sh google-workspace                        # Sync one source
./scripts/sync.sh --status                                # Show sync state
./scripts/sync.sh --mark-custom google-workspace gws-gmail  # Protect a skill
./scripts/sync.sh --diff google-workspace gws-gmail         # Compare local vs upstream
```

## Keeping Skills Updated

### Upstream sync

Skills sourced from external repos (like `googleworkspace/cli`) can be synced without overwriting your customizations:

```bash
# Pull latest from all upstream sources
./scripts/sync.sh

# Customize a skill, then protect it from future syncs
vim plugins/google-workspace/skills/gws-gmail/SKILL.md
./scripts/sync.sh --mark-custom google-workspace gws-gmail
```

### Marketplace auto-update

Users with auto-update enabled receive changes on their next Claude Code startup. Others run:

```
/plugin marketplace update
```

## Adding New Plugins

1. Create the plugin directory:
   ```bash
   mkdir -p plugins/my-plugin/.claude-plugin
   mkdir -p plugins/my-plugin/skills/my-skill
   ```

2. Add `plugin.json` and `SKILL.md` files.

3. Register in `marketplace.json`.

4. For upstream-sourced plugins, add an entry to `sources.json` and run `./scripts/sync.sh`.

See the **marketplace-maintain** skill for the full guide on adding plugins, skills, agents, hooks, MCP servers, and all other component types.

## Team Setup

Add to any project's `.claude/settings.json` so team members get the marketplace automatically:

```json
{
  "extraKnownMarketplaces": {
    "agenticmastermind": {
      "source": {
        "source": "github",
        "repo": "JorgeMoreira-com/agenticmastermind-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "google-workspace@agenticmastermind": true
  }
}
```

For auto-updates on private repos, set `GITHUB_TOKEN` in your shell config.

## License

Apache-2.0
