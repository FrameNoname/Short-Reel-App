# ดัชนีหน้าจอ: แบบ ↔ ไฟล์ view ↔ บทบาทที่เข้าถึง

ภาพในโฟลเดอร์ [`docs/ui-screens/`](ui-screens/) เป็นภาพหน้าจอของแอปจริง (ไม่ใช่แบบวาดใหม่) ใช้เป็นหลักฐานของ Sprint 1 (แบบ/โครง Flutter) และ Sprint 2 (หน้าจอที่ทำงานกับ API)

โครงสร้าง MVC: `mobile/lib/models/` · `views/` (หน้าจอ) · `controllers/` (`ChangeNotifier` + Provider) · `data/` (repository: `ApiRepository` ใช้จริง, `MockRepository` อยู่ใน `mobile/test/support/` ใช้ใน test) · `theme/app_theme.dart` (สี/ฟอนต์เดียวทั้งแอป) · `widgets/` (ปุ่ม การ์ด Loading/Error/Empty ที่ใช้ร่วมกัน) · `views/app_shell.dart` (แท็บล่างตาม role: `tabsFor(role)`)

| หน้าจอในแผน | ไฟล์ view | ภาพ | Guest | Viewer | Creator | Admin | ต่อ API |
|---|---|---|---|---|---|---|---|
| Login / Register | `views/auth/login_view.dart`, `register_view.dart` | 01, 02, 03 | ✔ | – | – | – | `POST /auth/login`, `/auth/register` |
| Feed / Player | `views/feed/feed_view.dart`, `film_page.dart`, `episode_video.dart`, `episodes_sheet.dart`, `unlock_sheets.dart`, `unlock_success_view.dart`, `login_gate_view.dart`; `views/player/player_view.dart` | 04–12 | ดูตอนฟรี | ✔ | ✔ | ✔ | `GET /films`, `/episodes/:id`, `/stream`, `POST /episodes/:id/unlock` |
| Search / Filters | `views/search/search_view.dart`, `filters_view.dart` | 13, 14, 15 | ✔ | ✔ | ✔ | ✔ | `GET /films?q=&genre=&ai_tool=&length=` |
| Wallet / Top-up | `views/wallet/wallet_view.dart`, `top_up_view.dart` | 16, 17, 19 | ต้อง login | ✔ | ✔ | ✔ | `GET /wallet`, `/wallet/transactions`, `POST /wallet/topup` |
| Subscription (Plus) | `views/wallet/plus_view.dart` (การ์ดใน wallet) | 18 | ต้อง login | ✔ | ✔ | ✔ | `GET/POST/DELETE /subscription` |
| Profile | `views/profile/profile_view.dart`, `edit_profile_view.dart`, `creator_profile_view.dart`, `settings_view.dart` | 20, 21, 22, 23 | – | ✔ | ✔ | ✔ | `GET/PUT /auth/me`, `/watchlist`, `/wallet/unlocked` |
| Creator dashboard | `views/profile/creator_dashboard_view.dart`, `creator_stats.dart` | 24 | – | – | ✔ | ✔ | `GET /creator/films`, `/creator/earnings` |
| Upload / Edit film | `views/upload/upload_view.dart` | 25, 26, 27 | – | – | ✔ | ✔ | `POST /films`, `POST /films/:id/episodes` (multipart), `PUT /films/:id` |
| Admin review | `views/admin/admin_view.dart` (แท็บคิว/รายงาน/Live) | 28, 29, 30 | – | – | – | ✔ | `GET /admin/reviews`, `POST /admin/films/:id/review`, `/admin/reports` |
| Admin sales + ตั้งค่าส่วนแบ่ง | ส่วนบนของ `admin_view.dart` | 28 (การ์ดสถิติ), ไม่มีภาพแยก | – | – | – | ✔ | `GET /admin/sales`, `GET/PUT /admin/settings/revenue-share` |
| Social (like/บันทึก/คอมเมนต์/ติดตาม/รายงาน) | `views/feed/rail_icons.dart`, `comments_sheet.dart`, `report_sheet.dart` | 07, 09 | อ่านคอมเมนต์ | ✔ | ✔ | ✔ | ดู `docs/api.md` ส่วน Social |

ภาพที่ไม่อยู่ในแผน Sprint 1–2 แต่มีในแอป: การแจ้งเตือน (ไม่มี backend แสดงรายการว่าง), onboarding, หน้าตั้งค่า, catalog (ปิดไว้ในค่าเริ่มต้น)

## หลักฐานรายหน้า (องค์ประกอบ / ปฏิสัมพันธ์ที่ทำงานจริง / ที่ยังค้าง)

ใช้เกณฑ์ "เกิน 50%" เป็นรายการที่ติ๊กได้ ไม่ใช่เปอร์เซ็นต์ที่ประเมินเอง; ✔ = มี test หรือลองจริงตามคอลัมน์หลักฐาน

