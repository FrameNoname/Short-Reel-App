# ผลการทำและทดสอบ Sprint 1–2

เริ่มจาก commit `58ca1da` (ก่อนรอบนี้: backend 166 test, Flutter 253 test, analyzer ผ่าน) ยังไม่มีการ commit/push รอบนี้ สถานะรายข้ออยู่ที่ [`sprint-1-2-checklist.md`](sprint-1-2-checklist.md)

## 1. สรุปว่าปิดได้หรือไม่

> **หมายเหตุ:** โฟลเดอร์ `backend/db/migrations` ถูกลบแล้ว (เอกสารนี้เขียนก่อนหน้านั้น) ฐาน `shortreel` จริงมีคอลัมน์ `owner_is_admin` ครบแล้ว

### Sprint 1 — **ยังปิดไม่ได้**

1. GitHub branch rules: `main` ยัง **ไม่ protected** (GitHub API แบบไม่ล็อกอิน: `protected:false`) ต้องให้ผู้ใช้อนุญาตหรือตั้งเอง ข้อเสนออยู่ในแถว "GitHub repo และ branch rules" ของ checklist — ไม่ได้ตั้งหรือ push อะไร
2. Newman ยังไม่ได้รัน (ต้องดาวน์โหลดแพ็กเกจ) Collection ผ่านครบด้วยตัวรันของโปรเจกต์ (`docs/postman/run-collection.js`) ซึ่ง **ไม่ใช่ Newman** และยังไม่ได้ยืนยันว่า import เข้า Postman แล้วส่งไฟล์ upload ได้โดยไม่ต้องเลือกไฟล์ใหม่
3. หัวข้ออื่นของ Sprint 1 (ไอเดีย/บทบาท, ER, schema, แบบหน้าจอ, โครง Flutter, README/env, API contract, คลิปตัวอย่างสำหรับเดโมปัจจุบัน) **ครบพร้อมหลักฐาน**

### Sprint 2 — **ยังปิดไม่ได้**

เหตุผลคือแถวใน checklist ที่ไม่ใช่ `ผ่าน` เท่านั้น:

1. **ไม่ได้ทดสอบบนอุปกรณ์/แพลตฟอร์มเป้าหมาย** (`รอสิ่งภายนอก`): Android, secure storage (Keystore/Keychain), native file picker, ปัดฟีดช้า ๆ ด้วยมือบนอุปกรณ์ — ลองเฉพาะ **เว็บ (Chromium)** และ widget test ที่ใช้ picker/video platform ปลอม
2. **Newman** ยังไม่ได้รัน (`รอสิ่งภายนอก`, ข้อ 2 ของ Sprint 1)
3. `_refreshCount` ของหน้า Filters ยังไม่มี test เฉพาะ (`ยังไม่มีหลักฐาน`)
4. ขั้นเลือกไฟล์ใน flow "Creator → Upload → Admin review" ผ่านหน้าจอจริงทำอัตโนมัติไม่ได้ (picker ของระบบ) — ครึ่งหลัง (Admin approve จากหน้าจอ) ลองแล้ว ดู §3

ส่วน API/DB และ UI บนเว็บ **ครบพร้อมหลักฐาน**: auth/role, protected playback, review, wallet/unlock (atomic + race ทั้งสองลำดับ), subscription, ส่วนแบ่ง/earnings/admin sales, upload (ตรวจไฟล์จริง), pagination, session guard, single player, Profile/Creator dashboard refresh

## 2. คำสั่งและผลทดสอบ

