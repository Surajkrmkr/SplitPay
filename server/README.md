# SplitPay Backend API

A production-ready REST API for the SplitPay group expense splitting Flutter app.

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 20 |
| Language | TypeScript 5 (strict mode) |
| Framework | Express.js 4 |
| Database | PostgreSQL 16 |
| ORM | Prisma 5 |
| Auth | JWT (access + refresh tokens) |
| Validation | Zod |
| Logging | Pino + pino-pretty |
| Container | Docker + docker-compose |

---

## Prerequisites

- Node.js >= 20.0.0
- npm >= 10
- PostgreSQL 16 (or Docker)
- Google OAuth2 client credentials

---

## Local Development Setup

### 1. Clone and install

```bash
git clone <repo>
cd BE
npm install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Start PostgreSQL

```bash
# Using Docker
docker run -d \
  --name splitpay_postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=splitpay_db \
  -p 5432:5432 \
  postgres:16-alpine
```

### 4. Run database migrations

```bash
npm run db:generate  # Generate Prisma client
npm run db:migrate   # Run migrations (creates DB schema)
```

### 5. Start the development server

```bash
npm run dev
```

The API will be available at `http://localhost:3000/api/v1`.

---

## Docker Setup

### Start all services

```bash
# Copy and edit environment variables
cp .env.example .env

# Build and start
docker-compose up -d

# View logs
docker-compose logs -f api
```

### Stop services

```bash
docker-compose down          # Stop containers
docker-compose down -v       # Stop and remove volumes (deletes DB data)
```

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `NODE_ENV` | No | `development` | Environment (`development`, `production`, `test`) |
| `PORT` | No | `3000` | HTTP server port |
| `API_PREFIX` | No | `/api/v1` | URL prefix for all routes |
| `DATABASE_URL` | Yes | — | PostgreSQL connection URL |
| `JWT_ACCESS_SECRET` | Yes | — | Secret for signing access tokens (min 16 chars) |
| `JWT_REFRESH_SECRET` | Yes | — | Secret for signing refresh tokens (min 16 chars) |
| `JWT_ACCESS_EXPIRES_IN` | No | `15m` | Access token expiry |
| `JWT_REFRESH_EXPIRES_IN` | No | `7d` | Refresh token expiry |
| `GOOGLE_CLIENT_ID` | Yes | — | Google OAuth2 client ID |
| `RATE_LIMIT_WINDOW_MS` | No | `900000` | Rate limit window in milliseconds (15 min) |
| `RATE_LIMIT_MAX` | No | `100` | Max requests per window per IP |
| `ALLOWED_ORIGINS` | No | `http://localhost:3000` | Comma-separated allowed CORS origins |
| `LOG_LEVEL` | No | `info` | Pino log level |

---

## API Endpoints

### Authentication (`/api/v1/auth`)

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/google` | No | Authenticate with Google ID token |
| POST | `/auth/refresh` | No | Refresh an access token |
| POST | `/auth/logout` | No | Invalidate a refresh token session |

**POST /auth/google**
```json
{ "idToken": "google-id-token" }
```
Returns `{ accessToken, refreshToken, user }`.

---

### Users (`/api/v1/users`)

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | Yes | Get authenticated user's profile |
| GET | `/users/search?q=query` | Yes | Search users by name or email |

---

### Groups (`/api/v1/groups`)

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/groups` | Yes | Create a new group |
| GET | `/groups` | Yes | List all groups the user belongs to |
| GET | `/groups/:id` | Yes | Get group details |
| POST | `/groups/:id/members` | Yes | Add a member (admin only) |
| DELETE | `/groups/:id/members/:memberId` | Yes | Remove a member |
| GET | `/groups/:id/expenses` | Yes | List expenses for a group |
| GET | `/groups/:id/balances` | Yes | Get simplified balance sheet |
| GET | `/groups/:id/settlements` | Yes | List settlements for a group |
| GET | `/groups/:id/activity` | Yes | Get activity feed (last 50 events) |

**POST /groups**
```json
{
  "name": "Goa Trip 2024",
  "description": "Annual trip expenses",
  "avatar": "https://example.com/avatar.png"
}
```

**POST /groups/:id/members**
```json
{ "userId": "uuid-of-user-to-add" }
```

---

