# Integration Flows - OUTE

Guia detalhado dos fluxos de integração entre os 3 domínios da aplicação.

## 📊 Arquitetura de Integração

```
┌─────────────────────────────────────────────────────────────┐
│                     00_Dashboard (Port 3000)                 │
│  Frontend web que consome APIs dos outros serviços          │
└──────────────┬──────────────────────────────────────────────┘
               │
       ┌───────┴───────┐
       │               │
       ▼               ▼
┌──────────────────┐ ┌──────────────────┐
│  01_Auth-Profile │ │   02_Projects    │
│  (Port 3001)     │ │  (Port 3002)     │
│                  │ │                  │
│ - Login          │ │ - CRUD projects  │
│ - JWT issue      │ │ - Validate JWT   │
│ - User profile   │ │ - Associate user │
└──────────────────┘ └──────────────────┘
       │
       ▼
   ┌─────────────┐
   │ PostgreSQL  │
   │ Centralizado│
   └─────────────┘
```

---

## 1️⃣ Authentication Flow (01_auth-profile)

### 1.1 Login Process

**User flow**:
1. User fills login form in 00_dashboard
2. Form submits to 01_auth-profile `/auth/login`
3. Auth service validates credentials
4. Issues JWT token
5. Dashboard stores JWT locally
6. User can now access other services

**Endpoint**: `POST /auth/login`

**Request**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid-123",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Code example** (00_dashboard):
```typescript
async function login(email: string, password: string) {
  const response = await fetch('http://localhost:3001/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });

  if (response.ok) {
    const data = await response.json();
    localStorage.setItem('token', data.token);
    localStorage.setItem('user', JSON.stringify(data.user));
    return data;
  }

  throw new Error('Login failed');
}
```

### 1.2 JWT Token Storage & Usage

**Where stored**:
- Browser localStorage: `token` key
- Expires in 24 hours (configurable)

**Usage in other requests**:
```typescript
const token = localStorage.getItem('token');

fetch('http://localhost:3002/projects', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### 1.3 JWT Validation

**Token structure**:
```
Header.Payload.Signature
```

**Payload** (decoded):
```json
{
  "sub": "user-uuid",          // user ID
  "email": "user@example.com",
  "iat": 1694000000,           // issued at
  "exp": 1694086400            // expires in 24h
}
```

**Validation** (in 02_projects):
```typescript
import jwt from 'jsonwebtoken';

export async function validateJWT(token: string): Promise<string | null> {
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    return payload.sub;  // user ID
  } catch {
    return null;  // Invalid token
  }
}
```

### 1.4 Logout Flow

**Endpoint**: `POST /auth/logout`

**Request**:
```bash
curl -X POST http://localhost:3001/auth/logout \
  -H "Authorization: Bearer <token>"
```

**Response**:
```json
{
  "message": "Logged out successfully"
}
```

**Client side** (00_dashboard):
```typescript
function logout() {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  // Redirect to login
  window.location.href = '/login';
}
```

---

## 2️⃣ Projects Flow (02_projects)

### 2.1 Fetch Projects List

**User has logged in with JWT token**

**Endpoint**: `GET /projects`

**Request headers**:
```
Authorization: Bearer eyJhbGc...
```

**Flow**:
1. 00_dashboard sends GET request to 02_projects with JWT
2. 02_projects receives request
3. Extracts JWT from Authorization header
4. Validates JWT (verify signature, expiration)
5. Extracts user ID from JWT payload
6. Queries database: `SELECT * FROM projects WHERE user_id = ?`
7. Returns projects list

**Code example** (02_projects):
```typescript
// routes/projects/+server.ts

export async function GET({ request }) {
  // Extract JWT
  const authHeader = request.headers.get('Authorization');
  const token = authHeader?.replace('Bearer ', '');

  if (!token) {
    return new Response(JSON.stringify({ error: 'No token' }), { status: 401 });
  }

  // Validate JWT
  const userId = await validateJWT(token);
  if (!userId) {
    return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 });
  }

  // Get user's projects
  const projects = await db.query(
    'SELECT * FROM projects WHERE user_id = $1',
    [userId]
  );

  return new Response(JSON.stringify(projects), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
}
```

### 2.2 Create Project

**Endpoint**: `POST /projects`

**Request**:
```json
{
  "name": "My Project",
  "description": "Project description",
  "status": "active"
}
```

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Code example** (02_projects):
```typescript
export async function POST({ request }) {
  // Validate JWT
  const userId = await validateTokenFromRequest(request);
  if (!userId) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
  }

  const body = await request.json();

  // Insert project
  const result = await db.query(
    `INSERT INTO projects (user_id, name, description, status, created_at)
     VALUES ($1, $2, $3, $4, NOW())
     RETURNING *`,
    [userId, body.name, body.description, body.status || 'active']
  );

  return new Response(JSON.stringify(result.rows[0]), { status: 201 });
}
```

### 2.3 Update Project

**Endpoint**: `PATCH /projects/:id`

**Request**:
```json
{
  "name": "Updated name",
  "status": "archived"
}
```

### 2.4 Delete Project

**Endpoint**: `DELETE /projects/:id`

**Important**: Only delete if user owns the project

---

## 3️⃣ User Profile Flow (01_auth-profile)

### 3.1 Get User Profile

**Endpoint**: `GET /profile`

**Request**:
```bash
curl http://localhost:3001/profile \
  -H "Authorization: Bearer <token>"
