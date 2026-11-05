/// Thai text for the app's own wording. User-written content, such as film
/// titles, comments and bios, is not in here and is shown as written.
library;

const _months = {
  'Jan': 'ม.ค.',
  'Feb': 'ก.พ.',
  'Mar': 'มี.ค.',
  'Apr': 'เม.ย.',
  'May': 'พ.ค.',
  'Jun': 'มิ.ย.',
  'Jul': 'ก.ค.',
  'Aug': 'ส.ค.',
  'Sep': 'ก.ย.',
  'Oct': 'ต.ค.',
  'Nov': 'พ.ย.',
  'Dec': 'ธ.ค.',
};

const _exact = {
  // Navigation and tabs
  'Home': 'หน้าแรก',
  'Search': 'ค้นหา',
  'Catalog': 'แคตตาล็อก',
  'Search series': 'ค้นหาซีรีส์',
  'No series found': 'ไม่พบซีรีส์',
  'Cannot play this episode': 'เล่นตอนนี้ไม่ได้',
  'Wallet': 'กระเป๋าเงิน',
  'Profile': 'โปรไฟล์',
  'Admin': 'แอดมิน',
  'Back': 'กลับ',
  'Close': 'ปิด',
  'Settings': 'การตั้งค่า',

  // Sign in and sign up
  'AI short films, one episode at a time.': 'หนังสั้น AI ทีละตอน',
  'Username': 'ชื่อผู้ใช้',
  'Password': 'รหัสผ่าน',
  'Confirm password': 'ยืนยันรหัสผ่าน',
  'Log in': 'เข้าสู่ระบบ',
  'Log out': 'ออกจากระบบ',
  'Log out?': 'ออกจากระบบหรือไม่?',
  'Stay': 'อยู่ต่อ',
  'You can log back in any time.': 'คุณเข้าสู่ระบบใหม่ได้ทุกเมื่อ',
  'Create account': 'สร้างบัญชี',
  'Create your account': 'สร้างบัญชีของคุณ',
  'Show password': 'แสดงรหัสผ่าน',
  'Hide password': 'ซ่อนรหัสผ่าน',
  'Watch free episodes without an account': 'ดูตอนฟรีได้โดยไม่ต้องมีบัญชี',
  'Watch': 'ดู',
  'Viewer': 'ผู้ชม',
  'Create': 'สร้าง',
  'Choose a username': 'ตั้งชื่อผู้ใช้',
  'Choose a username.': 'กรุณาตั้งชื่อผู้ใช้',
  'Create a password': 'ตั้งรหัสผ่าน',
  'Type it again': 'พิมพ์อีกครั้ง',
  'At least 8 characters, with a letter and a number.':
      'อย่างน้อย 8 ตัวอักษร มีตัวอักษรและตัวเลข',
  "Passwords don't match.": 'รหัสผ่านไม่ตรงกัน',
  'Already have an account?': 'มีบัญชีอยู่แล้ว?',
  'Password reset is not ready yet.': 'ยังไม่เปิดให้รีเซ็ตรหัสผ่าน',
  'Username or password is incorrect. Please try again.':
      'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง กรุณาลองอีกครั้ง',
  'This username is already taken.': 'ชื่อผู้ใช้นี้มีคนใช้แล้ว',
  'Log in to continue': 'เข้าสู่ระบบเพื่อดำเนินการต่อ',
  'Log in to comment': 'เข้าสู่ระบบเพื่อแสดงความคิดเห็น',
  'Log in to keep watching': 'เข้าสู่ระบบเพื่อดูต่อ',
  'Keep browsing free episodes': 'ดูตอนฟรีต่อไป',
  'Save films and unlock episodes': 'บันทึกหนังและปลดล็อกตอน',
  'Unlock': 'ปลดล็อก',
  'Like': 'ถูกใจ',
  'Save': 'บันทึก',

  // Feed and player
  'Eps': 'ตอน',
  'Episodes': 'ตอน',
  'Share': 'แชร์',
  'Speed': 'ความเร็ว',
  'This episode costs coins. Unlock it to keep watching.':
      'ตอนนี้ต้องใช้เหรียญ ปลดล็อกเพื่อดูต่อ',
  'Log in to keep watching this episode.': 'เข้าสู่ระบบเพื่อดูตอนนี้ต่อ',
  'Log in or unlock': 'เข้าสู่ระบบหรือปลดล็อก',
  'Pause video': 'หยุดวิดีโอ',
  'Save film': 'บันทึกหนัง',
  'Films': 'หนัง',
  'Not approved': 'ไม่ผ่านการอนุมัติ',
  'Simulated sales (USD)': 'ยอดขายจำลอง (USD)',
  'More': 'เพิ่มเติม',
  'Report': 'รายงาน',
  'Delete': 'ลบ',
  'Saved': 'บันทึกแล้ว',
  'Playback speed': 'ความเร็วในการเล่น',
  'Comments': 'ความคิดเห็น',
  'Add a comment': 'เพิ่มความคิดเห็น',
  'No comments yet. Say something.': 'ยังไม่มีความคิดเห็น ลองพูดอะไรสักหน่อย',
  'Send comment': 'ส่งความคิดเห็น',
  'No films to show yet.': 'ยังไม่มีหนังให้แสดง',

  // Episodes and unlock
  'Free': 'ฟรี',
  'Paid': 'เสียเงิน',
  'Playing': 'กำลังเล่น',
  'Unlocked': 'ปลดล็อกแล้ว',
  'Price': 'ราคา',
  'Your balance': 'ยอดเหรียญของคุณ',
  'After unlock': 'หลังปลดล็อก',
  'Yours to rewatch anytime': 'ดูซ้ำได้ทุกเมื่อ',
  'Not enough coins': 'เหรียญไม่พอ',
  'Top up': 'เติมเหรียญ',
  'Open wallet': 'เปิดกระเป๋าเงิน',
  'Confirm purchase': 'ยืนยันการซื้อ',
  'Confirm': 'ยืนยัน',
  'Go back': 'ย้อนกลับ',
  'Up next': 'ตอนถัดไป',
  'Legend': 'คำอธิบาย',

  // Search and filters
  'Recent searches': 'ค้นหาล่าสุด',
  'Clear all': 'ล้างทั้งหมด',
  'Trending': 'กำลังฮิต',
  'Discover': 'ค้นพบ',
  'Search films': 'ค้นหาหนัง',
  'Watch and unlock AI short films.': 'ดูและปลดล็อกหนังสั้น AI',
  'Clear search': 'ล้างการค้นหา',
  'No films match your search.': 'ไม่พบหนังที่ตรงกับการค้นหา',
  'Genre': 'แนวหนัง',
  'Drama': 'ดราม่า',
  'Sci-Fi': 'ไซไฟ',
  'Romance': 'โรแมนติก',
  'Thriller': 'ระทึกขวัญ',
  'Fantasy': 'แฟนตาซี',
  'Mystery': 'ลึกลับ',
  'Text-to-video': 'ข้อความเป็นวิดีโอ',
  'Image-to-video': 'ภาพเป็นวิดีโอ',
  'Video-to-video': 'วิดีโอเป็นวิดีโอ',
  'Mixed': 'ผสมหลายเครื่องมือ',

  // Profile
  'Watchlist': 'รายการที่บันทึก',
  'Coins': 'เหรียญ',
  'Likes': 'ถูกใจ',
  'Saved films appear here.': 'หนังที่บันทึกไว้จะแสดงที่นี่',
  'Unlocked films appear here.': 'หนังที่ปลดล็อกแล้วจะแสดงที่นี่',
  'Edit profile': 'แก้ไขโปรไฟล์',
  'Name': 'ชื่อ',
  'Bio': 'คำอธิบายตัวเอง',
  'Tell people what you make': 'บอกให้คนอื่นรู้ว่าคุณสร้างอะไร',
  'Profile saved.': 'บันทึกโปรไฟล์แล้ว',
  'Enter a name for your channel.': 'กรุณาใส่ชื่อช่องของคุณ',
  'Change your name and bio': 'เปลี่ยนชื่อและคำอธิบายของคุณ',
  'No films yet.': 'ยังไม่มีหนัง',
  'Verified': 'ยืนยันแล้ว',

  // Onboarding
  'New': 'ใหม่',
  'Earlier': 'ก่อนหน้า',
  'Just now': 'เมื่อสักครู่',

  // Settings
  'Account': 'บัญชี',
  'Playback': 'การเล่น',
  'About': 'เกี่ยวกับ',
  'Language': 'ภาษา',
  'Default speed': 'ความเร็วเริ่มต้น',
  'Every film starts at this speed. You can still change it from the Speed button.':
      'หนังทุกเรื่องจะเริ่มที่ความเร็วนี้ คุณยังเปลี่ยนได้จากปุ่มความเร็ว',
  'Haptic feedback': 'การสั่นตอบสนอง',
  'A small buzz when you hold for 2x speed':
      'สั่นเบาๆ เมื่อกดค้างเพื่อเล่น 2 เท่า',
  'Short Reel': 'Short Reel',
  'This is a demo build. Payments are simulated and no real money is charged.':
      'นี่คือเวอร์ชันทดลอง การชำระเงินเป็นการจำลอง ไม่มีการเรียกเก็บเงินจริง',

  // Wallet
  'Top up coins': 'เติมเหรียญ',
  '+100 free': 'รับฟรี +100',
  'Added 100 free coins.': 'เพิ่มเหรียญฟรี 100 เหรียญแล้ว',
  'Payments are simulated. No real money is charged.':
      'การชำระเงินเป็นการจำลอง ไม่มีการเรียกเก็บเงินจริง',
  'Payment is simulated. No real money is charged.':
      'การชำระเงินเป็นการจำลอง ไม่มีการเรียกเก็บเงินจริง',
  'Demo purchase. No real money is charged.':
      'การซื้อเพื่อทดลอง ไม่มีการเรียกเก็บเงินจริง',
  'This is a demo, so no real money is charged.':
      'นี่คือการทดลอง จึงไม่มีการเรียกเก็บเงินจริง',
  'DEMO': 'ทดลอง',
  'History': 'ประวัติ',
  'Hide': 'ซ่อน',
  'Show': 'แสดง',
  'All': 'ทั้งหมด',
  'Added': 'เติมเข้า',
  'Spent': 'ใช้ไป',
  'Today': 'วันนี้',
  'Yesterday': 'เมื่อวาน',
  'Top-up': 'เติมเหรียญ',
  'Episode unlock': 'ปลดล็อกตอน',
  'Demo top-up': 'เติมเหรียญทดลอง',
  'No coin activity yet.': 'ยังไม่มีรายการเหรียญ',
  'No top-ups yet.': 'ยังไม่มีการเติมเหรียญ',
  'No unlocks yet.': 'ยังไม่มีการปลดล็อก',
  'Choose a coin pack': 'เลือกแพ็กเกจเหรียญ',
  'Most popular': 'ยอดนิยม',
  'Best value': 'คุ้มที่สุด',
  'Active': 'ใช้งานอยู่',
  'Cancelled': 'ยกเลิกแล้ว',
  '/mo': '/เดือน',

  // Upload and creator studio
  'Title': 'ชื่อเรื่อง',
  'Coins ': 'เหรียญ',
  'coins': 'เหรียญ',
  'Save changes': 'บันทึกการเปลี่ยนแปลง',
  'Changes saved.': 'บันทึกการเปลี่ยนแปลงแล้ว',
  'Unlocks': 'การปลดล็อก',
  'A price must be 0 to 500 coins.': 'ราคาต้องอยู่ระหว่าง 0 ถึง 500 เหรียญ',

  // Admin
  'Total sales (demo)': 'ยอดขายรวม (ทดลอง)',

  // Errors and misc
  'Try again': 'ลองอีกครั้ง',
  'Cannot reach the server': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
  'The server sent an unexpected response': 'เซิร์ฟเวอร์ตอบกลับผิดปกติ',
  'Write a comment first.': 'เขียนความคิดเห็นก่อน',
  'That comment is no longer there.': 'ไม่พบความคิดเห็นนี้แล้ว',
};

