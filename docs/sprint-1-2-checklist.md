# Sprint 1–2 checklist: ShortReel

อ้างอิงเอกสารต้นฉบับ `MONTHAKAN KAEWSAI - Project 2 (3).pdf` หน้า 3–6 (ภาพรวมและตารางแบ่งงาน Sprint 1 หน้า 5, Sprint 2 หน้า 6) รวมตารางหน้า 6 ตามที่กำหนด จึงตรวจ wallet/unlock, subscription, upload/review และรายได้/ส่วนแบ่งใน Sprint 2 ด้วย

**สถานะ:** `ผ่าน` = มีหลักฐานตรงกับงานนั้น · `ยังต้องแก้` · `ยังไม่มีหลักฐาน` · `รอสิ่งภายนอก` (ต้องการผู้ใช้/อุปกรณ์/บริการภายนอก) · `ไม่อยู่ใน Sprint 1–2`

**ผู้รับผิดชอบตามแผน** คือเลขนักศึกษาในตารางของเอกสาร ใช้อ้างอิงงานเท่านั้น ไม่ได้แปลว่าคนนั้นทำเสร็จเอง (แถว 6731501102 และ 6731501076 ของ Sprint 1 ในเอกสารต้นฉบับมีข้อความเหมือนกัน)

**ผลทดสอบรอบนี้** (รายละเอียดคำสั่งใน [`sprint-1-2-results.md`](sprint-1-2-results.md)): backend 179/179 · Flutter 278/278 · `flutter analyze` ไม่มีปัญหา · Postman collection 116 คำขอ 168 assertions ผ่านหมด (ตัวรันในโฟลเดอร์ `docs/postman/` ไม่ใช่ Newman) · `flutter build web` สำเร็จและลองบนเว็บ (Chromium) จริง · ไม่ได้ลอง Android

คำย่อ: `B:` = `backend/test/…` · `F:` = `mobile/test/…` · `PM` = Postman collection

---

