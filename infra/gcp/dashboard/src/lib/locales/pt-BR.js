export default {
  header: {
    subtitle: 'Guardrails Analytics',
    nav: { dashboard: 'Painel', docs: 'Como funciona' },
    auth: { signIn: 'Entrar com GitHub', signOut: 'Sair', signingIn: 'Entrando…', signInError: 'Falha ao entrar. Tente novamente.' }
  },
  app: { initializing: 'Inicializando…' },
  landing: {
    hero: {
      headline: 'Sua IA acabou de fazer push para a main. De novo.',
      sub: 'hapai é um sistema determinístico de guardrails para assistentes de código com IA. Hooks via shell que bloqueiam ações perigosas antes de executar — não regras em markdown que a IA ignora.',
      cta: 'Começar',
      github: 'Ver no GitHub'
    },
    problem: {
      label: 'O Problema',
      heading: 'Ferramentas de IA ignoram suas regras',
      cards: [
        { title: 'Commits em branches protegidas', desc: 'Você escreveu "nunca faça push para a main" no CLAUDE.md. A IA leu, confirmou, e fez push assim mesmo. Markdown é sugestão, não restrição.' },
        { title: 'Comandos destrutivos em produção', desc: 'rm -rf, git push --force, DROP TABLE — assistentes de IA executam esses comandos se o contexto sugerir. Uma inferência errada, dano permanente.' },
        { title: 'Edições silenciosas em arquivos sensíveis', desc: 'Seu .env foi commitado. Seu lockfile foi reescrito. Seu workflow de CI foi modificado. Você não percebeu até a build quebrar — ou pior, até não quebrar.' }
      ]
    },
    solution: {
      label: 'A Solução',
      heading: 'Hooks, não prompts. Determinístico, não probabilístico.',
      steps: [
        { title: 'Instale em 30 segundos', desc: 'Clone o repositório, adicione ao PATH, execute hapai install --global. Três comandos. Sem SDK, sem servidor, sem dependências além de bash e jq.' },
        { title: 'Hooks interceptam cada ação', desc: 'Cada vez que seu assistente de IA tenta executar um comando, editar um arquivo ou fazer um commit — os hooks shell do hapai avaliam contra suas regras antes de executar.' },
        { title: 'Violações são bloqueadas, não registradas', desc: 'Quando uma regra é violada, a ação é negada. A IA recebe uma mensagem de erro clara e instruções de como proceder corretamente. Sem danos.' }
      ]
    },
    guardrails: {
      label: 'Guardrails',
      heading: '11 guards determinísticos. Todos configuráveis.',
      note: 'Cada guard suporta o modo fail_open — defina como true para avisos suaves ou false para bloqueios rígidos.',
      link: 'Ver configuração completa →',
      guards: {
        branchProtection: 'Bloqueia commits, pushes e exclusões via gh api em main, master ou qualquer branch protegida.',
        branchTaxonomy: 'Aplica convenções de nomenclatura: feat/, fix/, chore/, docs/, hotfix/.',
        branchRules: 'Valida descrições de branch e rastreamento de origem.',
        commitHygiene: 'Remove atribuições de IA: Co-Authored-By, "Generated with Claude".',
        fileProtection: 'Impede escrita em .env, lockfiles, workflows de CI e qualquer padrão definido.',
        destructiveCommands: 'Bloqueia rm -rf, git push --force, DROP TABLE e padrões configuráveis.',
        blastRadius: 'Avisa quando um commit toca muitos arquivos ou pacotes. Compatível com monorepos.',
        uncommittedChanges: 'Impede a IA de sobrescrever seu trabalho não commitado.',
        prReview: 'Revisão de código em background para cada PR. Auto-fix opcional antes de bloquear.',
        gitWorkflow: 'Aplica modelo trunk-based ou GitFlow em toda a equipe.',
        flowDispatcher: 'Chains sequenciais de hooks com lógica de gate condicional para fluxos complexos.'
      }
    },
    ecosystem: {
      label: 'Ecossistema',
      heading: 'Uma config. Toda ferramenta de IA.'
    },
    quickStart: {
      label: 'Início Rápido',
      heading: 'Três comandos. Você está protegido.',
      links: { config: 'Quer configurar os guardrails?', overrides: 'Precisa de overrides por projeto?' }
    },
    analytics: {
      label: 'Analytics',
      heading: 'Veja o que sua IA está fazendo.',
      desc: 'hapai registra cada ação — negações, avisos e permissões — em um audit trail append-only. Sincronize com BigQuery para analytics empresarial, ou use o dashboard integrado para visualizar a atividade dos guardrails em todos os seus projetos.',
      features: 'Timeline de 30 dias · Drill-down por guard e ferramenta · Cards de taxa Allow/Deny · Breakdown por projeto · Drawer de detalhe do evento',
      cta: 'Entrar com GitHub',
      signingIn: 'Entrando…',
      signInError: 'Falha ao entrar. Tente novamente.',
      note: 'O dashboard requer autenticação GitHub. Seus dados de auditoria são seus.'
    },
    footer: {
      heading: 'Pare de esperar que a IA siga as regras. Aplique-as.',
      cta: 'Começar',
      links: { github: 'GitHub', docs: 'Documentação', changelog: 'Changelog' },
      note: 'hapai v1.6.2 · Bash puro. Zero dependências. Segurança determinística.'
    }
  },
  docs: {
    nav: {
      groups: { gettingStarted: 'Primeiros Passos', configuration: 'Configuração', reference: 'Referência', cloud: 'Nuvem', help: 'Ajuda' },
      whatIs: 'O que é hapai',
      quickStart: 'Início Rápido',
      guardrails: 'Guardrails',
      configuration: 'Configuração',
      automations: 'Automações',
      cliCommands: 'Comandos CLI',
      analytics: 'Analytics',
      cloudLogging: 'Cloud Logging',
      export: 'Exportar',
      faq: 'FAQ'
    },
    sections: {
      whatIs: {
        heading: 'O que é hapai',
        p1: 'hapai é um sistema determinístico de guardrails para assistentes de código com IA (Claude Code, Cursor, Copilot). Ele aplica regras de segurança via hooks shell que interceptam chamadas de ferramentas e bloqueiam violações antes da execução — não prompts probabilísticos que são ignorados.',
        p2: 'Por que isso importa: ferramentas de IA com frequência ignoram instruções em markdown. Elas commitam em branches protegidas, editam arquivos de segredos, executam comandos destrutivos e adicionam atribuição de IA apesar de regras explícitas. LLMs veem markdown como sugestões, não requisitos.',
        p3: 'A solução: aplicação determinística via hooks rodando antes da ação, não depois.'
      },
      quickStart: { heading: 'Início Rápido' },
      guardrails: {
        heading: 'Guardrails',
        intro: 'Os guardrails bloqueiam violações antes da execução. Todos suportam fail_open:',
        guards: [
          'Branch Protection — Commits, pushes e exclusões gh api em branches protegidas (main, master)',
          'Branch Taxonomy — Aplica convenções de nomenclatura (feat/, fix/, chore/, etc.)',
          'Commit Hygiene — Bloqueia Co-Authored-By, menções a IA, "Generated with Claude"',
          'File Protection — Impede escrita em .env, lockfiles, arquivos de workflow CI',
          'Destructive Commands — Bloqueia rm -rf, git push --force, DROP TABLE, etc.',
          'Blast Radius — Avisa em commits grandes que tocam muitos arquivos',
          'Uncommitted Changes — Impede sobrescrever seu trabalho não commitado',
          'PR Review — Revisão de código em background para todos os PRs (opcional)',
          'Git Workflow — Aplicação de trunk-based ou GitFlow'
        ],
        failOpenTitle: 'Modos fail_open:',
        failOpenModes: [
          'fail_open: false — Bloqueia execução, exibe erro',
          'fail_open: true — Avisa mas permite (restrições suaves)'
        ]
      },
      configuration: {
        heading: 'Configuração',
        intro: 'Baseado em YAML com fallback em três camadas:',
        tiers: [
          'Projeto ./hapai.yaml (sobrescreve tudo)',
          'Global ~/.hapai/hapai.yaml',
          'Padrões hapai.defaults.yaml'
        ]
      },
      automations: {
        heading: 'Automações',
        intro: 'Automações executam após a execução. Habilite em hapai.yaml:'
      },
      cliCommands: {
        heading: 'Comandos CLI',
        installation: 'Instalação:',
        monitoring: 'Monitoramento:',
        emergency: 'Emergência:',
        export: 'Exportar:'
      },
      analytics: {
        heading: 'Dashboard de Analytics',
        intro: 'Este dashboard exibe eventos de guardrail em tempo real dos seus logs de auditoria:',
        features: [
          'Timeline — Contagem diária de negações/avisos (janela rolante de 30 dias)',
          'Top Blocking Hooks — Quais guardrails estão mais ativos',
          'Recent Events — Feed ao vivo de negações e avisos',
          'Tool Distribution — Quais ferramentas acionam mais guards',
          'Project Breakdown — Estatísticas por projeto',
          'Deny Rate Trend — Análise histórica'
        ],
        setupTitle: 'Configuração:',
        setup: [
          'Crie um projeto Firebase com GitHub OAuth',
          'Configure os secrets do GitHub Actions (VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID)',
          'Faça push para main → GitHub Actions faz build e deploy para GitHub Pages',
          'Dashboard disponível em: https://owner.github.io/repo/'
        ]
      },
      cloudLogging: {
        heading: 'Cloud Logging (Opcional)',
        p1: 'Sincronize logs de auditoria para GCP para analytics empresarial e compliance.',
        archTitle: 'Arquitetura:',
        enableTitle: 'Habilitar em hapai.yaml:',
        syncTitle: 'Sincronizar:',
        autoSyncTitle: 'Sincronização automática:',
        autoSyncColMethod: 'Ferramenta',
        autoSyncColWhen: 'Quando',
        autoSyncColHow: 'Como',
        autoSyncSessionEnd: 'Fim de sessão',
        autoSyncPostCommit: 'Após cada commit'
      },
      export: {
        heading: 'Exportar para Outras Ferramentas',
        p1: 'hapai exporta guardrails para 6 ferramentas de IA diferentes:',
        cols: { tool: 'Ferramenta', file: 'Arquivo', command: 'Comando' },
        exportAll: 'Exportar para todas as ferramentas de uma vez:',
        gitHooksNote: 'Sincronização automática do log de auditoria após cada commit — funciona com qualquer ferramenta que use git:'
      },
      faq: {
        heading: 'FAQ',
        questions: [
          { q: 'Os hooks afetam a performance do Claude Code?', a: 'Minimamente. Cada hook roda em menos de 100ms. PreToolUse tem timeout de 7s, PostToolUse de 5s.' },
          { q: 'Como desabilito temporariamente um guardrail?', a: 'Edite o hapai.yaml e defina enabled: false para aquele guardrail, ou use hapai kill para desabilitar todos os hooks.' },
          { q: 'Posso criar guardrails personalizados?', a: 'Sim. Crie um script em ~/.hapai/hooks/pre-tool-use/my-guard.sh e registre-o em ~/.claude/settings.json.' },
          { q: 'Onde os logs de auditoria ficam armazenados?', a: 'Local: ~/.hapai/audit.jsonl (append-only). Cloud: BigQuery (se a sincronização com GCP estiver habilitada).' },
          { q: 'Como vejo o que os hooks estão fazendo?', a: 'Use hapai audit para ver entradas recentes, ou tail -f ~/.hapai/audit.jsonl para streaming ao vivo.' }
        ]
      },
      footer: 'Para guias detalhados de configuração, veja hapai no GitHub.'
    }
  },
  dashboard: {
    loading: 'Buscando analytics…',
    error: 'Erro',
    retry: 'Tentar novamente',
    denials: 'Ações Bloqueadas',
    warnings: 'Avisos Emitidos'
  },
  charts: {
    timeline: 'Atividade Diária',
    hooks: 'Principais Guards',
    hotspots: { title: 'Hotspots', byTool: 'Por Ferramenta', byProject: 'Por Projeto' },
    labels: { denials: 'Negações', warnings: 'Avisos', denialsPerDay: 'Negações por dia' }
  },
  table: {
    title: 'Eventos Recentes',
    empty: 'Tudo certo. Quando hapai bloquear ou avisar uma ação, ela aparecerá aqui.',
    noMatches: 'Nenhum evento corresponde a esses filtros. Tente ampliar a seleção.',
    filterAll: 'Todos os tipos',
    filterHook: 'Todos os hooks',
    filterTool: 'Todas as ferramentas',
    clearFilters: 'Limpar filtros',
    viewAll: 'Ver todos os eventos',
    loadMore: 'Carregar mais do servidor',
    cols: { time: 'Hora', type: 'Tipo', hook: 'Hook', tool: 'Ferramenta', reason: 'Motivo' }
  },
  statCard: { period: 'Últimos 30 dias', period7d: 'Últimos 7 dias', period14d: 'Últimos 14 dias', allowRate: 'Taxa de Permissão', denyRate: 'Taxa de Bloqueio' },
  loading: { default: 'Carregando…' },
  common: { justNow: 'agora', minutesAgo: 'm atrás', hoursAgo: 'h atrás' },
  drilldown: {
    close: '×',
    denials: 'negações',
    warnings: 'avisos',
    triggeredByTool: 'Acionado por ferramenta',
    triggeredByGuard: 'Acionado por guard',
    recentEvents: 'Eventos Recentes',
    empty: 'Sem eventos neste período.',
    viewEvent: 'Ver',
    loading: 'Carregando…',
    activity: 'Atividade',
    denyRate: 'taxa de bloqueio'
  },
  detail: {
    title: 'Detalhe do Evento',
    close: 'Fechar',
    prev: '← Ant.',
    next: 'Próx. →',
    guard: 'Guard',
    tool: 'Ferramenta',
    project: 'Projeto',
    reason: 'Motivo',
    time: 'Hora',
    of: 'de'
  }
}
