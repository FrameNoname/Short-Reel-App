# Acceptance checklist: ShortReel เทียบกับเอกสารข้อกำหนด

เทียบแต่ละข้อกำหนดของ Project 2 (Group 7) กับของที่มีอยู่จริง ณ ตอนนี้

**สถานะ:** `ทำแล้ว` = เชื่อม Flutter → REST API → MySQL จริงและมี test หรือผ่านการลองจริง · `ทำแล้ว (ยังไม่ยืนยันบางส่วน)` = โค้ดและ test ผ่านแต่มีส่วนที่ยังไม่ได้ลอง (ระบุไว้) · `ยังเป็น mock` = ใช้ข้อมูลจำลองในแอป · `ยังไม่ทำ`

- ชื่อ test: `B:` = `backend/test/…` (รันด้วย `npm test --prefix backend` ต้องมี MariaDB; แต่ละไฟล์สร้างฐานข้อมูลชั่วคราว `shortreel_<ชื่อ>_test` แล้วลบทิ้ง และ **ปฏิเสธทำงานถ้าชื่อฐานข้อมูลไม่ลงท้าย `_test`**) · `F:` = `mobile/test/…`
- เดโมที่ทำมือ (D1–D8) อยู่ท้ายเอกสาร

## 1. ระบบสมาชิกและสิทธิ์

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test / เดโม | สถานะ |
|---|---|---|---|---|---|
| Register / Login ด้วย username + password เก็บ argon2id | `POST /auth/register`, `/auth/login` | Login, Register | `users.password` (`$argon2id$…`) | B: accounts (hash เป็น argon2id, ซ้ำ 409, validation) | ทำแล้ว |
| JWT + เก็บ token อย่างปลอดภัย | JWT HS256, `Authorization: Bearer` | — | — | B: auth, accounts · F: api_repository (token ถูกส่งกับคำขอถัดไป) · `flutter_secure_storage` | ทำแล้ว (Keystore/Keychain บนเครื่องจริงยังไม่ได้ลอง; ลองบนเว็บแล้ว) |
| เปิดแอปใหม่แล้วยัง login อยู่ | `GET /auth/me` | splash แล้วเข้า Feed | — | F: api_repository (restore, token ถูกปฏิเสธ → ล้าง) · D1 | ทำแล้ว |
| Logout ล้าง token และ state | `POST /auth/logout` (stateless) | Settings → Log out | — | F: api_repository (ล้าง token แม้เซิร์ฟเวอร์ล่ม); controller ที่เก็บข้อมูลผู้ใช้ถูกรีเซ็ตผ่าน `addLogoutListener` | ทำแล้ว (ไม่มีการเพิกถอน token ฝั่งเซิร์ฟเวอร์ ดู "ข้อจำกัด") |
| 401 กลางทางพาไปหน้า login และไม่ส่ง token ที่ถูกปฏิเสธซ้ำ | — | — | — | F: api_repository (`onUnauthorized`, ไม่นับรหัสผ่านผิด, หลัง 401 คำขอถัดไปไม่มี `Authorization`) | ทำแล้ว |
| ลิงก์เล่นวิดีโอใช้เป็น login token ไม่ได้ (รวมถึงกับ `/api/catalog/*`) | `readToken` ปฏิเสธ payload ที่มี `typ` | — | — | B: auth, playback | ทำแล้ว |
| รองรับ Viewer / Creator / Admin | `role` ใน `users` | tab ตาม role | `users.role` | B: endpoints (ตาราง role ครบทุก endpoint ที่ mount (48 รายการ ตรวจจำนวนเทียบกับไฟล์ routes อัตโนมัติ) พร้อม status/body ที่คาดหวังของแต่ละรายการ) | ทำแล้ว |
| ตรวจ role และ ownership ที่ backend | `requireRole`, `loadOwnedFilm` | — | — | B: accounts, upload_review (แก้/ลบของคนอื่น → 403, role อ่านจาก DB ทุกคำขอ) | ทำแล้ว |
| Creator แก้ไขได้เฉพาะหนังของตน | `PUT/DELETE /films/:id`, `/episodes/:id` | Creator studio | `films.creator_id` | B: upload_review | ทำแล้ว |
| สมัครเป็น Admin ไม่ได้ | `register` ส่ง `role:"admin"` → 403 | — | — | B: accounts | ทำแล้ว |
| (เพิ่ม admin ได้ทางไหน) | `PUT /admin/users/:id/role` | — | `users.role` | B: accounts | ทำแล้ว |