## Sprint 1

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 1 | ยืนยันไอเดีย 3 บทบาท (Viewer/Creator/Admin) และรายการฟีเจอร์ MVP, Guest preview, ขอบเขต social | 6731501103 | `README.md` (บทบาท, ตารางสถานะ), `docs/api.md` (ระดับการเข้าถึง), `docs/screens-index.md` (ตารางสิทธิ์ต่อหน้า), `docs/acceptance-checklist.md` | ไม่มีเอกสาร "ปัญหาที่แอปแก้/กลุ่มผู้ใช้" แยกหัวข้อ (ย่อไว้ใน README บรรทัดแรก) | อ่านเอกสาร เทียบกับตาราง role ที่ทดสอบอัตโนมัติ | ตาราง role ทุก endpoint (48 รายการ) ผ่าน B: endpoints; social: ทำ like/บันทึก/ติดตาม/คอมเมนต์เรียบ/report ส่วน reply ซ้อน, like คอมเมนต์, แจ้งเตือน เลื่อนและระบุไว้ใน README และ UI | ผ่าน |
| 1 | ออกแบบตารางหลัก users, films, episodes, coin_transactions, unlocked_episodes (+ review status, ราคาฟรี/เหรียญ) และ ER diagram | 6731501100 | `backend/db/shortreel.sql`, `docs/er-diagram.md` (Mermaid), migrations `001`,`002` (ลบแล้ว) | ไม่มีภาพ export ของ ER (Mermaid แสดงใน GitHub/VS Code) | เทียบ ER กับ schema; รัน schema ใน test ทุกไฟล์ | PK/FK/UNIQUE(user_id,episode_id)/enum review ตรงกับ `shortreel.sql`; B: ทุกไฟล์สร้างฐาน `_test` จาก schema สำเร็จ | ผ่าน |
| 1 | กติกา wallet / transaction / unlock / ส่วนแบ่งรายได้ และ acceptance cases (ยอดคงเหลือ, ซื้อซ้ำ) | 6731501102, 6731501076 | `docs/er-diagram.md` (กติกา + ตัวอย่าง + acceptance cases), `docs/api.md` (กติกา unlock 6 ข้อ) | – | ตาราง acceptance cases ชี้ test จริง | ทุกกรณีมี test: wallet.test.js (ซื้อซ้ำ, 402, parallel 5 คำขอ), sprint12_regressions (ลบ↔ซื้อ 2 ลำดับ, role change, Plus 5 ครั้ง) | ผ่าน |
| 1 | แบบหน้าจอ Login/Register, Feed/Player, Search, Wallet, Profile, Upload, Admin review, Creator dashboard, Admin sales | 6731501078, 103, 100, 102/076, 125 | `docs/ui-screens/` (30 ภาพของแอปจริง), `docs/screens-index.md` | Admin sales ไม่มีภาพแยก (อยู่ในการ์ดสถิติหน้า Admin ภาพ 28) | เทียบดัชนีกับไฟล์ view จริง | ทุกหน้ามีภาพ + ไฟล์ view + บทบาทที่เข้าถึง ยกเว้นข้อยกเว้นข้างบน | ผ่าน |
| 1 | โครง Flutter MVC, theme, shared widgets, navigation | 6731501125 | `mobile/lib/{models,views,controllers,data,theme,widgets}`, `views/app_shell.dart` | – | `flutter analyze`; F: app_shell (tab ตาม role) | analyze สะอาด; ใช้งานได้จริงบนเว็บ (ลอง Guest → สมัคร → Wallet → Feed) | ผ่าน |
| 1 | Repo + environment: README setup, `.env.example`, DB, migration, backend/mobile run, health check | 6731501078 | `README.md`, `backend/.env.example`, `GET /api/health` | – | ทำตาม README กับฐานทดสอบ: สร้างฐานจาก schema, import คลิป, รัน server พอร์ต 3100, health | `{"status":"ok","db":"up"}`; migration 001+002 รันซ้ำบนสำเนา schema เดิมไม่เสียข้อมูล (`docs/evidence/migration-run.txt`) | ผ่าน |
| 1 | GitHub repo และ branch rules | 6731501078 | remote `origin` = `FrameNoname/Short-Reel-App` | branch `main` ยัง **ไม่ protected** | อ่านอย่างเดียว: `git ls-remote` (branches Frame-dev, develop, main ที่ `58ca1da`); GitHub API `branches/main` → `protected:false` (ไม่มี `gh`/สิทธิ์เจ้าของ จึงอ่านรายละเอียด rule ไม่ได้) | มี repo + 3 branch; ยังไม่มี branch rule. **ข้อเสนอ (ยังไม่ได้ตั้ง):** protect `main` และ `develop`: ต้องผ่าน pull request, ต้องมี approval ≥ 1, ต้องผ่าน CI (backend test + `flutter analyze/test`), ห้าม force-push/ลบ branch, ทำงานบน `Frame-dev`/feature branch. ผู้ใช้ต้องอนุญาตหรือตั้งเอง | รอสิ่งภายนอก |
| 1 | คลิปตัวอย่าง (free/paid preview, ทดสอบ player) พร้อมแหล่งที่มา/สิทธิ์ใช้และวิธีนำเข้า | 6731501125 | `backend/scripts/import-demo-clips.js`, README หัวข้อคลิปเดโม; `backend/uploads/` (ถูก ignore) | ชุดสุดท้าย 10–20 คลิปของทีมเป็นงาน Sprint 4; คลิปปัจจุบัน 12 + 1 คลิปยาวเป็นคลิปที่สร้างเองชั่วคราว (ไม่มีไฟล์ลิขสิทธิ์ภายนอก, ไม่มี ffmpeg ในเครื่องจึงตรวจ codec ด้วย probe ของ backend: avc1 ทุกไฟล์) | `inspectMp4` ทุกไฟล์ valid; เล่นจริงบนเว็บ: `<video>` เดียว readyState 4 เวลาเดินหน้า; ตอนฟรีเล่นได้ ตอนเสียเงิน guest ถูกถามให้ login; script ใช้ชื่อไฟล์ที่มี hash ของเนื้อหา ไม่ชนกัน (B: import_clips) | ผ่าน (สำหรับเดโมปัจจุบัน; ชุดสุดท้ายอยู่นอก Sprint 1–2) |
| 1 | ตกลง API contract + รูปแบบ error + Flutter API client | 6731501103 | `docs/api.md`, `mobile/lib/services/api_client.dart`, `ApiException` | – | B: ทุก error คืน `{error:{code,message}}`; F: api_client_test | อ่าน `docs/api.md` ที่แก้ให้ตรง routes ปัจจุบัน; ตาราง endpoint ใน test ตรวจจำนวนเทียบกับไฟล์ routes อัตโนมัติ | ผ่าน |
| 1 | Postman collection + environment ไม่มี secret, ตัวแปรได้มาอย่างไร, ขั้นตอนรัน + expected result (รวม multipart) | 6731501103 | `docs/postman/*` | Newman ยังไม่ได้รัน (ไม่ได้ติดตั้ง) | รัน collection ด้วยตัวรันของโปรเจกต์กับ API+ฐานทดสอบ `shortreel_e2e_test` | 116 คำขอ 168 assertions ผ่านหมด; report ไม่มี token/รหัสผ่าน; ตัวแปร id ได้จาก response | ผ่าน (รันด้วยตัวรันของโปรเจกต์) |
| 1 | รัน collection ด้วย Newman | – | `newman run …` (คำสั่งใน `docs/postman/README.md`) | ต้องติดตั้ง `npm i -g newman` (ดาวน์โหลดแพ็กเกจ ยังไม่ได้ขออนุญาต) | – | ยังไม่ได้รัน | รอสิ่งภายนอก |

