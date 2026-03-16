---
name: gws-setup
description: "Set up the agenticmastermind marketplace environment. Checks and installs all required dependencies (Node.js, npm, gh, jq, gws CLI) and authenticates with Google Workspace. Use when onboarding, when dependencies are missing, or before first use of any gws-* skill."
allowed-tools: Bash, Read
---

# Marketplace Setup

Before using any Google Workspace skill, ensure all dependencies are installed and authenticated.

## Step 1: Check dependencies

Read `DEPENDENCIES.json` at the marketplace root to understand what's required. Then run:

```bash
./scripts/setup.sh --check --plugin google-workspace
```

## Step 2: Install missing dependencies

If any checks fail, run without `--check`:

```bash
./scripts/setup.sh --plugin google-workspace
```

Or install individually based on what's missing:

| Dependency | Install |
|-----------|---------|
| Node.js 18+ | `brew install node` or use nvm |
| GitHub CLI | `brew install gh` then `gh auth login` |
| jq | `brew install jq` |
| gws CLI | `npm install -g @googleworkspace/cli` |

## Step 3: Authenticate gws

```bash
gws auth setup     # Creates GCP project + OAuth (requires gcloud)
gws auth login     # Browser-based OAuth login
```

For headless/CI environments:
```bash
gws auth export --unmasked > credentials.json
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/credentials.json
```

## Step 4: Sync skills

```bash
./scripts/sync.sh --status          # Check current sync state
./scripts/sync.sh                   # Pull latest skills from upstream
```

## Verification

After setup, verify everything works:

```bash
gws --version
gws drive files list --params '{"pageSize": 1}'
```
