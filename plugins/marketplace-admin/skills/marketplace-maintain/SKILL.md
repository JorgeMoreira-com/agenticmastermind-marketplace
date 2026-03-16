---
name: marketplace-maintain
description: "Maintain the agenticmastermind marketplace — sync upstream skills, version plugins, validate structure, release updates, and manage customizations. Use when adding plugins, pulling upstream changes, preparing releases, or troubleshooting the marketplace."
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Marketplace Maintenance

This skill covers all maintenance operations for the agenticmastermind marketplace.

## Marketplace Structure

```
agenticmastermind-marketplace/
├── .claude-plugin/
│   └── marketplace.json           # Marketplace catalog (name, owner, plugins list)
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json        # Plugin manifest (NO version — version lives in marketplace.json)
│       ├── dependencies.json      # What this plugin needs installed
│       ├── skills/                # Agent skills (SKILL.md per directory)
│       │   └── <skill-name>/
│       │       └── SKILL.md
│       ├── commands/              # Slash commands (.md files)
│       │   └── <command>.md
│       ├── agents/                # Custom subagents (.md files)
│       │   └── <agent>.md
│       ├── hooks/                 # Event hooks
│       │   └── hooks.json
│       ├── scripts/               # Utility scripts for hooks/setup
│       │   └── <script>.sh
│       ├── .mcp.json              # MCP server definitions
│       ├── .lsp.json              # LSP server configurations
│       └── settings.json          # Default plugin settings
├── scripts/
│   ├── setup.sh                   # Check/install dependencies for a plugin
│   ├── sync.sh                    # Pull upstream skill updates
│   └── install.sh                 # Deploy skills to Claude Code, Codex, etc.
├── sources.json                   # Tracks upstream repos and customization state
└── .gitignore
```

## Plugin Component Types

A plugin can contain any combination of these 7 component types:

| Component | Location | Format | Purpose |
|-----------|----------|--------|---------|
| **Skills** | `skills/<name>/SKILL.md` | Directory with SKILL.md | Reusable agent instructions, invoked as `/<plugin>:<skill>` |
| **Commands** | `commands/<name>.md` | Markdown files | Slash commands invoked as `/<plugin>:<command>` |
| **Agents** | `agents/<name>.md` | Markdown with frontmatter | Custom subagents Claude can invoke for specialized tasks |
| **Hooks** | `hooks/hooks.json` | JSON config | Shell commands triggered by events (PreToolUse, PostToolUse, etc.) |
| **MCP Servers** | `.mcp.json` | JSON config | External tool integrations via Model Context Protocol |
| **LSP Servers** | `.lsp.json` | JSON config | Code intelligence (go-to-definition, diagnostics, hover) |
| **Output Styles** | `styles/` | Directory | Custom formatting for Claude's output |

### Skills (`skills/`)

```
skills/
├── my-skill/
│   ├── SKILL.md           # Required: agent instructions
│   ├── reference.md       # Optional: supporting docs
│   └── scripts/           # Optional: utility scripts
│       └── helper.sh
```

SKILL.md frontmatter (all fields optional, `description` recommended):

| Field | Purpose |
|-------|---------|
| `name` | Display name, becomes `/skill-name`. Defaults to directory name |
| `description` | When Claude should use this skill (used for auto-invocation decisions) |
| `allowed-tools` | Restrict tools: `Read, Grep, Glob, Bash(npm *)` |
| `disable-model-invocation` | `true` = only user can invoke (for side-effect workflows like deploy) |
| `user-invocable` | `false` = hide from `/` menu (for background knowledge Claude auto-loads) |
| `model` | Override model: `sonnet`, `opus`, `haiku`, or full ID like `claude-opus-4-6` |
| `context` | `fork` = run in isolated subagent (no conversation history) |
| `agent` | Subagent type when `context: fork`: `Explore`, `Plan`, `general-purpose`, or custom name |
| `argument-hint` | Shown in autocomplete: `[file-path]`, `[issue-number]` |
| `hooks` | Hooks scoped to this skill's lifecycle |

