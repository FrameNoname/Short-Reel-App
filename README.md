# ShortReel

[ภาษาไทย](#ภาษาไทย) · [English](#english)

---

## ภาษาไทย

ShortReel เป็นแอปดูหนังสั้น AI แบบเลื่อนแนวตั้ง ดูทีละตอน ตอนแรก ๆ ดูฟรี ตอนที่เหลือปลดล็อกด้วยเหรียญ ผู้ใช้มี 2 แบบคือ Viewer (คนดู) และ Admin (ผู้ดูแลแคตตาล็อก) (Group 7, Project 2)

**Flutter → REST API (Node.js/Express) → MySQL/MariaDB**

### ฟีเจอร์

- **ฟีด:** เลื่อนดูหนังแนวตั้ง ปรับความเร็ววิดีโอได้ และลากแถบเลื่อนเพื่อ seek
- **ตอนและเหรียญ:** ตอนฟรีดูได้โดยไม่ต้องล็อกอิน ตอนที่ล็อกไว้ใช้เหรียญปลดล็อก
- **กระเป๋าเงิน:** เติมเหรียญด้วย coin pack หรือปุ่มเดโม +100 ดูประวัติธุรกรรมได้ โบนัสและป้าย "คุ้มที่สุด" ของแต่ละแพ็กคำนวณจากจำนวนเหรียญและราคาจริง แอดมินแก้แพ็กแล้วข้อความเปลี่ยนตาม
- **โซเชียล:** กดถูกใจ บันทึกหนังไว้ดูทีหลัง และคอมเมนต์
- **ค้นหา:** ค้นจากชื่อหนัง ระบบจะค้นหลังหยุดพิมพ์ 300 มิลลิวินาที และโหลดรายการใหม่ทุกครั้งที่เปิดแท็บ
- **โปรไฟล์:** ดูเหรียญ รายการหนังที่บันทึกไว้ และหนังที่ปลดล็อกแล้ว
- **แอดมิน:** ดูยอดขายและเรื่องที่ขายดี ถอดหนังออกหรือนำกลับมา ตั้งตอนฟรีและราคาแต่ละตอน ดูและลบความคิดเห็น แก้ราคา Series Jeen จำนวนตอนฟรี เหรียญทดลอง และแพ็กเหรียญ เหรียญที่ใช้ปลดล็อกเป็นของแอดมินทั้งหมด รวมถึงซีรีส์จาก Series Jeen
- **Series Jeen:** แท็บแคตตาล็อกแสดงซีรีส์พากย์ไทยจาก FreeReels ผ่าน Series Open API (`https://api.seriesjeen.online`) ซีรีส์เหล่านี้ต่อท้ายฟีดด้วย ตอนที่ 1-5 ดูฟรี ตอนต่อจากนั้นตอนละ 10 เหรียญ (แก้ได้ที่ `catalog_free_episodes` และ `catalog_price_coins` ในตาราง `settings`) backend ตรวจสิทธิ์ก่อนส่งลิงก์วิดีโอทุกครั้ง บนเว็บจะไม่มีซับไทย เพราะเซิร์ฟเวอร์ของ FreeReels ไม่อนุญาต CORS แต่วิดีโอเล่นได้ปกติ บน Android ซับขึ้นตามปกติ

แอปแสดงผลเป็นภาษาไทย การจ่ายเงินทั้งหมดเป็นแบบ **จำลอง** ไม่มี payment gateway และไม่ใช้เงินจริง

### โครงสร้างโปรเจกต์

```
backend/            REST API (Express 5)
  db/shortreel.sql  สคีมาและข้อมูลตัวอย่าง (13 ตาราง)
  src/routes/       เส้นทาง API
  src/controllers/  ตรวจ input และตอบกลับ
  src/models/       คำสั่ง SQL
  src/services/     สตรีมวิดีโอ, Series Jeen (FreeReels)
  test/             unit test (node --test ไม่ต้องใช้ฐานข้อมูล)
  scripts/          สคริปต์นำเข้าคลิปเดโม
  uploads/          ไฟล์วิดีโอ (ไม่อยู่ใน git)
mobile/             แอป Flutter แบบ MVC
  lib/models/       โมเดลข้อมูล
  lib/views/        หน้าจอ
  lib/widgets/      widget ที่ใช้ร่วมกัน
  lib/controllers/  state ของแต่ละหน้า (Provider)
  lib/data/         repository ที่เรียก API
  lib/services/     HTTP client, token และ Series Jeen
  lib/l10n/         คำแปลภาษาไทย
  test/             unit test ของ model และ controller
```

หน้าจอคุยกับ controller เท่านั้น controller เก็บ repository เป็นตัวแปร private หน้าจอจึงเรียก API หรือ repository เองไม่ได้

### ความปลอดภัย

- รหัสผ่านเก็บแบบ argon2id และล็อกอินด้วย JWT
- backend ตรวจ role และความเป็นเจ้าของทุกคำขอ
- วิดีโอเปิดได้เฉพาะผ่าน `/api/episodes/:id/stream` ซึ่งตรวจสิทธิ์ทุกครั้งและรองรับ Range (206) โฟลเดอร์ `uploads/` ไม่ได้เปิดสาธารณะ
- การปลดล็อกทำใน transaction เดียว จึงไม่หักเหรียญซ้ำและยอดไม่ติดลบ
- API key ของ Series Jeen เก็บไว้ที่ backend แอปไม่เห็น key
- แอปรอเชื่อมต่อ API ไม่เกิน 10 วินาที และรอคำตอบไม่เกิน 20 วินาที ถ้าเน็ตหลุดจะขึ้นข้อความแทนการโหลดค้าง

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

`--dry-run` ใช้ดูก่อนว่าคลิปไหนจะไปอยู่ตอนไหน สคริปต์จะคัดลอกคลิปเข้า `backend/uploads/` และอัปเดตเฉพาะหนังตัวอย่าง (id 1–5) ถ้าคลิปมีไม่ถึง 40 ไฟล์จะวนใช้ซ้ำ

#### 4. แอป

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

ถ้าใช้ Android emulator ค่าเริ่มต้นคือ `http://10.0.2.2:3000/api` ถ้าใช้มือถือจริง ให้ใส่ IP ของเครื่องที่รัน backend เช่น `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api` แอปรองรับ Android และเว็บ

#### 5. Series Jeen

ใส่ `SERIESJEEN_API_KEY` ใน `backend/.env` แท็บแคตตาล็อกจะโหลดซีรีส์ได้ทุกครั้งที่รัน ถ้าไม่มี key แท็บนี้จะโหลดไม่ขึ้น แต่ส่วนอื่นของแอปยังใช้ได้ปกติ key ต้องมีสิทธิ์แพลตฟอร์ม FreeReels FreeReels ใช้ id แบบตัวอักษร backend จึงแปลงเป็นเลขผ่านตาราง `catalog_series`

### บัญชีทดสอบ

| Username | Password | Role |
|---|---|---|
| `admin` | `1111` | Admin |
| `mira.lens` | `4444` | Viewer มี 142 เหรียญ และปลดล็อกไว้บางตอน |
| `viewer01` | `6666` | Viewer มี 80 เหรียญ |

สมัครสมาชิกใหม่ได้เป็น Viewer เท่านั้น ถ้าต้องการ Admin เพิ่ม ให้แก้คอลัมน์ `role` ในตาราง `users` เป็น `admin` ผ่าน phpMyAdmin

### API

ทุกเส้นทางขึ้นต้นด้วย `/api`

| กลุ่ม | เส้นทาง |
|---|---|
| ระบบ | `GET /health`, `GET /lookups` (genre และ AI tool) |
| บัญชี | `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET/PUT /auth/me` |
| หนัง | `GET /films?q=`, `GET /films/:id` |
| ตอน | `GET /episodes/:id`, `GET /episodes/:id/stream`, `POST /episodes/:id/unlock` |
| กระเป๋าเงิน | `GET /wallet`, `GET /wallet/transactions`, `GET /wallet/unlocked`, `POST /wallet/topup`, `GET /coin-packs` |
| โซเชียล | `POST/DELETE /films/:id/like`, `GET /watchlist`, `POST/DELETE /films/:id/watchlist`, `GET/POST /films/:id/comments`, `DELETE /comments/:id` |
| แอดมิน | `GET /admin/sales`, `GET /admin/films`, `PUT /admin/films/:id/status`, `GET /admin/films/:id/episodes`, `PUT /admin/episodes/:id`, `GET /admin/comments`, `DELETE /admin/comments/:id`, `GET/PUT /admin/settings`, `GET/POST /admin/coin-packs`, `PUT/DELETE /admin/coin-packs/:id` |
| Series Jeen | `GET /catalog/platforms`, `GET /catalog/platforms/:platformId/dramas`, `GET /catalog/dramas/:dramaId`, `GET /catalog/dramas/:dramaId/episodes`, `POST /catalog/dramas/:dramaId/episodes/:episodeNo/unlock`, `GET /catalog/access` |

### ตรวจโค้ดและ test

```bash
cd mobile && flutter analyze
npm test --prefix backend
cd mobile && flutter test
```

ไฟล์ test ของ backend วางที่ `backend/test/*.test.js` ส่วนของ Flutter วางที่ `mobile/test/*_test.dart` ถ้า test ต้องใช้ฐานข้อมูล ให้ใช้ฐานที่ชื่อลงท้ายด้วย `_test` ห้ามใช้ `shortreel`

### Branch

| Branch | ใช้ทำอะไร |
|---|---|
| `main` | เวอร์ชันหลัก |
| `develop` | รวมงานก่อนขึ้น `main` |
| `Frame-dev` | งานที่กำลังพัฒนา แอปต่อ backend จริง |
| `frontend-only` | แอปอย่างเดียว ไม่ต่อ backend ใช้ข้อมูลจำลองใน `mobile/lib/data/mock_repository.dart` รันได้ด้วย `flutter run` โดยไม่ต้องเปิด backend หรือ MySQL แท็บแคตตาล็อกใช้ซีรีส์ Series Jeen 60 เรื่องที่บันทึกไว้ใน `mock_catalog_data.dart` (โปสเตอร์ต้องต่อเน็ต) และเล่นคลิปตัวอย่างในแอปแทนวิดีโอจริง |

---

## English

ShortReel is a vertical-feed app for AI short films, watched one episode at a time. Early episodes are free, and the rest are unlocked with coins. There are two kinds of user: Viewers, who watch, and the Admin, who runs the catalogue. (Group 7, Project 2)

**Flutter → REST API (Node.js/Express) → MySQL/MariaDB**

### Features

- **Feed:** vertical swipe feed with playback speed control and a draggable seek bar.
- **Episodes and coins:** free episodes play without logging in. Locked episodes are unlocked with coins.
- **Wallet:** top up with coin packs or the demo +100 button, and view transaction history. Each pack's bonus and the "Best value" badge are worked out from its coins and price, so they follow any pack the admin edits.
- **Social:** like, save to a watchlist, and comment.
- **Search:** by film title. It searches once typing pauses for 300 ms, and reloads each time the tab is opened.
- **Profile:** your coins, saved films and unlocked films.
- **Admin:** view sales and top sellers, take films down or bring them back, set which episodes are free and what each costs, read and delete comments, and change the Series Jeen price, free episode count, demo top-up and coin packs. Every coin spent on an unlock goes to the admin, including Series Jeen episodes.
- **Series Jeen:** a catalog tab with Thai-dubbed FreeReels series from the Series Open API (`https://api.seriesjeen.online`). These series are also added to the end of the feed. Episodes 1-5 are free and each later episode costs 10 coins (set by `catalog_free_episodes` and `catalog_price_coins` in the `settings` table). The backend checks access before it hands out any video link. On the web there are no Thai subtitles, because the FreeReels servers do not allow CORS; the video still plays. On Android the subtitles show normally.

The app is shown in Thai. All payments are **simulated**: there is no payment gateway and no real money.

### Project structure

```
backend/            REST API (Express 5)
  db/shortreel.sql  schema and sample data (13 tables)
  src/routes/       API routes
  src/controllers/  input checks and responses
  src/models/       SQL queries
  src/services/     video streaming, Series Jeen (FreeReels)
  test/             unit tests (node --test, no database needed)
  scripts/          demo clip import script
  uploads/          video files (not in git)
mobile/             Flutter app (MVC)
  lib/models/       data models
  lib/views/        screens
  lib/widgets/      shared widgets
  lib/controllers/  per-screen state (Provider)
  lib/data/         repository that calls the API
  lib/services/     HTTP client, token storage and Series Jeen
  lib/l10n/         Thai translations
  test/             model and controller unit tests
```

Screens talk to controllers only. Each controller keeps its repository private, so a screen cannot call the API or the repository itself.

### Security

- Passwords are hashed with argon2id, and logins use JWT.
- The backend checks role and ownership on every request.
- Videos are served only through `/api/episodes/:id/stream`. It checks access on every request and supports Range requests (206). The `uploads/` folder is not public.
- An unlock runs in a single transaction, so coins are never charged twice and balances never go negative.
- The Series Jeen API key stays on the backend. The app never sees it.
- The app waits at most 10 seconds to connect to the API and 20 seconds for an answer. A dropped connection shows a message instead of an endless spinner.

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

#### 4. App

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

On the Android emulator the default is `http://10.0.2.2:3000/api`. On a real phone, pass the IP of the machine that runs the backend, for example `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`. The app runs on Android and the web.

#### 5. Series Jeen

Set `SERIESJEEN_API_KEY` in `backend/.env`. The catalog tab then loads series on every run. Without a key, the tab cannot load, but the rest of the app works normally. The key needs access to the FreeReels platform. FreeReels names series with string ids, so the backend gives each one a number in the `catalog_series` table.

### Test accounts

| Username | Password | Role |
|---|---|---|
| `admin` | `1111` | Admin |
| `mira.lens` | `4444` | Viewer with 142 coins and a few unlocked episodes |
| `viewer01` | `6666` | Viewer with 80 coins |

New sign-ups are always Viewers. To make someone an Admin, set their `role` column in the `users` table to `admin` through phpMyAdmin.

### API

All routes start with `/api`.

| Area | Routes |
|---|---|
| System | `GET /health`, `GET /lookups` (genres and AI tools) |
| Accounts | `POST /auth/register`, `POST /auth/login`, `POST /auth/logout`, `GET/PUT /auth/me` |
| Films | `GET /films?q=`, `GET /films/:id` |
| Episodes | `GET /episodes/:id`, `GET /episodes/:id/stream`, `POST /episodes/:id/unlock` |
| Wallet | `GET /wallet`, `GET /wallet/transactions`, `GET /wallet/unlocked`, `POST /wallet/topup`, `GET /coin-packs` |
| Social | `POST/DELETE /films/:id/like`, `GET /watchlist`, `POST/DELETE /films/:id/watchlist`, `GET/POST /films/:id/comments`, `DELETE /comments/:id` |
| Admin | `GET /admin/sales`, `GET /admin/films`, `PUT /admin/films/:id/status`, `GET /admin/films/:id/episodes`, `PUT /admin/episodes/:id`, `GET /admin/comments`, `DELETE /admin/comments/:id`, `GET/PUT /admin/settings`, `GET/POST /admin/coin-packs`, `PUT/DELETE /admin/coin-packs/:id` |
| Series Jeen | `GET /catalog/platforms`, `GET /catalog/platforms/:platformId/dramas`, `GET /catalog/dramas/:dramaId`, `GET /catalog/dramas/:dramaId/episodes`, `POST /catalog/dramas/:dramaId/episodes/:episodeNo/unlock`, `GET /catalog/access` |

### Lint and tests

```bash
cd mobile && flutter analyze
npm test --prefix backend
cd mobile && flutter test
```

Put backend tests in `backend/test/*.test.js` and Flutter tests in `mobile/test/*_test.dart`. Tests that need a database must use one whose name ends in `_test`, never `shortreel`.

### Branches

| Branch | Purpose |
|---|---|
| `main` | The main version |
| `develop` | Collects work before it goes to `main` |
| `Frame-dev` | Work in progress; the app talks to the real backend |
| `frontend-only` | The app alone, with no backend. It uses sample data from `mobile/lib/data/mock_repository.dart` and runs with `flutter run`, without the backend or MySQL. The catalog tab uses 60 Series Jeen series saved in `mock_catalog_data.dart` (posters need internet) and plays the bundled sample clips instead of the real videos. |
