# ShortReel REST API

- **Base URL:** `http://localhost:3000/api` (Android emulator: `http://10.0.2.2:3000/api`)
- **Auth:** ส่ง `Authorization: Bearer <JWT>` ใน endpoint ที่ต้อง login (JWT เป็น HS256 มี `sub` กับ `role` และอายุตาม `JWT_EXPIRES_IN`)
- **สถานะ:** ทุก endpoint ในตารางด้านล่าง **ทำงานจริงบน MySQL** และมี integration test ใน `backend/test/` ครอบคลุมสิทธิ์ (ตาราง role ของทุก endpoint ใน `endpoints.test.js`)
- **Role ตรวจจากฐานข้อมูลทุกคำขอ** ไม่เชื่อ role ใน token: ถูกลดสิทธิ์หรือลบบัญชีแล้วใช้ token เดิมไม่ได้ทันที

## รูปแบบ error

```json
{ "error": { "code": "INSUFFICIENT_COINS", "message": "Not enough coins to unlock this episode" } }
```

| Code | HTTP | ใช้เมื่อ |
|---|---|---|
| `VALIDATION_ERROR` | 400 | ข้อมูลหรือไฟล์ไม่ถูกต้อง |
| `UNAUTHENTICATED` | 401 | ไม่มี token, token ใช้ไม่ได้, รหัสผ่านผิด หรือยังไม่ได้ login เพื่อดูตอนที่ต้องจ่าย |
| `INSUFFICIENT_COINS` | 402 | เหรียญไม่พอ |
| `FORBIDDEN` | 403 | role หรือความเป็นเจ้าของไม่ผ่าน หรือตอนยังไม่ได้ปลดล็อก |
| `NOT_FOUND` | 404 | ไม่พบข้อมูล หรือหนังยังไม่ approved (ซ่อนจากคนที่ไม่ใช่เจ้าของ/admin) |
| `CONFLICT` | 409 | ซ้ำ (username, เลขตอน) หรือผิดกติกา (ลบหนังที่มีคนจ่ายแล้ว, เปลี่ยนสถานะที่ไม่อนุญาต) |
| `FILE_TOO_LARGE` | 413 | ไฟล์เกิน 200 MB |
| `INTERNAL_ERROR` | 500 | ข้อผิดพลาดที่ไม่คาดคิด (ไม่เปิดรายละเอียด) |
| `DB_UNAVAILABLE` | 503 | ติดต่อฐานข้อมูลไม่ได้ |

ระดับการเข้าถึง: `public` ไม่ตรวจ token, `optional` รองรับ guest (แต่ token ที่ส่งมาต้องถูกต้อง), `auth` ต้อง login, `creator` คือ creator หรือ admin, `admin` คือ admin เท่านั้น

## Endpoints

### Health และข้อมูลอ้างอิง

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| GET | `/api/health` | public | `{status:"ok",db:"up"}` หรือ 503 |
| GET | `/api/lookups` | public | `genres` และ `ai_tools` ใช้กับฟอร์ม Upload และตัวกรอง |
| GET | `/api/coin-packs` | public | แพ็กเหรียญ, `demo_topup_coins`, `subscription_price_usd`, `simulated_payment:true` |

### Auth

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| POST | `/api/auth/register` | public | `username` (3–30 ตัว `A-Za-z0-9_.`), `password` (6–72), `role` = `viewer`\|`creator` (ส่ง `admin` ได้ 403) → 201 `{token,user}` |
| POST | `/api/auth/login` | public | → `{token,user}`; รหัสผ่านผิดและ username ไม่มีตอบข้อความเดียวกัน |
| POST | `/api/auth/logout` | auth | `{status:"ok"}` token เป็น stateless แอปลบ token ทิ้งเอง (เซิร์ฟเวอร์ไม่มีอะไรให้เพิกถอน) |
| GET | `/api/auth/me` | auth | `{user}` รวม `has_active_subscription` |
| PUT | `/api/auth/me` | auth | `display_name`, `bio` |

รหัสผ่านเก็บเป็น argon2id (`$argon2id$...`)

