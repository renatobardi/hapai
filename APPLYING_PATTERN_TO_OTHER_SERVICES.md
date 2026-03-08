# Applying Hexagonal Architecture Pattern to Other Services

## Overview

This document provides a **template and step-by-step guide** for applying the same Hexagonal Architecture + DDD + Clean Code + TDD pattern used in `01_auth-profile` to the other services:

- **00_dashboard** - Dashboard UI and widget management
- **02_projects** - Project management and collaboration

## Architecture Template

Every service should follow this structure:

```
packages/XX_service/
├── src/
│   ├── domain/                          # Pure business logic
│   │   ├── entities/
│   │   │   └── [Entity].ts
│   │   ├── value-objects/
│   │   │   └── [ValueObject].ts
│   │   ├── services/
│   │   │   └── [DomainService].ts
│   │   ├── repositories/
│   │   │   └── I[Entity]Repository.ts
│   │   └── errors/
│   │       └── [Error].ts
│   │
│   ├── application/                     # Orchestration
│   │   ├── use-cases/
│   │   │   └── [use-case]/[UseCase].ts
│   │   ├── dto/
│   │   │   └── [Request|Response].ts
│   │   ├── dto/mappers/
│   │   │   └── [Entity]Mapper.ts
│   │   └── ports/
│   │       └── I[Adapter].ts
│   │
│   ├── infrastructure/                  # Adapters
│   │   ├── adapters/
│   │   │   └── [Adapter].ts
│   │   └── config/
│   │       └── [config].ts
│   │
│   ├── presentation/                    # HTTP/API Layer
│   │   ├── handlers/
│   │   │   └── [Handler].ts
│   │   ├── middleware/
│   │   │   └── [middleware].ts
│   │   ├── errors/
│   │   │   └── ErrorMapper.ts
│   │   └── routes/
│   │       └── api/[endpoint]/+server.ts
│   │
│   ├── app.ts                           # Entry point
│   ├── hooks.server.ts                  # DI setup
│   └── __tests__/
│       ├── unit/
│       ├── integration/
│       └── e2e/
│
├── playwright.config.ts                 # E2E config
├── tsconfig.json
├── package.json
├── README.md
└── PHASE_*.md                          # Documentation
```

---

## Service-Specific Patterns

### 00_dashboard Service

#### Domain Layer

**Key Entities**:
```typescript
// domain/entities/Dashboard.ts
export class Dashboard {
  private constructor(
    public readonly id: DashboardId,
    public readonly userId: UserId,
    public name: string,
    public description: string,
    private widgets: Widget[],
    public readonly createdAt: Date,
    public updatedAt: Date
  ) {}

  static create(props: {
    userId: UserId;
    name: string;
    description: string;
  }): Dashboard {
    // Factory method with validation
  }

  addWidget(widget: Widget): void {
    if (this.widgets.length >= 10) {
      throw new DashboardLimitExceededError('Max 10 widgets');
    }
    this.widgets.push(widget);
  }

  removeWidget(widgetId: WidgetId): void {
    this.widgets = this.widgets.filter(w => !w.id.equals(widgetId));
  }

  getWidgets(): Widget[] {
    return [...this.widgets]; // Immutable for external use
  }
}

// domain/entities/Widget.ts
export class Widget {
  private constructor(
    public readonly id: WidgetId,
    public readonly dashboardId: DashboardId,
    public title: string,
    public type: WidgetType, // CHART, TABLE, METRIC, etc.
    public config: Record<string, unknown>,
    public readonly createdAt: Date
  ) {}

  static create(props: {
    dashboardId: DashboardId;
    title: string;
    type: WidgetType;
    config: Record<string, unknown>;
  }): Widget {
    // Validation & construction
  }

  updateConfig(config: Record<string, unknown>): void {
    // Domain logic for config update
  }
}
```

