# ShortReel Project Skeleton: Design Spec

- **วันที่:** 2026-10-31
- **กลุ่ม:** Group 7, Project 2
- **ที่มา:** `MONTHAKAN KAEWSAI - Project 2 (3).pdf` และ `shortreel.sql`

## 1. เป้าหมาย

สร้างโครงโปรเจกต์ที่รันได้จริง เพื่อให้สมาชิกทั้ง 6 คนแยกทำงานตาม task division ใน PDF ได้โดยแก้ไฟล์ชนกันน้อยที่สุด

งานนี้ครอบคลุมสิ่งที่ Sprint 1 ต้องส่ง ได้แก่ repo ในเครื่อง, backend skeleton, API health check, โฟลเดอร์ Flutter แบบ MVC, theme, shared widgets, API client และรูปแบบ error ที่ตกลงร่วมกัน

### เงื่อนไขความสำเร็จ

1. `npm test` ใน `backend/` ผ่าน โดยไม่ต้องมี MySQL
2. เมื่อ import `shortreel.sql` แล้ว `GET /api/health` ตอบ `200` และ `db: "up"`
3. เมื่อ DB ไม่พร้อม `GET /api/health` ตอบ `503` ตามรูปแบบ error กลาง
4. ทุก endpoint ในหัวข้อ 5 มี route และตอบ `501` เมื่อผ่านการตรวจสิทธิ์แล้ว
5. `flutter analyze` ไม่มี error และ `flutter test` ผ่าน
6. แอป Flutter เปิดได้ มี bottom navigation และหน้าจอ placeholder ครบตามหัวข้อ 6

### นอกขอบเขต

- Logic จริงของ login, feed, เหรียญ, การอัปโหลด และ social ซึ่งเป็นงาน Sprint 2 ถึง 4
- การสร้าง repo บน GitHub, branch rules และการ push
- ไฟล์วิดีโอตัวอย่าง
- การแก้ไข schema ใน `shortreel.sql`

## 2. แนวทางที่เลือก

ใช้ **monorepo เดียว** ที่มี `backend/` และ `mobile/` โดย backend ใช้ JavaScript และ SQL ตรงผ่าน `mysql2`

| ตัวเลือก | ผล | เหตุผล |
|---|---|---|
| Monorepo + `mysql2` | เลือก | แก้ API และ Flutter ใน PR เดียวได้ และใช้ schema ที่มีอยู่ตรง ๆ |
| แยก 2 repo | ไม่เลือก | การเปลี่ยน API หนึ่งครั้งต้องเปิดสอง PR |
| TypeScript + Prisma | ไม่เลือก | เพิ่มสิ่งที่ต้องเรียนรู้ และต้องดูแล schema ซ้ำสองที่ |

## 3. โครงสร้าง repo

```text
short_reel_app/
├─ backend/
│  ├─ db/shortreel.sql        คัดลอกจากไฟล์ต้นฉบับโดยไม่แก้
│  ├─ uploads/                ไฟล์วิดีโอ ไม่เข้า git (เก็บเฉพาะ .gitkeep)
│  ├─ src/
│  │  ├─ routes/              หนึ่งไฟล์ต่อหนึ่งฟีเจอร์
│  │  ├─ controllers/         หนึ่งไฟล์ต่อหนึ่งฟีเจอร์
│  │  ├─ models/              หนึ่งไฟล์ต่อหนึ่งฟีเจอร์ คำสั่ง SQL อยู่ที่นี่เท่านั้น
│  │  ├─ middleware/          auth.js, requireRole.js, upload.js, errorHandler.js
│  │  ├─ utils/               ApiError.js, notImplemented.js
│  │  ├─ config/              db.js, env.js
│  │  ├─ app.js               createApp({ pool })
│  │  └─ server.js            เริ่ม server
│  ├─ test/
│  ├─ .env.example
│  └─ package.json
├─ mobile/                    แอป Flutter
│  ├─ lib/
│  │  ├─ models/
│  │  ├─ controllers/
│  │  ├─ views/
│  │  ├─ widgets/
│  │  ├─ services/api_client.dart
│  │  ├─ theme/
│  │  └─ main.dart
│  └─ test/
├─ docs/api.md
├─ .gitignore
└─ README.md
```

