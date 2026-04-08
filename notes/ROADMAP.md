# hapai — Roadmap Completo

## Origem

A dor: IA (Claude Code e ferramentas similares) ignora instruções em CLAUDE.md/speckit e executa ações proibidas. Instruções em markdown são probabilísticas — hooks são determinísticos.

Pesquisa de referência analisou:
- **wangbooth/Claude-Code-Guardrails** — shell puro, install.sh, auto-checkpoint, squash
- **disler/claude-code-hooks-mastery** — 13 hooks lifecycle, TTS, audit trail, auto-allow
- **rulebricks/claude-code-guardrails** — descartado (vendor lock-in, API paga)
- **renatobardi/GitNexus** — hook dispatcher, settings.json merger, graceful failure, CLAUDE.md injection
- **renatobardi/gitagent** — manifesto YAML, validate, export multi-tool, kill switch, hook chains

Projetos analisados para entender necessidades reais: **oute.me** (monorepo SvelteKit + FastAPI) e **the-loop** (SvelteKit + FastAPI com CONSTITUTION.md).

---

## v1.0 — 5 Fases de Hooks

### Fase 1 — Segurança Core (MVP) ✅
| Hook | Evento | O que faz |
|------|--------|-----------|
| `guard-branch.sh` | PreToolUse | Bloqueia commit/push em main/master |
| `guard-commit-msg.sh` | PreToolUse | Bloqueia Co-Authored-By, menções a IA |
| `guard-destructive.sh` | PreToolUse | Bloqueia rm -rf, force-push, DROP TABLE |

### Fase 2 — Proteção de Arquivos + CLI ✅
| Hook | Evento | O que faz |
|------|--------|-----------|
| `guard-files.sh` | PreToolUse | Bloqueia .env, lockfiles, CI configs |
| `guard-uncommitted.sh` | PreToolUse | Detecta mudanças não-commitadas |
| `guard-blast-radius.sh` | PreToolUse | Alerta se commit toca muitos arquivos |

CLI: install, uninstall, validate, kill, revive, status, audit, export

### Fase 3 — Qualidade Automática ✅
| Hook | Evento | O que faz |
|------|--------|-----------|
| `auto-format.sh` | PostToolUse | Roda prettier/ruff após Write/Edit |
| `auto-lint.sh` | PostToolUse | Roda ESLint/ruff check |
| `auto-checkpoint.sh` | PostToolUse | Snapshot git por arquivo editado |
| `squash-checkpoints.sh` | Stop | Consolida checkpoints em 1 commit |

### Fase 4 — Observabilidade + DX ✅
| Hook | Evento | O que faz |
|------|--------|-----------|
| `require-tests.sh` | Stop | Avisa/bloqueia se nenhum teste rodou |
| `backup-transcript.sh` | PreCompact | Salva transcripts antes de compactação |
| `sound-alert.sh` | Notification | Toca som quando Claude precisa de input |
| `auto-allow-readonly.sh` | PermissionRequest | Auto-aprova Read/Glob/Grep |

### Fase 5 — Inteligência de Sessão ✅
| Hook | Evento | O que faz |
|------|--------|-----------|
| `warn-production.sh` | UserPromptSubmit | Warning para prod/deploy/release |
| `load-context.sh` | SessionStart | Carrega git status, TODOs, issues |
| `audit-trail.sh` | PostToolUse | Log de toda operação em JSONL |
| `cost-tracker.sh` | Stop | Estima custo da sessão e alerta |

### Code Review ✅
19 issues corrigidas (2 critical, 4 high, 6 medium, 7 low):
- Removido `eval` (command injection) em auto-format/auto-lint
- Reescrito config parser YAML context-aware (leaf-key collision)
- Fix warn() JSON escaping via jq --arg
- Fix guard-uncommitted para usar path completo (não basename)
- Fix guard-branch regex para evitar false positives em echo/grep
- Permitido --force-with-lease (safe alternative)
- Self-protection: bloqueia `hapai kill/uninstall` via IA
- Status mostra warn_count + deny_count
- Audit log via jq (safe contra injection)
- macOS sed compatibility ([[:space:]] em vez de \s)

---

## v1.1 — Export Multi-Tool + Hardening ✅

### Export para 8 Ferramentas AI ✅
| Ferramenta | Arquivo gerado | Formato |
|-----------|---------------|---------|
| Claude Code | `.claude/settings.json` + `CLAUDE.md` | Hooks (enforcement real) |
| Cursor | `.cursor/rules/hapai.mdc` | MDC com `alwaysApply: true` |
| VS Code Copilot | `.github/copilot-instructions.md` | Markdown |
| Windsurf | `.windsurf/rules/hapai.md` | MD com `trigger: always_on` |
| Devin.ai | `AGENTS.md` | Markdown com markers hapai |
| Trae | `.trae/rules/hapai.md` | MD com `alwaysApply: true` |
| Antigravity | `GEMINI.md` + `AGENTS.md` | Markdown com markers |
| Universal | `AGENTS.md` | Padrão cross-tool |

CLI: `hapai export --target <tool>` + `hapai export --all`

Template comum: `templates/guardrails-rules.md` (single source of truth)

### CI/CD ✅
- GitHub Actions em ubuntu + macOS matrix
- Roda `tests/run-tests.sh` em cada push/PR

