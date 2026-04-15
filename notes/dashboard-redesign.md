# hapai Dashboard — Diagnóstico & Proposta de Redesign

## 1. Diagnóstico do Estado Atual

### O que existe hoje

O dashboard atual tem 7 queries ao BigQuery (stats, timeline, hooks, denials, tools, projects, trends) e renderiza tudo numa única tela plana:

**Topo:** 2 StatCards (Blocked Actions, Soft Warnings) + Timeline chart
**Meio:** DenialsTable (tabela flat com todas as linhas)
**Bottom row:** 3 gráficos lado a lado (Hooks donut, Tools bar, Projects bar)
**Rodapé:** TrendChart (line chart dark)

### Problemas Identificados

#### 1.1 Arquitetura de Informação — Tudo no mesmo nível
Não há hierarquia. Um número agregado (denials: 47) está ao lado de uma tabela com dezenas de linhas brutas, que está ao lado de um gráfico de tendência. O usuário não sabe **por onde começar a olhar** e não tem como ir do macro ao micro progressivamente.

#### 1.2 Densidade sem significado
A DenialsTable mostra **cada evento individual** — timestamp, type, hook, tool, reason. Com uso real, isso vira 50-200+ linhas sem paginação, sem filtro, sem sort. É um log dump, não uma tabela analítica. O "reason" está truncado com `text-overflow: ellipsis` em 320px, então o campo mais importante é o que menos se lê.

#### 1.3 Gráficos que não contam história
- **Timeline (bar chart):** Denials vs Warnings por dia. 30 barras lado a lado — com poucos dados fica esparso, com muitos fica ilegível. Não mostra tendência, não mostra anomalias.
- **Hooks (donut):** Proporção de hooks. Donut charts são ruins para comparações precisas. Com 8+ fatias, as menores ficam invisíveis.
- **Tools (horizontal bar):** OK como conceito, mas sem contexto — "Bash teve 23 denials" não diz nada se eu não sei quantas execuções totais teve.
- **Projects (vertical bar):** Mostra o path truncado. Com muitos projetos, as labels se sobrepõem.
- **Trend (line chart em fundo escuro):** Mostra "denials per day" — mas é essencialmente a mesma informação do Timeline só que como line. **Redundância.**

#### 1.4 Copy genérica e passiva
- "Blocked Actions" e "Soft Warnings" são labels de contagem pura. Não dizem se 47 é bom ou ruim, se está subindo ou descendo.
- "Event Timeline — 30 days" é um título de eixo, não um insight.
- "Guardrail Activity" na tabela é genérico demais.
- "Top Blocking Hooks" — ok, mas sem contexto de "e daí?".

#### 1.5 Estética
- Cards e gráficos são blocos brancos com borda cinza sem elevação visual — flat demais para criar hierarquia.
- Sem border-radius (BMW-inspired) mas também sem compensação de contraste — tudo parece "planilha".
- O TrendChart usa fundo escuro (`--color-near-black`) enquanto todo o resto é branco — ruptura visual sem propósito.
- Tipografia é consistente mas monótona: tudo uppercase 11px com letter-spacing, o que achata a hierarquia.

---

## 2. Proposta de Redesign — "Overview → Drill-Down → Detail"

### 2.1 Modelo Mental: 3 Níveis de Profundidade

```
L1: Overview (o que aconteceu?)
  └─ L2: Breakdown (onde/por quê?)
       └─ L3: Detail (evento individual)
```

**L1 — Overview:** KPIs com sparklines + tendência. Responde "preciso me preocupar?"
**L2 — Breakdown:** Click em qualquer KPI ou gráfico abre um painel de análise. Responde "o que exatamente?"
**L3 — Detail:** Click em uma linha específica abre um modal/drawer com o evento completo. Responde "me mostra."

### 2.2 Layout Proposto