## 2. หนังและการเล่นวิดีโอ

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test / เดโม | สถานะ |
|---|---|---|---|---|---|
| Feed แสดงเฉพาะ approved | `GET /films` | Feed, Search | `films.status` | B: playback, upload_review | ทำแล้ว |
| เล่นวิดีโอจริง ครั้งละหนึ่งรายการ | `GET /episodes/:id` → `/stream` | Feed (`EpisodeVideo`) | `episodes.video_path` | D2 (เล่นจริงในเบราว์เซอร์: `readyState 4`, `currentTime` ไหล) · ฟีดส่ง `active` ให้เฉพาะหน้าที่เลือกอยู่; หน้าอื่นไม่โหลด/ไม่เล่น, controller ที่ initialize ล้มเหลวหรือผู้ใช้ออกก่อนถูก dispose (F: episode_video_test ด้วย platform ปลอมที่นับ create/dispose/play) | ทำแล้ว (ลองบนเว็บ Chromium; ยังไม่ได้ลองบน Android) |
| Guest ดูตอนฟรีได้ | `access:"free"` | Feed | `episodes.is_free` | B: playback · D2 | ทำแล้ว |
| ตอนเสียเงินแสดงคำเชิญ login/ปลดล็อก | `stream_url:null`, `/stream` → 401 | prompt "Log in or unlock" | — | B: playback · D3 | ทำแล้ว |
| ดูตอนเสียเงินได้เมื่อซื้อแล้วหรือ subscription ไม่หมดอายุ | `access: unlocked/subscription` | Feed | `unlocked_episodes`, `subscriptions` | B: wallet, playback | ทำแล้ว |
| Backend ตรวจสิทธิ์ก่อนให้ไฟล์ | `/stream` ตรวจใหม่ทุกคำขอ | — | — | B: playback (guest/ไม่ปลดล็อก/ลิงก์สลับตอน/login token ใช้เป็นลิงก์ไม่ได้) | ทำแล้ว |
| ไม่เปิด `uploads/` เป็น public | ไม่มี `express.static` | — | — | B: playback (`/uploads/...` → 404), path `../` ออกนอกโฟลเดอร์ไม่ได้ | ทำแล้ว |
| Seek | `/stream` → 206 `Accept-Ranges` | แถบเลื่อน (`VideoProgressIndicator`, ลากเพื่อ seek) เหนือชื่อหนัง | — | B: playback (`Range: bytes=10-19` → 206) · ลองจริงในเบราว์เซอร์กับคลิป 24 วินาที: กดแถบที่ ~77% แล้ว `currentTime` กระโดดจาก ~10 s เป็น ~19.5 s (D2b) | ทำแล้วบนเว็บ (คลิปทดสอบเล็กพอที่เบราว์เซอร์โหลดครบก่อน จึงไม่ได้เห็นคำขอ Range ใหม่ตอน seek; ฝั่ง Range ยืนยันด้วย test ของ backend; ยังไม่ได้ลองบนอุปกรณ์เป้าหมาย) |
| วิดีโอหยุดเมื่อเปลี่ยนหน้า/แท็บ | — | `EpisodeVideo` ใช้ `TabActive` + `ModalRoute.isCurrent` | — | D4: เปลี่ยนไปแท็บ Wallet ระหว่างเล่น แล้วอ่าน `<video>`: `paused:true` และ `ended:false` (หยุดก่อนจบคลิป) | ทำแล้ว (ลองมือบนเว็บ; ไม่มี test อัตโนมัติเพราะ `video_player` ต้องใช้ platform) |
| ปลดล็อก/สมัคร Plus/login จากพรอมต์แล้วเล่นต่อทันที | — | ปุ่ม Unlock รอให้หน้ารายการตอนปิดแล้วขอลิงก์ใหม่ | — | โค้ด (`onLocked` เป็น Future) | ทำแล้วในโค้ด (ยังไม่ได้ลองในเบราว์เซอร์; ปุ่ม Try again/ขอลิงก์ใหม่ใช้เส้นทางเดียวกับที่ลองแล้ว) |
| จัดการ error ของวิดีโอ | — | ข้อความ + ปุ่ม Try again | — | โค้ด (`hasError`, ไฟล์หาย → 404 → ข้อความ) · B: playback (ไฟล์หาย 404) | ทำแล้ว |

