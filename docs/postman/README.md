# Postman collection: ShortReel Sprint 1–2

ไฟล์:

| ไฟล์ | หน้าที่ |
|---|---|
| `ShortReel-Sprint1-2.postman_collection.json` | 116 คำขอ (guest, auth, role, upload, review, wallet/unlock, subscription, revenue, profile/social/admin อื่น ๆ, take down) แต่ละคำขอมี test ตรวจ status และ body |
| `ShortReel-local.postman_environment.example.json` | ตัวแปรตัวอย่าง **ไม่มี secret/token**: `base_url`, ชื่อบัญชี admin ของ seed, path ไฟล์ตัวอย่าง |
| `build-collection.js` | สร้างคอลเลกชันจากรายการคำขอ (แก้ที่นี่แล้วรันใหม่ แทนการแก้ JSON) |
| `run-collection.js` | ตัวรันเล็ก ๆ ไม่ต้องติดตั้งอะไร ใช้เมื่อไม่มี Newman (**ไม่ใช่ Newman**) |
| `fixtures/` | ไฟล์ทดสอบ upload ที่ผิด: `header-only.mp4` (มีแต่ header `ftyp` ไม่มี video track) และ `not-a-video.txt` |
| `last-run.json` | ผลการรันล่าสุดจากตัวรันข้างบน (ไม่มี token หรือรหัสผ่าน) |

## ตัวแปรและวิธีได้มา

ไม่มี ID ที่ผูกกับฐานของเครื่องใดเครื่องหนึ่ง คำขอแรกสร้าง `run_id`; ผู้ใช้ใหม่ชื่อ `viewer_<run_id>` / `creator_<run_id>` ถูกสมัครระหว่างรัน และ token, id, film, episode ถูกเก็บเข้าตัวแปรเองจาก response:

`token_viewer`, `token_creator`, `token_other_creator`, `token_admin` ← response ของ register/login · `seed_film_id`, `free_episode_id`, `paid_episode_id` ← อ่านจาก `GET /films` และ `GET /films/:id` · `film_id`, `new_free_episode_id`, `new_paid_episode_id` ← จาก upload

ตัวแปรที่ต้องตั้งเอง: `base_url`, `admin_username` และ **`admin_password` (เว้นว่างไว้ในไฟล์ ไม่ commit รหัสผ่าน** — ใส่ตอนรัน: ตัวรันในโฟลเดอร์นี้อ่านจาก `PM_ADMIN_PASSWORD=<รหัสของบัญชี admin ใน seed ที่ระบุไว้ใน README>`; Postman/Newman ใช้ `--env-var admin_password=...`; ใช้กับฐานทดสอบเท่านั้น), `sample_video_path` (MP4 จริงที่เล่นได้ เช่น คลิปใน `backend/uploads/` หรือโฟลเดอร์คลิปของทีม). path ไฟล์เป็นแบบสัมพันธ์กับโฟลเดอร์ที่สั่งรัน (Newman: ใช้ `--working-dir <root ของ repo>`)

**ข้อจำกัดที่ยังไม่ได้ยืนยัน:** collection นี้ทดสอบกับ `run-collection.js` เท่านั้น ยังไม่ได้รันใน Postman หรือ Newman. ตัวรันแทนค่า `{{ตัวแปร}}` ในช่อง path ของไฟล์ (`file src`) แต่ Postman/Newman อาจไม่แทนค่าให้ ถ้าไฟล์ในคำขอ upload ไม่ถูกส่ง ให้เลือกไฟล์ใหม่ในคำขอ Upload (`sample.mp4`, `header-only.mp4`, `not-a-video.txt`) ด้วยตัวเอง

`token_expired` ตั้งเป็นค่าที่ไม่ถูกต้องไว้ก่อน (ได้ 401 เหมือนกัน). Token ที่หมดอายุจริงมี test ฝั่ง backend (`auth.test.js`); ตัวรันในโฟลเดอร์นี้สร้างให้เองเมื่อกำหนด `E2E_JWT_SECRET`

## วิธีรัน

**ห้ามชี้ไปที่ฐานข้อมูลจริง** คอลเลกชันสมัครผู้ใช้ อัปโหลดหนัง อนุมัติ/take down และเปลี่ยนค่าส่วนแบ่ง ให้ใช้ฐานชั่วคราว:

```bash
# 1) ฐานชั่วคราวจาก schema (เปลี่ยนชื่อฐานก่อน เพราะไฟล์มี DROP DATABASE)
sed 's/`shortreel`/`shortreel_e2e_test`/g' backend/db/shortreel.sql | mysql -uroot

# 2) คลิปตัวอย่างให้ seed (ถ้าต้องการให้ guest ดูตอนฟรีของ seed ได้) ลงโฟลเดอร์ upload ชั่วคราว
mkdir -p /tmp/e2e_uploads && cp <คลิป MP4 ของทีม>/*.mp4 /tmp/e2e_uploads/
DB_NAME=shortreel_e2e_test UPLOAD_DIR=/tmp/e2e_uploads node backend/scripts/import-demo-clips.js /tmp/e2e_uploads

# 3) เปิด API ที่พอร์ตอื่น
cd backend && PORT=3100 DB_NAME=shortreel_e2e_test UPLOAD_DIR=/tmp/e2e_uploads JWT_SECRET=e2e-only-secret node src/server.js
```