### Expenses (`/api/v1/expenses`)

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/expenses` | Yes | Create a new expense |

**POST /expenses** — Equal split
```json
{
  "groupId": "group-uuid",
  "title": "Dinner at Taj",
  "amount": 1200.00,
  "paidById": "user-uuid",
  "splitType": "EQUAL",
  "participants": [
    { "userId": "user-1-uuid" },
    { "userId": "user-2-uuid" },
    { "userId": "user-3-uuid" }
  ]
}
```

**POST /expenses** — Percentage split
```json
{
  "splitType": "PERCENTAGE",
  "participants": [
    { "userId": "user-1-uuid", "percentage": 50 },
    { "userId": "user-2-uuid", "percentage": 30 },
    { "userId": "user-3-uuid", "percentage": 20 }
  ]
}
```

**POST /expenses** — Exact amounts
```json
{
  "splitType": "EXACT",
  "amount": 1000,
  "participants": [
    { "userId": "user-1-uuid", "share": 600 },
    { "userId": "user-2-uuid", "share": 400 }
  ]
}
```

---

### Settlements (`/api/v1/settlements`)

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/settlements` | Yes | Record a settlement payment |

**POST /settlements**
```json
{
  "groupId": "group-uuid",
  "payerId": "user-uuid-who-paid",
  "payeeId": "user-uuid-who-receives",
  "amount": 500.00,
  "notes": "UPI transfer"
}
```

---

### Health Check

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/v1/health` | No | Service health status |

---

## Database Schema Overview

```
users           — User accounts (linked to Google OAuth)
sessions        — Refresh token sessions
groups          — Expense groups
group_members   — Group membership with roles (ADMIN/MEMBER)
expenses        — Group expenses with split type
expense_participants — Per-user share of each expense
settlements     — Recorded payments between users
activities      — Audit log / activity feed
```

### Key Design Decisions

- **UUID primary keys** for all entities (compatible with mobile offline-first sync)
- **Decimal(12, 2)** for monetary amounts (no floating point errors)
- **Cascade deletes** — removing a group removes all its expenses, settlements, activities
- **Soft references** — activity records use `SetNull` so deleting an expense doesn't lose the activity log entry

---

## Balance Calculation

The `/groups/:id/balances` endpoint uses a **greedy min-cash-flow algorithm**:

1. Sum up all expenses per participant (who owes whom, how much)
2. Subtract all settlements to get net balances
3. Separate into net creditors (+) and net debtors (-)
4. Greedily match the largest debtor with the largest creditor
5. Returns the minimum number of transactions to settle all debts

---

## Architecture

```
src/
  configs/      — Environment configuration (Zod-validated)
  middlewares/  — auth, error handling, validation
  modules/      — Feature modules (auth, users, groups, expenses, settlements, activity)
    <module>/
      *.repository.ts  — Data access layer (Prisma only)
      *.service.ts     — Business logic layer (no Express types)
      *.controller.ts  — HTTP layer (parse req, call service, send response)
      *.routes.ts      — Express Router
  prisma/       — Prisma client singleton
  routes/       — Route aggregator
  types/        — Shared TypeScript types
  utils/        — Shared utilities (jwt, logger, response, errors, balance)
  app.ts        — Express app setup
  server.ts     — Entry point, graceful shutdown
```

---

## Digital Ocean Deployment

### Option A: App Platform (Managed, Recommended)

1. Push code to GitHub/GitLab
2. In DO App Platform, create a new app from your repo
3. Add a **PostgreSQL** managed database component
4. Set environment variables in the App Platform dashboard
5. Set the **Run Command** to:
   ```bash
   npx prisma migrate deploy && node dist/server.js
   ```
6. Set the **Build Command** to:
   ```bash
   npm ci && npm run build && npm run db:generate
   ```

### Option B: Droplet (Manual)

See `docker/deploy.md` for full step-by-step instructions.

---

## Scripts

| Script | Description |
|---|---|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm run start` | Start production server |
| `npm run lint` | Lint TypeScript files |
| `npm run lint:fix` | Auto-fix lint issues |
| `npm run format` | Format code with Prettier |
| `npm run db:generate` | Generate Prisma client from schema |
| `npm run db:migrate` | Run pending migrations (dev) |
| `npm run db:deploy` | Deploy migrations (production) |
| `npm run db:studio` | Open Prisma Studio GUI |