**Key Value Objects**:
```typescript
// domain/value-objects/DashboardId.ts
export class DashboardId {
  private constructor(private value: string) {
    if (!isValidUUID(value)) {
      throw new InvalidDashboardIdError();
    }
  }

  static generate(): DashboardId {
    return new DashboardId(uuidv4());
  }

  static fromString(value: string): DashboardId {
    return new DashboardId(value);
  }

  getValue(): string {
    return this.value;
  }
}

// domain/value-objects/WidgetType.ts
export class WidgetType {
  static CHART = new WidgetType('CHART');
  static TABLE = new WidgetType('TABLE');
  static METRIC = new WidgetType('METRIC');
  static CUSTOM = new WidgetType('CUSTOM');

  private constructor(public readonly value: string) {}

  static fromString(value: string): WidgetType {
    const types = [WidgetType.CHART, WidgetType.TABLE, WidgetType.METRIC, WidgetType.CUSTOM];
    const type = types.find(t => t.value === value);
    if (!type) throw new InvalidWidgetTypeError();
    return type;
  }

  equals(other: WidgetType): boolean {
    return this.value === other.value;
  }
}
```

**Key Ports**:
```typescript
// domain/repositories/IDashboardRepository.ts
export interface IDashboardRepository {
  save(dashboard: Dashboard): Promise<void>;
  findById(id: DashboardId): Promise<Dashboard | null>;
  findByUserId(userId: UserId): Promise<Dashboard[]>;
  delete(id: DashboardId): Promise<void>;
}

// domain/repositories/IWidgetRepository.ts
export interface IWidgetRepository {
  save(widget: Widget): Promise<void>;
  findById(id: WidgetId): Promise<Widget | null>;
  findByDashboardId(dashboardId: DashboardId): Promise<Widget[]>;
  delete(id: WidgetId): Promise<void>;
}
```

#### Application Layer

**Use Cases**:
```typescript
// application/use-cases/create-dashboard/CreateDashboardUseCase.ts
export class CreateDashboardUseCase {
  constructor(
    private dashboardRepository: IDashboardRepository,
    private authService: IAuthService // From 01_auth-profile
  ) {}

  async execute(input: CreateDashboardInput): Promise<CreateDashboardOutput> {
    // Validate user authenticated
    const user = await this.authService.getCurrentUser();
    if (!user) throw new UnauthorizedError();

    // Create dashboard
    const dashboard = Dashboard.create({
      userId: UserId.fromString(user.id),
      name: input.name,
      description: input.description
    });

    // Persist
    await this.dashboardRepository.save(dashboard);

    return new CreateDashboardOutput({
      id: dashboard.id.getValue(),
      name: dashboard.name,
      description: dashboard.description
    });
  }
}

// application/use-cases/add-widget/AddWidgetUseCase.ts
export class AddWidgetUseCase {
  constructor(
    private dashboardRepository: IDashboardRepository,
    private widgetRepository: IWidgetRepository
  ) {}

  async execute(input: AddWidgetInput): Promise<AddWidgetOutput> {
    // Load dashboard
    const dashboard = await this.dashboardRepository.findById(
      DashboardId.fromString(input.dashboardId)
    );
    if (!dashboard) throw new DashboardNotFoundError();

    // Create widget
    const widget = Widget.create({
      dashboardId: dashboard.id,
      title: input.title,
      type: WidgetType.fromString(input.type),
      config: input.config
    });

    // Add to dashboard
    dashboard.addWidget(widget);

    // Persist both
    await this.widgetRepository.save(widget);
    await this.dashboardRepository.save(dashboard);

    return toDashboardOutput(dashboard);
  }
}
```

#### Test Strategy (TDD)