```bash
# 4a) ตัวรันในโฟลเดอร์นี้ (ไม่ต้องติดตั้ง)
PM_BASE_URL=http://localhost:3100/api PM_ADMIN_PASSWORD=<รหัส admin ของ seed> E2E_JWT_SECRET=e2e-only-secret \
  node docs/postman/run-collection.js --report docs/postman/last-run.json

# 4b) Newman (ต้องติดตั้งก่อน: npm i -g newman)
newman run docs/postman/ShortReel-Sprint1-2.postman_collection.json \
  -e docs/postman/ShortReel-local.postman_environment.example.json \
  --env-var base_url=http://localhost:3100/api --env-var admin_password=<รหัส admin ของ seed> --working-dir .
```

ใน Postman: Import คอลเลกชันและ environment แล้วตั้ง `base_url`, กด Runner รันทุก folder ตามลำดับ

## ผลที่คาดหวัง

ทุกคำขอผ่านทุก assertion (116 คำขอ, 168 assertions ในการรันล่าสุด) ลำดับของ folder สำคัญเพราะคำขอถัดไปใช้ตัวแปรจากคำขอก่อนหน้า ตัวอย่างต่อคำขอ:

| กลุ่ม | ผลที่คาดหวัง |
|---|---|
| Guest | feed มีเฉพาะ `approved`; ตอนฟรีมี `stream_url`; ตอนเสียเงิน `stream_url:null` และ `/stream` → 401 |
| Register | valid 201 (role viewer, ไม่มี password ใน response) · ซ้ำ 409 · รหัสสั้น/ไม่มีตัวเลข/ไม่มี username 400 · `role:"admin"` 403 |
| Login / token | ถูก 200 · ผิด/ไม่มีผู้ใช้ 401 ข้อความเดียวกัน · ไม่มี token 401 · token หมดอายุ/ผิด 401 |
| Role / ownership | viewer สร้างหนัง 403 · viewer/creator เปิดคิว admin 403 · creator คนอื่นแก้/ลบหนัง 403 |
| Upload (multipart) | ไม่ติ๊ก AI 400 · ไฟล์ไม่ใช่วิดีโอ 400 · MP4 ที่มีแต่ header 400 · ราคา 501 400 · ไฟล์จริง 201 |
| Review | หนัง pending: guest 404, ไม่อยู่ใน feed, stream 404 · approve 200 แล้ว guest เห็น · reject ไม่มี note 400 · pending → taken_down 409 |
| Wallet / unlock | ไม่มีเหรียญ 402 (balance ยัง 0) · demo +100 → 100 · unlock จ่าย 30 → 70 · ซ้ำจ่าย 0 → 70 · ลบหนังที่มีคนจ่าย 409 |
| Subscription | ยังไม่สมัคร inactive · สมัครซ้ำ 3 ครั้งช่วงวันต่อเนื่อง · ยกเลิกแล้วยัง active ถึงสิ้นสุด |
| Revenue | creator ได้ 21 จาก 30 เหรียญ (admin 30%) · เปลี่ยนเป็น 50% และเปลี่ยน role ผู้สร้างแล้วยอดเดิมไม่เปลี่ยน · admin sales แยกหน่วยเหรียญกับเงินจำลอง · 101% → 400 |

ยังไม่ครอบคลุมในคอลเลกชัน (มี test ฝั่ง backend แทน): การปลดล็อกพร้อมกัน (concurrent), subscription ที่หมดอายุจริง (ต้องแก้วันในฐานข้อมูล), ลบตอนพร้อมซื้อ, และ catalog (ตัวเสริม ปิดไว้)

## ใช้กับ client แบบเบา (VS Code "REST Client")

ไฟล์ [`docs/api-tests.http`](../api-tests.http) คือชุดเดียวกัน 116 คำขอ (สร้างด้วย `node docs/postman/build-http-file.js`) ใช้กับส่วนขยาย **REST Client** (`humao.rest-client`) ของ VS Code และ JetBrains HTTP Client ได้ ตัวแปรที่ได้จาก response ถูกผูกไว้ให้แล้ว (เช่น `{{reg_viewer.response.body.$.token}}`)

1. เปิดฐานและ server ชั่วคราวตามขั้นตอนด้านบน
2. แก้ตัวแปรหัวไฟล์: `@base_url`, `@admin_password` (พิมพ์เองในเครื่อง ไม่ commit), `@run_id` (เปลี่ยนทุกครั้งที่เริ่มรันใหม่)
3. กด Send Request ไล่จากบนลงล่าง เทียบกับบรรทัด `# Expect:` และ `check:` เหนือแต่ละคำขอ

หมายเหตุ: id ของ seed ในไฟล์นี้ (หนัง 1, ตอนฟรี 1, ตอนเสียเงิน 3) ใช้ได้กับฐานใหม่จาก `shortreel.sql` เท่านั้น. การตรวจ `check:` และการเทียบวันที่ subscription ต้องดูด้วยตาเอง ผมตรวจว่าทั้ง 116 คำขอได้ status ตามที่ระบุเมื่อรันตามลำดับด้วยตัวทดสอบชั่วคราว แต่ยังไม่ได้เปิดใน REST Client จริง