### Films และ Episodes

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| GET | `/api/films` | optional | **เฉพาะ approved** query: `q`, `genre` (คั่นด้วย `,`), `ai_tool`, `length` = `under5`\|`5to15`\|`15to30` (รวมความยาวทุกตอน), `sort` = `latest`\|`popular`\|`title`, `creator_id`, `page`, `page_size` ≤ 100. ถ้า login จะมี `liked`/`saved`/`following_creator` |
| GET | `/api/films/:id` | optional | หนัง + ตอนทั้งหมด แต่ละตอนมี `access`. หนังที่ไม่ approved เห็นได้เฉพาะเจ้าของและ admin ที่เหลือ 404 |
| POST | `/api/films` | creator | JSON: `title`, `genre`, `ai_tool` (ชื่อจาก `/lookups`), `prompt_credit`, `synopsis?`, **`is_ai_generated: true` บังคับ** → 201 สถานะ `pending` เสมอ |
| PUT | `/api/films/:id` | creator (เจ้าของ/admin) | แก้ข้อมูล ถ้าเจ้าของแก้หนังที่ approved/rejected สถานะกลับเป็น `pending` และล้าง `review_note`; admin แก้ไม่เปลี่ยนสถานะ; หนังที่ถูก take down เจ้าของแก้ไม่ได้ (409) |
| DELETE | `/api/films/:id` | creator (เจ้าของ/admin) | **409** ถ้ามีคนจ่ายเหรียญปลดล็อกแล้ว (ให้ take down แทน) ลบไฟล์วิดีโอที่ไม่มีตอนไหนอ้างอิงแล้ว → 204 |
| POST | `/api/films/:id/episodes` | creator (เจ้าของ/admin) | `multipart/form-data`: ไฟล์ `video` (MP4 ≤ 200 MB, ตรวจ mimetype และ signature `ftyp`), `price_coins` (0 = ฟรี, 1–500), `episode_no?`, `title?`, `duration_sec?` (ไม่ส่งจะอ่านจาก mp4). ตรวจเจ้าของ **ก่อน** รับไฟล์. ถ้าบันทึกฐานข้อมูลไม่สำเร็จไฟล์ถูกลบ. ถ้าเพิ่มตอนในหนังที่ approved โดยไม่ใช่ admin หนังกลับเป็น `pending` |
| GET | `/api/episodes/:id` | optional | ข้อมูลตอน + `access` + `stream_url` (null ถ้ายังดูไม่ได้) |
| PUT | `/api/episodes/:id` | creator (เจ้าของ/admin) | `title`, `is_free`, `price_coins` (ผู้ที่ปลดล็อกแล้วยังดูได้ ราคาใหม่ใช้กับคนถัดไป) |
| DELETE | `/api/episodes/:id` | creator (เจ้าของ/admin) | 409 ถ้ามีคนจ่ายแล้ว |
| GET | `/api/episodes/:id/stream` | optional | ส่งไฟล์วิดีโอ (รองรับ `Range` → 206 สำหรับ seek). ตรวจสิทธิ์ทุกครั้ง; ใช้ `?t=<playback token>` เมื่อ player ส่ง header ไม่ได้ (เว็บ) |
| POST | `/api/episodes/:id/unlock` | auth | ปลดล็อกด้วยเหรียญ ดูด้านล่าง |

**ค่า `access` ของแต่ละตอน:** `free`, `owner` (เจ้าของหรือ admin), `unlocked`, `subscription`, `locked` (login แล้วแต่ต้องจ่าย), `login_required` (guest).

**การเล่นวิดีโอ**

- โฟลเดอร์ `uploads/` **ไม่ได้เปิดเป็น static** ไฟล์ออกทาง `/stream` เท่านั้น และ path ที่เก็บในฐานข้อมูลถูกบังคับให้อยู่ในโฟลเดอร์ upload
- `GET /api/episodes/:id` ให้ `stream_url` เฉพาะเมื่อดูได้ เป็น link อายุ 10 นาที ผูกกับตอนและผู้ใช้ (`typ:"stream"`) **ไม่ใช่ login token** และ login token เอาไปใช้เป็น link ไม่ได้
- ลิงก์ใช้เป็น login token ไม่ได้ (`readToken` ปฏิเสธ payload ที่มี `typ`) รวมถึงกับ `/api/catalog/*`
- link บอกแค่ว่าใครขอ ทุกคำขอ `/stream` ตรวจใหม่ว่าหนัง approved, ตอนฟรี/เป็นของผู้ขอ/ปลดล็อก/subscription ยังไม่หมด ดังนั้น take down แล้ว link เก่าใช้ไม่ได้ทันที (404)
- guest ดูตอนฟรีได้โดยไม่ต้อง login; ตอนที่ต้องจ่ายตอบ 401 (guest) หรือ 403 (login แล้วแต่ยังไม่ปลดล็อก)