```typescript
// __tests__/unit/domain/entities/Dashboard.test.ts
describe('Dashboard Entity', () => {
  it('should create dashboard with valid data', async () => {
    const userId = UserId.fromString('550e8400-e29b-41d4-a716-446655440000');
    const dashboard = Dashboard.create({
      userId,
      name: 'My Dashboard',
      description: 'Dashboard description'
    });

    expect(dashboard.name).toBe('My Dashboard');
    expect(dashboard.getWidgets()).toHaveLength(0);
  });

  it('should add widget to dashboard', async () => {
    const dashboard = Dashboard.create({
      userId,
      name: 'My Dashboard',
      description: 'desc'
    });

    const widget = Widget.create({
      dashboardId: dashboard.id,
      title: 'Chart Widget',
      type: WidgetType.CHART,
      config: { datasource: 'api' }
    });

    dashboard.addWidget(widget);
    expect(dashboard.getWidgets()).toHaveLength(1);
  });

  it('should reject more than 10 widgets', async () => {
    const dashboard = Dashboard.create({...});

    for (let i = 0; i < 10; i++) {
      const widget = Widget.create({...});
      dashboard.addWidget(widget);
    }

    const extraWidget = Widget.create({...});
    expect(() => dashboard.addWidget(extraWidget))
      .toThrow(DashboardLimitExceededError);
  });
});

// __tests__/integration/repositories/PostgresDashboardRepository.test.ts
describe('PostgresDashboardRepository', () => {
  it('should persist and retrieve dashboard', async () => {
    const repository = new PostgresDashboardRepository(db);
    const dashboard = Dashboard.create({
      userId,
      name: 'Test Dashboard',
      description: 'desc'
    });

    await repository.save(dashboard);
    const retrieved = await repository.findById(dashboard.id);

    expect(retrieved).toBeDefined();
    expect(retrieved?.name).toBe('Test Dashboard');
  });
});

// __tests__/e2e/dashboard.spec.ts
describe('Dashboard E2E', () => {
  test('should create dashboard and add widget', async ({ page }) => {
    // Login
    const token = await login(page, 'test@example.com', 'SecurePass123!');

    // Create dashboard
    const dashResponse = await page.request.post('/api/dashboard', {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        name: 'E2E Dashboard',
        description: 'Testing dashboard'
      }
    });

    expect(dashResponse.status()).toBe(201);
    const dashboard = await dashResponse.json();
    const dashboardId = dashboard.id;

    // Add widget
    const widgetResponse = await page.request.post('/api/dashboard/:id/widgets', {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        title: 'Chart',
        type: 'CHART',
        config: { datasource: 'api' }
      }
    });

    expect(widgetResponse.status()).toBe(201);
    const widget = await widgetResponse.json();
    expect(widget.title).toBe('Chart');
  });
});
```

---

### 02_projects Service

#### Domain Layer