/// Sentences that carry a number, name or date. Each rule turns the English
/// pattern into Thai, keeping the parts that came from the app's data.
final _rules = <(RegExp, String Function(Match))>[
  (RegExp(r'^Episode (\d+)$'), (m) => 'ตอนที่ ${m[1]}'),
  (RegExp(r'^Episode (\d+) is yours$'), (m) => 'ตอนที่ ${m[1]} เป็นของคุณแล้ว'),
  (RegExp(r'^Unlock Episode (\d+)$'), (m) => 'ปลดล็อกตอนที่ ${m[1]}'),
  (RegExp(r'^Play episode (\d+)$'), (m) => 'เล่นตอนที่ ${m[1]}'),
  (RegExp(r'^Unlock for (\d+) coins$'), (m) => 'ปลดล็อกด้วย ${m[1]} เหรียญ'),
  (RegExp(r'^(\d+) coins$'), (m) => '${m[1]} เหรียญ'),
  (RegExp(r'^(\d+) eps$'), (m) => '${m[1]} ตอน'),
  (RegExp(r'^(\d+) episodes?$'), (m) => '${m[1]} ตอน'),
  (RegExp(r'^(\d+) free$'), (m) => 'ฟรี ${m[1]} ตอน'),
  (RegExp(r'^(\d+) films?$'), (m) => '${m[1]} เรื่อง'),
  (RegExp(r'^(\d+) selected$'), (m) => 'เลือกแล้ว ${m[1]}'),
  (RegExp(r'^About (\d+) episodes$'), (m) => 'ประมาณ ${m[1]} ตอน'),
  (
    RegExp(r'^Includes (\d+) bonus coins, about (\d+) episodes$'),
    (m) => 'แถมโบนัส ${m[1]} เหรียญ ประมาณ ${m[2]} ตอน',
  ),
  (RegExp(r'^Enough for (\d+) episodes?$'), (m) => 'ดูได้ประมาณ ${m[1]} ตอน'),
  (
    RegExp(r'^Buy (\d+) coins for \$([\d.]+)$'),
    (m) => 'ซื้อ ${m[1]} เหรียญ ราคา \$${m[2]}',
  ),
  (
    RegExp(r'^Buy (\d+) coins · \$([\d.]+) & unlock$'),
    (m) => 'ซื้อ ${m[1]} เหรียญ · \$${m[2]} แล้วปลดล็อก',
  ),
  (
    RegExp(
      r'^Buy (\d+) coins for \$([\d.]+), then spend (\d+) coins on Episode '
      r'(\d+)\. This is a demo, so no real money is charged\.$',
    ),
    (m) =>
        'ซื้อ ${m[1]} เหรียญ ราคา \$${m[2]} แล้วใช้ ${m[3]} เหรียญกับตอนที่ '
        '${m[4]} นี่คือการทดลอง จึงไม่มีการเรียกเก็บเงินจริง',
  ),
  (
    RegExp(
      r'^Paid through (\w{3} \d+)\. Buying again adds one more month after '
      r'that\.$',
    ),
    (m) =>
        'จ่ายครอบคลุมถึง ${_date(m[1]!)} ซื้อซ้ำจะเพิ่มอีกหนึ่งเดือนต่อจากนั้น',
  ),
  (RegExp(r'^Started (\w{3} \d+)$'), (m) => 'เริ่ม ${_date(m[1]!)}'),
  (RegExp(r'^Ends (\w{3} \d+)$'), (m) => 'สิ้นสุด ${_date(m[1]!)}'),
  (
    RegExp(r'^(\d+) days? left, paid through (\w{3} \d+)$'),
    (m) => 'เหลือ ${m[1]} วัน จ่ายครอบคลุมถึง ${_date(m[2]!)}',
  ),
  (
    RegExp(
      r'^You keep every episode until (\w{3} \d+)\. After that, coins apply '
      r'again\.$',
    ),
    (m) =>
        'คุณยังดูได้ทุกตอนจนถึง ${_date(m[1]!)} หลังจากนั้นจะใช้เหรียญตามปกติ',
  ),
  (
    RegExp(r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d+)$'),
    (m) {
      return _date('${m[1]} ${m[2]}');
    },
  ),
  (
    RegExp(r'^Coins spent on (\d+) unlocks?$'),
    (m) => 'เหรียญที่ใช้ปลดล็อก ${m[1]} ครั้ง',
  ),
  (RegExp(r'^(.+) likes$'), (m) => 'ถูกใจ ${m[1]}'),
  (RegExp(r'^Enter 1 to (\d+) coins\.$'), (m) => 'ใส่ 1 ถึง ${m[1]} เหรียญ'),
  (RegExp(r'^(\S+) speed$'), (m) => 'ความเร็ว ${m[1]}'),
  (
    RegExp(r'^VIDEO · (.+) · EP (\d+)$'),
    (m) => 'วิดีโอ · ${m[1]} · ตอนที่ ${m[2]}',
  ),
  (
    RegExp(
      r'^(.+)\. It stays in your library, so you can rewatch it anytime\.$',
    ),
    (m) => '${m[1]} หนังเรื่องนี้จะอยู่ในคลังของคุณ ดูซ้ำได้ตลอด',
  ),
  (
    RegExp(
      r'^You watched the free episodes of (.+)\. Log in to continue from '
      r'Episode (\d+)\.$',
    ),
    (m) => 'คุณดูตอนฟรีของ ${m[1]} แล้ว เข้าสู่ระบบเพื่อดูต่อจากตอนที่ ${m[2]}',
  ),
  (RegExp(r'^(\d+) × (.+) coins$'), (m) => '${m[1]} × ${m[2]} เหรียญ'),
  (RegExp(r'^Episode (\d+) costs$'), (m) => 'ตอนที่ ${m[1]} ราคา'),
  (
    RegExp(r'^\. You have (\d+) — you need$'),
    (m) => '. คุณมี ${m[1]} เหรียญ ต้องใช้อีก',
  ),
  (RegExp(r'^(\d+) more\.$'), (m) => '${m[1]} เหรียญ'),
  (RegExp(r'^· (.+)$'), (m) => '· ${thaiOf(m[1]!)}'),
  (RegExp(r'^(@\S+) · (\w+)$'), (m) => '${m[1]} · ${thaiOf(m[2]!)}'),
  (RegExp(r'^Poster of (.+)$'), (m) => 'โปสเตอร์ของ ${m[1]}'),
  (RegExp(r'^(\d+) days$'), (m) => '${m[1]} วัน'),
  (RegExp(r'^vs previous (\d+) days$'), (m) => 'เทียบกับ ${m[1]} วันก่อนหน้า'),
  (RegExp(r'^(\d+)m ago$'), (m) => '${m[1]} นาทีที่แล้ว'),
  (RegExp(r'^(\d+)h ago$'), (m) => '${m[1]} ชั่วโมงที่แล้ว'),
  (RegExp(r'^(\d+)d ago$'), (m) => '${m[1]} วันที่แล้ว'),
  (RegExp(r'^liked (.+)$'), (m) => 'ถูกใจ ${m[1]}'),
  (RegExp(r'^commented on (.+)$'), (m) => 'แสดงความคิดเห็นใน ${m[1]}'),
  (
    RegExp(r'^replied to your comment on (.+)$'),
    (m) => 'ตอบกลับความคิดเห็นของคุณใน ${m[1]}',
  ),
  (
    RegExp(r'^unlocked Episode (\d+) of (.+)$'),
    (m) => 'ปลดล็อกตอนที่ ${m[1]} ของ ${m[2]}',
  ),
  (RegExp(r'^(.+) was approved$'), (m) => '${m[1]} ได้รับการอนุมัติแล้ว'),
  (RegExp(r'^(.+) was taken down$'), (m) => '${m[1]} ถูกถอดออก'),
];

String _date(String english) {
  final parts = english.split(' ');
  return '${parts[1]} ${_months[parts[0]] ?? parts[0]}';
}

/// The Thai for [english], or [english] itself when there is none.
String thaiOf(String english) {
  final lead = RegExp(r'^\s*').stringMatch(english)!;
  final trail = RegExp(r'\s*$').stringMatch(english)!;
  final core = english.trim();
  if (core.isEmpty) return english;

  final translated = _translateCore(core);
  return translated == core ? english : '$lead$translated$trail';
}

String _translateCore(String core) {
  final exact = _exact[core];
  if (exact != null) return exact;

  for (final (pattern, build) in _rules) {
    final match = pattern.firstMatch(core);
    if (match != null) return build(match);
  }

  // "@name · Genre · AI tool": translate each part on its own.
  if (core.contains(' · ')) {
    return core.split(' · ').map(_translateCore).join(' · ');
  }
  return core;
}