### Series Jeen / catalog (ตัวเสริม)

| ข้อกำหนด | สถานะ |
|---|---|
| ไม่เป็น dependency ของ flow หลัก | ทำแล้ว: ไม่ตั้ง `SERIESJEEN_API_KEY` → `/api/catalog/*` ตอบ 503 และ endpoint อื่นไม่กระทบ; ใช้ตรวจ token แบบไม่แตะ DB; แอปเปิด catalog ด้วย `--dart-define=CATALOG=true` เท่านั้น และโหลดล้มเหลวก็ยังเห็นหนังของระบบ (F: api_repository) |
| แยกหนังภายนอกออกจากหนัง AI ที่ creator อัปโหลด | ทำแล้ว: ต่อท้ายหนังของระบบ, id ≥ 100000000, ช่อง "Series Jeen" (ไม่ใช่บัญชีจริง ไม่มีเครื่องหมาย verified), ไม่ผูกกับ admin |
| ไม่ติดป้าย AI-generated โดยไม่มีข้อมูลยืนยัน | ทำแล้ว: `isAiGenerated:false` (F: api_repository, catalog_test) |
| แก้บั๊ก catalog/player ที่พบก่อนหน้า | **ยังไม่ได้ตรวจ**: เอกสารนี้ไม่ได้ระบุว่าบั๊กคืออะไร เปิดจุดนี้ไว้เพื่อให้ระบุ |

## 3. CRUD หนังและตอน + อัปโหลด

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test | สถานะ |
|---|---|---|---|---|---|
| Multer รับไฟล์จริง | `POST /films/:id/episodes` (`multipart`) | Upload | `episodes` | B: upload_review, upload | ทำแล้ว |
| Creator/Admin สร้างหนังและเพิ่มตอน | `POST /films` | Upload | `films` | B: upload_review | ทำแล้ว |
| title, genre, AI tool, prompt credit, AI label | ฟิลด์ใน `POST /films`; `is_ai_generated:true` บังคับ | Upload (ติ๊ก "AI-generated") | `films.*`, `genres`, `ai_tools` | B: upload_review (ไม่ติ๊ก/ชื่อไม่รู้จัก → 400) | ทำแล้ว |
| ตอนฟรีหรือราคาเหรียญ | `price_coins` 0–500 | Upload (การ์ดราคา) | `episodes.is_free/price_coins` | B: upload_review · F: upload_price | ทำแล้ว |
| อ่าน/แก้/ลบหนังและตอน | `GET/PUT/DELETE` | Creator studio, Upload (แก้) | — | B: upload_review | ทำแล้ว |
| ตรวจ ownership ทุก endpoint ที่แก้ | `loadOwnedFilm` ก่อน multer | — | — | B: upload_review (คนอื่นไม่ได้เขียนไฟล์ลงดิสก์) | ทำแล้ว |
| ตรวจขนาดและชนิดไฟล์ | mimetype + signature `ftyp` + 200 MB | แจ้งขนาดฝั่งแอป | — | B: upload_review (text/ไฟล์ปลอม → 400, ใหญ่เกิน → 413) | ทำแล้ว |
| ไฟล์ที่อัปโหลดแต่บันทึก DB ล้มเหลว | ลบไฟล์ใน `catch` | — | — | B: upload_review (ซ้ำเลขตอน → ไฟล์ถูกลบ) | ทำแล้ว |
| ผลกระทบต่อผู้ซื้อก่อนลบ | ลบหนัง/ตอนที่มีคนจ่ายแล้ว → 409 | ข้อความ error | `unlocked_episodes` | B: upload_review | ทำแล้ว |
| หน้า Upload ไม่รายงานสำเร็จถ้าไม่มีไฟล์ส่งจริง | เลือกไฟล์ด้วย `file_picker`; ปุ่ม submit ปิดจนกว่าจะเลือกไฟล์ จะแจ้งสำเร็จหลังเซิร์ฟเวอร์ตอบ 201 ครบทุกตอน ล้มกลางทางจะลบหนังที่ค้าง | Upload | — | F: api_repository (อัปโหลดล้มเหลว → ไม่สำเร็จ + ลบหนัง), upload_price (ต้องกดเลือกวิดีโอก่อน) | ทำแล้ว (การเลือกไฟล์ด้วยหน้าต่างจริงของระบบปฏิบัติการยังไม่ได้ลองด้วยมือ) |

