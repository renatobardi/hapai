# hapai — Prompt Orquestrador (Cole no Claude Code CLI)

## Como usar

```bash
cd /Users/bardi/Projetos/hapai
claude
```

Então cole o bloco abaixo inteiro no chat. O Claude Code vai lançar os subagentes
em paralelo automaticamente usando a ferramenta Task interna.

---

## PROMPT ORQUESTRADOR — cole inteiro no Claude Code

```
Você é o orquestrador de um plano de fixes para o repositório hapai.
Seu trabalho é lançar subagentes em paralelo usando a ferramenta Task,
aguardar cada wave completar, e depois lançar a próxima wave.

Contexto do projeto:
- hapai é um sistema de guardrails determinísticos para AI coding assistants
- Stack: Bash puro nos hooks + Svelte 5 dashboard + GCP
- Repo: /Users/bardi/Projetos/hapai
- Branch protegida: main — nunca commitar direto nela
- Commits: conventional commits, sem Co-Authored-By, sem mencionar AI/Claude
- Testes: bash tests/run-tests.sh

Diagnóstico já feito — problemas identificados:

P0-A: bin/hapai linha 19 define HAPAI_ROOT como pai do binário. Quando instalado em
/usr/local/bin/hapai, HAPAI_ROOT=/usr/local — hooks não existem lá. Fix: após linha 19,
adicionar fallback para HAPAI_HOME quando HAPAI_ROOT/hooks não existir.
Também: ensure_jq() hardcoded para "brew install jq" mesmo em Linux.
Também: cmd_sync faz source de _lib.sh sem guard de existência.

P0-B: install.sh — quando instala em ~/.local/bin (fallback sem sudo), PATH não é
atualizado. Usuário fica sem acesso ao binário. Fix: detectar shell e appendar ao rc file.
Também: macOS tem Bash 3.2 por padrão — o warn atual não bloqueia, mas deveria dar
exit 1 com instrução clara de "brew install bash".
Também: post_install não verifica se hooks foram realmente copiados.

P0-C: templates/settings.hooks.json — guard-branch.sh está registrado 3 vezes para
"Bash(gh api*)" (linhas 33-48). Causa triple-execution por operação. Fix: manter apenas 1.

P1-A: infra/gcp/functions/main.py — CORS origins hardcoded para renatobardi.github.io.
Quem faz self-host do dashboard tem CORS bloqueado. Fix: ler de env var CORS_ORIGINS.

P1-B: Documentação de comunidade open-source faltando: CONTRIBUTING.md, issue templates,
PR template, e badges no README.

---

WAVE 1 — Lance estes 3 subagentes em PARALELO (use Task para todos de uma vez):

Task A — "fix/hapai-root-standalone":
  Crie a branch fix/hapai-root-standalone a partir de main.
  
  Arquivo: bin/hapai
  
  Fix 1 — Após linha 19 (HAPAI_ROOT="..."), inserir:
    # Fallback: if running as installed binary (not inside repo), use HAPAI_HOME
    if [[ ! -d "$HAPAI_ROOT/hooks" ]]; then
      if [[ -d "$HAPAI_HOME/hooks" ]]; then
        HAPAI_ROOT="$HAPAI_HOME"
      else
        echo "hapai: hooks not found at $HAPAI_ROOT or $HAPAI_HOME" >&2
        echo "Run: curl -fsSL https://raw.githubusercontent.com/renatobardi/hapai/main/install.sh | bash" >&2
        exit 1
      fi
    fi
  
  Fix 2 — Função ensure_jq() (~linha 53), substituir a mensagem de erro fixa por:
    local os_hint
    case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
      darwin*) os_hint="brew install jq" ;;
      linux*)  os_hint="apt-get install -y jq  # ou: dnf install jq / pacman -S jq" ;;
      *)       os_hint="see https://jqlang.github.io/jq/download/" ;;
    esac
    log_error "jq is required but not installed. Install: $os_hint"
    exit 1
  
  Fix 3 — Função cmd_sync (~linha 823), antes do "source", adicionar:
    if [[ ! -f "$HAPAI_ROOT/hooks/_lib.sh" ]]; then
      log_error "hooks/_lib.sh not found. Run: hapai install --global"
      exit 1
    fi
  
  Após editar: rodar bash tests/run-tests.sh e confirmar que passa.
  Commitar os 3 fixes juntos: "fix(bin): HAPAI_ROOT fallback for standalone install, OS-aware jq hint, _lib guard"
  NÃO abrir PR — apenas commitar na branch.

Task B — "fix/installer-robustness":
  Crie a branch fix/installer-robustness a partir de main.
  
  Arquivo: install.sh
  
  Fix 1 — Função install_from_github, no bloco que instala em ~/.local/bin (quando cp
  para /usr/local/bin falha e sudo não está disponível), após o cp e o log_warn de PATH,
  adicionar o auto-fix de PATH:
    local shell_rc=""
    case "$(basename "${SHELL:-bash}")" in
      zsh)  shell_rc="$HOME/.zshrc" ;;
      bash) shell_rc="$HOME/.bashrc" ;;
      fish) shell_rc="$HOME/.config/fish/config.fish" ;;
    esac
    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
      if ! grep -q 'HOME/.local/bin' "$shell_rc" 2>/dev/null; then
        printf '\n# hapai — added by installer\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$shell_rc"
        log_ok "Added ~/.local/bin to PATH in $shell_rc"
        log_warn "Restart your terminal or run: source $shell_rc"
      fi
    fi
  
  Fix 2 — Função check_deps, substituir o bloco do bash version check por:
    local bash_major="${BASH_VERSINFO[0]:-3}"
    if [[ "$bash_major" -lt 4 ]]; then
      local os
      os="$(detect_os)"
      if [[ "$os" == "darwin" ]]; then
        log_error "Bash ${BASH_VERSION} detected. hapai requires Bash 4+."
        log_info "macOS ships with Bash 3.2 (GPL license constraint). Fix:"
        log_info "  brew install bash"
        log_info "Then re-run:"
        log_info '  /opt/homebrew/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/renatobardi/hapai/main/install.sh)"'
        exit 1
      else
        log_warn "Bash ${BASH_VERSION} detected (4+ recommended)."
      fi
    fi
  
  Fix 3 — Função post_install, antes do log_ok final de "Default config", adicionar:
    local hook_count
    hook_count="$(find "$HAPAI_HOME/hooks" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$hook_count" -eq 0 ]]; then
      die "Installation failed: no hooks found in $HAPAI_HOME/hooks — the download may be incomplete"
    fi
    log_ok "Hooks verified: $hook_count scripts installed"
  
  Commitar: "fix(install): PATH auto-update on fallback, Bash 4+ hard gate on macOS, post-install hook count check"
  NÃO abrir PR — apenas commitar na branch.

Task C — "fix/settings-dedup":
  Crie a branch fix/settings-dedup a partir de main.
  
  Arquivo: templates/settings.hooks.json
  
  Abrir o arquivo e localizar os 3 objetos idênticos dentro do matcher "Bash" que têm:
    "command": "bash __HAPAI_HOOKS__/pre-tool-use/guard-branch.sh"
    "if": "Bash(gh api*)"
  Remover 2 deles, deixando exatamente 1.
  
  Após a edição, validar que o JSON é válido:
    jq '.' templates/settings.hooks.json > /dev/null && echo "JSON válido"
  
  Também contar quantas vezes cada comando .sh aparece no JSON para confirmar
  que não existe mais nenhum outro duplicado:
    jq '[.. | objects | .command? // empty] | group_by(.) | map(select(length > 1))' \
      templates/settings.hooks.json
  O resultado deve ser array vazio [].
  
  Commitar: "fix(template): remove duplicate guard-branch registrations for gh api matcher"
  NÃO abrir PR — apenas commitar na branch.

---

Aguarde os 3 Tasks da Wave 1 completarem.

Depois de todos concluídos, rode em sequência no shell:
  cd /Users/bardi/Projetos/hapai
  git checkout main && git pull
  
  # Merge na ordem (C primeiro — toca só JSON, B depois, A por último — bin/hapai)
  git checkout fix/settings-dedup && git rebase main && git checkout main && git merge --squash fix/settings-dedup && git commit -m "fix(template): remove duplicate guard-branch registrations for gh api matcher"
  git checkout fix/installer-robustness && git rebase main && git checkout main && git merge --squash fix/installer-robustness && git commit -m "fix(install): PATH auto-update, Bash 4+ hard gate on macOS, hook count check"
  git checkout fix/hapai-root-standalone && git rebase main && git checkout main && git merge --squash fix/hapai-root-standalone && git commit -m "fix(bin): HAPAI_ROOT fallback for standalone install, OS-aware jq hint, _lib guard"

Depois do merge, rodar o teste de aceitação:
  bash tests/run-tests.sh
  jq '[.. | objects | .command? // empty] | group_by(.) | map(select(length > 1))' templates/settings.hooks.json

---

WAVE 2 — Lance estes 2 subagentes em PARALELO:

Task D — "fix/cors-configurable":
  Crie a branch fix/cors-configurable a partir de main.
  
  Arquivo: infra/gcp/functions/main.py
  
  Localizar onde estão as CORS origins hardcoded (buscar por "renatobardi.github.io").
  
  Fix: antes da função hapai_bq_query, adicionar:
    import os  # se ainda não importado no topo do arquivo
    
    _DEFAULT_CORS_ORIGINS = {
        "https://renatobardi.github.io",
        "http://localhost:5173",
        "http://localhost:4173",
    }
    
    def _get_allowed_origins() -> set:
        env_val = os.environ.get("CORS_ORIGINS", "")
        if env_val:
            return {o.strip() for o in env_val.split(",") if o.strip()}
        return _DEFAULT_CORS_ORIGINS
  
  Na função hapai_bq_query, substituir o check de origin hardcoded por:
    allowed_origins = _get_allowed_origins()
    origin = request.headers.get("Origin", "")
    cors_origin = origin if origin in allowed_origins else ""
  
  Também adicionar ao final de infra/gcp/SETUP.md uma seção:
    ## Self-hosting the Dashboard
    By default, CORS is allowed from renatobardi.github.io and localhost.
    To allow your own domain, set the env var when deploying:
      gcloud functions deploy hapai-bq-query \
        --set-env-vars CORS_ORIGINS=https://yourdomain.com
    Multiple origins: --set-env-vars CORS_ORIGINS=https://a.com,https://b.com
  
  Commitar: "fix(cloud): configurable CORS origins via CORS_ORIGINS env var"
  NÃO abrir PR.

Task E — "docs/open-source-community":
  Crie a branch docs/open-source-community a partir de main.
  
  Criar CONTRIBUTING.md na raiz com estas seções:
  - "Getting started" — fork, clone, HAPAI_DEV=1 bash install.sh para dev local
  - "Running tests" — bash tests/run-tests.sh, como testar um hook individual
  - "Adding a guardrail" — checklist: criar guard-*.sh, registrar em settings.hooks.json, config key em hapai.defaults.yaml, testes, docs
  - "Commit convention" — conventional commits (feat/fix/docs/chore/refactor/test)
  - "Branch naming" — feat/, fix/, docs/, chore/, refactor/, test/
  - "PR checklist" — testes passam, sem deps externas, CHANGELOG atualizado
  - "Philosophy" — Pure Bash, zero external deps beyond jq, fail-open on internal errors
  
  Criar .github/ISSUE_TEMPLATE/bug_report.md:
    ---
    name: Bug report
    about: Something is broken
    labels: bug
    ---
    **OS:** [macOS / Linux / WSL / Windows]
    **Bash version:** (run: bash --version)
    **hapai version:** (run: hapai version)
    **Installation method:** [curl installer / dev mode]
    **Steps to reproduce:**
    **Expected behavior:**
    **Actual behavior:**
    **Logs:** (run: hapai audit 30 and paste relevant lines)
  
  Criar .github/ISSUE_TEMPLATE/feature_request.md:
    ---
    name: Feature request
    about: Suggest a new guardrail or improvement
    labels: enhancement
    ---
    **AI tool you use:** [Claude Code / Cursor / Copilot / other]
    **What guardrail is missing:**
    **Use case / scenario:**
    **Would you contribute a PR?** [yes / no / maybe]
  
  Criar .github/pull_request_template.md:
    ## What does this PR do?
    ## Type of change
    - [ ] Bug fix
    - [ ] New guardrail
    - [ ] Improvement to existing guardrail
    - [ ] Documentation only
    ## Testing
    - [ ] bash tests/run-tests.sh passes
    - [ ] Tested on macOS
    - [ ] Tested on Linux / WSL
    ## Checklist
    - [ ] No new external dependencies
    - [ ] hapai.defaults.yaml updated (if new config key)
    - [ ] CHANGELOG.md updated
  
  No README.md, adicionar logo após o primeiro heading:
    - Badge shields.io: "Pure Bash" (color: green)
    - Badge shields.io: CI (apontando para .github/workflows/ci.yml)
    - Badge shields.io: License
  
  Adicionar ao README.md uma seção "Contributing" com link para CONTRIBUTING.md
  e uma seção "Community" com link para GitHub Issues e Discussions.
  
  Commitar: "docs: CONTRIBUTING, issue templates, PR template, README badges and community section"
  NÃO abrir PR.

---

Aguarde os Tasks D e E completarem.

Depois fazer o merge da Wave 2:
  git checkout main && git pull
  git checkout fix/cors-configurable && git rebase main && git checkout main && git merge --squash fix/cors-configurable && git commit -m "fix(cloud): configurable CORS origins via CORS_ORIGINS env var"
  git checkout docs/open-source-community && git rebase main && git checkout main && git merge --squash docs/open-source-community && git commit -m "docs: CONTRIBUTING, issue templates, PR template, README badges"

---

WAVE 3 — 1 agente (sequencial):

Task F — "feat/release-workflow":
  Crie a branch feat/release-workflow a partir de main.
  
  Criar scripts/tag-release.sh:
    #!/usr/bin/env bash
    # Usage: bash scripts/tag-release.sh 1.0.1
    set -euo pipefail
    VERSION="${1:-}"
    [[ -z "$VERSION" ]] && echo "Usage: $0 <semver>  ex: $0 1.0.1" && exit 1
    [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "Invalid semver: $VERSION" && exit 1
    
    echo "Bumping version to $VERSION..."
    # Update bin/hapai
    sed -i.bak "s/^HAPAI_VERSION=.*/HAPAI_VERSION=\"${VERSION}\"/" bin/hapai && rm -f bin/hapai.bak
    # Update hooks/_lib.sh
    sed -i.bak "s/^HAPAI_VERSION=.*/HAPAI_VERSION=\"${VERSION}\"/" hooks/_lib.sh && rm -f hooks/_lib.sh.bak
    # Update install.sh comment line (if versioned)
    
    git add bin/hapai hooks/_lib.sh
    git commit -m "chore(release): bump version to ${VERSION}"
    git tag -a "v${VERSION}" -m "Release v${VERSION}"
    
    echo ""
    echo "✓ Tag v${VERSION} criada localmente."
    echo "Para publicar:"
    echo "  git push origin main && git push origin v${VERSION}"
  
  chmod +x scripts/tag-release.sh
  
  Verificar que HAPAI_VERSION é consistente entre bin/hapai e hooks/_lib.sh.
  Ambos devem ter o mesmo valor. Se divergirem, sincronizar para o maior.
  
  Verificar o arquivo .github/workflows/release.yml existente.
  Garantir que o workflow:
  1. Faz trigger em push de tags v*
  2. Gera tarball: git archive --format=tar.gz --prefix=hapai-${VERSION}/ HEAD
  3. Gera checksums.txt com sha256sum (Linux) ou shasum -a 256 (macOS runner)
  4. Faz upload do tarball e checksums.txt como release assets
  Se algum desses passos estiver faltando, adicionar.
  
  Commitar: "feat(release): tag-release.sh script, version sync, checksums in release workflow"
  NÃO abrir PR.

Fazer merge:
  git checkout main && git pull
  git checkout feat/release-workflow && git rebase main && git checkout main && git merge --squash feat/release-workflow && git commit -m "feat(release): tag-release.sh, version sync, checksums in release workflow"

---

Ao final de tudo, rodar:
  bash tests/run-tests.sh
  hapai validate
  git log --oneline -10

E reportar um resumo de cada fix aplicado com ✅ ou ❌.
```