| หน้า | ทำแล้ว (✔) | ยังค้าง / ข้อจำกัดที่ระบุตรง ๆ | หลักฐาน |
|---|---|---|---|
| Login/Register | ฟอร์ม + validation (รหัส ≥ 8 ตัว มีตัวอักษรและตัวเลข ตรงกับ API), error จาก server, เลือก Viewer/Creator, ไม่มีทางสมัคร Admin, ไม่ trim รหัสผ่าน | forgot password ไม่มี backend (กดแล้วแสดง "Password reset is not ready yet." ตรง ๆ ไม่แสดงว่าส่งอีเมล) | B: accounts · F: app_shell, auth tests · ลองจริงบนเว็บ (สมัคร `uiviewer1`) |
| Feed/Player | เล่นวิดีโอจริงผ่าน `/stream`, ตอนฟรี/guest, prompt login/unlock, เลือกตอน, like/save/share/report, ปัดข้ามหนัง, เล่นครั้งละหนึ่งตัว (หน้า active เท่านั้น), ตอนเลขไม่ต่อเนื่อง, error + Try again | ยังไม่ได้ลองบนอุปกรณ์จริง, seek ลองบนเว็บเท่านั้น | F: episode_video_test, session_guard_test, feed_gestures · ลองจริงบนเว็บ (1 `<video>`, readyState 4) |
| Search | คำค้น + ตัวกรอง genre/ความยาว/AI tool, ประวัติค้นหา, ผลล่าสุดเท่านั้น (ไม่ให้ตอบเก่าทับ) | Trending เรียงด้วยยอดวิวซึ่ง backend ยังไม่นับ (ค่า 0) | F: search_extras, film search tests |
| Wallet | ยอดจาก server ทุกครั้งที่เปิด, ประวัติ + ตัวกรอง, demo +100, coin pack จำลอง, ป้าย DEMO/จำลอง | ยังไม่มีปุ่ม "โหลดเพิ่ม" ในประวัติ (แอปดึงทุกหน้าจนหมด สูงสุด 4,000 แถว) | F: wallet_history, session_guard_test · ลองจริงบนเว็บ |
| Subscription | วันที่จริงจาก server (inclusive), `paid_through`, วันที่เหลือ, ยกเลิกยังใช้ได้ถึงสิ้นสุด, ข้อความไม่อ้างการต่ออัตโนมัติ/การแบ่งรายได้ | – | B: wallet, sprint12_regressions · F: gap_flows |
| Profile | ข้อมูลจริง, รายการบันทึก/ปลดล็อก (อ่านจาก `/wallet/unlocked`), แก้โปรไฟล์ | รายการที่ติดตามของคนอื่น (public profile) ไม่มี API จึงไม่แสดงรายการของ viewer แทน | F: repository_features, session_guard_test |
| Creator dashboard | รายได้เหรียญจาก snapshot, หนังทุกสถานะ + review note, refresh หลัง upload, ไม่พังเมื่อ session หมดอายุ | กราฟรายวัน/ยอดวิวไม่มี backend (ไม่แสดง) | F: creator_stats, sprint12_flows |
| Upload / Edit | เลือกวิดีโอ (ตรวจขนาดก่อนอ่าน), ราคาต่อตอน ≤ 500, ติ๊ก AI label, edit แบบ atomic ผ่าน `episode_prices`, loading/error/retry ตอนโหลดตอนของหนัง | native picker ลองบนอุปกรณ์จริงไม่ได้ (ทดสอบด้วย fake picker); เพิ่ม/ลบตอนรายตอนของหนังเดิมจากแอปยังไม่มี (backend มี route) | F: upload_price, sprint12_flows · B: upload_review |
| Admin review | คิว pending (เฉพาะ Approve/Reject ตาม transition ที่ backend อนุญาต, ปิดปุ่มระหว่างส่ง), reports, Live + Take down, เหตุผลบังคับ; ลองจริงบนเว็บ: Approve หนังที่อัปโหลดทาง API → ฐานข้อมูล `approved`/`reviewed_by` และ guest เห็นใน feed. หน้าคิวแสดง "The review queue is empty." ช่วงสั้น ๆ ก่อนข้อมูลโหลดเสร็จ (ไม่มี loading state ในหน้านี้) | ดูตัวอย่างวิดีโอก่อนตัดสินยังไม่มีในหน้า Admin; จัดการ role/ผู้ใช้ และดู rejected/taken_down ยังไม่มี UI (มี API) | F: gap_flows, sprint12_flows |
| Admin sales | การ์ดยอดจำลอง (USD) แยกจากเหรียญ, ส่วนแบ่ง admin, ตั้งเปอร์เซ็นต์ | ไม่มีภาพหน้าจอแยก | F: gap_flows · B: revenue |