Advanced skill features:
- **Arguments**: `$ARGUMENTS` (all args), `$0`, `$1` (positional) in content
- **Dynamic context**: `` !`command` `` runs shell before sending to Claude — output replaces placeholder
- **Supporting files**: Add `reference.md`, `examples/`, `scripts/` alongside SKILL.md
- **Extended thinking**: Include "ultrathink" anywhere in content

### Commands (`commands/`)

Simple markdown files — lighter than skills, no directory wrapper needed:
```markdown
---
description: What this command does
---

Instructions for the command...
```

### Agents (`agents/`)

Custom subagents with isolated context, model control, and tool restrictions:

```markdown
---
name: agent-name
description: What this agent specializes in (Claude uses this to auto-delegate)
tools: Read, Grep, Glob, Bash           # Allowlist (omit to inherit all)
disallowedTools: Write, Edit            # Denylist
model: sonnet                           # sonnet, opus, haiku, inherit, or full ID
permissionMode: default                 # default, acceptEdits, dontAsk, bypassPermissions, plan
maxTurns: 20                            # Max agentic turns before stopping
skills:                                 # Preload full skill content at startup
  - api-conventions
memory: user                            # Persistent memory: user, project, or local
background: false                       # true = always run as background task
isolation: worktree                     # Run in isolated git worktree
mcpServers:                             # Scoped MCP servers
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---

System prompt. This is the ONLY prompt the subagent receives (no conversation history).
```

Key agent rules:
- Subagents **cannot spawn other subagents**
- Plugin agents do NOT support `hooks`, `mcpServers`, or `permissionMode` — copy to `.claude/agents/` if needed
- `memory: user` builds persistent knowledge across sessions
- `background: true` agents run concurrently — permissions pre-approved before launch

### Hooks (`hooks/hooks.json`)

Event handlers that run shell commands, LLM prompts, or agentic verifiers:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
          }
        ]
      }
    ]
  }
}
```

**All available events:**

| Event | Fires when | Matcher input |
|-------|-----------|---------------|
| `PreToolUse` | Before tool use | Tool name |
| `PostToolUse` | After successful tool use | Tool name |
| `PostToolUseFailure` | After failed tool use | Tool name |
| `UserPromptSubmit` | User submits prompt | — |
| `SessionStart` / `SessionEnd` | Session lifecycle | — |
| `Stop` | Claude attempts to stop | — |
| `PreCompact` | Before conversation compaction | — |
| `TaskCompleted` | Task marked complete | — |
| `SubagentStart` / `SubagentStop` | Subagent lifecycle | Agent type name |
| `TeammateIdle` | Agent team member idle | — |
| `Notification` / `PermissionRequest` | UI events | — |

**Hook types:**
- `command` — Shell script. Exit 0 = allow, exit 2 = block (stderr sent to Claude)
- `prompt` — LLM evaluation (uses `$ARGUMENTS` for context)
- `agent` — Agentic verifier with tool access for complex validation

### MCP Servers (`.mcp.json`)

Connect Claude to external tools/services via Model Context Protocol:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "API_KEY": "${MY_API_KEY}" },
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

- **Use `${CLAUDE_PLUGIN_ROOT}`** for ALL paths — plugins are cached to `~/.claude/plugins/cache/`
- Servers start automatically when the plugin is enabled
- Tools integrate seamlessly into Claude's toolkit
- Can scope servers to specific subagents via the agent's `mcpServers` field
- Supports `stdio`, `http`, `sse`, and `ws` transport types

### LSP Servers (`.lsp.json`)

Real-time code intelligence — type info, go-to-definition, diagnostics, hover:
```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": { ".go": "go" },
    "restartOnCrash": true,
    "maxRestarts": 3
  }
}
```

The language server binary must be installed separately. Official marketplace plugins: `pyright-lsp` (Python), `typescript-lsp`, `rust-lsp`.

### Output Styles (`styles/`)

Custom formatting rules for Claude's output responses.

## Key Rules

- **Version only in marketplace.json** — never set `version` in `plugin.json` for relative-path plugins. The marketplace entry is the authority.
- **Plugin names are kebab-case** — no spaces, max 64 characters.
- **All components for this project go in the marketplace** — never create standalone skills, commands, agents, or hooks outside the plugin structure.
- **`pluginRoot`** is set to `./plugins` in marketplace.json, so plugin sources use just the directory name (e.g., `"source": "google-workspace"`).
- **All paths must be relative** — start with `./`, never use `../` to escape the plugin directory.
- **Use `${CLAUDE_PLUGIN_ROOT}`** in hooks and MCP configs — plugins are copied to cache on install, so hardcoded paths break.
- **Components at plugin root, not in `.claude-plugin/`** — only `plugin.json` goes in `.claude-plugin/`.

---

## 1. Sync Upstream Skills

Pull latest skills from upstream source repos while protecting local customizations.

```bash
# Sync all sources
./scripts/sync.sh