**Key Entities**:
```typescript
// domain/entities/Project.ts
export class Project {
  private constructor(
    public readonly id: ProjectId,
    public name: ProjectName,
    public description: string,
    public readonly owner: UserId,
    private members: ProjectMember[],
    public status: ProjectStatus,
    public readonly createdAt: Date,
    public updatedAt: Date
  ) {}

  static create(props: {
    name: ProjectName;
    description: string;
    owner: UserId;
  }): Project {
    const project = new Project(
      ProjectId.generate(),
      props.name,
      props.description,
      props.owner,
      [],
      ProjectStatus.DRAFT,
      new Date(),
      new Date()
    );

    // Owner is always added as member
    project.addMember(props.owner, MemberRole.OWNER);
    return project;
  }

  addMember(userId: UserId, role: MemberRole): void {
    if (this.members.some(m => m.userId.equals(userId))) {
      throw new UserAlreadyMemberError();
    }

    const member = ProjectMember.create({
      projectId: this.id,
      userId,
      role
    });

    this.members.push(member);
  }

  removeMember(userId: UserId): void {
    if (this.owner.equals(userId)) {
      throw new CannotRemoveOwnerError();
    }

    this.members = this.members.filter(m => !m.userId.equals(userId));
  }

  canUserEdit(userId: UserId): boolean {
    const member = this.members.find(m => m.userId.equals(userId));
    return member?.isEditor() ?? false;
  }

  getMembers(): ProjectMember[] {
    return [...this.members];
  }

  transitionStatus(newStatus: ProjectStatus): void {
    // Business logic: validate state transitions
    const validTransitions: Record<string, ProjectStatus[]> = {
      [ProjectStatus.DRAFT]: [ProjectStatus.ACTIVE],
      [ProjectStatus.ACTIVE]: [ProjectStatus.COMPLETED, ProjectStatus.DRAFT],
      [ProjectStatus.COMPLETED]: []
    };

    if (!validTransitions[this.status.value].includes(newStatus)) {
      throw new InvalidStatusTransitionError();
    }

    this.status = newStatus;
    this.updatedAt = new Date();
  }
}

// domain/entities/ProjectMember.ts
export class ProjectMember {
  private constructor(
    public readonly id: ProjectMemberId,
    public readonly projectId: ProjectId,
    public readonly userId: UserId,
    public role: MemberRole,
    public readonly joinedAt: Date
  ) {}

  static create(props: {
    projectId: ProjectId;
    userId: UserId;
    role: MemberRole;
  }): ProjectMember {
    return new ProjectMember(
      ProjectMemberId.generate(),
      props.projectId,
      props.userId,
      props.role,
      new Date()
    );
  }

  isEditor(): boolean {
    return this.role.equals(MemberRole.EDITOR) || this.role.equals(MemberRole.OWNER);
  }

  isOwner(): boolean {
    return this.role.equals(MemberRole.OWNER);
  }
}
```

**Key Value Objects**:
```typescript
// domain/value-objects/ProjectName.ts
export class ProjectName {
  private constructor(private value: string) {
    if (!value || value.trim().length === 0) {
      throw new InvalidProjectNameError('Name cannot be empty');
    }
    if (value.length > 100) {
      throw new InvalidProjectNameError('Name must be <= 100 chars');
    }
  }

  static create(value: string): ProjectName {
    return new ProjectName(value.trim());
  }

  getValue(): string {
    return this.value;
  }

  equals(other: ProjectName): boolean {
    return this.value === other.value;
  }
}

// domain/value-objects/ProjectStatus.ts
export class ProjectStatus {
  static DRAFT = new ProjectStatus('DRAFT');
  static ACTIVE = new ProjectStatus('ACTIVE');
  static COMPLETED = new ProjectStatus('COMPLETED');

  private constructor(public readonly value: string) {}

  static fromString(value: string): ProjectStatus {
    const statuses = [ProjectStatus.DRAFT, ProjectStatus.ACTIVE, ProjectStatus.COMPLETED];
    const status = statuses.find(s => s.value === value);
    if (!status) throw new InvalidProjectStatusError();
    return status;
  }

  equals(other: ProjectStatus): boolean {
    return this.value === other.value;
  }
}

// domain/value-objects/MemberRole.ts
export class MemberRole {
  static OWNER = new MemberRole('OWNER');
  static EDITOR = new MemberRole('EDITOR');
  static VIEWER = new MemberRole('VIEWER');

  private constructor(public readonly value: string) {}

  static fromString(value: string): MemberRole {
    const roles = [MemberRole.OWNER, MemberRole.EDITOR, MemberRole.VIEWER];
    const role = roles.find(r => r.value === value);
    if (!role) throw new InvalidMemberRoleError();
    return role;
  }

  equals(other: MemberRole): boolean {
    return this.value === other.value;
  }
}
```

