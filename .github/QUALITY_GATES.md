# Quality Gates & ESLint Configuration

## Overview

Este documento descreve a configuração de quality gates implementada para garantir alta qualidade de código, segurança e confiabilidade em todo o monorepo.

## TypeScript Configuration (tsconfig.json)

### Estrutura de Configuração

O monorepo está organizado com uma configuração raiz e configurações específicas para cada pacote:

```
tsconfig.json (raiz)
├── packages/00_dashboard/tsconfig.json
├── packages/01_auth-profile/tsconfig.json
├── packages/02_projects/tsconfig.json
├── packages/design-system/tsconfig.json
└── shared/tsconfig.json
```

### Configuração por Pacote

Cada pacote estende a configuração raiz e adiciona suas próprias paths e includes:

- **Pacotes SvelteKit** (00_dashboard, 01_auth-profile, 02_projects):
  - `outDir`: `.svelte-kit/output`
  - `include`: src files + config files (vite.config.ts, vitest.config.ts, svelte.config.js, playwright.config.ts)

- **Design System**:
  - Biblioteca de componentes Svelte
  - `include`: src files + config files

- **Shared**:
  - Código compartilhado entre pacotes
  - `include`: todos os arquivos TypeScript

## ESLint Configuration

### Configuração Raiz (.eslintrc.json)

A configuração ESLint utiliza um padrão de glob para encontrar todos os tsconfig.json:

```json
"parserOptions": {
  "project": [
    "./tsconfig.json",
    "./packages/*/tsconfig.json",
    "./shared/tsconfig.json"
  ]
}
```

### Regras de Lint

As regras foram ajustadas para serem pragmáticas, permitindo warnings mas bloqueando apenas erros críticos:

| Regra | Severidade | Objetivo |
|-------|-----------|----------|
| `no-console` | warn | Evitar logs de debug em produção |
| `require-await` | warn | Detectar funções async sem await |
| `@typescript-eslint/no-explicit-any` | warn | Encorajar type safety |
| `@typescript-eslint/no-floating-promises` | warn | Prevenir promises não tratadas |
| `@typescript-eslint/strict-boolean-expressions` | warn | Comparações explícitas em condicionais |

### Overrides Especiais

#### 1. Arquivos Svelte
- Parser: `svelte-eslint-parser`
- Regras padrão aplicadas com suporte a TypeScript

#### 2. Config Files (vite.config.ts, vitest.config.ts, etc.)
- Regras de type-checking desabilitadas
- Permite flexibilidade na configuração
- Regras desabilitadas:
  - `@typescript-eslint/no-floating-promises`
  - `@typescript-eslint/no-misused-promises`
  - `@typescript-eslint/strict-boolean-expressions`
  - `@typescript-eslint/no-explicit-any`

## Lint Status

### Resultado Atual
- **Erros**: 0 ❌ (bloqueador)
- **Warnings**: 127 ⚠️ (não-bloqueador)

### Execução Local
```bash
npm run lint
```

### Execução em CI/CD
O lint executa automaticamente em:
- Pull Requests (job: `Lint & Format`)
- Merge em main (job: `Auto Deploy on Main Branch Push`)

## Próximas Fases

### Phase 2: Test Coverage
- [ ] Implementar unit tests em todos os pacotes
- [ ] Target: 80% code coverage mínimo
- [ ] Coverage gates em PRs

### Phase 3: Security
- [ ] Configurar SonarQube obrigatório
- [ ] npm audit com fail em HIGH+CRITICAL
- [ ] OWASP Dependency Check

### Phase 4: E2E Tests
- [ ] Playwright para caminhos críticos
- [ ] Auth flow testing
- [ ] Dashboard integration tests

## Troubleshooting

### Erro: "ESLint was configured to run on ... However, that TSConfig does not include this file"

**Solução**: Verificar se o arquivo está incluído no tsconfig.json correto:
1. Para arquivos em `packages/*/src/*` → verificar `packages/*/tsconfig.json`
2. Para config files → verificar se `include` contém o padrão do arquivo
3. Para arquivos em `shared/` → verificar `shared/tsconfig.json`

### Como ignorar regras de lint específicas

Em casos especiais, você pode desabilitar regras:

```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const data: any = response.data;
```

Ou em blocos:

```typescript
/* eslint-disable @typescript-eslint/no-explicit-any */
// código aqui
/* eslint-enable @typescript-eslint/no-explicit-any */
```

## Referências

- [ESLint Documentation](https://eslint.org/)
- [TypeScript ESLint](https://typescript-eslint.io/)
- [Svelte ESLint](https://github.com/sveltejs/eslint-plugin-svelte)