# Sync a specific source
./scripts/sync.sh google-workspace

# Check current sync state
./scripts/sync.sh --status
```

### Customization protection

```bash
# Mark a skill as customized (won't be overwritten on sync)
./scripts/sync.sh --mark-custom <source> <skill-name>

# Unmark (allow overwrite again)
./scripts/sync.sh --unmark-custom <source> <skill-name>

# Compare your local version vs upstream
./scripts/sync.sh --diff <source> <skill-name>
```

Customized skills are tracked in `sources.json` under the `customized` array. The sync script skips these and warns you.

---

## 2. Add a New Plugin

### From an upstream repo (synced)

1. Add entry to `sources.json`:
```json
{
  "name": "new-source",
  "repo": "https://github.com/org/repo.git",
  "branch": "main",
  "upstreamSkillsPath": "skills",
  "plugin": "new-plugin",
  "lastSyncedCommit": null,
  "lastSyncedAt": null,
  "customized": []
}
```

2. Create plugin structure (include only the component directories you need):
```bash
mkdir -p plugins/new-plugin/.claude-plugin
mkdir -p plugins/new-plugin/skills      # Agent skills
mkdir -p plugins/new-plugin/commands    # Slash commands
mkdir -p plugins/new-plugin/agents      # Custom subagents
mkdir -p plugins/new-plugin/hooks       # Event hooks
mkdir -p plugins/new-plugin/scripts     # Utility scripts
mkdir -p plugins/new-plugin/styles      # Output styles
# Also create .mcp.json and .lsp.json at plugin root if needed
```

3. Create `plugins/new-plugin/.claude-plugin/plugin.json`:
```json
{
  "name": "new-plugin",
  "description": "Description of the plugin",
  "author": { "name": "Agentic Mastermind", "email": "admin@agenticmastermind.ai" },
  "license": "Apache-2.0",
  "keywords": ["relevant", "keywords"]
}
```

4. Create `plugins/new-plugin/dependencies.json` with core and plugin-specific deps.

5. Add to marketplace.json plugins array:
```json
{
  "name": "new-plugin",
  "source": "new-plugin",
  "description": "Description",
  "version": "1.0.0",
  "author": { "name": "Agentic Mastermind", "email": "admin@agenticmastermind.ai" },
  "keywords": ["relevant", "keywords"],
  "category": "category-name"
}
```

6. Run sync: `./scripts/sync.sh new-source`

### From scratch (no upstream)

Follow steps 2-5 above, skip the `sources.json` entry, and create SKILL.md files manually.

---

## 3. Add Components to an Existing Plugin

### Add a skill
```bash
mkdir -p plugins/<plugin>/skills/<skill-name>
```
Create `plugins/<plugin>/skills/<skill-name>/SKILL.md` with frontmatter (`name`, `description`, optionally `allowed-tools`, `model`, `context`, `agent`).

If hand-written (not from upstream), mark it as customized:
```bash
./scripts/sync.sh --mark-custom <source> <skill-name>
```

### Add a command
Create `plugins/<plugin>/commands/<command-name>.md`:
```markdown
---
description: What this command does
---

Instructions...
```

### Add a subagent
Create `plugins/<plugin>/agents/<agent-name>.md`:
```markdown
---
name: agent-name
description: What this agent specializes in
---

