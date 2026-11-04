# ShortReel

[ภาษาไทย](#ภาษาไทย) · [English](#english)

---

## ภาษาไทย

ShortReel เป็นแอปดูหนังสั้น AI แบบเลื่อนแนวตั้ง ดูทีละตอน ตอนแรก ๆ ดูฟรี ตอนที่เหลือปลดล็อกด้วยเหรียญ ครีเอเตอร์อัปโหลดหนังของตัวเองได้ และได้ส่วนแบ่งเมื่อมีคนปลดล็อก (Group 7, Project 2)

**Flutter → REST API (Node.js/Express) → MySQL/MariaDB**

### ฟีเจอร์

- **ฟีด:** เลื่อนดูหนังแนวตั้ง แยกแท็บ "สำหรับคุณ" กับ "กำลังติดตาม" ปรับความเร็ววิดีโอได้ และลากแถบเลื่อนเพื่อ seek
- **ตอนและเหรียญ:** ตอนฟรีดูได้โดยไม่ต้องล็อกอิน ตอนที่ล็อกไว้ใช้เหรียญปลดล็อก
- **กระเป๋าเงิน:** เติมเหรียญด้วย coin pack หรือปุ่มเดโม +100 ดูประวัติธุรกรรมได้
- **โซเชียล:** กดถูกใจ บันทึกหนังไว้ดูทีหลัง ติดตามครีเอเตอร์ และคอมเมนต์
- **ค้นหา:** ค้นจากชื่อหนังหรือชื่อครีเอเตอร์
- **ครีเอเตอร์:** สร้าง แก้ไข และลบหนัง อัปโหลดวิดีโอทีละตอน ตั้งราคาแต่ละตอน ต้องระบุ AI tool และดูรายได้
- **แอดมิน:** ตรวจหนังได้ 4 แบบ (รอตรวจ, อนุมัติ, ไม่อนุมัติ, ถอดออก) จัดการ role ผู้ใช้ ตั้งส่วนแบ่งรายได้ และดูยอดขาย
- **Series Jeen:** แท็บแคตตาล็อกรวมซีรีส์จาก FreeReels, Melolo และแพลตฟอร์มอื่น ซีรีส์เหล่านี้ต่อท้ายฟีดด้วย

แอปแสดงผลเป็นภาษาไทย การจ่ายเงินทั้งหมดเป็นแบบ **จำลอง** ไม่มี payment gateway และไม่ใช้เงินจริง

### โครงสร้างโปรเจกต์

```
backend/            REST API (Express 5)
  db/shortreel.sql  สคีมาและข้อมูลตัวอย่าง (13 ตาราง)
  src/routes/       เส้นทาง API
  src/controllers/  ตรวจ input และตอบกลับ
  src/models/       คำสั่ง SQL
  src/services/     สตรีมวิดีโอ, Series Jeen
  scripts/          สคริปต์นำเข้าคลิปเดโม
  uploads/          ไฟล์วิดีโอ (ไม่อยู่ใน git)
mobile/             แอป Flutter แบบ MVC
  lib/models/       โมเดลข้อมูล
  lib/views/        หน้าจอ
  lib/controllers/  state ของแต่ละหน้า (Provider)
  lib/data/         repository ที่เรียก API
  lib/l10n/         คำแปลภาษาไทย
```

### ความปลอดภัย

- รหัสผ่านเก็บแบบ argon2id และล็อกอินด้วย JWT
- backend ตรวจ role และความเป็นเจ้าของทุกคำขอ
- วิดีโอเปิดได้เฉพาะผ่าน `/api/episodes/:id/stream` ซึ่งตรวจสิทธิ์ทุกครั้งและรองรับ Range (206) โฟลเดอร์ `uploads/` ไม่ได้เปิดสาธารณะ
- การปลดล็อกทำใน transaction เดียว จึงไม่หักเหรียญซ้ำและยอดไม่ติดลบ
- API key ของ Series Jeen เก็บไว้ที่ backend แอปไม่เห็น key

### วิธีติดตั้ง

#### สิ่งที่ต้องมี

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB 10.4)
- Chrome/Edge หรือ Android emulator