ฟีเจอร์ของ backend มี 8 กลุ่ม: `auth`, `films`, `episodes`, `wallet`, `subscriptions`, `creator`, `admin`, `social`

`app.js` รับ `pool` เป็นพารามิเตอร์ เพื่อให้ test ส่ง pool จำลองเข้ามาได้โดยไม่ต้องมี MySQL

## 4. Backend ส่วนที่ทำงานจริง

Stack: Node.js 22, Express, `mysql2/promise`, `jsonwebtoken`, `multer`, `dotenv` โดยติดตั้ง `argon2` ไว้ให้ Sprint 2 ใช้ต่อ

### ค่า environment

`.env.example` มี `PORT=3000`, `DB_HOST=127.0.0.1`, `DB_PORT=3306`, `DB_USER=root`, `DB_PASSWORD=`, `DB_NAME=shortreel`, `JWT_SECRET=change-me`, `JWT_EXPIRES_IN=7d`

`.env` ไม่เข้า git

### Health check

`GET /api/health` รัน `SELECT 1` ผ่าน pool

- สำเร็จ: `200` และ `{ "status": "ok", "db": "up" }`
- ล้มเหลว: `503` และรหัส error `DB_UNAVAILABLE`

### รูปแบบ error

ทุก error ใช้รูปแบบเดียวกัน:

```json
{ "error": { "code": "NOT_IMPLEMENTED", "message": "This endpoint is not implemented yet" } }
```

| Code | HTTP | ใช้เมื่อ |
|---|---|---|
| `VALIDATION_ERROR` | 400 | ข้อมูลไม่ถูกต้อง |
| `UNAUTHENTICATED` | 401 | ไม่มี token หรือ token ใช้ไม่ได้ |
| `INSUFFICIENT_COINS` | 402 | เหรียญไม่พอ |
| `FORBIDDEN` | 403 | role หรือความเป็นเจ้าของไม่ผ่าน |
| `NOT_FOUND` | 404 | ไม่พบข้อมูลหรือ route |
| `CONFLICT` | 409 | ข้อมูลซ้ำ เช่น username |
| `FILE_TOO_LARGE` | 413 | ไฟล์เกินขนาด |
| `NOT_IMPLEMENTED` | 501 | stub ที่ยังไม่ได้ทำ |
| `INTERNAL_ERROR` | 500 | ข้อผิดพลาดที่ไม่คาดคิด |
| `DB_UNAVAILABLE` | 503 | ติดต่อฐานข้อมูลไม่ได้ |

`errorHandler` แปลง `ApiError` และ error ของ Multer ให้เป็นรูปแบบนี้ ส่วน `INTERNAL_ERROR` ต้องไม่ส่งรายละเอียดภายในกลับไปที่ client

### Middleware

- `requireAuth`: ตรวจ `Authorization: Bearer <token>` แล้วตั้ง `req.user = { id, role }` จาก payload `{ sub, role }`
- `optionalAuth`: ไม่มี token ก็ผ่านแบบ guest แต่ถ้ามี token ที่ใช้ไม่ได้จะตอบ `401`
- `requireRole(...roles)`: ตอบ `403` เมื่อ role ไม่ตรง และต้องวางหลัง `requireAuth`
- `upload`: Multer เก็บไฟล์ใน `uploads/` ตั้งชื่อใหม่แบบสุ่ม รับเฉพาะ `video/mp4` จำกัด 200 MB

### Stub

Controller ทุกตัวเรียก `notImplemented` ซึ่งโยน `ApiError` รหัส `NOT_IMPLEMENTED` โดย middleware ตรวจสิทธิ์ทำงานก่อนเสมอ ดังนั้นคำขอที่ไม่มีสิทธิ์จะได้ `401` หรือ `403` ไม่ใช่ `501`

