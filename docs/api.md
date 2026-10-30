# ShortReel REST API

- **Base URL:** `http://localhost:3000/api` (Android emulator: `http://10.0.2.2:3000/api`)
- **Auth:** ส่ง `Authorization: Bearer <token>` ใน endpoint ที่ต้อง login
- **สถานะปัจจุบัน:** ทุก endpoint ด้านล่างตอบ `501 NOT_IMPLEMENTED` จนกว่าเจ้าของงานจะเขียน controller จริง ยกเว้น `GET /api/health`

## Health check

`GET /api/health` ตอบ `200` และ `{ "status": "ok", "db": "up" }` หรือ `503 DB_UNAVAILABLE`

## รูปแบบ error

```json
{ "error": { "code": "NOT_IMPLEMENTED", "message": "This endpoint is not implemented yet" } }
```

| Code | HTTP | ใช้เมื่อ |
|---|---|---|
| `VALIDATION_ERROR` | 400 | ข้อมูลไม่ถูกต้อง |
| `UNAUTHENTICATED` | 401 | ไม่มี token หรือ token ใช้ไม่ได้ |
| `INSUFFICIENT_COINS` | 402 | เหรียญไม่พอ |
| `FORBIDDEN` | 403 | role หรือความเป็นเจ้าของไม่ผ่าน |
| `NOT_FOUND` | 404 | ไม่พบข้อมูลหรือ route |
| `CONFLICT` | 409 | ข้อมูลซ้ำ เช่น username |
| `FILE_TOO_LARGE` | 413 | ไฟล์เกินขนาด |
| `NOT_IMPLEMENTED` | 501 | stub ที่ยังไม่ได้ทำ |
| `INTERNAL_ERROR` | 500 | ข้อผิดพลาดที่ไม่คาดคิด |
| `DB_UNAVAILABLE` | 503 | ติดต่อฐานข้อมูลไม่ได้ |

## Endpoints

ระดับการเข้าถึง: `public` ไม่ตรวจ token, `optional` รองรับ guest, `auth` ต้อง login, `creator` คือ creator หรือ admin, `admin` คือ admin เท่านั้น

| Method | Path | การเข้าถึง |
|---|---|---|
| POST | `/api/auth/register` | public |
| POST | `/api/auth/login` | public |
| POST | `/api/auth/logout` | auth |
| GET | `/api/auth/me` | auth |
| GET | `/api/films` | optional |
| GET | `/api/films/:id` | optional |
| POST | `/api/films` | creator |
| PUT | `/api/films/:id` | creator |
| DELETE | `/api/films/:id` | creator |
| POST | `/api/films/:id/episodes` | creator |
| GET | `/api/episodes/:id` | optional |
| PUT | `/api/episodes/:id` | creator |
| DELETE | `/api/episodes/:id` | creator |
| GET | `/api/episodes/:id/stream` | optional |
| POST | `/api/episodes/:id/unlock` | auth |
| GET | `/api/wallet` | auth |
| GET | `/api/wallet/transactions` | auth |
| POST | `/api/wallet/topup` | auth |
| GET | `/api/coin-packs` | public |
| GET | `/api/subscription` | auth |
| POST | `/api/subscription` | auth |
| GET | `/api/creator/films` | creator |
| GET | `/api/creator/earnings` | creator |
| GET | `/api/admin/reviews` | admin |
| POST | `/api/admin/films/:id/review` | admin |
| GET | `/api/admin/sales` | admin |
| PUT | `/api/admin/settings/revenue-share` | admin |
| GET | `/api/admin/users` | admin |
| PUT | `/api/admin/users/:id/role` | admin |
| GET | `/api/admin/reports` | admin |
| POST | `/api/admin/reports/:id/resolve` | admin |
| POST | `/api/films/:id/like` | auth |
| DELETE | `/api/films/:id/like` | auth |
| GET | `/api/watchlist` | auth |
| POST | `/api/films/:id/watchlist` | auth |
| DELETE | `/api/films/:id/watchlist` | auth |
| GET | `/api/films/:id/comments` | public |
| POST | `/api/films/:id/comments` | auth |
| DELETE | `/api/comments/:id` | auth |
| POST | `/api/creators/:id/follow` | auth |
| DELETE | `/api/creators/:id/follow` | auth |
| POST | `/api/films/:id/reports` | auth |
