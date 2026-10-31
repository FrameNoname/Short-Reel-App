# ShortReel

แอปดูหนังสั้น AI แบบ vertical feed (Group 7, Project 2) ประกอบด้วย

- `backend/`: REST API ด้วย Node.js, Express และ MySQL/MariaDB
- `mobile/`: แอป Flutter แบบ MVC
- `docs/api.md`: สัญญา API, รูปแบบ error และรายการ endpoint ทั้งหมด

**สถานะ:** backend ทำงานจริงเฉพาะ health check และ middleware ส่วน endpoint อื่นตอบ `501 NOT_IMPLEMENTED` แอป Flutter มี UI ครบตามดีไซน์ แต่ใช้ข้อมูลจำลองจาก `mobile/lib/data/mock_repository.dart` ซึ่งรีเซ็ตทุกครั้งที่เปิดแอปใหม่ และพื้นที่วิดีโอยังเป็น placeholder

เมื่อ API ส่วนไหนพร้อม ให้เขียน class ที่ implement `AppRepository` ด้วย `ApiClient` แล้วส่งเข้า `ShortReelApp` ใน `mobile/lib/main.dart` โดยไม่ต้องแก้หน้าจอ

บัญชีทดสอบในแอปคือ `viewer01` / `6666`, `mira.lens` / `4444`, `admin` / `1111` โดย `mira.lens` มี Plus อยู่แล้ว จึงต้องใช้ `viewer01` เพื่อลอง flow ปลดล็อกด้วยเหรียญ

## สิ่งที่ต้องติดตั้ง

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB)
- Android Studio พร้อม Android SDK และ emulator สำหรับรันแอป

## ฐานข้อมูล

เปิด MySQL ใน XAMPP แล้ว import `backend/db/shortreel.sql` ผ่าน phpMyAdmin

> **คำเตือน:** ไฟล์นี้มี `DROP DATABASE IF EXISTS` การ import ซ้ำจะล้างข้อมูลเดิมทั้งหมด

บัญชี demo อยู่ที่หัวไฟล์ SQL และใช้สำหรับการสาธิตเท่านั้น

## Backend

```bash
cd backend
npm install
cp .env.example .env
```

แก้ `JWT_SECRET` ใน `.env` เป็นค่าสุ่มยาว ๆ แล้วรัน

```bash
npm run dev
```

ตรวจว่าทำงานได้ที่ `http://localhost:3000/api/health` ต้องตอบ `{"status":"ok","db":"up"}`

ไฟล์วิดีโออยู่ใน `backend/uploads/` ซึ่งไม่เข้า git ห้ามเปิดโฟลเดอร์นี้เป็น static เพราะวิดีโอต้องผ่าน `GET /api/episodes/:id/stream` เพื่อตรวจสิทธิ์ก่อนเสมอ

## Mobile

```bash
cd mobile
flutter pub get
flutter run
```

ลองบน Edge ได้โดยไม่ต้องมี emulator

```bash
flutter run -d edge --web-port 8080
```

ค่าเริ่มต้นของ API คือ `http://localhost:3000/api` บนเว็บ และ `http://10.0.2.2:3000/api` บน Android emulator ถ้ารันบนอุปกรณ์อื่นให้กำหนดเอง

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

## การทดสอบ

```bash
npm test --prefix backend
```

Test ของ backend ไม่ต้องมีฐานข้อมูล

```bash
cd mobile
flutter analyze
flutter test
```

## เจ้าของงานตาม Sprint 2

| Student ID | ไฟล์ backend หลัก |
|---|---|
| 6731501100 | `films`, `episodes` (feed, detail, stream), การ review ใน `admin` |
| 6731501102 | `auth`, `subscriptions`, middleware สิทธิ์ |
| 6731501076 | `wallet`, unlock, sales และ revenue share ใน `admin` |
| 6731501103 | `config/db.js`, seed, การสร้าง แก้ไข และลบ film/episode |
| 6731501078 | `creator`, Profile, API collection |
| 6731501125 | `social` (ถ้าทีมตัดสินใจรวมไว้) |

แต่ละฟีเจอร์มีไฟล์ใน `backend/src/routes`, `controllers` และ `models` ชื่อเดียวกัน ให้แทนที่ `notImplemented` ใน controller ทีละฟังก์ชัน และเขียน SQL ไว้ใน model เท่านั้น