Model เป็นไฟล์เปล่าที่มีคอมเมนต์บอกตารางที่เกี่ยวข้อง

### การเล่นวิดีโอ

ห้ามเปิด `uploads/` เป็น static เด็ดขาด เพราะคนที่รู้ URL จะดูตอนที่ต้องจ่ายเหรียญได้ฟรี วิดีโอต้องผ่าน `GET /api/episodes/:id/stream` ซึ่งต้องตรวจสิทธิ์ก่อนส่งไฟล์ และเมื่อทำจริงต้องรองรับ HTTP Range เพื่อให้ผู้ใช้เลื่อนวิดีโอได้

## 5. Endpoint ทั้งหมด

ระดับการเข้าถึง: `public` ไม่ตรวจ token, `optional` รองรับ guest, `auth` ต้อง login, `creator` คือ creator หรือ admin, `admin` คือ admin เท่านั้น

Endpoint ทั้งหมดในตารางตอบ `501` ใน skeleton และบันทึกไว้ใน `docs/api.md`

| Method | Path | การเข้าถึง |
|---|---|---|
| POST | `/api/auth/register` | public |
| POST | `/api/auth/login` | public |
| POST | `/api/auth/logout` | auth |
| GET | `/api/auth/me` | auth |
| GET | `/api/films` | optional |
| GET | `/api/films/:id` | optional |
| POST | `/api/films` | creator |
| PUT | `/api/films/:id` | creator |
| DELETE | `/api/films/:id` | creator |
| POST | `/api/films/:id/episodes` | creator |
| GET | `/api/episodes/:id` | optional |
| PUT | `/api/episodes/:id` | creator |
| DELETE | `/api/episodes/:id` | creator |
| GET | `/api/episodes/:id/stream` | optional |
| POST | `/api/episodes/:id/unlock` | auth |
| GET | `/api/wallet` | auth |
| GET | `/api/wallet/transactions` | auth |
| POST | `/api/wallet/topup` | auth |
| GET | `/api/coin-packs` | public |
| GET | `/api/subscription` | auth |
| POST | `/api/subscription` | auth |
| GET | `/api/creator/films` | creator |
| GET | `/api/creator/earnings` | creator |
| GET | `/api/admin/reviews` | admin |
| POST | `/api/admin/films/:id/review` | admin |
| GET | `/api/admin/sales` | admin |
| PUT | `/api/admin/settings/revenue-share` | admin |
| GET | `/api/admin/users` | admin |
| PUT | `/api/admin/users/:id/role` | admin |
| GET | `/api/admin/reports` | admin |
| POST | `/api/admin/reports/:id/resolve` | admin |
| POST | `/api/films/:id/like` | auth |
| DELETE | `/api/films/:id/like` | auth |
| GET | `/api/watchlist` | auth |
| POST | `/api/films/:id/watchlist` | auth |
| DELETE | `/api/films/:id/watchlist` | auth |
| GET | `/api/films/:id/comments` | public |
| POST | `/api/films/:id/comments` | auth |
| DELETE | `/api/comments/:id` | auth |
| POST | `/api/creators/:id/follow` | auth |
| DELETE | `/api/creators/:id/follow` | auth |
| POST | `/api/films/:id/reports` | auth |

การตรวจความเป็นเจ้าของ เช่น creator แก้ได้เฉพาะหนังของตัวเอง ต้องอ่านข้อมูลจาก DB จึงเป็นงานของ controller ใน Sprint 2

## 6. Flutter

Stack: Flutter 3.44, `provider`, `dio`, `flutter_secure_storage`, `video_player` โดยสร้างด้วยชื่อ `shortreel`, org `com.shortreel`, แพลตฟอร์ม Android และ iOS