### Wallet, Unlock, Subscription (ทั้งหมดเป็นการจ่ายเงินจำลอง)

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| GET | `/api/wallet` | auth | `coin_balance`, `demo_topup_coins`, `simulated_payment:true` |
| GET | `/api/wallet/transactions` | auth | ประวัติ (ใหม่สุดก่อน) มี `type` (`topup`\|`unlock`), `amount`, `balance_after`, `price_usd` (เงินจำลองที่ตัดตอนซื้อ, null สำหรับ unlock), ชื่อหนัง/ตอน; query `limit`, `offset` |
| POST | `/api/wallet/topup` | auth | `{"demo":true}` เพิ่ม 100 เหรียญ (ค่า `demo_topup_coins`) หรือ `{"pack_id":2}`; **client ส่งจำนวนเหรียญเองไม่ได้** (ตอบ 400) |
| POST | `/api/episodes/:id/unlock` | auth | `{access, charged, already_unlocked, balance}` |
| GET | `/api/subscription` | auth | `{active, subscription:{start_date,end_date,price_usd,is_cancelled}, price_usd}` |
| POST | `/api/subscription` | auth | สมัคร 1 เดือน (จำลอง); ถ้ายัง active อยู่จะต่อท้ายวันสิ้นสุด |
| DELETE | `/api/subscription` | auth | ยกเลิกการต่ออายุ ยังดูได้ถึง `end_date` |

**กติกา unlock (ทั้งหมดอยู่ใน DB transaction เดียว)**

1. ล็อกแถวผู้ใช้ (`SELECT … FOR UPDATE`) คำขอพร้อมกันของคนเดียวกันจึงเรียงคิว
2. ตอนฟรี, ของตัวเอง/admin, ปลดล็อกแล้ว หรือ subscription ยัง active → ตอบ `charged: 0` ไม่หักเหรียญ ไม่เขียนรายการใหม่
3. อ่านราคาจาก `episodes` และเปอร์เซ็นต์จาก `settings` ณ ตอนนั้น (ราคาและส่วนแบ่งกำหนดที่ backend)
4. `UPDATE users SET coin_balance = coin_balance - ? WHERE id = ? AND coin_balance >= ?` ไม่มีแถวเปลี่ยน → 402 (เหรียญไม่มีวันติดลบ)
5. เขียน `unlocked_episodes` (มี `UNIQUE(user_id, episode_id)`) พร้อม `creator_share`/`admin_share` และ `coin_transactions`
6. สิทธิ์ที่ซื้อแล้วอยู่ในฐานข้อมูล เปิดแอปใหม่หรือ login ใหม่ยังเห็น

**ส่วนแบ่งรายได้:** `creator_share = floor(coins × (100 − admin_percent) / 100)` และ `admin_share = coins − creator_share` ผลรวมจึงเท่าเหรียญที่ใช้เสมอ (เศษปัดเข้า admin). หนังของ admin: `creator_share = 0`, `admin_share = ทั้งหมด`. ค่าถูกบันทึกตอนปลดล็อก การเปลี่ยนเปอร์เซ็นต์ทีหลังไม่แก้รายการเก่า. เหรียญของ creator ไม่ได้ถูกเติมเข้า `coin_balance` รายได้ดูจาก `unlocked_episodes`. ค่าสมัคร subscription ไม่ถูกแบ่ง (ยังไม่มีในเอกสารข้อกำหนด)

### Creator

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| GET | `/api/creator/films` | creator | หนังของตนทุกสถานะ พร้อม `review_note` |
| GET | `/api/creator/earnings` | creator | `unit:"coins"`, `coins_earned`, `unlock_count`, `films[]`, `recent_unlocks[]`, `admin_share_percent` (creator ได้ `creator_share`; admin ได้ `admin_share` จากหนังของตน) |

### Admin