## Sprint 2 — A. Feed / Search / Episodes / Protected playback / Review (6731501100)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | API feed/search/filter/episode detail กับ DB จริง; public feed เฉพาะ approved; guest ดูตอนฟรีได้ ตอนเสียเงินไม่ได้ | 6731501100 | `GET /films`, `/films/:id`, `/episodes/:id` | – | B: playback, upload_review; PM โฟลเดอร์ 1, 3 | feed ทุกเรื่อง approved; ตอนเสียเงิน guest `stream_url:null` และ `/stream` 401; pending 404/ไม่อยู่ใน feed | ผ่าน |
| 2 | List ไม่ตัดข้อมูลเงียบ ๆ (pagination) | 6731501100 | `GET /films` `has_more` | – | B: sprint12_regressions · F: session_guard (3 หน้าต่อกัน) | ฟีดโหลดครบทุกหน้า (สูงสุด 20 หน้า × 100) | ผ่าน |
| 2 | ตรวจ role/ownership ที่ backend ไม่พึ่งการซ่อนปุ่ม | 6731501100 | `requireRole`, `loadOwnedFilm`, `loadOwnedEpisode` | – | B: endpoints, accounts, upload_review; PM โฟลเดอร์ 2–3 | viewer/creator คนอื่นถูก 403; creator คนอื่นแก้/ลบ/อัปโหลดให้หนังที่ไม่ใช่ของตน 403/404 | ผ่าน |
| 2 | stream เฉพาะผู้มีสิทธิ์; ข้ามผ่าน URL/โฟลเดอร์ uploads ไม่ได้ | 6731501100 | `GET /episodes/:id/stream` (token สั้น + ตรวจใหม่ทุกคำขอ), ไม่มี `express.static` | – | B: playback | `/uploads/...` 404; path `../` ออกนอกโฟลเดอร์ไม่ได้; take down แล้ว link เดิมใช้ไม่ได้ (PM โฟลเดอร์ 8) | ผ่าน |
| 2 | Admin approve/reject/take down ตาม transition; หนังที่ยังไม่ผ่านไม่หลุด public | 6731501100 | `POST /admin/films/:id/review` | – | B: upload_review; PM (pending→taken_down 409, reject ไม่มี note 400) | ผ่านทั้ง API และปุ่มในแอป (คิว pending แสดงเฉพาะ Approve/Reject, F: sprint12_flows) | ผ่าน |
| 2 | หน้า Feed/Player เกิน 50% + flow ฟรีที่เชื่อม API และเล่นไฟล์จริง | 6731501100 | `views/feed/*`, `views/player/player_view.dart` | ลองบนอุปกรณ์จริงไม่ได้ | ลองจริงบนเว็บ Chromium + ตารางใน `docs/screens-index.md`; Admin approve ผ่านหน้าจอจริงแล้วตรวจฐานข้อมูล/feed | เล่นวิดีโอจริงผ่าน `/stream` (`<video>` เดียว readyState 4); องค์ประกอบ/ปฏิสัมพันธ์ที่ทำงานจริงและที่ยังค้างแยกเป็นรายการใน `docs/screens-index.md` (ไม่ได้คำนวณเป็นเปอร์เซ็นต์) | ผ่าน (บนเว็บ) |
| 2 | เล่นครั้งละหนึ่งรายการ (ปัดช้า เปลี่ยนแท็บ เปิดหน้าซ้อน เปลี่ยนผู้ใช้) | 6731501100 | `FeedView` ส่ง `active` → `FilmPage` → `EpisodeVideo` | ไม่ได้ลองปัดช้าจริงด้วยมือบนอุปกรณ์; บนเว็บเห็น `<video>` 1 ตัวเสมอ | F: episode_video_test (platform ปลอมนับ create/dispose/play: หน้า inactive ไม่โหลดเลย, ปัดออก → dispose, max เล่นพร้อมกัน 1, initialize ล้มเหลว/ออกกลางคัน → dispose ครบ) | 5/5 ผ่าน; ผู้ใช้เปลี่ยน/logout → หน้าที่ซ้อนถูกปิดทั้งหมด (F: sprint12_flows) | ผ่าน (widget test + เว็บ) |
| 2 | ตอนเลขไม่ต่อเนื่อง Player ไม่ไปตอนที่ไม่มี | 6731501100 | `FeedController.episodeAfter`, `EpisodeVideo` (fall-forward) | – | F: episode_video_test | เลขตอน [3,5,8]: ขอ 1 → ไปตอน 3; ถัดจาก 3 → 5 | ผ่าน |

