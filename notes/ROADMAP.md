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

## Backlog (v1.2+)

### Hook Chains (Flow) ⬜
Encadeamento sequencial de hooks com gates condicionais:
```yaml
flows:
  pre_commit_review:
    steps:
      - hook: guard-branch
      - hook: guard-commit-msg
      - hook: guard-blast-radius
        gate: warn
```

### Instalação e Teste Real ⬜
- `hapai install --global` e testar com Claude Code real
- Testar em oute.me e the-loop com configs customizadas

### Expansão Futura ⬜
- Publicar como brew tap ou installer universal
- Dashboard web para visualizar audit trail
- State avançado (blocklist temporária, cooldown por hook)
- Hook marketplace (community-contributed hooks)

---

## Números Finais

| Métrica | Valor |
|---------|-------|
| Hooks | 19 |
| Eventos cobertos | 8 (PreToolUse, PostToolUse, Stop, PreCompact, Notification, PermissionRequest, UserPromptSubmit, SessionStart) |
| Exporters | 7 (+ Claude via install) |
| Testes | 55 |
| Commits | 9 |
| Dependências | 1 (jq) |
| Linguagem | Bash puro |

## Timeline

| Data | Marco |
|------|-------|
| 2026-04-07 | v1.0.0 — 5 fases, 19 hooks, CLI |
| 2026-04-07 | Code review — 19 issues corrigidas |
| 2026-04-07 | v1.1 — Export 8 tools, CI/CD, hardening |