**Key Ports**:
```typescript
// domain/repositories/IProjectRepository.ts
export interface IProjectRepository {
  save(project: Project): Promise<void>;
  findById(id: ProjectId): Promise<Project | null>;
  findByOwnerId(userId: UserId): Promise<Project[]>;
  findByMemberId(userId: UserId): Promise<Project[]>;
  delete(id: ProjectId): Promise<void>;
}

// domain/repositories/IProjectMemberRepository.ts
export interface IProjectMemberRepository {
  save(member: ProjectMember): Promise<void>;
  findById(id: ProjectMemberId): Promise<ProjectMember | null>;
  findByProjectId(projectId: ProjectId): Promise<ProjectMember[]>;
  findByUserId(userId: UserId): Promise<ProjectMember[]>;
  delete(id: ProjectMemberId): Promise<void>;
}
```

#### Application Layer

**Use Cases**:
```typescript
// application/use-cases/create-project/CreateProjectUseCase.ts
export class CreateProjectUseCase {
  constructor(private projectRepository: IProjectRepository) {}

  async execute(input: CreateProjectInput): Promise<CreateProjectOutput> {
    const ownerUserId = UserId.fromString(input.userId);
    const projectName = ProjectName.create(input.name);

    const project = Project.create({
      name: projectName,
      description: input.description,
      owner: ownerUserId
    });

    await this.projectRepository.save(project);

    return new CreateProjectOutput({
      id: project.id.getValue(),
      name: project.name.getValue(),
      description: project.description,
      owner: project.owner.getValue(),
      status: project.status.value,
      members: project.getMembers().map(m => ({
        userId: m.userId.getValue(),
        role: m.role.value
      }))
    });
  }
}

// application/use-cases/add-member/AddMemberUseCase.ts
export class AddMemberUseCase {
  constructor(
    private projectRepository: IProjectRepository,
    private memberRepository: IProjectMemberRepository
  ) {}

  async execute(input: AddMemberInput): Promise<void> {
    const project = await this.projectRepository.findById(
      ProjectId.fromString(input.projectId)
    );
    if (!project) throw new ProjectNotFoundError();

    // Only owner can add members
    if (!project.owner.equals(UserId.fromString(input.requestingUserId))) {
      throw new UnauthorizedError('Only project owner can add members');
    }

    const member = ProjectMember.create({
      projectId: project.id,
      userId: UserId.fromString(input.userId),
      role: MemberRole.fromString(input.role)
    });

    project.addMember(member.userId, member.role);

    await this.memberRepository.save(member);
    await this.projectRepository.save(project);
  }
}
```

---

## Implementation Roadmap

### Step 1: Domain Layer (1-2 weeks)
1. **Identify Entities**: What are the core business concepts?
2. **Define Value Objects**: What validates, immutable objects do we need?
3. **Design Repositories**: What persistence operations are required?
4. **Create Errors**: What domain-specific errors can occur?
5. **Write Tests**: TDD - tests before implementation

**Deliverables**: Domain layer complete with 60+ unit tests

### Step 2: Infrastructure Layer (1 week)
1. **Implement Repositories**: Persist entities
2. **Create Adapters**: External integrations (APIs, databases)
3. **Setup DI**: Configure dependencies
4. **Write Integration Tests**: Test adapters with real/mock resources

**Deliverables**: Infrastructure layer complete with 30+ integration tests

### Step 3: Application Layer (1 week)
1. **Create Use Cases**: Orchestrate domain + infrastructure
2. **Design DTOs**: Input/output contracts
3. **Implement Mappers**: Entity → DTO conversion
4. **Write Tests**: Use case validation

**Deliverables**: Application layer complete with 40+ tests

### Step 4: Presentation Layer (1 week)
1. **Create Handlers**: HTTP request orchestration
2. **Setup Routes**: SvelteKit API routes
3. **Implement Middleware**: Authentication, authorization
4. **Error Mapping**: Domain errors → HTTP responses

**Deliverables**: Presentation layer complete with 40+ tests

### Step 5: E2E Tests (1 week)
1. **Setup Playwright**: Configuration & fixtures
2. **Write Flows**: Complete user workflows
3. **Security Tests**: Authentication, authorization
4. **Integration Tests**: Service-to-service calls

