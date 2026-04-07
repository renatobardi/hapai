# Guia de Uso — hapai

## Instalação Rápida

```bash
# 1. Clone o repo
git clone https://github.com/renatobardi/hapai.git ~/hapai

# 2. Adicione ao PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# 3. Instale globalmente (aplica a todos os projetos)
hapai install --global

# 4. Verifique
hapai validate
```

## Modos de Instalação

### Global (recomendado para começar)

```bash
hapai install --global
```

Instala em `~/.claude/settings.json` e `~/.hapai/`. Aplica a **todos** os projetos que você abrir com Claude Code.

### Por Projeto

```bash
cd meu-projeto
hapai install --project
```

Instala em `.claude/settings.json` do projeto. Útil para regras específicas por projeto (ex: proteger `CONSTITUTION.md` no the-loop).

### Os dois juntos

Você pode ter instalação global + projeto. O Claude Code carrega ambos. Hooks de projeto complementam os globais.

---

## Configuração (hapai.yaml)

Após instalar, um arquivo `hapai.yaml` é criado (em `~/.hapai/hapai.yaml` para global, ou `hapai.yaml` na raiz do projeto).

### Editando regras

Abra o arquivo e ajuste conforme seu projeto:

```yaml
version: "1.0"
risk_tier: medium

guardrails:
  # Quais branches são protegidas?
  branch_protection:
    enabled: true
    protected: [main, master, develop]  # adicione branches aqui
    fail_open: false                     # false = bloqueia, true = só avisa

  # Quais padrões são proibidos em commits?
  commit_hygiene:
    enabled: true
    blocked_patterns:
      - "Co-Authored-By:"
      - "Generated with Claude"
      - "noreply@anthropic.com"
      - "Claude Code"
      - "Anthropic"
    fail_open: false

  # Quais arquivos não podem ser editados pela IA?
  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
      - "package-lock.json"
      - "pnpm-lock.yaml"
      - ".github/workflows/*"
      # Adicione arquivos específicos do seu projeto:
      # - "CONSTITUTION.md"
      # - "firebase.json"
    unprotected:
      - ".env.example"
      - ".env.sample"
    fail_open: false

  # Comandos perigosos bloqueados
  command_safety:
    enabled: true
    blocked:
      - "rm -rf"
      - "git push --force"
      - "git push -f"
      - "git reset --hard"
      - "DROP TABLE"
      - "DROP DATABASE"
      - "TRUNCATE"
      - "chmod 777"
    fail_open: false

  # Alerta quando commit é muito grande
  blast_radius:
    enabled: true
    max_files: 10       # alerta se >10 arquivos no commit
    max_packages: 2     # alerta se toca >2 pacotes (monorepo)
    fail_open: true     # true = avisa mas permite, false = bloqueia

  # Avisa quando a IA vai sobrescrever seu trabalho não-commitado
  uncommitted_changes:
    enabled: true
    fail_open: true
```

### Configurando automação (opcional)

```yaml
automation:
  # Auto-checkpoint: cria snapshots git por arquivo editado
  auto_checkpoint:
    enabled: true          # ligue para nunca perder trabalho
    squash_on_stop: true   # consolida checkpoints ao fim da sessão
    commit_prefix: "checkpoint:"

  # Auto-format: roda formatter após cada escrita
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"

  # Auto-lint: roda linter após cada escrita
  auto_lint:
    enabled: true
    python: "ruff check {file}"
    javascript: "eslint {file}"
```

### O que é `fail_open`?

Cada guardrail tem um campo `fail_open`:
- **`false`** (padrão) = **Bloqueia**. A ação é impedida. Claude recebe mensagem de erro.
- **`true`** = **Avisa**. A ação é permitida, mas Claude recebe um aviso contextual.

Use `fail_open: true` para guardrails informativos (blast_radius, uncommitted_changes).
Use `fail_open: false` para guardrails invioláveis (branch_protection, commit_hygiene).

---

## Onde fica o quê?

```
~/.hapai/                    # Diretório global do hapai
├── hooks/                   # Scripts de hooks (instalados)
├── hapai.yaml               # Config global
├── audit.jsonl              # Log de tudo que os hooks fizeram
└── state/                   # Contadores e estado entre sessões

~/.claude/settings.json      # Hooks registrados aqui (global)
~/.claude/CLAUDE.md          # Regras injetadas aqui (<!-- hapai:start/end -->)

meu-projeto/
├── hapai.yaml               # Config por projeto (opcional, sobrescreve global)
├── .claude/settings.json    # Hooks registrados aqui (projeto)
└── CLAUDE.md                # Regras injetadas aqui (projeto)
```

---

## Usando o CLI

### Comandos do dia a dia

```bash
# Ver estado atual
hapai status

# Ver últimas 20 ações dos hooks
hapai audit

# Ver últimas 50 ações
hapai audit 50
```

### Emergência

```bash
# Desativa TODOS os hooks instantaneamente
hapai kill

# Reativa hooks
hapai revive
```

### Verificação

```bash
# Verifica se tudo está instalado corretamente
hapai validate
```

Output esperado:
```
hapai validate v1.0.0
─────────────────────────────────
✓ Hooks registered in /Users/you/.claude/settings.json
✓ Hook scripts: 11/11 executable in /Users/you/.hapai/hooks
✓ Global config: /Users/you/.hapai/hapai.yaml
✓ jq: jq-1.7.1
✓ Audit log: 42 entries
✓ State: 3 entries
─────────────────────────────────
All checks passed
```

### Exportar para outras ferramentas

```bash
# Gera .cursor/rules com as mesmas guardrails
hapai export --target cursor

# Gera .github/copilot-instructions.md
hapai export --target copilot
```