## Sprint 2 — B. Auth / Roles / Subscription (6731501102)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | register/login/logout contract, argon2id, JWT, secure storage | 6731501102 | `/auth/*`, `flutter_secure_storage` | Keystore/Keychain บนเครื่องจริงไม่ได้ลอง | B: accounts, auth; PM โฟลเดอร์ 2; ลองจริงบนเว็บ (สมัคร `uiviewer1` แล้วเช็กฐานข้อมูล `$argon2id$`) | ผ่านทั้งหมดบน API/เว็บ; secure storage บนอุปกรณ์ → รอสิ่งภายนอก | ผ่าน (API/เว็บ) · secure storage บนอุปกรณ์: รอสิ่งภายนอก |
| 2 | สมัครเป็น Admin จาก client ไม่ได้; ตรวจ role/ownership ที่ server | 6731501102 | `role:"admin"` → 403 | – | B: accounts; PM | 403 ทั้งใน test และ collection | ผ่าน |
| 2 | Password policy ตรงกันระหว่าง UI/API และไม่ trim เงียบ ๆ; seed เดิมยังเข้าได้ | 6731501102 | `auth.js rawPassword`, `register_view.dart` | – | B: accounts (123456, abcdefgh, ช่องว่างล้วน → 400; `'  pass 1234  '` login ต้องตรงทุกตัวอักษร); login seed `1111`/`6666` ผ่าน | ผ่าน | ผ่าน |
| 2 | Restore session, token invalid/expired, logout, สลับบัญชีไม่ทิ้งข้อมูลข้ามผู้ใช้ | 6731501102 | `ApiClient` (session generation), `AuthController` (epoch) | – | F: session_guard_test — top-up ของ A กลับมาหลัง logout/login B ไม่แก้ยอด B; profile ของ A ไม่ทำให้ A กลับมา; restore ช้าไม่ทับ B; 401 ของ A ไม่ลบ token B; 401 ของ token ปัจจุบันยัง logout | 10/10 ผ่าน | ผ่าน |
| 2 | Session หมดอายุแล้วหน้าที่ต้อง login ไม่พัง | 6731501102 | `main.dart navigatorKey`, `creator_dashboard_view.dart`, `notifications_view.dart` | – | F: sprint12_flows — `sessionExpired()` จากหน้า Creator studio: ไม่มี exception, กลับหน้า Login, ไม่มี route ค้าง | ผ่าน | ผ่าน |
| 2 | Subscription API start/end date, active/expired, ซื้อซ้ำไม่ทับ | 6731501102 | `/subscription`, `models/subscriptions.js` | – | B: wallet (active/expired/cancel), sprint12_regressions (5 ครั้ง รวมพร้อมกัน ต่อเนื่อง ไม่ทับ); PM โฟลเดอร์ 5 | ช่วงวัน inclusive, แผนใหม่เริ่มวันถัดจาก `paid_through` | ผ่าน |
| 2 | หน้า Login/Register และ Subscription เกิน 50%; ข้อความ/validation ตรง API; วันที่ตรง server | 6731501102 | `login_view`, `register_view`, `plus_view`, การ์ดใน `wallet_view` | ไม่มีการต่ออัตโนมัติ (ระบุใน UI ตรง ๆ) | F: gap_flows (cancel แสดงวันสิ้นสุด), language_test; Plus แสดง `paid_through`/วันที่เหลือจาก server | ผ่าน | ผ่าน |
| 2 | logout ล้าง token | 6731501102 | `AuthController.logout`, `clearSession` | ไม่มีการเพิกถอน token ฝั่งเซิร์ฟเวอร์ (ไม่บังคับ) | F: api_repository | ล้าง token แม้เซิร์ฟเวอร์ล่ม | ผ่าน |