**Deliverables**: E2E test suite complete with 20+ tests

### Total Effort: ~5-6 weeks per service

---

## Code Generation Script

To speed up scaffolding, create:

```bash
#!/bin/bash
# scripts/generate-service.sh

SERVICE_NAME=$1
SERVICE_DESC=$2

echo "Generating service: $SERVICE_NAME - $SERVICE_DESC"

# Create directories
mkdir -p packages/$SERVICE_NAME/src/{domain,application,infrastructure,presentation}/__tests__
mkdir -p packages/$SERVICE_NAME/src/domain/{entities,value-objects,services,repositories,errors}
mkdir -p packages/$SERVICE_NAME/src/application/{use-cases,dto/mappers,ports}
mkdir -p packages/$SERVICE_NAME/src/infrastructure/{adapters,config}
mkdir -p packages/$SERVICE_NAME/src/presentation/{handlers,middleware,routes/api,errors}

# Generate boilerplate files...
# (Copy from template files)

echo "✅ Service generated: $SERVICE_NAME"
```

---

## Reusable Patterns

### 1. Entity Factory Pattern
```typescript
export class Entity {
  private constructor(...props) { }

  // Create new instance with validation
  static create(props: CreateProps): Entity {
    // Validate
    // Return new instance
  }

  // Reconstruct from DB
  static reconstruct(props: DBProps): Entity {
    // Return new instance from DB data
  }

  // Business methods...
}
```

### 2. Value Object Pattern
```typescript
export class ValueObject {
  private constructor(value: string) {
    ValueObject.validate(value);
    this.value = value;
  }

  static create(value: string): ValueObject {
    return new ValueObject(value);
  }

  static fromString(value: string): ValueObject {
    return new ValueObject(value);
  }

  private static validate(value: string): void {
    // Throw specific error if invalid
  }

  getValue(): string {
    return this.value;
  }

  equals(other: ValueObject): boolean {
    return this.value === other.value;
  }
}
```

### 3. Repository Port Pattern
```typescript
export interface IRepository {
  save(entity: Entity): Promise<void>;
  findById(id: EntityId): Promise<Entity | null>;
  findBy(criteria: SearchCriteria): Promise<Entity[]>;
  delete(id: EntityId): Promise<void>;
}
```

### 4. Use Case Pattern
```typescript
export class UseCase {
  constructor(
    private repository: IRepository,
    private dependency: IDependency
  ) {}

  async execute(input: Input): Promise<Output> {
    // 1. Validate input
    // 2. Load entities
    // 3. Execute domain logic
    // 4. Persist changes
    // 5. Return output
  }
}
```

### 5. Handler Pattern
```typescript
export class Handler {
  async handle(request: Request): Promise<Response> {
    try {
      // 1. Extract & validate request
      // 2. Call use case
      // 3. Return formatted response
    } catch (error) {
      return ErrorMapper.toHttpResponse(error);
    }
  }
}
```

### 6. Error Mapping Pattern
```typescript
export class ErrorMapper {
  static toHttpResponse(error: unknown): HttpResponse {
    if (error instanceof DomainError) {
      return this.mapDomainError(error);
    }
    return this.mapUnknownError(error);
  }

  private static mapDomainError(error: DomainError): HttpResponse {
    const mapping: Record<string, number> = {
      InvalidEmailError: 400,
      UserNotFoundError: 404,
      UnauthorizedError: 401
    };

    return {
      status: mapping[error.constructor.name] || 500,
      body: { error: error.message, code: error.code }
    };
  }
}
```

---

## Testing Strategy

Each service should have:

### Unit Tests (60%+)
- Domain layer (entities, value objects, errors)
- Application layer (use cases, DTOs)
- Utilities and helpers

### Integration Tests (20%+)
- Infrastructure adapters
- Repository implementations
- External service integrations

### E2E Tests (15%+)
- Complete user workflows
- API contracts
- Cross-service communication