## 4. Admin review

| ข้อกำหนด | Endpoint | หน้าจอ | Test | สถานะ |
|---|---|---|---|---|
| หนังใหม่เริ่มเป็น pending | `POST /films` | — | B: upload_review | ทำแล้ว |
| approve / reject / take down | `POST /admin/films/:id/review` | Admin | B: upload_review | ทำแล้ว |
| pending/rejected/taken_down ไม่อยู่ใน feed | `GET /films` | — | B: upload_review, playback | ทำแล้ว |
| Creator ดูสถานะหนังตน (พร้อมเหตุผล) | `GET /creator/films` | Creator studio | B: upload_review | ทำแล้ว |
| URL ตรงไม่ข้ามสถานะ | `/films/:id`, `/episodes/:id`, `/stream` → 404 | — | B: upload_review (ลิงก์เล่นเก่าใช้ไม่ได้หลัง take down) | ทำแล้ว |
| ต้องมีเหตุผลเมื่อ reject/take down; เปลี่ยนสถานะผิดกติกา → 409; ต้องมีตอนก่อน approve | | | B: upload_review | ทำแล้ว |
| แก้หนังที่ approved โดย creator → กลับไปรอตรวจ (รวมการเพิ่มตอน) | | | B: upload_review | ทำแล้ว (เลือกกฎนี้เพื่อไม่ให้ตอนใหม่ข้ามการตรวจ; ผู้ที่ซื้อแล้วเห็นหนังหายระหว่างรอตรวจ) |
| เชื่อมหน้า Admin กับ backend | `/admin/reviews`, `/admin/films`, `/admin/reports` | Admin | F: error_states, gap_flows (mock) · D5 | ทำแล้ว |

## 5. Wallet และปลดล็อก

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test | สถานะ |
|---|---|---|---|---|---|
| ยอดเหรียญ + ประวัติจาก DB | `GET /wallet`, `/wallet/transactions` | Wallet | `users.coin_balance`, `coin_transactions` | B: wallet · D6 | ทำแล้ว |
| coin packs + ปุ่ม demo +100 | `GET /coin-packs`, `POST /wallet/topup` | Wallet, Top up | `coin_packs`, `settings` | B: wallet | ทำแล้ว |
| ป้าย simulated payment | `simulated_payment:true` | ป้าย DEMO + "Payments are simulated…" | — | B: wallet · D6 | ทำแล้ว |
| ไม่มี payment gateway | — | — | — | — | ตามข้อกำหนด |
| Backend กำหนดจำนวนเหรียญและราคา | client ส่งแค่ `pack_id` หรือ `demo:true` | — | — | B: wallet (ส่ง `coins` → 400) | ทำแล้ว |
| หักเหรียญ + บันทึก + ให้สิทธิ์ใน transaction เดียว | `POST /episodes/:id/unlock` | Unlock | `unlocked_episodes`, `coin_transactions` | B: wallet | ทำแล้ว |
| เหรียญไม่ติดลบ / คำขอพร้อมกัน | `UPDATE … WHERE coin_balance >= ?` + `FOR UPDATE` | — | — | B: wallet (5 คำขอพร้อมกันตอนเดียว หักครั้งเดียว; 5 ตอนพร้อมกันเหรียญ 45 สำเร็จ 2 ถูกปฏิเสธ 3, ยอดเหลือ 5) | ทำแล้ว |
| unlock ซ้ำไม่หักซ้ำ | `UNIQUE(user_id, episode_id)` | — | — | B: wallet | ทำแล้ว |
| เหรียญไม่พอ | 402 `INSUFFICIENT_COINS` | sheet เติมเหรียญ | — | B: wallet · F: api_repository | ทำแล้ว |
| เปิดแอปใหม่ สิทธิ์ยังอยู่ | อ่านจาก DB | — | — | B: wallet (login ใหม่) · D1 | ทำแล้ว |