```

**Response**:
```json
{
  "id": "uuid-123",
  "email": "user@example.com",
  "name": "John Doe",
  "createdAt": "2024-03-07T10:00:00Z"
}
```

### 3.2 Update User Profile

**Endpoint**: `PATCH /profile`

**Request**:
```json
{
  "name": "New Name"
}
```

---

## 4️⃣ Dashboard Integration

### 4.1 Login Page Flow

```
┌──────────────────┐
│ Login Page       │
│ (00_dashboard)   │
└────────┬─────────┘
         │
         │ User submits form
         ▼
    ┌─────────────────────────────────┐
    │ POST /auth/login                 │
    │ (01_auth-profile)               │
    │ { email, password }              │
    └────────┬────────────────────────┘
             │
             │ Validate credentials
             │ Generate JWT
             ▼
    ┌──────────────────────────────┐
    │ Response: { token, user }     │
    └────────┬─────────────────────┘
             │
             │ Store in localStorage
             ▼
    ┌──────────────────────────┐
    │ Dashboard Home           │
    │ Now authenticated        │
    └──────────────────────────┘
```

### 4.2 Dashboard Home Flow

```
┌────────────────────────────────┐
│ Dashboard Home                  │
│ Load on mount:                  │
│ 1. Check for token              │
│ 2. Fetch user projects          │
└────────┬───────────────────────┘
         │
         ├──► localStorage.getItem('token')
         │
         │ (if no token)
         ├──► Redirect to /login
         │
         │ (if token exists)
         ├──► GET /projects (02_projects)
         │    with JWT in headers
         │
         ▼
    ┌──────────────────────────┐
    │ Display Projects         │
    │ List all user projects   │
    └──────────────────────────┘
```

### 4.3 Create Project Flow

```
Create Project Form
        │
        ├──► Validate input locally
        │
        ├──► POST /projects (02_projects)
        │    Headers: { Authorization: Bearer <token> }
        │    Body: { name, description, status }
        │
        ├──► 02_projects validates JWT
        │
        ├──► Insert to database
        │
        ├──► Response: { id, name, ... }
        │
        ▼
   Refresh projects list
   Show success toast
```

---

## 5️⃣ Error Handling

### 5.1 Token Expired

**Flow**:
```
Request to 02_projects
    ↓
JWT validation fails
    ↓
Return 401 Unauthorized
    ↓
00_dashboard receives 401
    ↓
Clear localStorage
    ↓
Redirect to /login
```

**Code** (00_dashboard):
```typescript
async function fetchProjects() {
  const token = localStorage.getItem('token');

  const response = await fetch('http://localhost:3002/projects', {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (response.status === 401) {
    // Token expired or invalid
    localStorage.removeItem('token');
    window.location.href = '/login';
    return;
  }

  const projects = await response.json();
  return projects;
}
```

### 5.2 Network Errors

**Fallback**:
```typescript
try {
  const response = await fetch(url);
  const data = await response.json();
  return data;
} catch (error) {
  console.error('Network error:', error);
  throw new Error('Failed to fetch projects');
}
```

---

## 6️⃣ Development Testing

### Local Testing with cURL

**Login**:
```bash
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Fetch Projects** (replace TOKEN):
```bash
curl http://localhost:3002/projects \
  -H "Authorization: Bearer TOKEN"
```

**Create Project**:
```bash
curl -X POST http://localhost:3002/projects \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"My Project","description":"Test"}'
```

---

## 7️⃣ Deployment Considerations

### URLs in Production

Development:
```
Dashboard:      http://localhost:3000
Auth-Profile:   http://localhost:3001
Projects:       http://localhost:3002
```

Production (GCP Cloud Run):
```
Dashboard:      https://hapai-dashboard-xxx.run.app
Auth-Profile:   https://hapai-auth-profile-xxx.run.app
Projects:       https://hapai-projects-xxx.run.app
```

**Update environment variables** in Cloud Run deployment.

### CORS Configuration

If services run on different domains, configure CORS:

**02_projects (+server.ts)**:
```typescript
const headers = {
  'Access-Control-Allow-Origin': process.env.DASHBOARD_URL,
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
};
```

---

## 📝 Summary

| Flow | From | To | Auth | Data |
|------|------|-----|------|------|
| Login | Dashboard | Auth-Profile | Password | JWT + User |
| Fetch Projects | Dashboard | Projects | JWT | Projects list |
| Create Project | Dashboard | Projects | JWT | Project data |
| Get Profile | Dashboard | Auth-Profile | JWT | User profile |

All inter-service communication is **HTTP-based**, **JWT-authenticated**, and **stateless**.
