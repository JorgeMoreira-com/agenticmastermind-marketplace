# Get Help

## Common Issues

### "Plugin not loading" or validation errors

```bash
# Validate the marketplace structure
claude plugin validate .

# Or from within Claude Code
/plugin validate .
```

Check for: missing commas in JSON, duplicate plugin names, `..` in source paths.

### Skills not appearing after install

- Verify each skill has a `SKILL.md` file (exact capitalized name)
- Restart your Claude Code session or run `/reload-plugins`

### Sync overwrites a skill I customized

Mark it as customized before syncing:

```bash
./scripts/sync.sh --mark-custom google-workspace gws-gmail
```

To see what upstream changed vs your local version:

```bash
./scripts/sync.sh --diff google-workspace gws-gmail
```

### `gws` command not found

```bash
./scripts/setup.sh --plugin google-workspace
```

This checks and installs all dependencies including Node.js, npm, gh, jq, and the `gws` CLI.

### Authentication fails on private repo

```bash
# Check GitHub CLI auth
gh auth status

# For auto-updates, set token in your shell config
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

### Git timeout when installing plugins

```bash
export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000   # 5 minutes
```

### Node.js / npm not found in scripts

The scripts auto-load nvm and Homebrew, but if your setup differs:

```bash
# Verify node is accessible
source ~/.nvm/nvm.sh && node --version

# Or add to your shell profile
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

## Frequently Asked Questions

### How do I add the marketplace to Claude Code?

```
/plugin marketplace add JorgeMoreira-com/agenticmastermind-marketplace
/plugin install google-workspace@agenticmastermind
```

### How do I update skills when upstream changes?

```bash
./scripts/sync.sh
```

Customized skills are protected. Non-customized skills are updated automatically.

### How do I add a new plugin to the marketplace?

Use the maintenance skill for a full walkthrough:

```
/marketplace-admin:marketplace-maintain
```

Or see the [README](README.md#adding-new-plugins) for the quick version.

### How do I check sync status?

```bash
./scripts/sync.sh --status                                # See upstream sync state
./scripts/setup.sh --plugin google-workspace --check      # Verify dependencies
```

### Where do plugin components go?

All components must be at the **plugin root**, not inside `.claude-plugin/`:

```
plugins/my-plugin/
├── .claude-plugin/plugin.json    # Only manifest goes here
├── skills/                       # Skills
├── commands/                     # Commands
├── agents/                       # Subagents
├── hooks/hooks.json              # Hooks
├── .mcp.json                     # MCP servers
├── .lsp.json                     # LSP servers
└── scripts/                      # Utility scripts
```

### How do auto-updates work?

1. Claude Code checks for marketplace updates on startup
2. If versions changed in `marketplace.json`, plugins are refreshed
3. Set `GITHUB_TOKEN` in your shell config for private repo auto-updates
4. Manual update: `/plugin marketplace update`

## Contact

- **Issues**: Open an issue on this repository
- **Email**: admin@agenticmastermind.ai
- **Website**: [agenticmastermind.ai](https://agenticmastermind.ai)