## 6. Subscription

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test | สถานะ |
|---|---|---|---|---|---|
| มีวันเริ่มต้น/สิ้นสุด | `POST /subscription` | Plus | `subscriptions.start_date/end_date` | B: wallet | ทำแล้ว |
| active ดูทุกตอนไม่เสียเหรียญ | `access:"subscription"`, unlock → `charged:0` | — | — | B: wallet | ทำแล้ว |
| หมดอายุ → กลับไปกติกาปกติ | ตรวจ `CURDATE()` ฝั่ง DB | — | — | B: wallet (แก้ `end_date` ย้อนหลังแล้วเป็น `locked`, `/stream` → 403) | ทำแล้ว |
| ตอนที่เคยซื้อดูได้หลังหมดอายุ | | | | B: wallet | ทำแล้ว |
| ยกเลิก (ยังดูได้ถึงวันสิ้นสุด) | `DELETE /subscription` | Wallet | `cancelled_at` | B: wallet · F: repository_features (mock) | ทำแล้ว |
| Backend เป็นผู้ตรวจเวลา | | | | | ทำแล้ว |

## 7. ส่วนแบ่งรายได้

| ข้อกำหนด | Endpoint | หน้าจอ | ตาราง | Test | สถานะ |
|---|---|---|---|---|---|
| Admin ตั้งเปอร์เซ็นต์ | `PUT /admin/settings/revenue-share` | Admin (แถบเลื่อน) | `settings.admin_share_percent` | B: revenue (0–100 เท่านั้น, ไม่ใช่ admin → 403) | ทำแล้ว |
| แบ่งตามค่าที่ตั้ง; หนัง admin ได้ทั้งหมด | unlock | — | `unlocked_episodes.creator_share/admin_share` | B: revenue | ทำแล้ว |
| บันทึกส่วนแบ่ง ณ เวลาปลดล็อก; เปลี่ยน % ทีหลังไม่ย้อนหลัง | | | | B: revenue | ทำแล้ว |
| ปัดเศษให้ผลรวมตรง | `creator = floor(coins×(100−p)/100)`, `admin = coins − creator` | | | B: revenue (ราคา 1, 7, 19, 20, 99, 101 ที่ 33%) | ทำแล้ว |
| Creator dashboard แสดงรายได้จาก DB | `GET /creator/earnings` | Creator studio | | B: revenue · D7 | ทำแล้ว |
| Admin sales ตรวจที่มาได้ | `GET /admin/sales` (`per_film`, `recent_unlocks` ระบุผู้ซื้อ/หนัง/ตอน) | Admin | | B: revenue (ผลรวมตรงกับ ledger `coin_transactions`) | ทำแล้ว |
| แยกเงินจำลองกับเหรียญ ไม่บวกรวม | `coins` กับ `simulated_payments` แยกกัน, ไม่มีฟิลด์ `total` | Admin: "Simulated sales (USD)" กับ "Admin share … coins" | | B: revenue · F: api_repository | ทำแล้ว |
| ส่วนแบ่งของค่า subscription | — | — | — | ไม่มีในเอกสารข้อกำหนด จึงไม่แบ่ง | ยังไม่ทำ (ตั้งใจ) |

