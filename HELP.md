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
- For Claude Code: restart your session or run `/reload-plugins`
- For other agents: confirm the skill was copied to the correct directory with `./scripts/install.sh --list-agents`

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

### Profile lock conflict (gws CLI)

If a previous browser session wasn't closed cleanly:

```bash
rm -f profile/SingletonLock
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

### How do I install skills for Codex?

```bash
./scripts/install.sh --agent codex
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

### Can I use this with Gemini CLI, Cursor, or Copilot?

Yes. SKILL.md is a cross-platform open standard. Use the install script:

```bash
./scripts/install.sh --agent all
```

### How do I check what's installed?

```bash
./scripts/install.sh --list-agents        # See which agents are detected
./scripts/sync.sh --status                # See upstream sync state
./scripts/setup.sh --plugin google-workspace --check   # Verify dependencies
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

For Claude Code users who add the marketplace:

1. Marketplace checks for updates on each Claude Code startup
2. If versions changed in `marketplace.json`, plugins are refreshed
3. Set `GITHUB_TOKEN` for private repo auto-updates

For other agents, re-run `./scripts/install.sh` to get the latest.

## Contact

- **Issues**: Open an issue on this repository
- **Email**: admin@agenticmastermind.ai
- **Website**: [agenticmastermind.ai](https://agenticmastermind.ai)