### Total Coverage: 80%+

```bash
# Run all tests
npm run test --workspaces

# Run with coverage
npm run test -- --coverage

# Run E2E tests
npm run test:e2e --workspaces
```

---

## Checklist for Each Service

### Before Starting
- [ ] Clear domain understanding
- [ ] Key entities identified
- [ ] Value objects designed
- [ ] Use cases listed
- [ ] API contracts sketched

### Domain Layer
- [ ] Entities created with factories
- [ ] Value objects with validation
- [ ] Repository ports defined
- [ ] Domain errors hierarchy
- [ ] 60+ unit tests, all passing
- [ ] No infrastructure imports
- [ ] Business logic isolated

### Infrastructure Layer
- [ ] Repository adapters implemented
- [ ] Database/API integrations
- [ ] Dependency injection setup
- [ ] 30+ integration tests
- [ ] Adapters swappable (mock support)

### Application Layer
- [ ] Use cases implemented
- [ ] DTOs designed
- [ ] Mappers created
- [ ] 40+ use case tests
- [ ] Clear orchestration
- [ ] No business logic in adapters

### Presentation Layer
- [ ] HTTP handlers created
- [ ] SvelteKit routes setup
- [ ] Error mapping working
- [ ] Authentication/authorization enforced
- [ ] 40+ presentation tests
- [ ] CORS configured

### E2E Tests
- [ ] 20+ E2E tests
- [ ] Happy path scenarios
- [ ] Error scenarios
- [ ] Security checks
- [ ] CI/CD ready
- [ ] Documentation complete

---

## Success Criteria

✅ **100% of above completed**
✅ **All tests passing (unit + integration + E2E)**
✅ **80%+ code coverage**
✅ **Architecture follows template**
✅ **Documentation complete**
✅ **Ready for production deployment**

---

## Resources

### From 01_auth-profile (Template)
- Domain layer: `packages/01_auth-profile/src/domain/`
- Infrastructure: `packages/01_auth-profile/src/infrastructure/`
- Application: `packages/01_auth-profile/src/application/`
- Presentation: `packages/01_auth-profile/src/presentation/`
- E2E tests: `packages/01_auth-profile/src/__tests__/e2e/`

### Documentation
- `REFACTORING_COMPLETION.md` - Overall refactoring details
- `PHASE_1_SUMMARY.md` - Domain layer deep-dive
- `PHASE_2_SUMMARY.md` - Infrastructure deep-dive
- `PHASE_3_SUMMARY.md` - Application deep-dive
- `PHASE_4_SUMMARY.md` - Presentation deep-dive
- `PHASE_5_SUMMARY.md` - E2E testing deep-dive

### Tools & Commands
```bash
# Generate new service
./scripts/generate-service.sh 03_new-service "Service Description"

# Run tests
npm run test --workspaces
npm run test:e2e --workspaces

# Code coverage
npm run test -- --coverage

# Lint & format
npm run lint --workspaces
npm run format --workspaces
```

---

## Timeline Estimate

| Phase | 00_dashboard | 02_projects |
|-------|--------------|------------|
| Domain | 1-2 weeks | 1-2 weeks |
| Infrastructure | 1 week | 1 week |
| Application | 1 week | 1 week |
| Presentation | 1 week | 1 week |
| E2E Tests | 1 week | 1 week |
| **Total** | **5-6 weeks** | **5-6 weeks** |

**Total for both services: 10-12 weeks**

---

## Conclusion

By following this template and pattern, you can consistently implement:

✅ **Hexagonal Architecture** across all services
✅ **Domain-Driven Design** principles
✅ **Clean Code** standards
✅ **Comprehensive Testing** (TDD)
✅ **Professional Practices** (DoD, DoR)

This ensures **consistency, maintainability, and quality** across the entire OUTE monorepo.

---

**Template Version**: 1.0
**Based on**: 01_auth-profile implementation
**Status**: Ready for application