```
┌──────────────────────────────────────────────────────────┐
│  Header (como está)                                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │ Denials  │  │ Warnings│  │ Allow   │  │ Deny    │    │
│  │ 47 ↗12% │  │ 12 ↘5% │  │ Rate    │  │ Rate    │    │
│  │ ▂▃▅▂▃▄▅ │  │ ▅▃▂▃▂▁▂ │  │ 94.2%   │  │ 5.8%    │    │
│  │ last 30d │  │ last 30d│  │ ▁▁▂▁▁▂▁ │  │ ▂▃▅▂▃▅▂ │    │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │  Activity Timeline (stacked area, not bar)        │    │
│  │  ▁▂▃▅▇▅▃▂▁▂▃▅▆▅▃  deny ■ warn ■                │    │
│  │  [7d] [14d] [30d]  ← period selector             │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────┐  ┌─────────────────────────┐    │
│  │  Top Guards          │  │  Hotspots               │    │
│  │  ─────────────────  │  │  ─────────────────────  │    │
│  │  guard-branch   23  │  │  By Tool    By Project  │    │
│  │  ████████████▎  ──→ │  │  ┌──────────────────┐  │    │
│  │  guard-files    12  │  │  │  Bash        45%  │  │    │
│  │  ██████▎        ──→ │  │  │  Write       28%  │  │    │
│  │  guard-commit    8  │  │  │  Edit        18%  │  │    │
│  │  ████▎          ──→ │  │  │  Read         9%  │  │    │
│  │                      │  │  └──────────────────┘  │    │
│  │  → = click to drill │  │                         │    │
│  └─────────────────────┘  └─────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │  Recent Events (top 20, not all)                  │    │
│  │  ┌─ Filter: [All▾] [Hook▾] [Tool▾] [Project▾]   │    │
│  │  │                                                │    │
│  │  │  2m ago  DENY  guard-branch  Bash              │    │
│  │  │  → "Push to main blocked"                      │    │
│  │  │                                                │    │
│  │  │  15m ago WARN  blast-radius  Write             │    │
│  │  │  → "12 files modified (threshold: 10)"         │    │
│  │  │                                                │    │
│  │  │  [Show all events →]                           │    │
│  │  └────────────────────────────────────────────────│    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### 2.3 Drill-Down Panels (L2)

Quando o usuário clica num KPI, guard ou tool, abre um painel **inline** (expande abaixo do elemento clicado, não modal):

**Click em "guard-branch" →**
```
┌──────────────────────────────────────────────────────────┐
│  guard-branch — Branch Protection            [× close]   │
│                                                          │
│  23 denials in 30 days   Trend: ↗ increasing             │
│                                                          │
│  ┌─────────────────────────┐  ┌─────────────────────┐    │
│  │  Timeline mini           │  │  Breakdown          │    │
│  │  ▁▂▃▅▇▅▃▂▁▂▃▅           │  │  Bash        87%   │    │
│  └─────────────────────────┘  │  Write       13%   │    │
│                                └─────────────────────┘    │
│                                                          │
│  Recent events for this guard:                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Apr 9 14:32  DENY  Bash  "git push origin main"  │  │
│  │  Apr 8 09:15  DENY  Bash  "git commit on master"  │  │
│  │  Apr 7 16:44  DENY  Bash  "git push -f main"      │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**Click em "Bash" no Hotspots →**
```
┌──────────────────────────────────────────────────────────┐
│  Bash — Tool Analysis                        [× close]   │
│                                                          │
│  45 denials  │  12 warnings  │  894 total executions     │
│  Deny rate: 5.0%  │  Warn rate: 1.3%                    │
│                                                          │
│  Which guards trigger on Bash?                           │
│  guard-branch      15  ████████████                      │
│  guard-commands     12  ████████▎                         │
│  guard-uncommitted   8  █████▎                            │
│                                                          │
│  Which commands get blocked most?                        │
│  "git push origin main"    8                              │
│  "rm -rf node_modules/"    4                              │
│  "git reset --hard"        3                              │
└──────────────────────────────────────────────────────────┘
```

### 2.4 Detail Modal (L3)

Click em qualquer evento individual → modal/drawer lateral:

```
┌──────────────────────────────────┐
│  Event Detail           [close]  │
│                                  │
│  DENY                            │
│  Apr 9, 2026 · 14:32:07 UTC     │
│                                  │
│  Guard     guard-branch          │
│  Tool      Bash                  │
│  Project   ~/Projects/hapai      │
│                                  │
│  Reason                          │
│  Push to protected branch        │
│  'main' is not allowed.          │
│  Use a feature branch instead:   │
│  feat/, fix/, chore/             │
│                                  │
│  Context                         │
│  Command attempted:              │
│  $ git push origin main          │
│                                  │
│  ← Previous    Next →            │
└──────────────────────────────────┘
```

---

## 3. UX Copy Redesign

### 3.1 StatCards — De contadores passivos a indicadores ativos

| Atual | Proposto | Racional |
|-------|----------|----------|
| "Blocked Actions" / "47" | "47 Actions Blocked" + "↗ 12% vs last period" | O número ganha contexto de tendência |
| "Soft Warnings" / "12" | "12 Warnings Issued" + "↘ 5% vs last period" | Mesmo padrão |
| *(não existe)* | "94.2% Allow Rate" | Mostra a saúde geral — o positivo |
| *(não existe)* | "5.8% Deny Rate" | Complemento — foco no problema |
| "Last 30 days" | Embutido na sparkline | Reduz noise visual |

### 3.2 Gráficos — Títulos que contam história

| Atual | Proposto |
|-------|----------|
| "Event Timeline — 30 days" | "Daily Activity" (com seletor de período inline) |
| "Top Blocking Hooks" | "Top Guards" (com subtítulo "Which rules trigger most?") |
| "Denials by Tool" | Merge em "Hotspots" com tabs Tool / Project |
| "Denials by Project" | *(tab dentro de Hotspots)* |
| "Deny Rate Trend — 30 days" | **Removido** — redundante com timeline. A sparkline nos cards já cobre. |

### 3.3 Tabela — De log dump a feed inteligente

| Atual | Proposto |
|-------|----------|
| "Guardrail Activity" (título) | "Recent Events" |
| "No guardrail events yet..." | "All clear. When hapai blocks or warns an action, it will show up here." |
| Todas as colunas visíveis | Compact card-style: tipo + guard + tool + reason preview |
| Sem filtro, sem paginação | Filtros inline (type, hook, tool, project) + "Show all →" |
| "Details" (coluna truncada) | Reason expandível on click |

### 3.4 Empty States

| Contexto | Copy Proposta |
|----------|---------------|
| Dashboard sem dados | "No events yet. Once hapai starts enforcing guardrails, your activity will appear here." |
| Drill-down sem dados | "No events match these filters. Try broadening your selection." |
| Período vazio | "No activity in this period. Your AI was either idle or fully compliant." |

### 3.5 Ações e CTAs

| Elemento | Copy |
|----------|------|
| Period selector | "7d · 14d · 30d" (não "Last 7 days", "Last 14 days"...) |
| Drill-down arrow | "→" (sem texto, affordance visual basta) |
| Close drill-down | "×" |
| Show all events | "View all events →" |
| Filter empty state | "No matches. Clear filters" |
| Event card expand | Click na row inteira (não botão separado) |

---

## 4. Conformidade com o Design System Existente

### 4.0 O problema: o Dashboard ignora o Design System que a LandingPage respeita

O `app.css` define um design system BMW-inspired robusto. A LandingPage usa-o de forma exemplar — backgrounds alternados (`--color-black` → `--color-white` → `--color-off-white`), `--surface-terminal` no hero, `--color-border-medium` nos cards, `--color-text-muted` para texto secundário, `Space Grotesk` para headings. O Dashboard, no entanto, diverge completamente:

**Tokens definidos mas não utilizados no Dashboard:**

