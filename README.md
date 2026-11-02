# ShortReel

[ภาษาไทย](#ภาษาไทย) · [English](#english)

---

## ภาษาไทย

แอปดูหนังสั้น AI แบบ vertical feed (Group 7, Project 2) · Flutter → REST API (Node.js/Express) → MySQL/MariaDB

- `backend/`: REST API, Multer upload, argon2id + JWT, ตรวจสิทธิ์ทุกคำขอ
- `mobile/`: แอป Flutter แบบ MVC (`models/ views/ controllers/` + `data/` repository)
- `docs/api.md`: รายการ endpoint, กติกาสิทธิ์/unlock/ส่วนแบ่ง
- `docs/acceptance-checklist.md`: เทียบเอกสารข้อกำหนดกับของที่มีจริงทีละข้อ (ทำแล้ว / ยังเป็น mock / ยังไม่ทำ)
- `docs/sprint-1-2-checklist.md` และ `docs/sprint-1-2-results.md`: สถานะ Sprint 1–2 รายข้อ พร้อมคำสั่งและผลการทดสอบจริง
- `docs/er-diagram.md`: ER diagram (Mermaid) และกติกายอดเหรียญ/ส่วนแบ่ง/subscription · `docs/screens-index.md`: ดัชนีหน้าจอ · `docs/postman/`: Postman collection + วิธีรัน

การจ่ายเงินทั้งหมด **จำลอง** (ปุ่ม demo +100 เหรียญ, coin pack, Plus) ไม่มี payment gateway และไม่มีเงินจริง

### วิธีใช้

#### สิ่งที่ต้องติดตั้ง

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB 10.4)
- Chrome/Edge หรือ Android emulator

#### 1. ฐานข้อมูล

เปิด MySQL ใน XAMPP แล้ว import `backend/db/shortreel.sql` ผ่าน phpMyAdmin

> ไฟล์นี้มี `DROP DATABASE IF EXISTS` การ import ซ้ำจะล้างข้อมูลเดิมทั้งหมด

#### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

แก้ `JWT_SECRET` ใน `.env` ก่อนรัน แล้วเช็กที่ `http://localhost:3000/api/health` ต้องได้ `{"status":"ok","db":"up"}` (ตั้ง `DB_NAME`, `PORT`, `UPLOAD_DIR` ใน `.env` ได้ เช่นเมื่อรันกับฐานทดสอบ)

#### 3. คลิปเดโม (10–20 คลิป)

seed หนัง 5 เรื่อง × 8 ตอน ชี้ไปที่ `uploads/film<N>_ep<M>.mp4` แต่ **ไม่มีไฟล์วิดีโอมากับ repository** (`uploads/` ถูก ignore) ให้ทีมเตรียมคลิป MP4 ที่ทีมมีสิทธิ์ใช้ใส่โฟลเดอร์หนึ่ง แล้วนำเข้า

```bash
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป> --dry-run   # ดูก่อนว่าจะจับคู่อย่างไร
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป>
```

สคริปต์ตรวจว่าเป็น MP4, คัดลอกเข้า `backend/uploads/`, อัปเดต `video_path` ของตอนใน seed (หนัง id 1–5 เท่านั้น) และถ้าคลิปน้อยกว่า 40 คลิปจะใช้ซ้ำวนไป โดยไม่แตะหนังที่อัปโหลดผ่านแอป หนังที่อัปโหลดผ่านแอปเก็บไฟล์ของตัวเอง ไม่ต้องใช้สคริปต์นี้ ไม่มีบริการภายนอกเกี่ยวข้อง

#### 4. Mobile

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Android emulator ใช้ `http://10.0.2.2:3000/api` (เป็นค่าเริ่มต้นเมื่อไม่ใช่เว็บ) อุปกรณ์จริงให้ระบุ IP เครื่อง เช่น `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`

แอปรองรับ Android และเว็บ ไม่มีโฟลเดอร์ iOS

#### บัญชีทดสอบ (seed)

| Username | Password | หมายเหตุ |
|---|---|---|
| `viewer01` | `6666` | Viewer มี 80 เหรียญ ใช้ลอง flow ปลดล็อก |
| `mira.lens` | `4444` | Creator ที่มี Plus อยู่แล้ว |
| `kestrel_studio` | `2222` | Creator เจ้าของ "Salt & Signal" |
| `admin` | `1111` | Admin |

สมัครใหม่ได้เป็น Viewer หรือ Creator เท่านั้น Admin เพิ่มได้ทาง `PUT /api/admin/users/:id/role` โดย admin

แอปมีแถบเลื่อนเหนือชื่อหนัง ลากเพื่อ seek ได้ การลองเล่นและ seek ทำบนเว็บ (Chromium) เท่านั้น ยังไม่ได้ลองบน Android