System prompt for the agent...
```

### Add hooks
Create or edit `plugins/<plugin>/hooks/hooks.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh" }]
      }
    ]
  }
}
```
Make sure scripts are executable: `chmod +x plugins/<plugin>/scripts/*.sh`

### Add an MCP server
Create or edit `plugins/<plugin>/.mcp.json`:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/my-server",
      "args": ["--flag"],
      "env": { "KEY": "value" }
    }
  }
}
```

### Add an LSP server
Create or edit `plugins/<plugin>/.lsp.json`:
```json
{
  "python": {
    "command": "pyright-langserver",
    "args": ["--stdio"],
    "extensionToLanguage": { ".py": "python" }
  }
}
```
Install the language server binary separately — the plugin only configures the connection.

### Custom component paths
If components live in non-default directories, declare them in `plugin.json`:
```json
{
  "name": "my-plugin",
  "commands": ["./custom/commands/"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./config/mcp.json",
  "lspServers": "./config/lsp.json"
}
```
Custom paths **supplement** default directories — they don't replace them.

---

## 4. Versioning and Releases

### SemVer rules

| Change | Bump | Example |
|--------|------|---------|
| New skills added | Minor | 1.0.0 → 1.1.0 |
| Skill content updated | Patch | 1.1.0 → 1.1.1 |
| Skills removed or renamed | Major | 1.1.1 → 2.0.0 |
| Breaking frontmatter changes | Major | 1.1.1 → 2.0.0 |
| New plugin added | Minor (marketplace) | 1.0.0 → 1.1.0 |

### Release process

1. Update the plugin version in `marketplace.json` (the `version` field in the plugin entry).
2. Update `metadata.version` in marketplace.json if the marketplace itself changed.
3. Commit with a descriptive message:
   ```
   chore: bump google-workspace to 1.1.0 — synced 3 new upstream skills
   ```
4. Tag the release:
   ```bash
   git tag v1.1.0
   git push origin main --tags
   ```
5. Users with auto-update enabled get the changes on next Claude Code startup. Others run:
   ```
   /plugin marketplace update
   ```

### Release channels (optional)

For stable/latest split, create two marketplace repos pointing to different refs:
- `stable-marketplace` → pinned to a release tag
- `latest-marketplace` → tracks `main` branch

---

## 5. Validate the Marketplace

### CLI validation

```bash
claude plugin validate .
```

Or from within Claude Code:
```
/plugin validate .
```

### Manual checklist

**Marketplace level:**
- [ ] `.claude-plugin/marketplace.json` exists and has valid JSON
- [ ] Every plugin in the `plugins` array has `name` and `source`
- [ ] No duplicate plugin names
- [ ] No `..` in source paths
- [ ] `pluginRoot` matches actual directory layout

**Plugin level:**
- [ ] Each plugin directory has `.claude-plugin/plugin.json`
- [ ] Plugin `plugin.json` does NOT contain `version` (version is in marketplace.json)
- [ ] All component directories are at plugin root, NOT inside `.claude-plugin/`

**Skills:**
- [ ] Every skill directory contains a `SKILL.md` file (exact name, capitalized)
- [ ] SKILL.md frontmatter has at least `description`

**Commands:**
- [ ] Command files are `.md` with `description` in frontmatter

**Agents:**
- [ ] Agent files have `name` and `description` in frontmatter

**Hooks:**
- [ ] `hooks.json` has valid JSON with correct event names (case-sensitive)
- [ ] All scripts referenced are executable (`chmod +x`)
- [ ] Paths use `${CLAUDE_PLUGIN_ROOT}`, not hardcoded paths

**MCP Servers:**
- [ ] `.mcp.json` has valid JSON
- [ ] Server commands exist and are executable
- [ ] Paths use `${CLAUDE_PLUGIN_ROOT}`

**LSP Servers:**
- [ ] `.lsp.json` has valid JSON
- [ ] Language server binaries are installed on the system
- [ ] `extensionToLanguage` maps are correct

### Test locally

```bash
# Add marketplace for testing
/plugin marketplace add ./agenticmastermind-marketplace

# Install a plugin
/plugin install google-workspace@agenticmastermind

# Verify skills appear
/google-workspace:gws-gmail
```

---

## 6. Deploy Skills to Agents

The install script deploys skills to any supported agent's global skill directory.

```bash
# Auto-detect agents on this machine
./scripts/install.sh

# Target specific agent
./scripts/install.sh --agent claude
./scripts/install.sh --agent codex

# Install all agents
./scripts/install.sh --agent all

# Filter by plugin or skill
./scripts/install.sh --agent claude --plugin google-workspace
./scripts/install.sh --agent codex --skill gws-gmail

# Uninstall
./scripts/install.sh --uninstall --agent codex --plugin google-workspace

# List detected agents
./scripts/install.sh --list-agents
```

### Supported agents

| Agent | Global dir | Detection |
|-------|-----------|-----------|
| Claude Code | `~/.claude/skills/` | `~/.claude` exists |
| Codex | `~/.codex/skills/` | `~/.codex` exists |
| Gemini CLI | `~/.gemini/skills/` | `~/.gemini` exists |
| GitHub Copilot | `~/.copilot/skills/` | `~/.copilot` exists |
| Cursor | `~/.cursor/skills/` | `~/.cursor` exists |
| Amp | `~/.config/agents/skills/` | `~/.config/amp` exists |

---

## 7. Private Distribution

### GitHub (recommended)

```bash
git push origin main
```

Users add with:
```
/plugin marketplace add JorgeMoreira-com/agenticmastermind-marketplace
```

### Auto-update for private repos

Set `GITHUB_TOKEN` or `GH_TOKEN` in shell config so auto-updates work at Claude Code startup:
```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

### Team auto-registration

Add to a project's `.claude/settings.json` so team members get the marketplace automatically:
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

---

## 8. Troubleshooting

| Problem | Solution |
|---------|----------|
| Plugin not loading | Run `claude plugin validate .` or `claude --debug` to see loading errors |
| Relative path fails | Ensure `pluginRoot` is set and source uses dir name only |
| Skills not discovered | Verify `SKILL.md` (exact capitalized name) in a subdirectory of `skills/` |
| Commands not appearing | Ensure `.md` files are in `commands/` at plugin root, not inside `.claude-plugin/` |
| Agent not available | Check frontmatter has `name` and `description` |
| Hooks not firing | Verify event name is case-sensitive (`PostToolUse` not `postToolUse`), scripts are `chmod +x`, paths use `${CLAUDE_PLUGIN_ROOT}` |
| MCP server fails to start | Test server manually, check `claude --debug` for init errors, verify `${CLAUDE_PLUGIN_ROOT}` paths |
| LSP "Executable not found" | Install the language server binary (`pip install pyright`, `npm install -g typescript-language-server`, etc.) |
| Conflicting manifests | If using `strict: false` in marketplace entry, remove component declarations from `plugin.json` |
| Sync overwrites customized skill | Run `./scripts/sync.sh --mark-custom <source> <skill>` |
| Auth fails on private repo | Check `gh auth status`, set `GITHUB_TOKEN` for auto-updates |
| Version not updating for users | Ensure version changed in marketplace.json, not just plugin.json |
| Git timeout on install | `export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000` |
| Files not found after install | Plugins are cached — use `${CLAUDE_PLUGIN_ROOT}` for paths, use symlinks for shared files |

---

## 9. Common Workflows

### Morning sync
```bash
./scripts/sync.sh
./scripts/setup.sh --plugin google-workspace --check
```

### Add upstream skills, customize one, release
```bash
./scripts/sync.sh google-workspace
# Edit the skill you want to customize
./scripts/sync.sh --mark-custom google-workspace gws-gmail
# Bump version in marketplace.json
git add -A && git commit -m "feat: customize gws-gmail, sync latest upstream"
git tag v1.2.0 && git push origin main --tags
```

### Validate before pushing
```bash
claude plugin validate .
git push origin main
```