---

## Exemplos práticos

### Cenário 1: Claude tenta commitar na main

```
Claude: git commit -m "feat: add login"
hapai:  🛑 hapai: Commit blocked on protected branch 'main'.
        Create a feature branch first: git checkout -b feat/your-feature
```

### Cenário 2: Claude adiciona Co-Authored-By

```
Claude: git commit -m "feat: add button

        Co-Authored-By: Claude <noreply@anthropic.com>"
hapai:  🛑 hapai: Commit blocked — contains forbidden pattern 'Co-Authored-By:'.
        Remove AI attribution from the commit message.
```

### Cenário 3: Claude tenta rm -rf

```
Claude: rm -rf /
hapai:  🛑 hapai: Destructive command blocked — 'rm -rf' on dangerous path.
```

### Cenário 4: Claude edita .env

```
Claude: [Write] .env
hapai:  🛑 hapai: Write blocked — '.env' is a protected file.
        Environment files should not be modified by AI.
```

### Cenário 5: Commit grande (blast radius)

```
Claude: git commit -m "refactor: update everything"
hapai:  ⚠️ Blast radius: 15 files staged (threshold: 10).
        Also touches 3 packages (apps/web, apps/api, packages/ui).
        Consider splitting into smaller, focused commits.
```

---

## Configuração por projeto (exemplos)

### Para oute.me (monorepo SvelteKit + FastAPI)

```yaml
# oute.me/hapai.yaml
version: "1.0"
risk_tier: medium

guardrails:
  branch_protection:
    enabled: true
    protected: [main, develop]

  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
      - ".github/workflows/*"
      - "turbo.json"
      - "pnpm-workspace.yaml"

automation:
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"

  auto_lint:
    enabled: true
    python: "ruff check {file}"
    javascript: "eslint {file}"
```

### Para the-loop (com CONSTITUTION.md)

```yaml
# the-loop/hapai.yaml
version: "1.0"
risk_tier: high

guardrails:
  branch_protection:
    enabled: true
    protected: [main]

  file_protection:
    enabled: true
    protected:
      - ".env"
      - "*.lock"
      - ".github/workflows/*"
      - "CONSTITUTION.md"
      - ".semgrep/*"

  blast_radius:
    enabled: true
    max_files: 8
    max_packages: 1
    fail_open: false   # bloqueia (mais rigoroso)
```

---

## Audit Log

Toda ação dos hooks é gravada em `~/.hapai/audit.jsonl`:

```json
{"ts":"2026-04-07T20:30:00Z","event":"PreToolUse","hook":"guard-branch","tool":"Bash","result":"deny","reason":"Commit blocked on protected branch 'main'","project":"/Users/bardi/Projetos/oute.me"}
{"ts":"2026-04-07T20:30:05Z","event":"PreToolUse","hook":"guard-branch","tool":"Bash","result":"allow","reason":"","project":"/Users/bardi/Projetos/oute.me"}
```

Use `hapai audit` para ver de forma legível, ou processe com `jq`:

```bash
# Quantos bloqueios por hook
jq -r 'select(.result=="deny") | .hook' ~/.hapai/audit.jsonl | sort | uniq -c | sort -rn

# Bloqueios das últimas 24h
jq -r 'select(.result=="deny")' ~/.hapai/audit.jsonl | tail -20
```

---

## Dupla camada: Hooks + CLAUDE.md

O `hapai install` injeta regras no CLAUDE.md do projeto usando markers:

```markdown
<!-- hapai:start -->
## Hapai Guardrails (enforced by hooks)
- NEVER commit directly to protected branches (main, master)
- NEVER add Co-Authored-By or mention AI/Claude in commits, PRs, or docs
...
<!-- hapai:end -->
```

Isso cria **duas camadas de proteção**:
1. **CLAUDE.md** (probabilístico) — Claude lê e tenta seguir
2. **Hooks** (determinístico) — Se Claude ignorar, o hook bloqueia

A injeção é idempotente: rodar `hapai install` novamente atualiza o bloco sem duplicar.

---

## Desinstalação

```bash
# Remove hooks globais
hapai uninstall --global

# Remove hooks do projeto atual
hapai uninstall
```

Isso remove hooks do `settings.json` e o bloco `<!-- hapai:start/end -->` do CLAUDE.md. Não apaga o audit log nem o estado.

---

## Dúvidas Frequentes

**P: Os hooks afetam a velocidade do Claude Code?**
R: Mínimo. Cada hook roda em <100ms. PreToolUse tem timeout de 7s, PostToolUse de 5s. Se um hook travar, o timeout mata ele e o fluxo continua.

**P: E se eu precisar temporariamente editar um .env?**
R: Use `hapai kill` para desativar todos os hooks, faça a edição, e `hapai revive` para reativar. Ou edite `hapai.yaml` e adicione o arquivo à lista `unprotected`.

**P: Funciona com Cursor e Copilot?**
R: Os hooks são específicos do Claude Code. Mas `hapai export --target cursor` e `--target copilot` geram arquivos de regras para essas ferramentas (enforcement via instrução, não hooks).

**P: Posso adicionar hooks customizados?**
R: Sim. Crie um script `.sh` em `~/.hapai/hooks/pre-tool-use/` (ou `post-tool-use/`, `stop/`), torne executável, e registre no `~/.claude/settings.json`. Use `hooks/_lib.sh` como biblioteca.

**P: O audit log cresce indefinidamente?**
R: Configure `retention_days` no `hapai.yaml`. Para limpar manualmente: `> ~/.hapai/audit.jsonl`