| Token | Definido em app.css | Usado na Landing | Usado no Dashboard |
|-------|--------------------|--------------------|---------------------|
| `--shadow-sm/md/lg` | Sim | Não (mas não precisa) | **Não — cards completamente flat** |
| `--transition-fast/normal` | Sim | Sim (buttons, links) | **Não — zero transições** |
| `--color-allow (#27ae60)` | Sim | Sim (badges) | **Não — nenhuma métrica positiva** |
| `--surface-terminal` | Sim | Sim (hero terminal) | **Não — TrendChart usa `--color-near-black` hardcoded** |
| `--color-border-medium` | Sim | Sim (problem cards) | **Não — usa `--color-light-gray` direto** |
| `--color-text-muted` | Sim | Sim (descrições) | **Não — usa `#757575` hardcoded nos charts** |
| `--color-text-on-dark*` | Sim | Sim (hero, footer) | **Não — TrendChart usa valores diretos** |
| `Space Grotesk` (heading font) | Sim (Landing) | Sim | **Não — headings usam font genérica** |

**Cores hardcoded nos componentes Chart.js:**

- `TimelineChart.svelte`: `'#757575'`, `'#f0f0f0'`, `'#262626'` — deveriam ser `--color-meta-gray`, `--color-light-gray`, `--color-near-black`
- `HooksChart.svelte`: `'#262626'` — deveria ser `var(--color-near-black)`
- `ToolsChart.svelte`: `'rgba(28,105,212,0.85)'` — deveria ser baseado em `--color-blue`
- `ProjectsChart.svelte`: `'rgba(39,174,96,0.85)'` — deveria ser baseado em `--color-allow`

**Nota:** Chart.js não aceita CSS vars diretamente, mas o TrendChart já resolve isso com `getComputedStyle()`. Os outros charts devem seguir o mesmo padrão.

### 4.1 Regras de conformidade para o redesign

Toda mudança visual no dashboard deve:

1. **Usar tokens, nunca hardcoded** — cores, espaçamentos, pesos, sombras via CSS variables
2. **Resolver tokens para Chart.js via `getComputedStyle()`** — como TrendChart já faz
3. **Seguir a hierarquia tipográfica da Landing** — `Space Grotesk` para headings de seção, sistema font para body
4. **Usar elevação (shadows) para interatividade** — cards clicáveis ganham `--shadow-sm` + hover `--shadow-md`
5. **Manter border-radius: 0** — DNA BMW do design system (ângulos retos)
6. **Usar `--transition-fast` para hover states** — consistência com Header e Landing
7. **Incorporar `--color-allow`** — o dashboard precisa mostrar saúde positiva, não só problemas
8. **Background rhythm** — alternar `--color-white` e `--color-off-white` entre seções como a Landing faz
9. **Borders consistentes** — `--color-border-medium` para cards interativos (como Landing), `--color-light-gray` para separadores passivos

---

## 5. Mudanças Visuais Propostas

### 5.1 Cards com elevação e sparklines
- Adicionar `box-shadow: var(--shadow-sm)` + `:hover { box-shadow: var(--shadow-md); transition: box-shadow var(--transition-fast) }` nos cards clicáveis
- Sparkline inline (canvas 80x24px) dentro do StatCard mostrando tendência 30d
- Indicador de tendência: seta ↗/↘/→ com cor (`--color-deny` = piorando, `--color-allow` = melhorando)

### 5.2 Timeline como stacked area chart
- Substituir bar chart por stacked area — mais fluido, mostra tendência melhor
- Adicionar seletor de período (7d/14d/30d) como botões pill inline
- Hover mostra tooltip com breakdown do dia
- Cores via `getComputedStyle()` resolvendo `--color-deny` e `--color-warn`

### 5.3 Top Guards como horizontal bar simplificado
- Remover o donut chart (ruins para comparação)
- Horizontal bars com label à esquerda, valor à direita, barra preenchida proporcional
- Cada barra é clicável → abre drill-down
- Hover usa `--transition-fast` com `--shadow-sm`

### 5.4 Hotspots com tabs
- Merge Tools + Projects num único card com tabs "By Tool" / "By Project"
- Treemap ou horizontal bars (mesmo estilo do Top Guards)
- Cada item clicável → drill-down

### 5.5 Remover TrendChart
- Informação redundante. A tendência já estará nas sparklines e no timeline.
- Fundo escuro destoava do resto sem razão funcional.

