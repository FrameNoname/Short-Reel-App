# ShortReel

แอปดูหนังสั้น AI แบบ vertical feed (Group 7, Project 2) · Flutter → REST API (Node.js/Express) → MySQL/MariaDB

- `backend/`: REST API, Multer upload, argon2id + JWT, ตรวจสิทธิ์ทุกคำขอ
- `mobile/`: แอป Flutter แบบ MVC (`models/ views/ controllers/` + `data/` repository)
- `docs/api.md`: รายการ endpoint, กติกาสิทธิ์/unlock/ส่วนแบ่ง
- `docs/acceptance-checklist.md`: เทียบเอกสารข้อกำหนดกับของที่มีจริงทีละข้อ (ทำแล้ว / ยังเป็น mock / ยังไม่ทำ)
- `docs/sprint-1-2-checklist.md` และ `docs/sprint-1-2-results.md`: สถานะ Sprint 1–2 รายข้อ พร้อมคำสั่งและผลการทดสอบจริง
- `docs/er-diagram.md`: ER diagram (Mermaid) และกติกายอดเหรียญ/ส่วนแบ่ง/subscription · `docs/screens-index.md`: ดัชนีหน้าจอ · `docs/postman/`: Postman collection + วิธีรัน

การจ่ายเงินทั้งหมด **จำลอง** (ปุ่ม demo +100 เหรียญ, coin pack, Plus) ไม่มี payment gateway และไม่มีเงินจริง

## วิธีใช้

### สิ่งที่ต้องติดตั้ง

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB 10.4)
- Chrome/Edge หรือ Android emulator

### 1. ฐานข้อมูล

เปิด MySQL ใน XAMPP แล้วเลือกอย่างใดอย่างหนึ่ง

- **ติดตั้งใหม่:** import `backend/db/shortreel.sql` ผ่าน phpMyAdmin

  > ไฟล์นี้มี `DROP DATABASE IF EXISTS` การ import ซ้ำจะล้างข้อมูลเดิมทั้งหมด

- **ฐานเดิมที่ยังไม่มีคอลัมน์ล่าสุด:** ไม่มี migration แล้ว ต้อง import `shortreel.sql` ใหม่ (ข้อมูลเดิมหาย) หรือเพิ่มคอลัมน์เองให้ตรงกับไฟล์นี้ (เช่น `unlocked_episodes.owner_is_admin`)

### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

แก้ `JWT_SECRET` ใน `.env` ก่อนรัน แล้วเช็กที่ `http://localhost:3000/api/health` ต้องได้ `{"status":"ok","db":"up"}` (ตั้ง `DB_NAME`, `PORT`, `UPLOAD_DIR` ใน `.env` ได้ เช่นเมื่อรันกับฐานทดสอบ)

### 3. คลิปเดโม (10–20 คลิป)

seed หนัง 5 เรื่อง × 8 ตอน ชี้ไปที่ `uploads/film<N>_ep<M>.mp4` แต่ **ไม่มีไฟล์วิดีโอมากับ repository** (`uploads/` ถูก ignore) ให้ทีมเตรียมคลิป MP4 ที่ทีมมีสิทธิ์ใช้ใส่โฟลเดอร์หนึ่ง แล้วนำเข้า

```bash
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป> --dry-run   # ดูก่อนว่าจะจับคู่อย่างไร
node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป>
```

สคริปต์ตรวจว่าเป็น MP4, คัดลอกเข้า `backend/uploads/`, อัปเดต `video_path` ของตอนใน seed (หนัง id 1–5 เท่านั้น) และถ้าคลิปน้อยกว่า 40 คลิปจะใช้ซ้ำวนไป โดยไม่แตะหนังที่อัปโหลดผ่านแอป. หนังที่อัปโหลดผ่านแอปเก็บไฟล์ของตัวเอง ไม่ต้องใช้สคริปต์นี้
ไม่มีบริการภายนอกเกี่ยวข้อง

### 4. Mobile

```bash
cd mobile
flutter pub get
flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Android emulator ใช้ `http://10.0.2.2:3000/api` (เป็นค่าเริ่มต้นเมื่อไม่ใช่เว็บ). อุปกรณ์จริงให้ระบุ IP เครื่อง เช่น `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`

### บัญชีทดสอบ (seed)

| Username | Password | หมายเหตุ |
|---|---|---|
| `viewer01` | `6666` | Viewer มี 80 เหรียญ ใช้ลอง flow ปลดล็อก |
| `mira.lens` | `4444` | Creator ที่มี Plus อยู่แล้ว |
| `kestrel_studio` | `2222` | Creator เจ้าของ "Salt & Signal" |
| `admin` | `1111` | Admin |

สมัครใหม่ได้เป็น Viewer หรือ Creator เท่านั้น. Admin เพิ่มได้ทาง `PUT /api/admin/users/:id/role` โดย admin

แอปมีแถบเลื่อนเหนือชื่อหนัง ลากเพื่อ seek ได้ การลองเล่นและ seek ทำบนเว็บ (Chromium) เท่านั้น ยังไม่ได้ลองบน Android

### ตัวเสริม Series Jeen (ไม่บังคับ)

ใส่ `SERIESJEEN_API_KEY` ใน `backend/.env` และรันแอปด้วย `--dart-define=CATALOG=true` จะมีแท็บ catalog และหนังภายนอกต่อท้ายฟีด ไม่ใส่ก็ใช้แอปได้ครบทุกอย่างข้างบน หนังภายนอกไม่ติดป้าย AI

### รัน test

ชุด test อัตโนมัติของ backend และ Flutter ถูกลบออกเพื่อเขียนใหม่ ตอนนี้ยังไม่มี test ในโปรเจกต์ ไฟล์ใหม่ให้วางที่:

- backend: `backend/test/*.test.js` รันด้วย `npm test --prefix backend` (`node --test`) ถ้า test ต้องใช้ฐานข้อมูล ให้ใช้ฐานชื่อลงท้าย `_test` เท่านั้น ห้ามชี้ไปที่ `shortreel`
- Flutter: `mobile/test/*_test.dart` รันด้วย `cd mobile && flutter test`

ตรวจโค้ด Flutter ได้ด้วย `cd mobile && flutter analyze`

ทดสอบ API ด้วยมือ: ใช้ collection "ShortReel ทดสอบเอง (ไม่มีโค้ด)" ใน Postman กับ server ทดสอบพอร์ต 3100 (วิธีเปิดฐานและ server ชั่วคราวอยู่ใน [`docs/postman/README.md`](docs/postman/README.md))

## ทำถึงขั้นไหนแล้ว

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
| คลิปเดโมของทีม 10–20 คลิป | **ยังไม่มี** มีสคริปต์นำเข้า และตอนนี้ฐานข้อมูลพัฒนาชี้ไปที่คลิปที่สร้างเอง 12 คลิป (+1 คลิปยาวสำหรับลอง seek) เป็นชุดชั่วคราว ให้ทีมแทนที่ด้วยคลิปที่มีสิทธิ์ใช้ |

`main.dart` ใช้ `ApiRepository` (ต่อ backend จริง). `MockRepository` ถูกลบไปพร้อมชุด test เดิม

แอปรองรับ Android และเว็บ ไม่มีโฟลเดอร์ iOS