## 8. Search, Profile และโครงสร้าง

| ข้อกำหนด | สถานะ |
|---|---|
| Search/filter ตาม genre, length, AI tool จากข้อมูลจริง (`GET /films?genre=&ai_tool=&length=&q=`) | ทำแล้ว (B: playback; F: api_repository ส่ง filter ถูกต้อง). ช่วงความยาวนับเวลารวมทุกตอน; รายชื่อ genre/AI tool ในหน้า Upload/Filter ยังมาจากค่าคงที่ในแอปที่ตรงกับ seed ไม่ได้ดึงจาก `/api/lookups` |
| Profile และ dashboard เชื่อม API | ทำแล้ว (`PUT /auth/me`, รายการที่บันทึก/ปลดล็อกจาก API). ยอดวิวและกราฟรายวัน **ถอดออกจากแอปแล้ว** (ไม่มีใน backend): dashboard แสดงจำนวนหนัง ไลก์ และการปลดล็อกแทน; Trending ในหน้า Search เรียงตามยอดถูกใจ |
| MVC ตามเอกสาร | ทำแล้ว: Flutter `models/ views/ controllers/` (+ `data/` repository, `services/`), backend `routes/ controllers/ models/` |
| loading / empty / error / retry | ทำแล้วใน Feed, Search, Wallet, Top up, Admin, Creator studio, หน้า channel, ตัวเล่นวิดีโอ (F: error_states) |
| repository รองรับ async | ทำแล้ว: ส่วน core ทั้งหมดเป็น `Future` และปรับผู้เรียกครบ; ส่วนที่ยังอ่านแบบ sync คือ cache ของ like/save/follow ที่โหลดมากับ API |

## 9. Social และฟีเจอร์เสริม

| ฟีเจอร์ | Backend | Flutter | สถานะ |
|---|---|---|---|
| Like / Save (watchlist) / Follow | `POST/DELETE` พร้อม test (B: social) | `ApiRepository` เรียก API จริง | ทำแล้ว |
| Comment (เรียบ) | `GET/POST/DELETE` (B: social) | โหลด/เพิ่ม/ลบผ่าน API | ทำแล้ว; การตอบกลับซ้อนและ like คอมเมนต์ **ไม่มีใน backend**: ตอบกลับถูกโพสต์เป็นคอมเมนต์ปกติ, like คอมเมนต์เก็บในหน่วยความจำของเครื่องเท่านั้น |
| Report + Admin resolve | `POST /films/:id/reports`, `/admin/reports` (B: social) | ส่งและจัดการผ่าน API | ทำแล้ว |
| Continue watching | ไม่มี | ถอดออกจากแอปแล้ว | **ถอดออก** (ไม่มีตารางใน DB) |
| Notifications | ไม่มี | ถอดออกจากแอปแล้ว (ทั้งกระดิ่งและหน้ารายการ) | **ถอดออก** (ไม่มีตารางใน DB) |
| Forgot password | ไม่มี | ถอดลิงก์ออกจากหน้า Login | **ถอดออก** (ไม่มีตารางใน DB) |
| ภาษาไทย / onboarding / settings | — | ทำในแอป | ไม่ได้เกี่ยวกับ backend |
| ถูกใจ/คอมเมนต์ในหนังจาก catalog | — | like/save ทำในเครื่อง, comment แจ้งว่าไม่รองรับ | ตั้งใจ |

## 10. Verification

ผลรันล่าสุดดูหัวข้อ "ผลทดสอบ" ท้ายเอกสาร. เทียบกับรายการ test ที่เอกสารสั่ง:

| รายการที่ต้องทดสอบ | หลักฐาน |
|---|---|
| Guest ดูฟรีได้ แต่ดูตอนเสียเงินโดยตรงไม่ได้ | B: playback |
| Login/Register/Logout และ role/ownership | B: accounts, auth, endpoints, upload_review · F: api_repository |
| Upload → pending → approve → ปรากฏใน feed | B: upload_review ("upload -> pending -> approve -> appears in the feed") |
| Reject / take down → ไม่ปรากฏ และเปิดเล่นข้ามสิทธิ์ไม่ได้ | B: upload_review |
| เติมเหรียญ → history → unlock → ยอดถูกต้อง | B: wallet |
| เหรียญไม่พอ, unlock ซ้ำ, concurrent unlock | B: wallet |
| Subscription active/expired | B: wallet |
| ส่วนแบ่ง Creator/Admin รวมตรงกับเหรียญที่ใช้ | B: revenue |
| เปิดแอปใหม่แล้วข้อมูลและสิทธิ์ยังอยู่ | B: wallet (login ใหม่), D1 |
| วิดีโอหยุดเมื่อเปลี่ยนหน้า/แท็บ และจัดการ error | D4 + โค้ด; **ไม่มี test อัตโนมัติ** |

### เดโมที่ทำมือ (ทำเมื่อพร้อมสาธิต)

เตรียม: `npm run dev --prefix backend`, `flutter run -d edge --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000/api`, นำคลิปเข้าด้วย `node backend/scripts/import-demo-clips.js <โฟลเดอร์คลิป>` (ดู README)

| # | ขั้นตอน | คาดหวัง |
|---|---|---|
| D1 | login `viewer01 / 6666` → ปิดแท็บ → เปิดใหม่ | เข้า Feed ทันทีโดยไม่ต้อง login |
| D2 | เปิด Feed ตอนที่ 1–2 ของหนังใดก็ได้ | วิดีโอเล่นเอง; ใน DevTools คำขอ `/stream` ตอบ `206` |
| D3 | ตอนที่ 3 (เสียเหรียญ) ตอนยังไม่ login | ขึ้นข้อความ "Log in to keep watching…" และไม่มีคำขอไฟล์วิดีโอ |
| D4 | กดแท็บ Wallet ระหว่างวิดีโอเล่น | วิดีโอหยุด (`video.paused === true`); กลับ Home เล่นต่อ |
| D2b | ลากหรือกดแถบเลื่อนเหนือชื่อหนังระหว่างเล่น | เวลาเล่นกระโดดตามตำแหน่งที่กด |
| D5 | login `admin / 1111` → แท็บ Admin | เห็นคิวรอตรวจ, รายงาน, ยอดขาย, แถบส่วนแบ่ง |
| D6 | Wallet → "+100 free" | ยอดเพิ่ม 100 เหรียญและมีแถวใหม่ใน `coin_transactions` |
| D7 | Creator studio (login `kestrel_studio / 2222`) | รายได้เท่า `creator_share` รวมใน DB |
| D8 | Upload (เลือก 2 ไฟล์ mp4) → admin approve | ปรากฏใน Feed |

## ข้อจำกัดและสิ่งที่ยังไม่ได้ทดสอบ

- ยังไม่ได้ทดสอบบน Android จริงหรืออุปกรณ์เป้าหมาย (ลองบนเว็บ Chromium เท่านั้น)
- คลิปชุดชั่วคราว: ฐานข้อมูลพัฒนา (`shortreel`) ตอนนี้ชี้ 40 ตอนของหนัง seed ไปที่คลิปที่สร้างเอง 12 คลิป (ภาพเคลื่อนไหวกราฟิก 4 วินาที ไม่มีลิขสิทธิ์ของใคร) กับคลิปยาว 24 วินาทีอีก 1 คลิป (ตอน 1 ของ "ShortReel Intro" ไว้ลอง seek) อยู่ใน `backend/uploads/`. ไม่ใช่คลิปของทีม ใช้ `import-demo-clips.js` แทนที่ด้วยคลิปที่ทีมมีสิทธิ์ใช้ได้ เป็นคลิปที่ MediaRecorder ของเบราว์เซอร์เข้ารหัสแบบ fragmented MP4 ซึ่งไม่ใส่ความยาวใน header (สคริปต์จึงคงค่า `duration_sec` เดิมของ seed)
- Android: เพิ่ม `usesCleartextTraffic` เพราะ API เดโมเป็น `http://10.0.2.2:3000`; ไม่มี emulator/อุปกรณ์ในเครื่องนี้ จึงยังไม่ได้ลองบน Android
- Logout เป็น stateless: token ที่ถูกขโมยยังใช้ได้จนหมดอายุ (`JWT_EXPIRES_IN`, ค่าเริ่มต้น 7 วัน) ยกเว้นบัญชีถูกลบ/ลดสิทธิ์ซึ่งมีผลทันที
- ไม่มี rate limiting ของ login
- ไม่มีโฟลเดอร์ migration แล้ว: ฐาน `shortreel` ที่ใช้อยู่ถูกเพิ่มคอลัมน์ให้ตรงกับ `shortreel.sql` แล้ว. `shortreel.sql` ยัง `DROP DATABASE` ตามเดิม ห้าม import ทับข้อมูลที่ต้องการเก็บ
- งานอ่านและตัดสินใจเรื่อง catalog bug เดิม (ดูหัวข้อ 2)