#### ตัวเสริม Series Jeen (ไม่บังคับ)

ใส่ `SERIESJEEN_API_KEY` ใน `backend/.env` และรันแอปด้วย `--dart-define=CATALOG=true` จะมีแท็บ catalog และหนังภายนอกต่อท้ายฟีด ไม่ใส่ก็ใช้แอปได้ครบทุกอย่างข้างบน หนังภายนอกไม่ติดป้าย AI

#### รัน test

ชุด test อัตโนมัติของ backend และ Flutter ถูกลบออกเพื่อเขียนใหม่ ตอนนี้ยังไม่มี test ในโปรเจกต์ ไฟล์ใหม่ให้วางที่:

- backend: `backend/test/*.test.js` รันด้วย `npm test --prefix backend` (`node --test`) ถ้า test ต้องใช้ฐานข้อมูล ให้ใช้ฐานชื่อลงท้าย `_test` เท่านั้น ห้ามชี้ไปที่ `shortreel`
- Flutter: `mobile/test/*_test.dart` รันด้วย `cd mobile && flutter test`

ตรวจโค้ด Flutter ได้ด้วย `cd mobile && flutter analyze`

ทดสอบ API ด้วยมือ: ใช้ collection "ShortReel ทดสอบเอง (ไม่มีโค้ด)" ใน Postman กับ server ทดสอบพอร์ต 3100 (วิธีเปิดฐานและ server ชั่วคราวอยู่ใน [`docs/postman/README.md`](docs/postman/README.md))

### ทำถึงขั้นไหนแล้ว

รายละเอียดทีละข้อกำหนดอยู่ใน [`docs/acceptance-checklist.md`](docs/acceptance-checklist.md) สรุปสั้น ๆ:

| ส่วน | สถานะ |
|---|---|
| สมาชิก: register/login (argon2id), JWT, restore session, logout, role + ownership ตรวจที่ backend | ทำแล้ว |
| Feed เฉพาะ approved, เล่นวิดีโอจริงผ่าน `/stream` (ตรวจสิทธิ์ทุกครั้ง, Range/206, `uploads/` ไม่เปิด public), guest ดูตอนฟรี | ทำแล้ว (ลองบนเว็บ Chromium; ยังไม่ได้ลองบนอุปกรณ์เป้าหมาย) |
| CRUD หนัง/ตอน + อัปโหลด Multer, AI label บังคับ, ราคาต่อตอน, ลบไฟล์ที่ค้าง | ทำแล้ว |
| Admin review (pending/approve/reject/take down) และหน้า Admin | ทำแล้ว |
| Wallet, top-up จำลอง, unlock ใน DB transaction เดียว (ไม่หักซ้ำ, ไม่ติดลบ, ทน concurrent) | ทำแล้ว |
| Subscription (วันเริ่ม/สิ้นสุด, หมดอายุ, ยกเลิก) | ทำแล้ว |
| ส่วนแบ่งรายได้ (บันทึก ณ ตอนปลดล็อก, ปัดเศษรวมตรง, Creator dashboard, Admin sales แยกเหรียญ/ดอลลาร์จำลอง) | ทำแล้ว |
| Search/filter genre, length, AI tool; Profile | ทำแล้ว |
| Like, บันทึก, ติดตาม, คอมเมนต์ (เรียบ), report | ทำแล้ว |
| การตอบกลับซ้อน / like คอมเมนต์ | **ยังเป็น local** (ไม่มีใน backend) |
| ยอดวิว, กราฟรายวัน, การแจ้งเตือน, forgot password, continue watching | **ถอดออกจากแอปแล้ว** (ไม่มีตารางใน DB) |
| ตัวเสริม Series Jeen | ทำงานแยก ไม่กระทบ flow หลัก; บั๊กเดิมของ catalog/player ยังไม่ได้ตรวจ |
| คลิปเดโมของทีม 10–20 คลิป | **ยังไม่มี** มีสคริปต์นำเข้าแล้ว รอทีมเตรียมคลิปที่มีสิทธิ์ใช้ |

---

## English

An AI short-film app with a vertical feed (Group 7, Project 2) · Flutter → REST API (Node.js/Express) → MySQL/MariaDB

- `backend/`: REST API, Multer uploads, argon2id + JWT, authorization checked on every request
- `mobile/`: Flutter app using MVC (`models/ views/ controllers/` + a `data/` repository)
- `docs/api.md`: endpoint list and the rules for permissions, unlocking and revenue share
- `docs/acceptance-checklist.md`: the requirements document compared item by item with what actually exists (done / still mock / not done)
- `docs/sprint-1-2-checklist.md` and `docs/sprint-1-2-results.md`: Sprint 1–2 status per item, with the commands and real test results
- `docs/er-diagram.md`: ER diagram (Mermaid) and the rules for coin balances, revenue share and subscriptions · `docs/screens-index.md`: screen index · `docs/postman/`: Postman collection and how to run it

