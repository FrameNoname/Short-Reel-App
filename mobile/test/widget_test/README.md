# Widget test ทั้งแอป (ต่อ API จริง)

แต่ละไฟล์ในโฟลเดอร์นี้เปิดแอปทั้งตัวแบบเดียวกับ `main()` แล้วยิง HTTP ไปที่ backend จริง ซึ่งอ่าน/เขียน MariaDB จริงในฐาน `shortreel_widget_test` ของที่ปลอมมีแค่ตัวเล่นวิดีโอ (ใน test ไม่มี platform) กับผู้ให้บริการ Series Jeen ข้างนอก (กันไม่ให้กินโควตา) ก่อนทุก test ฐานจะถูกล้างกลับเป็นข้อมูลตั้งต้นจาก `backend/db/shortreel.sql`

## แบ่งงาน

| คน | ไฟล์ | ดูแลอะไร | test ตอนนี้ |
|---|---|---|---|
| Person 1 | `auth_widget_test.dart` | login, สมัครสมาชิก, โปรไฟล์, settings, logout | 9 |
| Person 2 | `feed_widget_test.dart` | ฟีด, ตัวเล่น, like/save/comment, ความเร็ว, รายการตอน | 7 |
| Person 3 | `search_widget_test.dart` | หน้าค้นหา | 2 |
| Person 4 | `wallet_widget_test.dart` | กระเป๋าเงิน, ซื้อแพ็กเหรียญ, ปลดล็อกตอน | 5 |
| Person 5 | `catalog_widget_test.dart` | แคตตาล็อก Series Jeen | 1 |
| Person 6 | `admin_widget_test.dart` | หน้าแอดมินทั้งหมด | 5 |

ตัวช่วยที่ทุกไฟล์ใช้ร่วมกันอยู่ใน `test/support/api_app_harness.dart` (`useApiApp`, `logIn`, `register`, `openTab`, `openEpisode`, `waitFor`, `serverText` ฯลฯ) ถ้าจะแก้ไฟล์นี้ บอกทีมก่อน เพราะกระทบทุกคน

## วิธีรัน

1. เปิด MariaDB (XAMPP)
2. สตาร์ต API สำหรับ test (จากโฟลเดอร์บนสุดของ repo)

```bash
node backend/scripts/widget-test-server.js
```

3. ในโฟลเดอร์ `mobile` รันทั้งโฟลเดอร์ หรือเฉพาะไฟล์ของตัวเอง

```bash
flutter test test/widget_test
```

```bash
flutter test test/widget_test/feed_widget_test.dart
```

หลายไฟล์ใช้ฐานเดียวกัน ไฟล์จึงต่อคิวกันผ่าน lock ของ server (`/__test/lock`) เอง ไม่ต้องตั้งอะไรเพิ่ม

## เขียน test ใหม่

- เริ่ม `main()` ด้วย `useApiApp();` และใส่ `@Timeout(Duration(minutes: 15))` บนสุดของไฟล์ (รอคิว lock ได้)
- แอปแสดงภาษาไทยอย่างเดียว ใช้ `text('English')` หรือ `th('English')` หาข้อความตามภาษาอังกฤษในโค้ด
- รอคำตอบจาก server ด้วย `waitFor` / `waitUntil` ไม่ใช่ `pumpAndSettle` อย่างเดียว
- เช็กสิ่งที่ server เก็บด้วย `serverText(path, username: ...)` ไม่ใช่แค่หน้าจอ
- ปิดท้ายด้วย `await closeApp(tester);` ทุกครั้งที่ login หรือเข้าแอปแล้ว
- บัญชีใน seed: `viewer01 / 6666` (80 เหรียญ), `mira.lens / 4444`, `admin / 1111`