| Method | Path | การเข้าถึง | รายละเอียด |
|---|---|---|---|
| GET | `/api/admin/reviews` | admin | หนังที่รอตรวจ (`pending`) |
| GET | `/api/admin/films?status=` | admin | หนังตามสถานะ (ค่าเริ่มต้น `approved`) |
| POST | `/api/admin/films/:id/review` | admin | `{status, note}`; `rejected` และ `taken_down` ต้องมี `note`; approve ต้องมีอย่างน้อย 1 ตอน |
| GET | `/api/admin/sales` | admin | `coins` (หน่วยเหรียญ: ใช้ไป/ส่วนแบ่ง creator/admin/จำนวน unlock), `simulated_payments` (หน่วย USD จำลอง: เติมเหรียญ, subscription), `per_film[]`, `recent_unlocks[]` ตรวจย้อนไปถึงผู้ซื้อและตอน. **ไม่มียอดรวมที่บวกเหรียญกับดอลลาร์เข้าด้วยกัน** |
| GET / PUT | `/api/admin/settings/revenue-share` | admin | `admin_share_percent` 0–100 (มีผลกับ unlock ถัดไป) |
| GET | `/api/admin/users` | admin | รายชื่อผู้ใช้ |
| PUT | `/api/admin/users/:id/role` | admin | `viewer`\|`creator`\|`admin` (เปลี่ยน role ตัวเองไม่ได้) นี่คือทางเดียวที่จะได้ admin เพิ่ม |
| GET | `/api/admin/reports` | admin | รายงานหนัง (open ก่อน) |
| POST | `/api/admin/reports/:id/resolve` | admin | ปิดรายงาน |

**การเปลี่ยนสถานะที่อนุญาต:** `pending → approved/rejected`, `approved → taken_down`, `rejected → approved`, `taken_down → approved`. take down จะปิดรายงานที่ค้างของหนังนั้นด้วย. `rejected/taken_down/pending` ไม่ปรากฏใน feed, search, หน้าตอน และ `/stream`

### Social (like, บันทึก, คอมเมนต์, ติดตาม, รายงาน)

| Method | Path | การเข้าถึง |
|---|---|---|
| POST / DELETE | `/api/films/:id/like` | auth → `{liked, like_count}` |
| GET | `/api/watchlist` | auth → `{film_ids}` |
| POST / DELETE | `/api/films/:id/watchlist` | auth |
| GET | `/api/films/:id/comments` | optional (เฉพาะหนังที่มองเห็นได้) |
| POST | `/api/films/:id/comments` | auth `{body ≤ 500}` |
| DELETE | `/api/comments/:id` | auth (เจ้าของคอมเมนต์หรือ admin) |
| POST / DELETE | `/api/creators/:id/follow` | auth |
| POST | `/api/films/:id/reports` | auth `{reason}` |

คอมเมนต์เป็นแบบเรียบ (ไม่มีการตอบกลับซ้อน และไม่มี like ของคอมเมนต์ ฝั่ง backend)

## ยังไม่มีใน backend

- นับยอดวิวและกราฟรายวัน (แอปไม่แสดงกราฟเมื่อใช้ API)
- การแจ้งเตือน (แอปแสดงรายการว่างเมื่อใช้ API)
- Forgot password
- ส่วนแบ่งรายได้ของค่า subscription
- Rate limiting ของ login
- การเพิกถอน token ก่อนหมดอายุ (logout ลบ token ฝั่งแอป)

## `/api/catalog/*` (ตัวเสริม Series Jeen)

relay ไปยังบริการภายนอก ต้องตั้ง `SERIESJEEN_API_KEY` ไม่ตั้งจะตอบ `503 CATALOG_UNAVAILABLE` และ **ไม่กระทบ endpoint อื่น**. ใช้ตรวจ token แบบไม่แตะฐานข้อมูล (`requireToken`) เพื่อไม่ให้ flow หลักผูกกับตัวเสริม. `GET /api/catalog/dramas/:id/episodes` เปลือง quota จึงต้อง login (หรือตั้ง `CATALOG_ALLOW_GUEST=true` สำหรับทดลองในเครื่อง)

| Method | Path |
|---|---|
| GET | `/api/catalog/platforms` |
| GET | `/api/catalog/platforms/:platformId/dramas` |
| GET | `/api/catalog/dramas/:dramaId` |
| GET | `/api/catalog/dramas/:dramaId/episodes?ep=` |