#### 1. ฐานข้อมูล

เปิด MySQL ใน XAMPP แล้ว import `backend/db/shortreel.sql` ผ่าน phpMyAdmin

> ไฟล์นี้มีคำสั่ง `DROP DATABASE IF EXISTS` ถ้า import ซ้ำ ข้อมูลเดิมจะหายหมด

#### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

แก้ `JWT_SECRET` ใน `.env` ก่อนรัน แล้วเปิด `http://localhost:3000/api/health` ต้องได้ `{"status":"ok","db":"up"}`

| ตัวแปรใน `.env` | ใช้ทำอะไร |
|---|---|
| `PORT` | พอร์ตของ API (ค่าเริ่มต้น 3000) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | การเชื่อมต่อฐานข้อมูล |
| `UPLOAD_DIR` | โฟลเดอร์เก็บวิดีโอ ถ้าเว้นว่างจะใช้ `backend/uploads` |
| `JWT_SECRET`, `JWT_EXPIRES_IN` | กุญแจและอายุของ token |
| `SERIESJEEN_API_KEY`, `SERIESJEEN_BASE_URL` | การเชื่อมต่อ Series Jeen |

#### 3. คลิปเดโม

ข้อมูลตัวอย่างมีหนัง 5 เรื่อง เรื่องละ 8 ตอน แต่ repository ไม่มีไฟล์วิดีโอ ให้ใส่คลิป MP4 ไว้ในโฟลเดอร์หนึ่ง แล้วนำเข้า:

```bash
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป> --dry-run
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป>
```

`--dry-run` ใช้ดูก่อนว่าคลิปไหนจะไปอยู่ตอนไหน สคริปต์จะคัดลอกคลิปเข้า `backend/uploads/` และอัปเดตเฉพาะหนังตัวอย่าง (id 1–5) ถ้าคลิปมีไม่ถึง 40 ไฟล์จะวนใช้ซ้ำ หนังที่อัปโหลดผ่านแอปไม่โดนแก้

#### 4. แอป

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

ถ้าใช้ Android emulator ค่าเริ่มต้นคือ `http://10.0.2.2:3000/api` ถ้าใช้มือถือจริง ให้ใส่ IP ของเครื่องที่รัน backend เช่น `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api` แอปรองรับ Android และเว็บ

#### 5. Series Jeen

ใส่ `SERIESJEEN_API_KEY` ใน `backend/.env` แท็บแคตตาล็อกจะโหลดซีรีส์ได้ทุกครั้งที่รัน ถ้าไม่มี key แท็บนี้จะโหลดไม่ขึ้น แต่ส่วนอื่นของแอปยังใช้ได้ปกติ

### บัญชีทดสอบ

| Username | Password | Role |
|---|---|---|
| `admin` | `1111` | Admin |
| `kestrel_studio` | `2222` | Creator เจ้าของ "Salt & Signal" |
| `mira.lens` | `4444` | Creator มี 142 เหรียญ |
| `viewer01` | `6666` | Viewer มี 80 เหรียญ |

สมัครสมาชิกใหม่ได้เฉพาะ Viewer หรือ Creator ถ้าต้องการ Admin ให้ admin เปลี่ยน role ให้ผ่าน `PUT /api/admin/users/:id/role`

### API

ทุกเส้นทางขึ้นต้นด้วย `/api`

