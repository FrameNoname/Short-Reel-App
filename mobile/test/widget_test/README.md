# Widget test ทั้งแอป (ต่อ API จริง)

แต่ละไฟล์ในโฟลเดอร์นี้เปิดแอปทั้งตัวแบบเดียวกับ `main()` แล้วยิง HTTP ไปที่ backend จริง ซึ่งอ่าน/เขียน MariaDB จริงในฐาน `shortreel_widget_test` ของที่ปลอมมีแค่ตัวเล่นวิดีโอ (ใน test ไม่มี platform) กับผู้ให้บริการ Series Jeen ข้างนอก (กันไม่ให้กินโควตา) ก่อนทุก test ฐานจะถูกล้างกลับเป็นข้อมูลตั้งต้นจาก `backend/db/shortreel.sql`

## แบ่งงาน

| คน | ไฟล์ | ดูแลอะไร | test ตอนนี้ |
|---|---|---|---|
| Person 1 | `auth_widget_test.dart` | login, สมัครสมาชิก (รหัสอ่อน, รหัสไม่ตรงกัน, ชื่อซ้ำ), โปรไฟล์, settings (ความเร็วเริ่มต้น, การสั่น), logout | 13 |
| Person 2 | `feed_widget_test.dart` | ฟีด, ตัวเล่น, like/save/comment, ความเร็ว, รายการตอน, ท่าทาง (แตะหยุด, แตะสองครั้งไลก์, กดค้าง 2x, ปัดเรื่องถัดไป), จบตอนแล้วเล่นตอนถัดไป, server ล่ม | 13 |
| Person 3 | `search_widget_test.dart` | หน้าค้นหา, ค้นไม่เจอ, server ล่ม | 4 |
| Person 4 | `wallet_widget_test.dart` | กระเป๋าเงิน, ซื้อแพ็กเหรียญ, ปลดล็อกตอน, server ล่ม | 6 |
| Person 5 | `catalog_widget_test.dart` | แคตตาล็อก Series Jeen: รายการ, ค้นหา, เปิดเล่น, ปลดล็อกตอน 10 เหรียญ, server ล่ม | 4 |
| Person 6 | `admin_widget_test.dart` | dashboard, ถอดเรื่องและเอากลับ, ราคาตอนและตอนฟรี, ลบคอมเมนต์, ราคาและแพ็กเหรียญ, server ล่ม | 8 |

รวม 48 test

ตัวช่วยที่ทุกไฟล์ใช้ร่วมกันอยู่ใน `test/support/api_app_harness.dart` (`useApiApp`, `logIn`, `register`, `openTab`, `openEpisode`, `waitFor`, `serverText`, `serverDown`, `video.finish` ฯลฯ) ถ้าจะแก้ไฟล์นี้ บอกทีมก่อน เพราะกระทบทุกคน

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
- จำลอง server ล่มด้วย `await serverDown(true);` แล้วเปิดกลับด้วย `serverDown(false)` (test ถัดไปเริ่มแบบ server ปกติเสมอ)
- จำลองว่าตอนจบด้วย `video.finish(video.playing.single);`
- ปิดท้ายด้วย `await closeApp(tester);` ทุกครั้งที่ login หรือเข้าแอปแล้ว
- บัญชีใน seed: `viewer01 / 6666` (80 เหรียญ), `mira.lens / 4444`, `admin / 1111`