### Testes de Hardening ✅
- 8 testes de export (formato + idempotência)
- 3 testes config parser (duplicate keys, lists, missing keys)
- 1 teste CLI integration (`--all`)
- Fix `_HAPAI_CONFIG` preservação em subshell

### Documentação ✅
- README.md expandido com arquitetura completa
- USAGE.md atualizado com Fases 4-5 e export multi-tool
- CLAUDE.md criado para o projeto hapai

---

## v1.2 — Hook Chains, State Avançado, Universal Distribution ✅

### Hook Chains (Flow) ✅
Encadeamento sequencial de hooks com gates condicionais:
```yaml
flows:
  pre_commit_review:
    steps:
      - hook: guard-branch
        gate: block
      - hook: guard-commit-msg
        gate: block
      - hook: guard-blast-radius
        gate: warn  # continua mesmo se negar
```
- `flow-dispatcher.sh` — executa steps em sequência
- `flow_run_step()` — aplica gate logic (block/warn/skip)
- Testes: 3 casos (gate=block, gate=warn, gate=skip)

### State Avançado ✅
- **Blocklist temporária:** `hapai block <pattern> --for 30m --type branch`
- **Cooldown por hook:** Escalação automática após N denials em T minutos
- CLI: `hapai blocklist` mostra blocos ativos com tempo restante
- Integração em guards: `guard-branch`, `guard-files`, `guard-blast-radius`

### Universal Installer ✅
- `install.sh` — curl | bash para Linux/macOS/WSL
- Detecta OS, verifica deps (bash 4+, jq, git)
- Resolve versão via GitHub API (ou usa `main` em dev)
- Fallback: ~/.local/bin se /usr/local/bin indisponível
- SHA256 verification contra checksums.txt (supply chain defense)

### Brew Tap ✅
- Repo `renatobardi/homebrew-hapai` com `Formula/hapai.rb`
- `scripts/update-brew-formula.sh` — automático após release
- Usuários: `brew tap renatobardi/hapai && brew install hapai`

### CLI Novos ✅
- `hapai block <pattern> [--type branch|file|command] [--for duration] [--reason text]`
- `hapai unblock <pattern>`
- `hapai blocklist` — lista blocos com expiração
- `hapai list-hooks` — lista hooks instalados

### Code Review ✅
12 issues corrigidas (2 critical, 5 high, 3 medium, 2 low):
- Path traversal defense (cooldown_active, cooldown_record, flow-dispatcher)
- Supply chain: SHA256 verification em install.sh
- Data loss prevention: cmd_revive merge logic
- Hot path optimization: blocklist_clean early-exit
- Input validation: tail $lines integer check, jq 1.6+ version check
- Injection defense: sanitizar cooldown_until ISO format, hook_name YAML quote-stripping

### Testes ✅
- 68/68 testes passando (adicionados 15+ testes para Flow, State, CLI)
- Incluindo quote-stripping edge cases, blocklist expiration, cooldown escalation

### Instalação e Teste Real ✅
- Testado em macOS + Ubuntu via CI/CD matrix
- Release workflow automático (tag → GitHub Release → Brew update)

## Backlog (v1.3+)

### Dashboard Web (GCP) ⬜
- Cloud Storage: audit log upload (`hapai sync`)
- Cloud Functions: trigger load-audit-log para BigQuery
- BigQuery: analytics dataset `hapai_dataset.events`
- GitHub Pages: static SPA com Canvas-flavored Markdown
- Custom domain: hapai.oute.pro via CNAME
- Zero always-on compute (serverless)

### Hook Marketplace (v1.4) ⬜
- Public registry: `renatobardi/hapai-marketplace`
- Community hooks: guard-secrets, guard-api-keys, auto-issue-link, etc
- CLI: `hapai search`, `hapai install-hook`, `hapai publish`
- Validation: metadata header + sha256 check

---

## Números Finais (v1.2)

| Métrica | Valor |
|---------|-------|
| Hooks | 19 (core) + 1 dispatcher (flow) |
| Eventos cobertos | 8 (PreToolUse, PostToolUse, Stop, PreCompact, Notification, PermissionRequest, UserPromptSubmit, SessionStart) |
| Exporters | 8 (+ CLI multi-tool) |
| CLI Commands | 20+ (install, kill, revive, block/unblock/blocklist, list-hooks, export, audit, validate, etc) |
| Testes | 68 (adicionados 13 para v1.2) |
| Commits | 20+ |
| Security Issues Fixed | 31 total (19 v1.0 + 12 v1.2) |
| Dependências | 1 (jq) |
| Linguagem | Bash puro |
| Instalação | curl\|bash + brew install |

## Timeline

| Data | Marco |
|------|-------|
| 2026-04-07 | v1.0.0 — 5 fases, 19 hooks, CLI |
| 2026-04-07 | Code review v1.0 — 19 issues corrigidas |
| 2026-04-07 | v1.1 — Export 8 tools, CI/CD, hardening |
| 2026-04-08 | Implementação v1.2 — Hook Chains, State Avançado, Installer, Brew |
| 2026-04-08 | Code review v1.2 — 12 issues corrigidas (security hardening) |
| 2026-04-08 | v1.2.0 Release — Published to GitHub + Homebrew |
| 2026-04-08 | Próximo: v1.3 — Dashboard Web (GCP + GitHub Pages) |