| กลุ่ม | เส้นทาง |
|---|---|
| ระบบ | `GET /health`, `GET /lookups` (genre และ AI tool) |
| บัญชี | `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET/PUT /auth/me` |
| หนัง | `GET /films?q=`, `GET /films/:id`, `POST /films`, `PUT/DELETE /films/:id`, `POST /films/:id/episodes` |
| ตอน | `GET/PUT/DELETE /episodes/:id`, `GET /episodes/:id/stream`, `POST /episodes/:id/unlock` |
| กระเป๋าเงิน | `GET /wallet`, `GET /wallet/transactions`, `GET /wallet/unlocked`, `POST /wallet/topup`, `GET /coin-packs` |
| โซเชียล | `POST/DELETE /films/:id/like`, `GET /watchlist`, `POST/DELETE /films/:id/watchlist`, `GET/POST /films/:id/comments`, `DELETE /comments/:id`, `POST/DELETE /creators/:id/follow` |
| ครีเอเตอร์ | `GET /creator/films`, `GET /creator/earnings` |
| แอดมิน | `GET /admin/reviews`, `GET /admin/films`, `POST /admin/films/:id/review`, `GET /admin/sales`, `GET/PUT /admin/settings/revenue-share`, `GET /admin/users`, `PUT /admin/users/:id/role` |
| Series Jeen | `GET /catalog/platforms`, `GET /catalog/platforms/:platformId/dramas`, `GET /catalog/dramas/:dramaId`, `GET /catalog/dramas/:dramaId/episodes` |

### ตรวจโค้ดและ test

```bash
cd mobile && flutter analyze
npm test --prefix backend
cd mobile && flutter test
```

ไฟล์ test ของ backend วางที่ `backend/test/*.test.js` ส่วนของ Flutter วางที่ `mobile/test/*_test.dart` ถ้า test ต้องใช้ฐานข้อมูล ให้ใช้ฐานที่ชื่อลงท้ายด้วย `_test` ห้ามใช้ `shortreel`

---

## English

ShortReel is a vertical-feed app for AI short films, watched one episode at a time. Early episodes are free, and the rest are unlocked with coins. Creators upload their own films and earn a share of each unlock. (Group 7, Project 2)

**Flutter → REST API (Node.js/Express) → MySQL/MariaDB**

### Features

- **Feed:** vertical swipe feed with "For you" and "Following" tabs, playback speed control, and a draggable seek bar.
- **Episodes and coins:** free episodes play without logging in. Locked episodes are unlocked with coins.
- **Wallet:** top up with coin packs or the demo +100 button, and view transaction history.
- **Social:** like, save to a watchlist, follow creators, and comment.
- **Search:** by film title or creator name.
- **Creator tools:**
  - Create, edit and delete films.
  - Upload videos episode by episode and set a price per episode.
  - An AI tool is required for every film.
  - View earnings.
- **Admin:**
  - Review films: approve, reject or take them down. New films wait in pending.
  - Manage user roles.
  - Set the revenue share and view sales.
- **Series Jeen:** a catalog tab with series from FreeReels, Melolo and other platforms. These series are also added to the end of the feed.

The app is shown in Thai. All payments are **simulated**: there is no payment gateway and no real money.

### Project structure

```
backend/            REST API (Express 5)
  db/shortreel.sql  schema and sample data (13 tables)
  src/routes/       API routes
  src/controllers/  input checks and responses
  src/models/       SQL queries
  src/services/     video streaming, Series Jeen
  scripts/          demo clip import script
  uploads/          video files (not in git)
mobile/             Flutter app (MVC)
  lib/models/       data models
  lib/views/        screens
  lib/controllers/  per-screen state (Provider)
  lib/data/         repository that calls the API
  lib/l10n/         Thai translations
```

### Security

- Passwords are hashed with argon2id, and logins use JWT.
- The backend checks role and ownership on every request.
- Videos are served only through `/api/episodes/:id/stream`. It checks access on every request and supports Range requests (206). The `uploads/` folder is not public.
- An unlock runs in a single transaction, so coins are never charged twice and balances never go negative.
- The Series Jeen API key stays on the backend. The app never sees it.

### Getting started

#### Requirements

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB 10.4)
- Chrome/Edge or an Android emulator

#### 1. Database