## Sprint 2 — C. Wallet / Transactions / Atomic unlock / Revenue / Admin sales (6731501076)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | Demo +100, coin packs จำลอง, ยอดคงเหลือและประวัติจาก DB; backend กำหนดราคา | 6731501076 | `/wallet`, `/wallet/transactions`, `/wallet/topup`, `/coin-packs` | – | B: wallet; PM โฟลเดอร์ 4; ลองจริงบนเว็บ (demo +100 → ฐานข้อมูล balance 100 + ledger topup 100) | client ส่งจำนวนเหรียญเองไม่ได้ (400) | ผ่าน |
| 2 | หัก/บันทึก/ให้สิทธิ์ใน transaction เดียว; ซื้อซ้ำไม่หักซ้ำ; ไม่ติดลบ; concurrent ไม่ทำให้เสียสิทธิ์ | 6731501076 | `models/wallet.js unlock` (ล็อก film S → user X → episode S) | – | B: wallet (parallel 5 → หักครั้งเดียว; parallel ต่างตอนไม่เกินยอด), sprint12_regressions (ลบ↔ซื้อ: 2 ลำดับแบบกำหนดแน่นอนด้วยการถือ lock + loop 12 รอบ); ลองจริงบนเว็บ (unlock → balance 80, ledger −20, unlocked 1) | ทั้งสองลำดับได้ผลตามกติกา; ทดสอบกับโค้ดก่อนแก้: test ใหม่ล้มเหลว | ผ่าน |
| 2 | บันทึกส่วนแบ่ง creator/admin ตอนปลดล็อก; หนัง admin ให้ admin ทั้งหมด; เปลี่ยน % หรือ role ภายหลังไม่ตีความรายได้ย้อนหลังใหม่ | 6731501076 | `unlocked_episodes.creator_share/admin_share/owner_is_admin`, `models/creator.js`, migration `002` | แถวที่มีมาก่อน migration ใช้ role ปัจจุบันเป็นค่าตั้งต้นครั้งเดียว (ไม่มีข้อมูลอดีตให้ใช้) | B: revenue, sprint12_regressions; PM โฟลเดอร์ 6 (21 → 21 หลังเปลี่ยน % และ role) | ผ่าน | ผ่าน |
| 2 | Share-setting และ Admin sales API; แยกหน่วยเหรียญกับเงินจำลอง | 6731501076 | `/admin/sales`, `/admin/settings/revenue-share` | – | B: revenue; PM | `coins` และ `simulated_payments` แยกกัน ผลรวมเหรียญตรง | ผ่าน |
| 2 | Wallet / Admin sales views เกิน 50% แสดงข้อมูลจริงและป้ายจ่ายเงินจำลอง; Wallet โหลดยอดปัจจุบัน | 6731501076 | `wallet_view`, `top_up_view`, `admin_view` | – | F: wallet_history, session_guard (โหลดอ่าน `GET /wallet`; โหลดซ้อนไม่ทับ); เว็บ | ป้าย DEMO/"Payments are simulated"; ประวัติดึงทุกหน้า | ผ่าน |
| 2 | รายการที่ซื้อแล้วไม่หายเมื่อมี pagination | 6731501076 | `GET /wallet/unlocked`, `ApiRepository.refreshLibrary` | – | B + F: unlock เก่าอยู่หลัง topup > 50 รายการยังอยู่ในรายการ | ผ่าน | ผ่าน |