## ผลทดสอบ (รันล่าสุด)

| คำสั่ง | ผล |
|---|---|
| `npm test --prefix backend` | 166 test ผ่าน 0 ล้มเหลว (integration บน MariaDB จริง) |
| `flutter analyze` (mobile) | No issues found |
| `flutter test` (mobile) | 253 test ผ่าน 0 ล้มเหลว |

ก่อนเริ่มงานรอบนี้: backend 84 test (ทั้งหมดเป็น stub 501), `flutter analyze` สะอาด, `flutter test` 230 ผ่าน.

**test เดิมที่ถูกแก้ และเหตุผล (ไม่ได้ลด assertion):**

- `backend/test/endpoints.test.js` เดิมยืนยันว่าทุก endpoint ตอบ 501; ตอนนี้ endpoint ทำงานจริง จึงเขียนใหม่เป็นตาราง role ของทุก endpoint (ไม่มี token → 401, role ไม่พอ → 403, role ที่อนุญาตต้องไม่ใช่ 401/403/501) ซึ่งเข้มกว่าเดิม
- `backend/test/auth.test.js`: เพิ่ม fake pool เพราะ `requireAuth` ตอนนี้อ่าน role จาก DB และเพิ่ม 2 test (token ที่อ้าง admin แต่ DB เป็น viewer → 403, บัญชีถูกลบ → 401)
- Flutter: เปลี่ยนเป็น `await` ตามที่ repository เป็น async, `topUp(coins:)` → `demoTopUp`, `episodePrices` → `episodes: [EpisodeDraft]`, และหน้า Upload ต้องกด "Choose episode videos" ก่อนจึงมีการ์ดราคา (เดิมมีการ์ด 2 ใบโดยไม่มีไฟล์) ทุก assertion เดิมยังอยู่
- วิธีทดสอบที่ปรับ: widget test ใช้ตัวเลือกวิดีโอปลอม (`pickVideos`) แทนหน้าต่างเลือกไฟล์ของระบบ

**ที่ลองมือจริง (Chromium ในแอป, backend ต่อ MariaDB `shortreel`):** login → ปิดแล้วเปิดใหม่ยังอยู่ → logout แล้วเปิดใหม่ต้อง login ใหม่ → ฟีดจาก API → วิดีโอเล่นจริง (12 คลิปทดสอบ 4 วินาที, `/stream` ตอบ 206) → ตอนที่ต้องจ่ายขึ้นข้อความ login/ปลดล็อก → Wallet (ยอดและประวัติจาก DB, ปุ่ม +100 เขียนลง `coin_transactions` จริง) → Profile (watchlist จาก DB) → Admin (คิว, รายงาน, ยอดขาย) → วิดีโอหยุดเมื่อสลับไปแท็บ Wallet. ข้อมูลที่เปลี่ยนจากการลองถูกคืนกลับ (ยอดของ `viewer01` = 80).

**ไม่ได้ลองมือ:** การเลือกไฟล์ด้วยหน้าต่างของระบบ, upload จากหน้าจอจริงจนถึงฟีด (ครอบคลุมด้วย test ของ backend และ test ของ repository), Android, บั๊ก catalog/player เดิม