### 5.6 Recent Events como feed compacto
- Cada evento = mini card (não row de tabela)
- Badge colorido (`badge-deny`, `badge-warn` — já existem no design system)
- Duas linhas: `guard-name · tool-name · tempo relativo` / `reason preview`
- Click expande inline → mostra reason completa
- Background alternado com `--color-off-white` nas rows pares
- Paginação: "View all events →" leva a uma view full-screen com filtros

### 5.7 Novos tokens CSS necessários

```css
:root {
  /* Dashboard-specific — extend the design system */
  --color-trend-up:      var(--color-deny);     /* ↗ getting worse */
  --color-trend-down:    var(--color-allow);    /* ↘ improving */
  --color-trend-flat:    var(--color-meta-gray); /* → stable */
  --sparkline-height:    24px;
  --sparkline-width:     80px;
}
```

---

## 6. Queries de Backend Necessárias

As 7 queries atuais (stats, timeline, hooks, denials, tools, projects, trends) precisam ser expandidas:

| Query Atual | Mantém? | Mudança |
|-------------|---------|---------|
| stats | Sim | Adicionar `total_events` e `allow_count` para calcular rates |
| timeline | Sim | Adicionar `allow` count por dia (não só deny/warn) |
| hooks | Sim | OK como está |
| denials | Sim | Adicionar paginação (limit/offset) e filtros server-side |
| tools | Sim | Adicionar `total_executions` por tool (não só denials) |
| projects | Sim | OK como está |
| trends | **Remover** | Redundante |

**Novas queries para drill-down:**

| Query | Parâmetros | Retorno |
|-------|-----------|---------|
| `hook_detail` | `hook_name`, `period` | Timeline + tool breakdown + recent events para esse guard |
| `tool_detail` | `tool_name`, `period` | Hook breakdown + top commands + recent events para esse tool |
| `event_detail` | `event_id` (ou `ts`) | Evento completo com todos os campos |

---

## 7. Priorização de Implementação

### Fase 1 — Design System compliance + Quick wins (sem backend changes)
1. **Refactor charts para usar tokens via `getComputedStyle()`** — eliminar todos os hardcoded
2. Adicionar `Space Grotesk` nos headings do Dashboard (matching Landing)
3. Redesign dos StatCards com tendência visual (↗/↘ calculado client-side)
4. Adicionar `--shadow-sm` nos cards + hover transitions
5. Remover TrendChart (redundante)
6. Substituir donut por horizontal bars no HooksChart
7. Merge ToolsChart + ProjectsChart em card com tabs
8. Copy redesign em todas as labels (i18n locales)
9. Filtros client-side na DenialsTable
10. Limitar tabela a 20 items + "View all"
11. Background alternado (`--color-off-white`) entre seções

### Fase 2 — Drill-down (precisa de UI work)
1. Click-to-expand nos horizontal bars → painel de detalhe inline
2. Event card expand → mostra reason completa
3. Side drawer para event detail (L3)

### Fase 3 — Backend (precisa de novas queries)
1. Allow count nos stats (para calcular rates)
2. Paginação server-side nos denials
3. Queries de drill-down (hook_detail, tool_detail)
4. Period selector com query parameterizada

---

## 8. Princípios Aplicados

1. **Números precisam de contexto**: "47" sozinho não diz nada. "47 ↗12%" diz que está piorando.
2. **Títulos são perguntas implícitas**: "Top Guards" → "quais regras disparam mais?" já está na cabeça do usuário.
3. **Empty states são oportunidades**: não diga "no data" — diga o que o usuário pode fazer.
4. **Ações são verbos específicos**: "View all events" não "See more" não "Load more".
5. **Redundância é ruído**: Timeline + Trend = mesma coisa em 2 visuais. Mate um.
6. **O design system existe para ser usado**: se declara `--shadow-md`, use-o. Se tem `--color-allow`, mostre métricas positivas.
7. **Consistência entre Landing e Dashboard**: quem entra pela Landing espera a mesma linguagem visual no Dashboard. Hoje são dois produtos diferentes.