## Sprint 2 — D. Database / Upload / Film CRUD / Review UI (6731501103)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | Pool, schema, constraints, seed, migration | 6731501103 | `config/db.js`, `shortreel.sql`, `migrations/001–002` (ลบแล้ว) | – | migration บนสำเนา schema เดิมรัน 001+002 สองรอบ: จำนวนแถวเท่าเดิม, snapshot ถูกเติมเฉพาะแถว NULL | `docs/evidence/migration-run.txt` | ผ่าน |
| 2 | Creator สร้าง/แก้/ลบหนังของตน + AI label, credits, ราคาต่อตอน | 6731501103 | `/films*`, `/episodes/:id` | เพิ่ม/ลบตอนรายตอนของหนังเดิมจากแอปยังไม่มี UI (backend มี route และ test; อยู่ในรายการ "งานที่แยกไว้" ไม่ได้อยู่ในตารางหน้า 6) | B: upload_review; PM โฟลเดอร์ 3, 7 | ผ่าน | ผ่าน |
| 2 | Multer: ตรวจชนิด/ขนาด; จัดการ DB/filesystem failure ไม่ทำไฟล์ที่ commit แล้วสูญหาย | 6731501103 | `middleware/upload.js`, `services/media.js inspectMp4`, `addEpisode` | ไม่ได้ลอง codec อื่นนอกรายการ avc1/avc3/hvc1/hev1/av01/vp09/mp4v (ไม่มี ffmpeg ในเครื่องให้สร้างไฟล์จริงหลาย codec; fixture ของ test เป็นโครงกล่องที่สร้างเอง) | B: sprint12_regressions — MP4 มีแต่ header, ตัดท้าย, ไม่มี video track, codec ไม่รองรับ → 400 และไฟล์ถูกลบ; fragmented → 201; error หลัง commit → ไฟล์ยังอยู่; B: upload (ใหญ่เกิน → 413) | ผ่าน; ทดสอบกับโค้ดก่อนแก้: ล้มเหลว | ผ่าน |
| 2 | รักษาข้อมูลการซื้อเมื่อลบ/แก้ไข (policy + race) | 6731501103 | ลบตอน/หนังที่มีคนจ่าย → 409; แก้ราคาไม่กระทบผู้ซื้อ | – | B: upload_review, sprint12_regressions; PM | ผ่าน | ผ่าน |
| 2 | แก้ film หลาย field แบบ atomic | 6731501103 | `PUT /films/:id` + `episode_prices`, `UploadController.update` | – | B: sprint12_regressions (genre ผิด / ตอนของหนังอื่น / ราคา 501 → ไม่มีอะไรเปลี่ยน); PM | ผ่าน | ผ่าน |
| 2 | ราคาตรงกัน UI/API (≤ 500) และ validation ความยาวชื่อ/prompt | 6731501103 | `upload_view.dart` `_maxPrice=500`, `_maxTitle=100`, `_maxPrompt=500` | – | F: sprint12_flows (501 ถูกบล็อก, 500 ผ่าน); B: price 501 → 400 | ผ่าน | ผ่าน |
| 2 | Upload / Admin review views เกิน 50% พร้อม loading/error, ส่งข้อมูลตรง API | 6731501103 | `upload_view`, `admin_view` | native file picker ลองบนอุปกรณ์จริงไม่ได้ (ส่วนเพิ่ม preview วิดีโอ/จัดการ role ในหน้า Admin อยู่ในรายการ "งานที่แยกไว้" ไม่ได้อยู่ในตารางหน้า 6) | F: upload_price, sprint12_flows (โหลดตอนล้ม → error + Retry + ปิด Save); ตรวจขนาดไฟล์จาก metadata ก่อนอ่าน (`checkVideoSizes`) | ผ่านบนเว็บ/widget test; picker จริง → รอสิ่งภายนอก | ผ่าน (ไม่รวม native picker: รอสิ่งภายนอก) |
| 2 | Creator dashboard refresh หลัง upload | 6731501103 | `creator_dashboard_view.dart` | – | F: sprint12_flows (อัปโหลดจากปุ่ม + Upload แล้วกลับมาเห็นหนังใหม่); ถอดการแก้ → test ล้มเหลว | ผ่าน | ผ่าน |

