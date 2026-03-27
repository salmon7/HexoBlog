# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a Hexo blog repository (`hexo` 8.x) using the NexT theme (`hexo-theme-next`) from npm dependencies, not a checked-in `themes/` directory.

Content is markdown-first:
- Posts live in `source/_posts/`
- Static files (including CNAME) live in `source/`
- New content templates are in `scaffolds/`

Site behavior/config is split across:
- `_config.yml` (core Hexo config, routing, deploy target, plugins)
- `_config.next.yml` (NexT theme configuration override)

Generated output is `public/` (gitignored).

## Common commands

Install dependencies:
```bash
npm install
```

Run local dev server:
```bash
npx hexo server
```

Clean generated/cache artifacts:
```bash
npx hexo clean
```

Generate static site into `public/`:
```bash
npx hexo generate
```

Create a new post:
```bash
npx hexo new post "Post Title"
```

Create a new page:
```bash
npx hexo new page "Page Title"
```

Deploy with GitHub Actions (default):
- Workflow: `.github/workflows/deploy-cross-repo.yml`
- Trigger: push to `master` or manual `workflow_dispatch`
- Target: `salmon7/salmon7.github.io` branch `master`
- Required secret in `HexoBlog`: `PUBLISH_DEPLOY_KEY` (private key for writable deploy key configured on target repo)

Local fallback publish workflow:
```bash
./deploy.sh
```

`deploy.sh` assumptions:
- Requires a sibling repo at `../salmon7.github.io`
- Runs clean + generate
- Rsyncs `public/` into that sibling repo
- Commits and pushes `master` there
- Use as fallback path when Actions deploy is unavailable

## Lint / test status

There are currently no explicit lint or test scripts defined in `package.json`.

- Lint: not configured as a project command
- Tests: not configured as a project command
- “Single test” workflow: not applicable in current repo state

For validation, use site generation and local preview:
```bash
npx hexo clean && npx hexo generate && npx hexo server
```

## Minimal change checklists

### When changing post/content

Check first:
- `source/_posts/<post>.md` (front-matter + markdown body)
- Optional static assets under `source/` or post asset folders (when `post_asset_folder: true`)

Validate with:
```bash
npx hexo clean && npx hexo generate && npx hexo server
```

### When changing theme/UI behavior

Check first:
- `_config.next.yml` (NexT customization entrypoint)
- `_config.yml` only if change involves global Hexo behavior (language, permalink, plugin wiring)

Avoid:
- Editing `node_modules/hexo-theme-next/` directly

Validate with:
```bash
npx hexo clean && npx hexo generate && npx hexo server
```

### When changing deploy/publish flow

Check first:
- `.github/workflows/deploy-cross-repo.yml` (default publish path)
- `deploy.sh` (local fallback publish path)
- `_config.yml` deploy section (`type: git`, target repo/branch)
- `source/CNAME` (must keep `blog.zhang7long.com`)

Before running publish:
- Ensure `PUBLISH_DEPLOY_KEY` is configured in source repo secrets and target repo deploy key is writable
- For local fallback, ensure sibling repo `../salmon7.github.io` exists and is a valid git repo

Publish commands:
```bash
# Default: push to master triggers GitHub Actions deploy
git push origin master

# Fallback: local deploy script
./deploy.sh
```

### Before you run commands

- Confirm context first: current path (`pwd`), git root (`git rev-parse --show-toplevel`), and repo roles (source: `HexoBlog`, publish: `../salmon7.github.io`).
- For deploy work, verify target branch/remotes and destination path before sync/push.
- Prefer non-destructive checks first; never run force-rewrite/destructive git or anything that can remove/overwrite `.git` unless explicitly requested.
- Default shell snippets to POSIX `sh`; if using bash/zsh-only syntax, call it out and provide a POSIX-safe alternative.

## Architecture notes for editing safely

- **Content pipeline**: Markdown/front-matter in `source/_posts` -> Hexo render/generate -> static files in `public/`.
- **Theme configuration model**: Keep NexT customizations in `_config.next.yml`; avoid editing package files under `node_modules/hexo-theme-next/`.
- **Deployment model**:
  - Default path is GitHub Actions workflow `.github/workflows/deploy-cross-repo.yml` for cross-repo publish to `salmon7/salmon7.github.io:master`.
  - `deploy.sh` remains local fallback path to sync generated output into sibling publish repo.
- **Domain mapping**: `source/CNAME` contains `blog.zhang7long.com`; preserve it during deployment-related changes.
- **Extra generator**: `hexo-generator-json-content` is enabled via `_config.yml` (`jsonContent` section), so generation changes can affect both HTML output and JSON metadata output.