| สิ่งที่รัน | คำสั่ง | ผล |
|---|---|---|
| Backend (ฐานทดสอบ `shortreel_<ชื่อ>_test` เท่านั้น) | `npm test --prefix backend` | **179 / 179 ผ่าน** (ก่อนรอบนี้ 166) |
| Flutter analyze | `cd mobile && flutter analyze` | No issues found |
| Flutter test | `cd mobile && flutter test` | **278 / 278 ผ่าน** (ก่อนรอบนี้ 253) |
| Flutter build (เว็บ) | `flutter build web --dart-define=API_BASE_URL=http://localhost:3100/api` | สำเร็จ (`build/web`) ลองบนเว็บเท่านั้น ไม่เหมารวม Android |
| Migration บนสำเนา schema เดิม | ดู §4 | จำนวนแถวเท่าเดิม รัน 001+002 ซ้ำได้ |
| Postman collection | `PM_BASE_URL=http://localhost:3100/api E2E_JWT_SECRET=… node docs/postman/run-collection.js --report docs/postman/last-run.json` | **116 คำขอ 168 assertions ผ่านหมด** (ตัวรันของโปรเจกต์ ไม่ใช่ Newman) |

ฐานข้อมูลจริง `shortreel` และ `backend/uploads/` **ไม่ถูกแตะ**: ทดสอบทั้งหมดใช้ `*_test` และโฟลเดอร์ upload ชั่วคราว; ฐาน `shortreel_e2e_test` ที่สร้างสำหรับ collection/เว็บถูกลบหลังรัน (ลบเฉพาะ process ที่เริ่มเองตามพอร์ต)

### ตรวจว่า regression ล้มเหลวบนโค้ดเดิมจริง

Backend: `git stash push -- backend/src` แล้วรัน test ใหม่กับ source ก่อนแก้ (schema ใหม่คงไว้) แล้ว `git stash pop`:

- ล้มเหลวบนโค้ดเดิม: password policy/ไม่ trim (2), ลบ↔ซื้อ (loop 12 รอบ), upload หลัง commit, Plus ต่อซ้ำ, role change, MP4 probe, pagination/`/wallet/unlocked`, edit film atomic = **9 test**; และ 2 test แบบกำหนดลำดับแน่นอนของ lock (delete ถือ lock ก่อน / ซื้อถือ lock ก่อน) ก็ล้มเหลว
- **ไม่ล้มเหลว**บนโค้ดเดิม: "the price limit is 500 coins everywhere" — API ปฏิเสธ 501+ อยู่แล้ว บั๊กจริงอยู่ที่ฟอร์ม Flutter (รับ 999); test นี้จึงเป็น guard ฝั่ง API ส่วนฟอร์มมี test ใน `mobile/test/sprint12_flows_test.dart`
- endpoint matrix เดิมยอมให้ 500 ผ่าน: แก้เป็น status/body เฉพาะต่อ endpoint (48 รายการ), ปฏิเสธ 5xx, และตรวจจำนวนเทียบกับไฟล์ routes

Flutter: regression ใหม่ใช้ API ที่เพิ่มรอบนี้ (เช่น `refreshBalance`, `active`) จึง **ไม่ได้รันกับ source เดิม** (คอมไพล์ไม่ผ่านอยู่แล้ว) แทนด้วยการ **ถอดการแก้ชั่วคราวแล้วรัน test** (mutation check) แล้วคืนค่า: ถอดการทิ้งคำตอบเก่าใน `ApiClient._dropIfStale` → `session_guard_test` ล้มเหลว (top-up ของบัญชีเก่า); ถอด `finally` ที่ dispose controller → `episode_video_test` ล้มเหลว 2 ข้อ (leak ตอน initialize ล้มเหลว/ออกกลางคัน); ถอด `_reload()` หลัง upload → test Creator studio ล้มเหลว; เปลี่ยน `OnActivated` กลับเป็น `OnInit` → test Profile ล้มเหลว

## 3. Flow ที่ลองจริง (เว็บ Chromium, ฐานชั่วคราว, backend พอร์ต 3100)

ลองผ่าน UI แล้วตรวจข้อมูลจริงจากฐานข้อมูล/DOM:

1. Guest → ฟีดเล่นตอนฟรี: `<video>` 1 ตัว `readyState 4` เวลาเดินหน้า → ตอนที่ 3 (เสียเงิน) ขึ้น "Log in to keep watching" → เลือกตอน → หน้า login gate
2. สมัครสมาชิกใหม่ `uiviewer1` ผ่านหน้า Register → ฐานข้อมูลมีผู้ใช้ รหัสผ่านเป็น `$argon2id$`
3. Wallet: เปิดแล้วอ่านยอดจากเซิร์ฟเวอร์ → "+100 free" → ยอด 100 และฐานข้อมูล `topup 100` → เปิดแท็บ Home กลับเห็น prompt ปลดล็อก
4. Unlock ตอนที่ 3 (20 เหรียญ): หน้าสรุปราคา/ยอดหลังปลดล็อก → ยืนยัน → ฐานข้อมูล `coin_balance 80`, `unlocked_episodes 1`, ledger `unlock −20`, ส่วนแบ่ง 0/20 และ `owner_is_admin 1` (หนังของ admin) → เล่นตอน 3 ได้ (`<video>` ตอน 35 `readyState 4`, เวลาเดินหน้า)

5. Admin approve ผ่านหน้าจอ: อัปโหลดหนัง "UI Review Film" ผ่าน API (สถานะ pending, guest ค้นไม่เจอ) → login `admin` ในแอป → แท็บ Admin: คิวแสดงหนังพร้อมปุ่ม **Approve / Reject เท่านั้น (ไม่มี Take down)** → กด Approve → ฐานข้อมูล `status=approved, reviewed_by=1`, คิวลดลง, Live เพิ่ม, `GET /films` ของ guest เห็นหนังเรื่องนี้

**ไม่ได้ลองผ่าน UI:** ขั้นเลือกไฟล์วิดีโอจากหน้า Upload ด้วย picker ของระบบ (ใช้ fake picker ใน widget test และอัปโหลดทาง API ตรงแทน), ปัดฟีดช้า ๆ ด้วยมือเพื่อพิสูจน์ "ไม่เล่นพร้อมกัน" (พิสูจน์ด้วย widget test + จำนวน `<video>` บนเว็บ), network failure/retry บนเว็บ

**ข้อสังเกต UX (ไม่ได้แก้):** หน้า Admin แสดง "The review queue is empty." ชั่วครู่ก่อนข้อมูลโหลดเสร็จ เพราะหน้านี้ไม่มี loading state

## 4. Migration (เก็บข้อมูลเดิม รันซ้ำได้)

สร้างฐาน `shortreel_migrate_test` จาก schema **ก่อน migration 001** (`git show 20eddf5:backend/db/shortreel.sql`) โดยแทนชื่อฐานเป็น `shortreel_migrate_test` ก่อนรัน (ไฟล์นั้นมี `DROP DATABASE` จึงห้ามรันดิบ) แล้วรัน `001` + `002` สองรอบ: ผลอยู่ที่ [`docs/evidence/migration-run.txt`](evidence/migration-run.txt) — ผู้ใช้/หนัง/ตอน/unlock/ledger/subscription เท่าเดิมทุกรอบ (ผู้ใช้ 6→7 มาจากแถวที่ผมใส่เองหนึ่งแถวเพื่อทดสอบ), `SUM(creator_share)` เท่าเดิม (42), `owner_is_admin` ถูกเติม 3 แถว creator และ 1 แถว admin ตรงกับ seed

ฐานข้อมูลจริง `shortreel` **ยังไม่มีคอลัมน์ `owner_is_admin`** จนกว่าจะรัน `002` — เปิดโค้ดใหม่กับฐานจริงโดยไม่รัน migration แล้วการปลดล็อกและหน้ารายได้ Creator จะล้มเหลว (ยังไม่ได้รันกับฐานจริง เพราะเป็นการเปลี่ยนฐานจริง) ดูกล่องคำเตือนใน §1 สำหรับลำดับคำสั่ง (สำรอง → 001 → 002)