## Sprint 2 — E. Profile / Creator earnings / API verification (6731501078)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | Profile และ Creator earnings API, บังคับสิทธิ์ | 6731501078 | `/auth/me`, `/creator/films`, `/creator/earnings` | – | B: accounts, revenue; PM | viewer เปิด earnings → 403 | ผ่าน |
| 2 | ยอดรายได้ตรงกับรายการซื้อและส่วนแบ่งที่บันทึก | 6731501078 | `models/creator.js` | – | B: revenue, sprint12_regressions; PM (21 จาก 30 เหรียญ) | ผ่าน | ผ่าน |
| 2 | Profile / Creator dashboard เกิน 50%; ไม่แสดงข้อมูลผิดบัญชี/ค่าจำลองโดยไม่แจ้ง | 6731501078 | `profile_view`, `creator_dashboard_view`, `creator_stats` | Following ของคนอื่นไม่มี API (ไม่แสดงแทน); ยอดวิว/กราฟรายวันไม่มี backend | F: repository_features, creator_stats, session_guard | ไม่แสดงข้อมูลของ viewer แทนของคนอื่น; saved list ตามหัวใจทันที; Profile โหลดซ้ำเมื่อกลับเข้าแท็บ | ผ่าน |
| 2 | Collection ครอบคลุม positive/negative ทุก endpoint ใน scope ที่เปิดใช้ | 6731501078 | `docs/postman/` | ไม่ครอบคลุมใน collection (มี test backend): concurrent unlock, subscription หมดอายุจริง, take down ระหว่างซื้อ; catalog ปิดไว้ | ตารางใน README ของ collection | 116 คำขอ ผ่านทั้งหมด | ผ่าน (Newman: รอสิ่งภายนอก) |

## Sprint 2 — F. Theme / Navigation / Search / Optional social (6731501125)

| Sprint | งานตามเอกสาร | ผู้รับผิดชอบตามแผน | ไฟล์ / endpoint | สิ่งที่ยังขาด | วิธีตรวจ | ผลจริง | สถานะ |
|---|---|---|---|---|---|---|---|
| 2 | Theme, navigation, shared states, Search view เกิน 50% | 6731501125 | `theme/app_theme.dart`, `widgets/*`, `views/search/*` | – | F: app_shell, search_extras | ผ่าน | ผ่าน |
| 2 | Search/filter ตรงคำขอปัจจุบัน ไม่ให้คำตอบเก่าทับ (ค้นหา, แท็บ, จำนวนตัวกรอง) | 6731501125 | `FilmSearchController` (request id), `FeedController` (load id), `filters_view._refreshCount` | จำนวนตัวกรองในหน้า Filters (`_refreshCount`) ไม่มี test เฉพาะ | F: request_race_test (คำตอบเก่ามาทีหลังไม่ทับ; error เก่าไม่ทับคำตอบใหม่; feed คงแท็บที่เลือกล่าสุด) | 3/3 ผ่าน | ผ่าน (ยกเว้น `_refreshCount`: ยังไม่มีหลักฐาน) |
| 2 | Social (like/บันทึก/คอมเมนต์/ติดตาม/รายงาน) ที่ทีมเลือก | 6731501125 | `social.js`, `views/feed/*` | reply/like คอมเมนต์/แจ้งเตือน ไม่มี backend (ระบุใน UI/README) | B: social; PM โฟลเดอร์ 7 | ผ่าน | ผ่าน |
| 2 | Catalog / Series Jeen ไม่กระทบ flow หลัก | – | `/api/catalog/*` | บัญชีที่ลบแล้วยังใช้ quota catalog ได้จน token หมดอายุ; feed หลักยังรอ catalog ที่เปิดอยู่ | ปิดเป็นค่าเริ่มต้น (`CATALOG` ไม่เปิด, ไม่มี API key → 503) | ทุก test รันโดยปิด catalog; flow หลักไม่แตะ | ไม่อยู่ใน Sprint 1–2 (ปิดไว้ ไม่กระทบ core) |

## บั๊ก 16 ข้อของรอบนี้