All payments are **simulated** (the demo +100 coins button, coin packs, Plus). There is no payment gateway and no real money.

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

Change `JWT_SECRET` in `.env` before running, then check `http://localhost:3000/api/health`; it should return `{"status":"ok","db":"up"}`. `DB_NAME`, `PORT` and `UPLOAD_DIR` can also be set in `.env`, for example when running against a test database.

#### 3. Demo clips (10–20 clips)

The seed has 5 films × 8 episodes pointing at `uploads/film<N>_ep<M>.mp4`, but **no video files are included in the repository** (`uploads/` is ignored). Put MP4 clips the team has the rights to use into a folder, then import them:

```bash
node backend/scripts/import-demo-clips.js <clips-folder> --dry-run   # preview how clips will be matched
node backend/scripts/import-demo-clips.js <clips-folder>
```

The script checks that each file is an MP4, copies it into `backend/uploads/`, and updates `video_path` for the seeded episodes (film ids 1–5 only). With fewer than 40 clips it cycles through them again. Films uploaded through the app keep their own files and are not touched, so they don't need this script. No external services are involved.

#### 4. Mobile

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

The Android emulator uses `http://10.0.2.2:3000/api` (the default on non-web builds). On a real device, pass your machine's IP, e.g. `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`.

The app supports Android and web; there is no iOS folder.

#### Test accounts (seed)

| Username | Password | Notes |
|---|---|---|
| `viewer01` | `6666` | Viewer with 80 coins, for trying the unlock flow |
| `mira.lens` | `4444` | Creator who already has Plus |
| `kestrel_studio` | `2222` | Creator who owns "Salt & Signal" |
| `admin` | `1111` | Admin |

New sign-ups can only be Viewer or Creator. An admin can promote users through `PUT /api/admin/users/:id/role`.

There is a progress bar above the film title that you can drag to seek. Playback and seeking have only been tried on the web (Chromium), not yet on Android.

#### Series Jeen add-on (optional)

Set `SERIESJEEN_API_KEY` in `backend/.env` and run the app with `--dart-define=CATALOG=true` to get a catalog tab and external films appended to the feed. Without it, everything above still works. External films do not carry the AI label.

#### Running tests

The automated backend and Flutter test suites were removed to be rewritten; the project currently has no tests. Put new files here:

- Backend: `backend/test/*.test.js`, run with `npm test --prefix backend` (`node --test`). Tests that need a database must use one whose name ends in `_test`; never point them at `shortreel`.
- Flutter: `mobile/test/*_test.dart`, run with `cd mobile && flutter test`.

Lint the Flutter code with `cd mobile && flutter analyze`.

Manual API testing: use the "ShortReel ทดสอบเอง (ไม่มีโค้ด)" collection in Postman against the test server on port 3100 (how to start the temporary database and server is in [`docs/postman/README.md`](docs/postman/README.md)).

### Project status

Per-requirement details are in [`docs/acceptance-checklist.md`](docs/acceptance-checklist.md). Summary:

| Area | Status |
|---|---|
| Accounts: register/login (argon2id), JWT, session restore, logout, role + ownership checked on the backend | Done |
| Feed shows approved films only, real video playback via `/stream` (checked every time, Range/206, `uploads/` not public), guests can watch free episodes | Done (tried on web Chromium; not yet on target devices) |
| Film/episode CRUD + Multer upload, required AI label, per-episode price, cleanup of orphaned files | Done |
| Admin review (pending/approve/reject/take down) and admin screens | Done |
| Wallet, simulated top-up, unlock in a single DB transaction (no double charge, no negative balance, safe under concurrency) | Done |
| Subscription (start/end dates, expiry, cancel) | Done |
| Revenue share (recorded at unlock time, rounding sums correctly, Creator dashboard, Admin sales split into coins / simulated dollars) | Done |
| Search/filter by genre, length, AI tool; Profile | Done |
| Like, save, follow, comments (flat), report | Done |
| Nested replies / comment likes | **Local only** (not in the backend) |
| View counts, daily charts, notifications, forgot password, continue watching | **Removed from the app** (no DB tables) |
| Series Jeen add-on | Runs separately without affecting the main flow; existing catalog/player bugs not yet reviewed |
| Team demo clips (10–20) | **Not yet** — the import script is ready; waiting for clips the team has rights to use |
