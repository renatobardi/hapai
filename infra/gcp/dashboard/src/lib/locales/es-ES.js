export default {
  header: {
    subtitle: 'Guardrails Analytics',
    nav: { dashboard: 'Panel', docs: 'Cómo funciona' },
    auth: { signIn: 'Iniciar sesión con GitHub', signOut: 'Cerrar sesión', signingIn: 'Iniciando sesión…', signInError: 'Error al iniciar sesión. Inténtalo de nuevo.' }
  },
  app: { initializing: 'Inicializando…' },
  landing: {
    hero: {
      headline: 'Tu IA acaba de hacer push a main. Otra vez.',
      sub: 'hapai es un sistema determinístico de guardrails para asistentes de programación con IA. Hooks basados en shell que bloquean acciones peligrosas antes de ejecutarse — no reglas en markdown que la IA ignora.',
      cta: 'Empezar',
      github: 'Ver en GitHub'
    },
    problem: {
      label: 'El Problema',
      heading: 'Las herramientas de IA ignoran tus reglas',
      cards: [
        { title: 'Commits en ramas protegidas', desc: 'Escribiste "nunca hagas push a main" en CLAUDE.md. La IA lo leyó, lo confirmó, y lo hizo de todos modos. El markdown es una sugerencia, no una restricción.' },
        { title: 'Comandos destructivos en producción', desc: 'rm -rf, git push --force, DROP TABLE — los asistentes de IA ejecutarán esto si el contexto lo sugiere. Una mala inferencia, daño permanente.' },
        { title: 'Ediciones silenciosas en archivos sensibles', desc: 'Tu .env fue confirmado. Tu lockfile fue reescrito. Tu flujo de trabajo de CI fue modificado. No te diste cuenta hasta que la build falló — o peor, hasta que no falló.' }
      ]
    },
    solution: {
      label: 'La Solución',
      heading: 'Hooks, no prompts. Determinístico, no probabilístico.',
      steps: [
        { title: 'Instala en 30 segundos', desc: 'Clona el repositorio, añade al PATH, ejecuta hapai install --global. Tres comandos. Sin SDK, sin servidor, sin dependencias más allá de bash y jq.' },
        { title: 'Los hooks interceptan cada acción', desc: "Cada vez que tu asistente de IA intenta ejecutar un comando, editar un archivo o hacer un commit — los hooks shell de hapai lo evalúan contra tus reglas antes de ejecutarse." },
        { title: 'Las violaciones se bloquean, no se registran', desc: 'Cuando se viola una regla, la acción es denegada. La IA recibe un mensaje de error claro e instrucciones sobre cómo proceder correctamente. Sin daños.' }
      ]
    },
    guardrails: {
      label: 'Guardrails',
      heading: '11 guards determinísticos. Todos configurables.',
      note: 'Cada guard soporta el modo fail_open — configura true para advertencias suaves o false para bloqueos estrictos.',
      link: 'Ver configuración completa →',
      guards: {
        branchProtection: 'Bloquea commits y pushes a main, master o cualquier rama protegida.',
        branchTaxonomy: 'Aplica convenciones de nomenclatura: feat/, fix/, chore/, docs/, hotfix/.',
        branchRules: 'Valida descripciones de rama y seguimiento de origen.',
        commitHygiene: 'Elimina atribuciones de IA: Co-Authored-By, "Generated with Claude".',
        fileProtection: 'Impide escrituras en .env, lockfiles, workflows de CI y cualquier patrón definido.',
        destructiveCommands: 'Bloquea rm -rf, git push --force, DROP TABLE y patrones configurables.',
        blastRadius: 'Advierte cuando un commit toca demasiados archivos o paquetes. Compatible con monorepos.',
        uncommittedChanges: 'Impide que la IA sobreescriba tu trabajo sin confirmar.',
        prReview: 'Revisión de código en segundo plano para cada PR. Auto-corrección opcional antes de bloquear.',
        gitWorkflow: 'Aplica el modelo trunk-based o GitFlow en todo el equipo.',
        flowDispatcher: 'Cadenas secuenciales de hooks con lógica de gate condicional para flujos complejos.'
      }
    },
    ecosystem: {
      label: 'Ecosistema',
      heading: 'Una config. Todas las herramientas de IA.'
    },
    quickStart: {
      label: 'Inicio Rápido',
      heading: 'Tres comandos. Estás protegido.',
      links: { config: '¿Quieres configurar los guardrails?', overrides: '¿Necesitas sobrescrituras por proyecto?' }
    },
    analytics: {
      label: 'Analytics',
      heading: 'Observa qué está haciendo tu IA.',
      desc: 'hapai registra cada acción — denegaciones, advertencias y permisos — en un registro de auditoría append-only. Sincroniza con BigQuery para analytics empresarial, o usa el dashboard integrado para visualizar la actividad de los guardrails en todos tus proyectos.',
      features: 'Línea de tiempo de 30 días · Hooks más bloqueadores · Distribución de herramientas · Desglose por proyecto · Tendencia de tasa de denegación',
      cta: 'Iniciar sesión con GitHub',
      signingIn: 'Iniciando sesión…',
      signInError: 'Error al iniciar sesión. Inténtalo de nuevo.',
      note: 'El dashboard requiere autenticación de GitHub. Tus datos de auditoría son tuyos.'
    },
    footer: {
      heading: 'Deja de esperar que la IA siga las reglas. Hazlas cumplir.',
      cta: 'Empezar',
      links: { github: 'GitHub', docs: 'Documentación', changelog: 'Changelog' },
      note: 'hapai v1.5.1 · Bash puro. Cero dependencias. Seguridad determinística.'
    }
  },
  docs: {
    nav: {
      groups: { gettingStarted: 'Primeros Pasos', configuration: 'Configuración', reference: 'Referencia', cloud: 'Nube', help: 'Ayuda' },
      whatIs: 'Qué es hapai',
      quickStart: 'Inicio Rápido',
      guardrails: 'Guardrails',
      configuration: 'Configuración',
      automations: 'Automatizaciones',
      cliCommands: 'Comandos CLI',
      analytics: 'Analytics',
      cloudLogging: 'Cloud Logging',
      export: 'Exportar',
      faq: 'FAQ'
    },
    sections: {
      whatIs: {
        heading: 'Qué es hapai',
        p1: 'hapai es un sistema determinístico de guardrails para asistentes de programación con IA (Claude Code, Cursor, Copilot). Aplica reglas de seguridad mediante hooks shell que interceptan llamadas de herramientas y bloquean violaciones antes de la ejecución — no prompts probabilísticos que se ignoran.',
        p2: 'Por qué importa: las herramientas de IA frecuentemente ignoran las instrucciones en markdown. Realizan commits en ramas protegidas, editan archivos de secretos, ejecutan comandos destructivos y añaden atribución de IA a pesar de las reglas explícitas. Los LLMs ven el markdown como sugerencias, no como requisitos.',
        p3: 'La solución: aplicación determinística mediante hooks que se ejecutan antes de la acción, no después.'
      },
      quickStart: { heading: 'Inicio Rápido' },
      guardrails: {
        heading: 'Guardrails',
        intro: 'Los guardrails bloquean violaciones antes de la ejecución. Todos soportan fail_open:',
        guards: [
          'Branch Protection — Commits/pushes en ramas protegidas (main, master)',
          'Branch Taxonomy — Aplica convenciones de nomenclatura (feat/, fix/, chore/, etc.)',
          'Commit Hygiene — Bloquea Co-Authored-By, menciones de IA, "Generated with Claude"',
          'File Protection — Impide escrituras en .env, lockfiles, archivos de workflow CI',
          'Destructive Commands — Bloquea rm -rf, git push --force, DROP TABLE, etc.',
          'Blast Radius — Advierte sobre commits grandes que tocan demasiados archivos',
          'Uncommitted Changes — Impide sobreescribir tu trabajo sin confirmar',
          'PR Review — Revisión de código en segundo plano para todos los PRs (opcional)',
          'Git Workflow — Aplicación de trunk-based o GitFlow'
        ],
        failOpenTitle: 'Modos fail_open:',
        failOpenModes: [
          'fail_open: false — Bloquea la ejecución, muestra error',
          'fail_open: true — Advierte pero permite (restricciones suaves)'
        ]
      },
      configuration: {
        heading: 'Configuración',
        intro: 'Basado en YAML con respaldo en tres niveles:',
        tiers: [
          'Proyecto ./hapai.yaml (sobrescribe todo)',
          'Global ~/.hapai/hapai.yaml',
          'Valores predeterminados hapai.defaults.yaml'
        ]
      },
      automations: {
        heading: 'Automatizaciones',
        intro: 'Las automatizaciones se ejecutan después de la ejecución. Habilita en hapai.yaml:'
      },
      cliCommands: {
        heading: 'Comandos CLI',
        installation: 'Instalación:',
        monitoring: 'Monitoreo:',
        emergency: 'Emergencia:',
        export: 'Exportar:'
      },
      analytics: {
        heading: 'Dashboard de Analytics',
        intro: 'Este dashboard muestra eventos de guardrail en tiempo real de tus registros de auditoría:',
        features: [
          'Timeline — Recuentos diarios de denegaciones/advertencias (ventana deslizante de 30 días)',
          'Top Blocking Hooks — Qué guardrails están más activos',
          'Recent Events — Feed en vivo de denegaciones y advertencias',
          'Tool Distribution — Qué herramientas activan más guards',
          'Project Breakdown — Estadísticas por proyecto',
          'Deny Rate Trend — Análisis histórico'
        ],
        setupTitle: 'Configuración:',
        setup: [
          'Crea un proyecto Firebase con GitHub OAuth',
          'Configura los secretos de GitHub Actions (VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID)',
          'Haz push a main → GitHub Actions construye y despliega en GitHub Pages',
          'Dashboard disponible en: https://owner.github.io/repo/'
        ]
      },
      cloudLogging: {
        heading: 'Cloud Logging (Opcional)',
        p1: 'Sincroniza registros de auditoría con GCP para analytics empresarial y cumplimiento normativo.',
        archTitle: 'Arquitectura:',
        enableTitle: 'Habilitar en hapai.yaml:',
        syncTitle: 'Sincronizar:',
        autoSyncTitle: 'Sincronización automática:',
        autoSyncColMethod: 'Herramienta',
        autoSyncColWhen: 'Cuándo',
        autoSyncColHow: 'Cómo',
        autoSyncSessionEnd: 'Fin de sesión',
        autoSyncPostCommit: 'Tras cada commit'
      },
      export: {
        heading: 'Exportar a Otras Herramientas',
        p1: 'hapai exporta guardrails a 6 herramientas de IA diferentes:',
        cols: { tool: 'Herramienta', file: 'Archivo', command: 'Comando' },
        exportAll: 'Exportar a todas las herramientas a la vez:',
        gitHooksNote: 'Sincronización automática del log de auditoría tras cada commit — funciona con cualquier herramienta que use git:'
      },
      faq: {
        heading: 'FAQ',
        questions: [
          { q: '¿Los hooks afectan el rendimiento de Claude Code?', a: 'Mínimamente. Cada hook se ejecuta en menos de 100ms. PreToolUse tiene un timeout de 7s, PostToolUse de 5s.' },
          { q: '¿Cómo desactivo temporalmente un guardrail?', a: 'Edita hapai.yaml y establece enabled: false para ese guardrail, o usa hapai kill para desactivar todos los hooks.' },
          { q: '¿Puedo crear guardrails personalizados?', a: 'Sí. Crea un script en ~/.hapai/hooks/pre-tool-use/my-guard.sh y regístralo en ~/.claude/settings.json.' },
          { q: '¿Dónde se almacenan los registros de auditoría?', a: 'Local: ~/.hapai/audit.jsonl (append-only). Cloud: BigQuery (si la sincronización con GCP está habilitada).' },
          { q: '¿Cómo veo qué están haciendo los hooks?', a: 'Usa hapai audit para ver entradas recentes, o tail -f ~/.hapai/audit.jsonl para streaming en vivo.' }
        ]
      },
      footer: 'Para guías de configuración detalladas, consulta hapai en GitHub.'
    }
  },
  dashboard: {
    loading: 'Cargando analytics…',
    error: 'Error',
    retry: 'Reintentar',
    denials: 'Acciones Bloqueadas',
    warnings: 'Advertencias Emitidas'
  },
  charts: {
    timeline: 'Actividad Diaria',
    hooks: 'Principales Guards',
    hotspots: { title: 'Hotspots', byTool: 'Por Herramienta', byProject: 'Por Proyecto' },
    labels: { denials: 'Denegaciones', warnings: 'Advertencias', denialsPerDay: 'Denegaciones por día' }
  },
  table: {
    title: 'Eventos Recientes',
    empty: 'Todo en orden. Cuando hapai bloquee o advierta una acción, aparecerá aquí.',
    noMatches: 'Ningún evento coincide con estos filtros. Amplía tu selección.',
    filterAll: 'Todos los tipos',
    filterHook: 'Todos los hooks',
    filterTool: 'Todas las herramientas',
    clearFilters: 'Limpiar filtros',
    viewAll: 'Ver todos los eventos',
    cols: { time: 'Hora', type: 'Tipo', hook: 'Hook', tool: 'Herramienta', reason: 'Motivo' }
  },
  statCard: { period: 'Últimos 30 días' },
  loading: { default: 'Cargando…' }
}
