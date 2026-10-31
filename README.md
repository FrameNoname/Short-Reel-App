# ShortReel

แอปดูหนังสั้น AI แบบ vertical feed (Group 7, Project 2)

- `backend/`: REST API ด้วย Node.js, Express และ MySQL/MariaDB
- `mobile/`: แอป Flutter แบบ MVC
- `docs/api.md`: รายการ endpoint และรูปแบบ error

## วิธีใช้

### สิ่งที่ต้องติดตั้ง

- Node.js 22
- Flutter 3.44
- XAMPP (MariaDB)
- Android Studio พร้อม emulator (หรือใช้ Edge แทนก็ได้)

### 1. ฐานข้อมูล

เปิด MySQL ใน XAMPP แล้ว import `backend/db/shortreel.sql` ผ่าน phpMyAdmin

> ไฟล์นี้มี `DROP DATABASE IF EXISTS` การ import ซ้ำจะล้างข้อมูลเดิมทั้งหมด

### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

แก้ `JWT_SECRET` ใน `.env` ก่อนรัน แล้วเช็กที่ `http://localhost:3000/api/health` ต้องได้ `{"status":"ok","db":"up"}`

### 3. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

ไม่มี emulator ให้รันบน Edge

```bash
flutter run -d edge --web-port 8080
```

ถ้ารันบนอุปกรณ์จริง ให้ระบุที่อยู่ API เอง

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

### บัญชีทดสอบในแอป

| Username | Password | หมายเหตุ |
|---|---|---|
| `viewer01` | `6666` | ใช้ลอง flow ปลดล็อกด้วยเหรียญ |
| `mira.lens` | `4444` | Creator ที่มี Plus อยู่แล้ว |
| `admin` | `1111` | Admin |

### รัน test

```bash
npm test --prefix backend
```

```bash
cd mobile
flutter analyze
flutter test
```

## ทำถึงขั้นไหนแล้ว

**สรุป:** ฝั่งแอป (Flutter) ทำหน้าจอครบแล้วแต่ยังใช้ข้อมูลจำลอง ส่วน backend ยังเป็นโครง ยังไม่ได้เชื่อมกัน

| ส่วน | สถานะ |
|---|---|
| Backend: health check, middleware, โครง route/controller/model, upload (Multer), error format | เสร็จ |
| Backend: ฐานข้อมูลและ seed (`shortreel.sql`) | เสร็จ |
| Backend: endpoint จริงของ auth, films, episodes, wallet, subscriptions, creator, admin, social | **ยังไม่ทำ** ตอบ `501 NOT_IMPLEMENTED` |
| Backend: argon2id และ JWT | **ยังไม่ทำ** |
| Mobile: หน้าจอทั้งหมด (Login/Register, Feed/Player, Search/Filter, Wallet/เติมเหรียญ/Plus, Profile, Creator dashboard, Upload, Admin review, Notifications, Settings, Onboarding) | เสร็จ ใช้ข้อมูลจำลอง |
| Mobile: ปลดล็อกตอนด้วยเหรียญ, Plus, like/บันทึก/คอมเมนต์/ติดตาม/รายงาน, ภาษาไทย | เสร็จ ใช้ข้อมูลจำลอง |
| Mobile: เชื่อมกับ backend จริง | **ยังไม่ทำ** (มี `ApiClient` กับ `TokenStore` พร้อมแล้ว) |
| Mobile: unit/widget test | มีแล้ว (ใน `mobile/test/`) |
| วิดีโอจริง | **ยังไม่ทำ** พื้นที่เล่นวิดีโอยังเป็น placeholder |

ข้อมูลจำลองอยู่ที่ `mobile/lib/data/mock_repository.dart` และรีเซ็ตทุกครั้งที่เปิดแอปใหม่ เมื่อ API ส่วนไหนพร้อม ให้เขียน class ที่ implement `AppRepository` ด้วย `ApiClient` แล้วส่งเข้า `ShortReelApp` ใน `mobile/lib/main.dart` โดยไม่ต้องแก้หน้าจอ
