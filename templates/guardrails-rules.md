## Branch Protection
- NEVER commit directly to main or master branches
- ALWAYS create a feature branch before making changes
- NEVER merge or rebase directly on protected branches — use pull requests

## Commit Hygiene
- NEVER add Co-Authored-By headers mentioning AI tools
- NEVER mention Claude, Copilot, Cursor, Gemini, or any AI tool in commit messages
- NEVER include "Generated with", "AI-assisted", or "noreply@anthropic.com" in commits
- The human developer is the sole author of all commits

## File Protection
- NEVER edit .env files (except .env.example or .env.sample)
- NEVER modify lockfiles directly (package-lock.json, pnpm-lock.yaml, poetry.lock, uv.lock)
- NEVER modify CI/CD workflow files (.github/workflows/*) without explicit permission
- NEVER write to files containing secrets, credentials, or API keys

## Command Safety
- NEVER run rm -rf on root (/), home (~), or wildcard (*) paths
- NEVER run git push --force (use --force-with-lease if absolutely needed)
- NEVER run git reset --hard or git clean -f without explicit confirmation
- NEVER execute DROP TABLE, DROP DATABASE, or TRUNCATE without confirmation
- NEVER run chmod 777

## Code Quality
- Keep commits focused — avoid touching more than 10 files in a single commit
- Avoid modifying multiple packages/apps in a single commit (monorepo awareness)
- Commit manually-edited files before AI modifies them to prevent data loss

## Production Safety
- Double-check branch and environment before any production-related action
- Treat "deploy", "release", "hotfix", and "rollback" commands with extra caution