Start MySQL in XAMPP, then import `backend/db/shortreel.sql` through phpMyAdmin.

> This file contains `DROP DATABASE IF EXISTS`. Importing it again wipes all existing data.

#### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

Change `JWT_SECRET` in `.env` before you start. Then open `http://localhost:3000/api/health`. It should return `{"status":"ok","db":"up"}`.

| `.env` variable | Purpose |
|---|---|
| `PORT` | API port (default 3000) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Database connection |
| `UPLOAD_DIR` | Where videos are stored. Leave empty to use `backend/uploads`. |
| `JWT_SECRET`, `JWT_EXPIRES_IN` | Token signing key and lifetime |
| `SERIESJEEN_API_KEY`, `SERIESJEEN_BASE_URL` | Series Jeen connection |

#### 3. Demo clips

The sample data has 5 films with 8 episodes each, but the repository has no video files. Put MP4 clips in a folder, then import them:

```bash
node backend/scripts/import-demo-clips.js <clips-folder> --dry-run
node backend/scripts/import-demo-clips.js <clips-folder>
```

- `--dry-run` shows which clip goes to which episode, without changing anything.
- The script copies the clips into `backend/uploads/` and updates the sample films only (ids 1–5).
- With fewer than 40 clips, it reuses them in a loop.
- Films uploaded through the app are left alone.

#### 4. App

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

On the Android emulator the default is `http://10.0.2.2:3000/api`. On a real phone, pass the IP of the machine that runs the backend, for example `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`. The app runs on Android and the web.

#### 5. Series Jeen

Set `SERIESJEEN_API_KEY` in `backend/.env`. The catalog tab then loads series on every run. Without a key, the tab cannot load, but the rest of the app works normally.

### Test accounts

| Username | Password | Role |
|---|---|---|
| `admin` | `1111` | Admin |
| `kestrel_studio` | `2222` | Creator who owns "Salt & Signal" |
| `mira.lens` | `4444` | Creator with 142 coins |
| `viewer01` | `6666` | Viewer with 80 coins |

New sign-ups can only be Viewer or Creator. To make someone an Admin, an admin changes their role through `PUT /api/admin/users/:id/role`.

### API

All routes start with `/api`.

| Area | Routes |
|---|---|
| System | `GET /health`, `GET /lookups` (genres and AI tools) |
| Accounts | `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET/PUT /auth/me` |
| Films | `GET /films?q=`, `GET /films/:id`, `POST /films`, `PUT/DELETE /films/:id`, `POST /films/:id/episodes` |
| Episodes | `GET/PUT/DELETE /episodes/:id`, `GET /episodes/:id/stream`, `POST /episodes/:id/unlock` |
| Wallet | `GET /wallet`, `GET /wallet/transactions`, `GET /wallet/unlocked`, `POST /wallet/topup`, `GET /coin-packs` |
| Social | `POST/DELETE /films/:id/like`, `GET /watchlist`, `POST/DELETE /films/:id/watchlist`, `GET/POST /films/:id/comments`, `DELETE /comments/:id`, `POST/DELETE /creators/:id/follow` |
| Creator | `GET /creator/films`, `GET /creator/earnings` |
| Admin | `GET /admin/reviews`, `GET /admin/films`, `POST /admin/films/:id/review`, `GET /admin/sales`, `GET/PUT /admin/settings/revenue-share`, `GET /admin/users`, `PUT /admin/users/:id/role` |
| Series Jeen | `GET /catalog/platforms`, `GET /catalog/platforms/:platformId/dramas`, `GET /catalog/dramas/:dramaId`, `GET /catalog/dramas/:dramaId/episodes` |

### Lint and tests

```bash
cd mobile && flutter analyze
npm test --prefix backend
cd mobile && flutter test
```

Put backend tests in `backend/test/*.test.js` and Flutter tests in `mobile/test/*_test.dart`. Tests that need a database must use one whose name ends in `_test`, never `shortreel`.