## 5. การตัดสินใจและข้อจำกัดที่ควรรู้

- **ราคา:** เพดานเดียว 500 เหรียญ ทั้ง API, ฟอร์ม Upload และ mock
- **Subscription:** วันที่ inclusive ทั้งสองด้าน แผนใหม่เริ่มวันถัดจาก `paid_through`; ไม่มีต่ออัตโนมัติ (ข้อความใน UI บอกตรง ๆ) และไม่มีการแบ่งรายได้ของค่า subscription (ยังไม่มีในเอกสารข้อกำหนด)
- **รายได้ย้อนหลัง:** แถวที่มีก่อน migration 002 ใช้ role ปัจจุบันของเจ้าของเป็นค่าตั้งต้นครั้งเดียว (ไม่มีประวัติให้ใช้)
- **Session:** `ApiClient` มี generation ที่เพิ่มเมื่อ login/logout; คำตอบของคำขอที่แนบ token ซึ่งกลับมาหลังเปลี่ยนคนจะถูกทิ้ง (`STALE_SESSION`); guest request ไม่ถูกทิ้ง ไม่ได้เพิ่ม revoke/refresh token
- **Wallet history:** แอปดึงทุกหน้า (สูงสุด 4,000 แถว) ยังไม่มีปุ่ม "โหลดเพิ่ม"
- **Catalog/Series Jeen:** ปิดเป็นค่าเริ่มต้น ไม่แตะ; บั๊กเฉพาะของ catalog (ข้อ 25–28 ใน fix-checklist) **ไม่ได้แก้** รวมทั้ง quota ของบัญชีที่ถูกลบ
- **คลิป:** ไม่มี ffmpeg ในเครื่อง; คลิปในเครื่อง 12 + 1 เป็นคลิปที่ทีมสร้างเองชั่วคราว (ไม่ใช่ชุดส่งจริง 10–20 คลิปของ Sprint 4) ผ่าน `inspectMp4` ทุกไฟล์ (avc1)
- **Backend tests ชั่วคราว:** MP4 ในชุดทดสอบเป็นโครงกล่องที่สร้างเอง (ftyp/moov/trak/avc1/mdat) ไม่ใช่วิดีโอเข้ารหัสจริง ใช้พิสูจน์ตรรกะ probe ไม่ใช่การเล่น

## 6. งานค้าง (แยกตาม Sprint)

**Sprint 1 / ต้องให้ผู้ใช้ช่วย:** ตั้ง branch rules ของ `main`/`develop` (ข้อเสนอใน checklist); อนุญาตติดตั้ง Newman หรือรันเองตามคำสั่งใน `docs/postman/README.md`

**Sprint 2 / ในเครื่องทำต่อได้ (ไม่อยู่ในตารางหน้า 6 และไม่ใช่ 1 ใน 16 บั๊ก จึงไม่นับเป็นข้อที่ทำให้ปิดไม่ได้):** test ของ `_refreshCount`; UI เพิ่ม/ลบตอนรายตอน; preview วิดีโอและจัดการ role ในหน้า Admin; ปุ่ม "โหลดเพิ่ม" ในประวัติ Wallet; loading state ของหน้า Admin

**Sprint 2 / ต้องใช้อุปกรณ์:** ทดสอบ Android (หรือแพลตฟอร์มที่ส่ง) — secure storage, native picker, เล่น/seek บนอุปกรณ์

**Sprint 3–4 / นอกขอบเขตรอบนี้:** รายการ 40 ข้อที่เหลือใน `docs/claude-fix-checklist.md` เฉพาะที่ไม่ได้อยู่ในบั๊ก 16 ข้อ (settings persistence, lookups จาก backend, catalog 25–28, Following/public profile API, production hardening), ชุดคลิป 10–20 คลิป, รายงาน/สไลด์ฉบับจบ