- **Models:** `User`, `Film`, `Episode`, `Transaction`, `Subscription` พร้อม `fromJson`
- **Controllers:** `ChangeNotifier` ตามฟีเจอร์ ได้แก่ `AuthController`, `FeedController`, `FilmSearchController`, `WalletController`, `ProfileController`, `UploadController`, `AdminController` โดยเริ่มจาก state ว่าง
- **ApiClient:** ใช้ `dio` ตัวเดียว แนบ JWT จาก secure storage และแปลง error กลางเป็น `ApiException(code, message, statusCode)`
- **Base URL:** อ่านจาก `--dart-define=API_BASE_URL=...` ค่าเริ่มต้น `http://10.0.2.2:3000/api`
- **Widgets กลาง:** `LoadingView`, `EmptyView`, `ErrorView`, `LoginPrompt`, `AiLabelBadge`

ใช้ชื่อ `FilmSearchController` เพราะ `SearchController` ชนกับ class ใน Flutter framework

### หน้าจอ

Views เป็น placeholder ทั้งหมด: Login, Register, Feed, Player, Search, Wallet, Coin shop, Subscription, Profile, Creator dashboard, Upload, Admin review, Admin sales

| Role | แท็บใน bottom navigation |
|---|---|
| Guest, Viewer | Feed, Search, Wallet, Profile |
| Creator | Feed, Search, Wallet, Profile, Upload |
| Admin | Feed, Search, Wallet, Profile, Upload, Admin |

- Guest ที่เปิด Wallet หรือ Profile จะเห็น `LoginPrompt`
- Creator dashboard เปิดจากหน้า Profile
- Wallet ต้องมีป้ายบอกว่าเป็นโหมด demo ตามที่ PDF กำหนด

## 7. การทดสอบ

**Backend** ใช้ `node:test` และ `supertest` โดยไม่ต้องมี MySQL:

- health ตอบ `200` เมื่อ pool ปกติ และ `503` เมื่อ pool ล้มเหลว
- route ที่ต้อง login ตอบ `401` เมื่อไม่มี token และเมื่อ token ใช้ไม่ได้
- route ของ admin ตอบ `403` เมื่อใช้ token ของ viewer
- token ที่มีสิทธิ์ถูกต้องได้ `501`
- route ที่ไม่มีอยู่ตอบ `404` ตามรูปแบบ error กลาง
- ไฟล์ใน `uploads/` เข้าถึงตรง ๆ ไม่ได้

**Flutter:**

- `flutter analyze`
- widget test: แท็บแสดงถูกต้องตาม role และ Guest เห็น `LoginPrompt`
- unit test: `ApiClient` แปลง error กลางเป็น `ApiException`

## 8. เจ้าของงานตาม Sprint 2

| Student ID | ไฟล์ backend หลัก |
|---|---|
| 6731501100 | `films`, `episodes` (feed, detail, stream), การ review ใน `admin` |
| 6731501102 | `auth`, `subscriptions`, middleware สิทธิ์ |
| 6731501076 | `wallet`, unlock, sales และ revenue share ใน `admin` |
| 6731501103 | `config/db.js`, seed, การสร้าง แก้ไข และลบ film/episode |
| 6731501078 | `creator`, Profile, API collection |
| 6731501125 | `social` (ถ้าทีมตัดสินใจรวมไว้) |

## 9. ข้อควรระวัง

- `shortreel.sql` มี `DROP DATABASE IF EXISTS` การ import ซ้ำจะล้างข้อมูลเดิมทั้งหมด
- รหัสผ่านใน seed ใช้สำหรับ demo เท่านั้น
- `video_path` ใน seed ยังไม่มีไฟล์จริง จนกว่าทีมจะเตรียมคลิปตาม Sprint 4
- PDF ระบุ MySQL แต่ไฟล์ SQL ใช้ MariaDB 10.4 ผ่าน XAMPP ซึ่ง `mysql2` ใช้ได้ทั้งคู่
- Sprint 3 ใน PDF บอกว่าสร้าง wallet API แต่ task division ของ Sprint 2 ระบุงานนี้เช่นกัน ทีมควรตกลงกำหนดส่งให้ชัด
- `coin_balance` ของ creator ใน seed ไม่รวมส่วนแบ่ง ดังนั้นรายได้ต้องรวมจาก `unlocked_episodes.creator_share`