| # | บั๊ก | แก้ที่ | หลักฐาน | สถานะ |
|---|---|---|---|---|
| 1 | ลบตอนชนกับ unlock แล้วหักเหรียญสิทธิ์หาย | `models/wallet.js` (ลำดับ lock) | B: sprint12_regressions ×3 (ล้มเหลวบนโค้ดเดิม) | ผ่าน |
| 2 | error หลัง commit upload ลบไฟล์ที่ DB อ้างอิง | `controllers/films.js addEpisode` | B: sprint12_regressions | ผ่าน |
| 3 | response ของบัญชีเก่าเปลี่ยนบัญชีใหม่ | `ApiClient` generation, `AuthController` epoch, `WalletController` | F: session_guard_test | ผ่าน |
| 4 | 401 เก่าล้าง token ใหม่; session หมดอายุ → หน้าที่ต้อง login พัง | `ApiClient`, `main.dart`, views | F: session_guard_test, sprint12_flows | ผ่าน |
| 5 | PageView เล่นวิดีโอพร้อมกัน; controller รั่ว | `feed_view`, `film_page`, `episode_video` | F: episode_video_test | ผ่าน |
| 6 | Subscription ต่อซ้ำทับ + วันไม่ตรง server | `models/subscriptions.js`, `plus_view`, `wallet_view` | B: sprint12_regressions · F: language/gap_flows | ผ่าน |
| 7 | รายได้ย้อนหลังเปลี่ยนเมื่อเปลี่ยน role | `unlocked_episodes.owner_is_admin`, `models/creator.js`, migration `002` | B: sprint12_regressions, PM | ผ่าน |
| 8 | Wallet refresh ไม่อ่านยอด; library/Profile ไม่สอดคล้อง | `GET /wallet`, `/wallet/unlocked`, `toggleSave` | F: session_guard_test | ผ่าน (Profile: `OnActivated` โหลดรายการใหม่ทุกครั้งที่กลับเข้าแท็บ + `toggleSave`/`unlock` อัปเดตแคชทันที; F: sprint12_flows ล้มเหลวเมื่อถอดการแก้) |
| 9 | Search/Feed/Filter race + pagination | request id ใน controller; `has_more` | F: session_guard (pagination), request_race_test (race) | ผ่าน (pagination + race ของ search/feed: F: request_race_test) |
| 10 | ราคา/validation upload และ register ไม่ตรง; ห้าม trim; seed เข้าได้ | `upload_view`, `auth.js` | B: accounts · F: sprint12_flows | ผ่าน |
| 11 | Edit film ไม่ atomic; โหลดตอนไม่มี loading/error/retry | `PUT /films/:id` + `episode_prices`; `upload_view` | B: sprint12_regressions · F: sprint12_flows | ผ่าน |
| 12 | เลขตอนไม่ต่อเนื่อง Player ไปตอนที่ไม่มี | `FeedController.episodeAfter`, `EpisodeVideo` | F: episode_video_test | ผ่าน |
| 13 | รับไฟล์ที่ไม่มี media จริง; อ่านไฟล์ใหญ่เข้า memory ก่อนตรวจ | `media.inspectMp4`; `video_picker.dart checkVideoSizes` | B: sprint12_regressions; ตรวจขนาดจาก metadata ก่อน `readAsBytes` (F: request_race_test ทดสอบ `checkVideoSizes`; การเรียกกับ file picker จริงไม่ได้ทดสอบ) | ผ่าน |
| 14 | ปุ่ม Admin ส่ง transition ที่ไม่อนุญาต; dashboard ไม่ refresh | `admin_view`, `creator_dashboard_view` | F: sprint12_flows (admin); dashboard ไม่มี test | ผ่าน (admin: F: sprint12_flows; dashboard refresh: F: sprint12_flows ล้มเหลวเมื่อถอดการแก้) |
| 15 | import-demo-clips ชื่อไทยชนกัน | `scripts/import-demo-clips.js storedName` | B: import_clips | ผ่าน |
| 16 | endpoint test ยอมให้ 500 | `endpoints.test.js` (status/body ต่อรายการ, reject 5xx, จำนวนตรวจกับ routes) | B: endpoints | ผ่าน |

## งานที่แยกไว้ (ไม่ปิดใน Sprint 1–2 นี้)

ชุดคลิปสุดท้าย 10–20 คลิปและรายงาน/สไลด์ (Sprint 4) · แจ้งเตือน/forgot password/ยอดวิว/กราฟรายวัน/reply ซ้อน/like คอมเมนต์ (ไม่มีใน backend, ระบุตรง ๆ ใน UI) · UI เพิ่ม/ลบตอนรายตอน, preview วิดีโอและจัดการ role ในหน้า Admin · persistence ของ settings/onboarding · lookups จาก `/lookups` ในฟอร์ม Upload/Filters (ยังใช้รายการในแอป) · Catalog quota auth · งาน production hardening (rate limit, HTTPS, DB user แยก, backup, graceful shutdown) · เดโมบน Android
