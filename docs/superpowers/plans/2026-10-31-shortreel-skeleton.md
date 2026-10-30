# ShortReel Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** สร้าง monorepo ที่รันได้จริง มี backend พร้อม stub ครบ 42 endpoint และแอป Flutter พร้อมหน้าจอ placeholder เพื่อให้ทีม 6 คนแยกงานต่อได้

**Architecture:** `backend/` เป็น Express แบบ routes/controllers/models แยกไฟล์ตามฟีเจอร์ โดย `createApp({ pool, jwtSecret })` รับ dependency เพื่อให้ test ไม่ต้องมี MySQL ส่วน `mobile/` เป็น Flutter แบบ MVC ใช้ `provider` และ `ApiClient` ตัวเดียว

**Tech Stack:** Node.js 22 (CommonJS), Express 5, mysql2, jsonwebtoken, multer, dotenv, argon2, node:test, supertest, Flutter 3.44, provider, dio, flutter_secure_storage, video_player

**Spec:** `docs/superpowers/specs/2026-10-31-shortreel-skeleton-design.md`

## Global Constraints

- รูปแบบ error ทุกกรณี: `{ "error": { "code": "...", "message": "..." } }`
- ข้อความ stub: `NOT_IMPLEMENTED`, `This endpoint is not implemented yet`
- ห้ามเปิด `uploads/` เป็น static
- ห้ามแก้เนื้อหา `backend/db/shortreel.sql` ต้องตรงกับไฟล์ต้นฉบับทุกไบต์
- `INTERNAL_ERROR` ห้ามส่งรายละเอียดภายในกลับไปที่ client
- Upload รับเฉพาะ `video/mp4` จำกัด 200 MB
- JWT payload คือ `{ sub, role }` ใช้ HS256
- ห้าม push และห้ามสร้าง repo บน GitHub
- ข้อความ commit ทุกครั้งต้องลงท้ายด้วย `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

- JSON เสียใน request body: ต้องได้ `400 VALIDATION_ERROR` ไม่ใช่ `500` (ทดสอบใน Task 1)
- Token หมดอายุ, เซ็นด้วย secret อื่น หรือใช้ `alg: none`: ต้องได้ `401` (ทดสอบใน Task 2)
- ไฟล์ผิดประเภทหรือใหญ่เกิน: ต้องได้ `400` หรือ `413` ตาม error กลาง และไม่เหลือไฟล์ค้าง (ทดสอบใน Task 4)
- ไม่ได้ตั้ง `JWT_SECRET`: server ต้องไม่เริ่มทำงาน แทนที่จะเซ็น token ด้วยค่าว่าง (ทดสอบใน Task 5)
- Backend ปิดอยู่หรือตอบ HTML แทน JSON: แอปต้องได้ `ApiException` ไม่ใช่ crash (ทดสอบใน Task 7)

---

### Task 1: Repo และแกนของ backend

**Files:**
- Create: `.gitignore`, `backend/package.json`, `backend/.env.example`, `backend/db/shortreel.sql`, `backend/uploads/.gitkeep`
- Create: `backend/src/app.js`, `backend/src/utils/ApiError.js`, `backend/src/middleware/errorHandler.js`
- Test: `backend/test/helpers.js`, `backend/test/app.test.js`

**Interfaces:**
- Produces: `createApp({ pool, jwtSecret }) -> express.Application` เก็บค่าไว้ที่ `app.locals.pool` และ `app.locals.jwtSecret`
- Produces: `new ApiError(status: number, code: string, message: string)`
- Produces จาก `test/helpers.js`: `TEST_SECRET`, `okPool`, `failingPool`, `makeApp(pool = okPool)`

- [ ] **Step 1: เริ่ม repo และ commit spec กับแผน**

ตรวจว่า `git config user.name` และ `user.email` มีค่า ถ้าไม่มีให้หยุดถามผู้ใช้ จากนั้น `git init -b main` เขียน `.gitignore` ให้ครอบคลุม `node_modules/`, `.env`, `backend/uploads/*`, `!backend/uploads/.gitkeep`

```bash
git add .gitignore docs
git commit -m "docs: add skeleton spec and plan"
```

- [ ] **Step 2: ตั้งค่า backend package**

เขียน `package.json` ชื่อ `shortreel-backend`, `"type": "commonjs"`, scripts `"start": "node src/server.js"`, `"dev": "node --watch src/server.js"`, `"test": "node --test"` ติดตั้ง dependencies ตาม Tech Stack และ `supertest` เป็น devDependency เขียน `.env.example` ตามค่าที่ spec หัวข้อ 4 กำหนด

คัดลอก `C:\Users\Admin\Downloads\shortreel.sql` ไปที่ `backend/db/shortreel.sql` แล้วเปรียบเทียบ hash ว่าตรงกัน

- [ ] **Step 3: เขียน test ที่ต้อง fail** ใน `backend/test/app.test.js`

```js
test('health is 200 when the pool answers', async () => {
  const res = await request(makeApp()).get('/api/health');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok', db: 'up' });
});

test('health is 503 when the pool fails', async () => {
  const res = await request(makeApp(failingPool)).get('/api/health');
  assert.equal(res.status, 503);
  assert.equal(res.body.error.code, 'DB_UNAVAILABLE');
});

test('unknown route is a 404 in the shared format', async () => {
  const res = await request(makeApp()).get('/api/nope');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

test('malformed JSON is a 400, not a 500', async () => {
  const res = await request(makeApp()).post('/api/nope')
    .set('Content-Type', 'application/json').send('{bad');
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
});

test('unexpected errors hide their details', async () => {
  const secret = 'db password leaked';
  const outer = require('express')();
  outer.get('/boom', () => { throw new Error(secret); });
  outer.use(require('../src/middleware/errorHandler'));
  const res = await request(outer).get('/boom');
  assert.equal(res.status, 500);
  assert.equal(res.body.error.code, 'INTERNAL_ERROR');
  assert.ok(!JSON.stringify(res.body).includes(secret));
});
```

- [ ] **Step 4: รัน test ให้เห็นว่า fail**

Run: `npm test --prefix backend`
Expected: FAIL เพราะหา `src/app.js` ไม่พบ

- [ ] **Step 5: เขียน `ApiError`, `errorHandler` และ `createApp`**

`errorHandler` export เป็นฟังก์ชัน middleware แบบ 4 พารามิเตอร์ ใช้ `err.type === 'entity.parse.failed'` ตรวจ JSON เสีย ส่วน `/api/health` เรียก `SELECT 1` และส่ง error ที่จับได้เป็น `ApiError(503, 'DB_UNAVAILABLE', 'Database is unavailable')`

- [ ] **Step 6: รัน test ให้ผ่าน**

Run: `npm test --prefix backend`
Expected: PASS ครบ 5 test

- [ ] **Step 7: Commit**

```bash
git add backend
git commit -m "feat(backend): add app core, health check and error format"
```

### Task 2: Middleware ตรวจสิทธิ์

**Files:**
- Create: `backend/src/middleware/auth.js`, `backend/src/middleware/requireRole.js`
- Modify: `backend/test/helpers.js`
- Test: `backend/test/auth.test.js`

**Interfaces:**
- Consumes: `ApiError`, `app.locals.jwtSecret`
- Produces: `requireAuth`, `optionalAuth` (จาก `auth.js`), `requireRole(...roles)` และ `req.user = { id: number, role: string }`
- Produces จาก helpers: `tokenFor(role, { id = 1, secret = TEST_SECRET, expiresIn = '1h' } = {})`

- [ ] **Step 1: เขียน test ที่ต้อง fail**

สร้าง express แอปเล็กใน test ที่ตั้ง `app.locals.jwtSecret`, มี route `/auth`, `/optional`, `/admin` และ `errorHandler` route ที่ผ่านตอบ `res.json(req.user ?? null)`

| Test | Assertion |
|---|---|
| `requireAuth rejects a missing token` | `401`, `UNAUTHENTICATED` |
| `requireAuth rejects an expired token` | ใช้ `expiresIn: -10` ได้ `401` |
| `requireAuth rejects a wrong secret` | ใช้ `secret: 'other'` ได้ `401` |
| `requireAuth rejects alg none` | token จาก `jwt.sign(payload, '', { algorithm: 'none' })` ได้ `401` |
| `requireAuth rejects a bare Bearer header` | header `Bearer ` ได้ `401` |
| `requireAuth exposes id and role` | body เท่ากับ `{ id: 7, role: 'viewer' }` |
| `optionalAuth lets guests through` | `200`, body เป็น `null` |
| `optionalAuth rejects an invalid token` | `401` |
| `requireRole rejects another role` | token viewer ได้ `403`, `FORBIDDEN` |
| `requireRole accepts a listed role` | token admin ได้ `200` |

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `npm test --prefix backend`
Expected: FAIL เพราะหา `src/middleware/auth.js` ไม่พบ

- [ ] **Step 3: เขียน middleware**

ใช้ `jwt.verify(token, secret, { algorithms: ['HS256'] })` และตั้ง `req.user.id = Number(payload.sub)`

- [ ] **Step 4: รัน test ให้ผ่าน**

Run: `npm test --prefix backend`
Expected: PASS ทั้งหมด

- [ ] **Step 5: Commit**

```bash
git add backend
git commit -m "feat(backend): add auth and role middleware"
```

### Task 3: Stub ครบ 42 endpoint

**Files:**
- Create: `backend/src/utils/notImplemented.js`
- Create: `backend/src/routes/{auth,films,episodes,wallet,subscriptions,creator,admin,social}.js`
- Create: `backend/src/controllers/{auth,films,episodes,wallet,subscriptions,creator,admin,social}.js`
- Create: `backend/src/models/{auth,films,episodes,wallet,subscriptions,creator,admin,social}.js`
- Create: `docs/api.md`
- Modify: `backend/src/app.js`
- Test: `backend/test/endpoints.test.js`

**Interfaces:**
- Consumes: `requireAuth`, `optionalAuth`, `requireRole`, `tokenFor`
- Produces: `notImplemented(req, res, next)` ส่ง `ApiError(501, 'NOT_IMPLEMENTED', 'This endpoint is not implemented yet')`
- Produces: controller แต่ละตัวมีชื่อฟังก์ชันตามงาน เช่น `exports.login = notImplemented` เจ้าของงานแทนที่ทีละฟังก์ชันได้

- [ ] **Step 1: เขียน test ที่ต้อง fail** แบบขับด้วยตาราง

คัดลอก 42 แถวจากตารางใน spec หัวข้อ 5 เป็น `ENDPOINTS = [[method, path, access], ...]` แทน `:id` ด้วย `1` แล้วสร้าง test ต่อแถว:

```js
test('the table lists all 42 endpoints', () => assert.equal(ENDPOINTS.length, 42));

// for each [method, path, access]:
const call = (token) => {
  const r = request(app)[method](path);
  return token ? r.set('Authorization', `Bearer ${token}`) : r;
};
// public, optional: call() -> 501
// auth:    call() -> 401, call(tokenFor('viewer')) -> 501
// creator: call() -> 401, call(tokenFor('viewer')) -> 403, call(tokenFor('creator')) -> 501
// admin:   call() -> 401, call(tokenFor('creator')) -> 403, call(tokenFor('admin')) -> 501
```

ทุก `501` ต้องตรวจ `res.body.error.code === 'NOT_IMPLEMENTED'` และ `creator` ต้องยอมรับ token `admin` ด้วย

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `npm test --prefix backend`
Expected: FAIL เพราะ endpoint ตอบ `404`

- [ ] **Step 3: เขียน routes, controllers และ models**

Mount ที่ `/api/auth`, `/api/films`, `/api/episodes`, `/api/wallet`, `/api/coin-packs` (ไปที่ router `wallet`), `/api/subscription`, `/api/creator`, `/api/admin` และ `social` ที่ `/api` ให้ mount ก่อน middleware 404

ไฟล์ model มีเพียงคอมเมนต์บอกตารางที่เกี่ยวข้อง route ของการอัปโหลดตอนที่ใส่คอมเมนต์ว่าให้เพิ่ม `upload.single('video')` เมื่อทำจริง เพื่อไม่ให้ stub เก็บไฟล์ค้างไว้

- [ ] **Step 4: เขียน `docs/api.md`**

ใส่ base URL, วิธีส่ง JWT, รูปแบบ error, ตารางรหัส error และตาราง 42 endpoint จาก spec

- [ ] **Step 5: รัน test ให้ผ่าน**

Run: `npm test --prefix backend`
Expected: PASS ทั้งหมด

- [ ] **Step 6: Commit**

```bash
git add backend docs/api.md
git commit -m "feat(backend): add stubs for all API endpoints"
```

### Task 4: Upload และการปิดกั้น `uploads/`

**Files:**
- Create: `backend/src/middleware/upload.js`
- Modify: `backend/src/middleware/errorHandler.js`
- Test: `backend/test/upload.test.js`

**Interfaces:**
- Produces: `createUpload({ dest, maxBytes = 200 * 1024 * 1024 }) -> multer instance` และ default `upload` ที่ชี้ไป `backend/uploads`

- [ ] **Step 1: เขียน test ที่ต้อง fail**

ใช้ `fs.mkdtempSync` เป็น `dest`, ตั้ง `maxBytes: 10` และ route ทดสอบที่ตอบ `res.json({ filename: req.file.filename })`

| Test | Assertion |
|---|---|
| `accepts mp4 with a random name` | `200`, ชื่อไฟล์จบด้วย `.mp4` และไม่ตรงกับชื่อต้นฉบับ `../evil.mp4` |
| `rejects other file types` | ไฟล์ `text/plain` ได้ `400 VALIDATION_ERROR` และ `dest` ว่าง |
| `rejects oversized files` | ไฟล์ 11 ไบต์ได้ `413 FILE_TOO_LARGE` และ `dest` ว่าง |
| `uploads are not served` | `GET /uploads/film1_ep1.mp4` บน `makeApp()` ได้ `404 NOT_FOUND` |

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `npm test --prefix backend`
Expected: FAIL เพราะหา `src/middleware/upload.js` ไม่พบ

- [ ] **Step 3: เขียน `createUpload` และแปลง `MulterError`**

ตั้งชื่อด้วย `crypto.randomUUID() + '.mp4'` โดย `LIMIT_FILE_SIZE` เป็น `413 FILE_TOO_LARGE` และ `MulterError` อื่นเป็น `400 VALIDATION_ERROR`

- [ ] **Step 4: รัน test ให้ผ่าน**

Run: `npm test --prefix backend`
Expected: PASS ทั้งหมด

- [ ] **Step 5: Commit**

```bash
git add backend
git commit -m "feat(backend): add video upload middleware"
```

### Task 5: การเริ่ม server และฐานข้อมูลจริง

**Files:**
- Create: `backend/src/config/env.js`, `backend/src/config/db.js`, `backend/src/server.js`
- Test: `backend/test/env.test.js`

**Interfaces:**
- Consumes: `createApp`
- Produces: `loadEnv(source = process.env) -> { port, db: { host, port, user, password, database }, jwtSecret, jwtExpiresIn }`
- Produces: `createPool(dbConfig) -> mysql2/promise Pool` โดยใช้ `connectionLimit: 10`, `charset: 'utf8mb4'`, `timezone: '+07:00'`

- [ ] **Step 1: เขียน test ที่ต้อง fail**

```js
test('loadEnv refuses a missing JWT_SECRET', () => {
  assert.throws(() => loadEnv({}), /JWT_SECRET/);
});

test('loadEnv applies the defaults', () => {
  const env = loadEnv({ JWT_SECRET: 's' });
  assert.equal(env.port, 3000);
  assert.equal(env.db.database, 'shortreel');
  assert.equal(env.jwtExpiresIn, '7d');
});
```

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `npm test --prefix backend`
Expected: FAIL เพราะหา `src/config/env.js` ไม่พบ

- [ ] **Step 3: เขียน `env.js`, `db.js`, `server.js`**

- [ ] **Step 4: รัน test ให้ผ่าน**

Run: `npm test --prefix backend`
Expected: PASS ทั้งหมด

- [ ] **Step 5: ทดสอบกับฐานข้อมูลจริง**

ตรวจก่อนว่ามีฐานข้อมูล `shortreel` อยู่หรือไม่ ถ้ามีให้ใช้ของเดิมโดยไม่ import ทับ ถ้าไม่มี MariaDB ที่เปิดอยู่ให้บันทึกว่าข้อนี้ยังไม่ได้ทดสอบ

สร้าง `backend/.env` จากตัวอย่าง รัน `npm start --prefix backend` แล้วเปิด `http://localhost:3000/api/health`
Expected: `{"status":"ok","db":"up"}`

- [ ] **Step 6: Commit**

```bash
git add backend
git commit -m "feat(backend): add server entry and database pool"
```

### Task 6: แอป Flutter และ models

**Files:**
- Create: `mobile/` จาก `flutter create`
- Create: `mobile/lib/models/{user,film,episode,transaction,subscription}.dart`
- Create: `mobile/lib/theme/app_theme.dart`
- Create: `mobile/lib/widgets/{loading_view,empty_view,error_view,login_prompt,ai_label_badge}.dart`
- Modify: `mobile/pubspec.yaml`, `mobile/android/app/src/debug/AndroidManifest.xml`, `mobile/analysis_options.yaml` (ถ้าต้องใช้)
- Test: `mobile/test/models_test.dart`

**Interfaces:**
- Produces: `enum UserRole { guest, viewer, creator, admin }` ใน `user.dart`
- Produces: `X.fromJson(Map<String, dynamic>)` ของทุก model คีย์ JSON ตรงกับชื่อคอลัมน์ใน `shortreel.sql`
- Produces: `AppTheme.dark`, `ErrorView({required String message, VoidCallback? onRetry})`, `EmptyView({required String message})`, `LoginPrompt({required VoidCallback onLogin})`, `AiLabelBadge()`, `LoadingView()`

- [ ] **Step 1: สร้างแอป**

```bash
flutter create --org com.shortreel --project-name shortreel --platforms android,ios mobile
```

เพิ่ม `provider`, `dio`, `flutter_secure_storage`, `video_player` ด้วย `flutter pub add` และลบ test ตัวอย่างจาก template

ใน debug manifest เพิ่ม `android:usesCleartextTraffic="true"` ที่ `<application>` เพราะ dev server ใช้ HTTP

- [ ] **Step 2: เขียน test ที่ต้อง fail**

```dart
test('Episode maps MySQL tinyint to bool', () {
  final e = Episode.fromJson({'id': 1, 'film_id': 2, 'episode_no': 3,
      'title': null, 'duration_sec': 60, 'is_free': 1, 'price_coins': 0});
  expect(e.isFree, isTrue);
  expect(e.title, isNull);
});

test('Subscription parses mysql2 DECIMAL strings', () {
  final s = Subscription.fromJson({'id': 1, 'price_usd': '6.99',
      'start_date': '2026-10-01', 'end_date': '2026-10-31'});
  expect(s.priceUsd, 6.99);
  expect(s.endDate, DateTime(2026, 10, 31));
});

test('User maps role and tolerates a null display_name', () {
  final u = User.fromJson({'id': 1, 'username': 'a', 'display_name': null,
      'role': 'creator', 'coin_balance': 0});
  expect(u.role, UserRole.creator);
});

test('Film and Transaction keep their key fields', () {
  final f = Film.fromJson({'id': 1, 'creator_id': 2, 'title': 'T',
      'genre_id': 1, 'ai_tool_id': 1, 'is_ai_generated': 1, 'status': 'approved'});
  expect(f.isAiGenerated, isTrue);
  final t = Transaction.fromJson({'id': 1, 'type': 'unlock', 'amount': -20,
      'balance_after': 80, 'created_at': '2026-10-31T10:00:00'});
  expect(t.amount, -20);
});
```

- [ ] **Step 3: รัน test ให้เห็นว่า fail**

Run: `flutter test` ในโฟลเดอร์ `mobile`
Expected: FAIL เพราะหา model ไม่พบ

- [ ] **Step 4: เขียน models, theme และ widgets**

`AppTheme.dark` ใช้ Material 3 แบบ dark เพื่อให้เข้ากับหน้าดูวิดีโอ

- [ ] **Step 5: รัน test ให้ผ่าน**

Run: `flutter test` และ `flutter analyze` ในโฟลเดอร์ `mobile`
Expected: test ผ่าน และ analyze ไม่มี error

- [ ] **Step 6: Commit**

```bash
git add mobile
git commit -m "feat(mobile): scaffold Flutter app with models and shared widgets"
```

### Task 7: API client

**Files:**
- Create: `mobile/lib/services/api_client.dart`, `mobile/lib/services/token_store.dart`
- Test: `mobile/test/api_client_test.dart`

**Interfaces:**
- Produces: `abstract class TokenStore { Future<String?> read(); Future<void> write(String token); Future<void> clear(); }` และ `SecureTokenStore`
- Produces: `class ApiException implements Exception { final String code; final String message; final int? statusCode; }`
- Produces: `ApiClient({required TokenStore tokens, Dio? dio})` พร้อม `Future<dynamic> get(String path, {Map<String, dynamic>? query})`, `post(String path, {Object? data})`, `put(String path, {Object? data})`, `delete(String path)`
- Produces: `const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api')`

- [ ] **Step 1: เขียน test ที่ต้อง fail**

ใช้ `HttpClientAdapter` จำลองที่คืน `ResponseBody.fromString` หรือโยน `DioException` และ `TokenStore` แบบเก็บในหน่วยความจำ

| Test | Assertion |
|---|---|
| `attaches the stored token` | adapter เห็น header `Authorization: Bearer abc` |
| `sends no header for guests` | ไม่มี header `Authorization` |
| `maps the shared error format` | `403` ได้ `ApiException` code `FORBIDDEN` พร้อม message และ `statusCode` 403 |
| `handles non-JSON error bodies` | `502` ที่ตอบ HTML ได้ code `UNKNOWN_ERROR`, `statusCode` 502 |
| `handles a connection failure` | ได้ code `NETWORK_ERROR`, `statusCode` เป็น `null` |
| `returns decoded JSON on success` | `200` คืนค่า `Map` ที่ถอดแล้ว |

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `flutter test test/api_client_test.dart` ในโฟลเดอร์ `mobile`
Expected: FAIL เพราะหา `api_client.dart` ไม่พบ

- [ ] **Step 3: เขียน `TokenStore` และ `ApiClient`**

แนบ token ใน `InterceptorsWrapper.onRequest` และให้เมธอดทั้งสี่ส่งผ่าน helper เดียวที่แปลง `DioException` เป็น `ApiException`

- [ ] **Step 4: รัน test ให้ผ่าน**

Run: `flutter test test/api_client_test.dart` ในโฟลเดอร์ `mobile`
Expected: PASS ครบ 6 test

- [ ] **Step 5: Commit**

```bash
git add mobile
git commit -m "feat(mobile): add API client with shared error handling"
```

### Task 8: Controllers, หน้าจอ และ navigation

**Files:**
- Create: `mobile/lib/controllers/{auth,feed,film_search,wallet,profile,upload,admin}_controller.dart`
- Create: `mobile/lib/views/auth/{login,register}_view.dart`, `mobile/lib/views/feed/feed_view.dart`, `mobile/lib/views/player/player_view.dart`, `mobile/lib/views/search/search_view.dart`, `mobile/lib/views/wallet/{wallet,coin_shop,subscription}_view.dart`, `mobile/lib/views/profile/{profile,creator_dashboard}_view.dart`, `mobile/lib/views/upload/upload_view.dart`, `mobile/lib/views/admin/{admin_view,admin_review_view,admin_sales_view}.dart`, `mobile/lib/views/app_shell.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/app_shell_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `UserRole`, `LoginPrompt`, `AppTheme.dark`
- Produces: `AuthController({UserRole role = UserRole.guest})` พร้อม getter `role`, `isLoggedIn`
- Produces: `enum AppTab { feed, search, wallet, profile, upload, admin }` และ `List<AppTab> tabsFor(UserRole role)`
- Produces: `AppShell()` ที่อ่าน `AuthController` จาก `provider`
- Produces: controller อื่นทั้งหมดเป็น `ChangeNotifier` ที่รับ `ApiClient` ทาง constructor

- [ ] **Step 1: เขียน test ที่ต้อง fail**

```dart
test('tabsFor matches the role table', () {
  const base = [AppTab.feed, AppTab.search, AppTab.wallet, AppTab.profile];
  expect(tabsFor(UserRole.guest), base);
  expect(tabsFor(UserRole.viewer), base);
  expect(tabsFor(UserRole.creator), [...base, AppTab.upload]);
  expect(tabsFor(UserRole.admin), [...base, AppTab.upload, AppTab.admin]);
});
```

Widget test ห่อ `AppShell` ด้วย `ChangeNotifierProvider<AuthController>`:

| Test | Assertion |
|---|---|
| `guest sees a login prompt on Wallet` | แตะแท็บ Wallet แล้วพบ `LoginPrompt` |
| `guest sees a login prompt on Profile` | แตะแท็บ Profile แล้วพบ `LoginPrompt` |
| `viewer sees the demo label on Wallet` | แตะแท็บ Wallet แล้วพบข้อความ `Demo` และไม่พบ `LoginPrompt` |
| `admin sees six tabs` | `NavigationDestination` มี 6 รายการ |
| `profile opens the creator dashboard` | role creator แตะปุ่ม `Creator dashboard` แล้วพบ `CreatorDashboardView` |

- [ ] **Step 2: รัน test ให้เห็นว่า fail**

Run: `flutter test test/app_shell_test.dart` ในโฟลเดอร์ `mobile`
Expected: FAIL เพราะหา `app_shell.dart` ไม่พบ

- [ ] **Step 3: เขียน controllers และ views**

แต่ละ view เป็น `Scaffold` ที่มี `AppBar` และ `EmptyView` บอกชื่อหน้าจอ `AppShell` ใช้ `NavigationBar` กับ `IndexedStack` ปุ่ม login ใน `LoginPrompt` เปิด `LoginView` และให้ `Admin` แสดง `AdminView` ที่ลิงก์ไปหน้า Admin review กับ Admin sales

`main.dart` ใช้ `MultiProvider` สร้าง `ApiClient` หนึ่งตัวส่งให้ทุก controller

- [ ] **Step 4: รัน test ให้ผ่าน**

Run: `flutter test` และ `flutter analyze` ในโฟลเดอร์ `mobile`
Expected: test ผ่าน และ analyze ไม่มี error

- [ ] **Step 5: Commit**

```bash
git add mobile
git commit -m "feat(mobile): add controllers, placeholder screens and role navigation"
```

### Task 9: README และการตรวจรอบสุดท้าย

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: ทุกอย่างจาก Task 1 ถึง 8

- [ ] **Step 1: เขียน `README.md`**

ใส่ภาพรวม, สิ่งที่ต้องติดตั้ง, วิธี import SQL พร้อมคำเตือนว่า `DROP DATABASE` จะล้างข้อมูลเดิม, วิธีรัน backend, วิธีรัน Flutter พร้อม `--dart-define`, วิธีรัน test, และตารางเจ้าของงานจาก spec หัวข้อ 8

- [ ] **Step 2: ตรวจเงื่อนไขความสำเร็จใน spec หัวข้อ 1**

Run: `npm test --prefix backend`, แล้วรัน `flutter analyze` กับ `flutter test` ในโฟลเดอร์ `mobile`
Expected: ผ่านทั้งหมด

เปิด Android emulator ถ้ามี แล้วรัน `flutter run` เพื่อดู bottom navigation ถ้าไม่มี emulator ให้ `flutter build apk --debug` และบันทึกว่ายังไม่ได้เปิดดูบนอุปกรณ์จริง

- [ ] **Step 3: ยืนยันว่าไฟล์ SQL ไม่เปลี่ยนและไม่มีความลับเข้า git**

Run: `git ls-files` และเปรียบเทียบ hash ของ `backend/db/shortreel.sql`
Expected: ไม่มี `.env` และไม่มี `node_modules` ในรายการ และ hash ตรงกับต้นฉบับ

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add project README"
```
