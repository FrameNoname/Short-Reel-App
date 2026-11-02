# ShortReel: รายการแก้ไขรวมสำหรับส่ง Claude

ตรวจ source ที่ D:/short_reel_app, commit58ca1dad99613c5431616dacd209ff161dd8e73d วันที่1พฤศจิกายน2026 โค้ดยังเหมือนรอบตรวจแรก ปัญหาเดิม11จุดยังไม่ได้แก้ รายการนี้รวมบั๊ก งานที่ยังขาดในหน้าจอ และข้อเสนอที่มีเงื่อนไข ไม่ได้หมายความว่าทุกข้อเป็นข้อผิดพลาดระดับเดียวกันหรือจำเป็นต่อเกณฑ์รายวิชาทั้งหมด

ข้อกำหนดอ้างอิง: C:/Users/Admin/Downloads/MONTHAKAN KAEWSAI - Project 2 (3).pdf (อ่านครบ9หน้า รวมตารางภาพหน้า2ในรอบก่อน) หลักฐานละเอียดใน review.md, backend-findings-root.md, mobile-findings-review-agent-core-c1.md และรายงานcycle2ในโฟลเดอร์เดียวกัน

## ข้อความมอบงาน

ช่วยแก้ ShortReel ตามรายการด้านล่าง โดยอ่าน source, README, docs/api.md และ acceptance checklist ก่อน เริ่มจากข้อ1–5 แล้วแก้ข้อบกพร่องของ core flow ตามลำดับ รักษา MVC, Flutter/Express/MySQL, การจ่ายเงินจำลอง และข้อมูลเดิม ไม่มีการเพิ่ม payment gateway จริงหรือย้ายระบบโดยไม่จำเป็น ไม่ reset ฐานข้อมูลจริง ไม่แก้ .claude/ หรือ docs/ui-screens/ ของผู้ใช้ และไม่ commit/push หากยังไม่ได้สั่ง

หลักการ: ตรวจซ้ำแต่ละข้อกับ source ปัจจุบัน หากแก้ไปแล้วให้แสดงหลักฐาน ไม่แก้ซ้ำตามความจำ เพิ่ม regression tests ที่ตรวจพฤติกรรมจริงของบั๊ก แยกงานจำเป็นกับฟีเจอร์เสริมตามหมวด และรายงานส่วนที่ยังไม่ทำอย่างชัดเจน

## บั๊กสำคัญที่ต้องแก้ก่อน

1. **ลบตอนพร้อมกับมีผู้ซื้อแล้วสิทธิ์หายหลังถูกหักเหรียญ** — backend/src/controllers/episodes.js:127–131 และ models/wallet.js. ทดสอบได้ purchase200/charged20 แล้ว delete204 ลบทั้งตอนและสิทธิ์ด้วยCASCADE เหลือbalance80และdebitที่episode_id=NULL. ให้การลบ/ซื้อ serialize บนข้อมูลตอนเดียวกัน ใช้ current/locking read และ lock order ที่สอดคล้องกัน หรือ soft delete ที่รักษาสิทธิ์ ทดสอบทั้งสองลำดับของ race รวม rollback/deadlock

2. **error หลัง commit upload ทำให้ลบไฟล์ที่มีข้อมูลอ้างอิงแล้ว** — backend/src/controllers/films.js:175–193. findWithFilm หลังcommitล้มเหลวแล้วcatchเรียกdiscardเสมอ ต้องcleanupเฉพาะก่อนcommitหรือแยกสถานะcommittedชัดเจน ทดสอบpostcommitread/serializationfailureแล้วไฟล์ยังอยู่

3. **response ของ session เก่าเปลี่ยนบัญชีใหม่/คืนผู้ใช้ที่logoutแล้ว** — mobile/lib/data/api_repository.dart, controllers/auth_controller.dart, wallet_controller.dart. ทดสอบจริงด้วยfakeHTTPว่าtopupของAกลับมาหลังlogout/loginBแล้วเปลี่ยนbalanceของBจาก10เป็น180; responseแก้profileกลับหลังlogoutทำให้user6กลับมาแม้token=null. ใช้session generation/identity snapshotทุกชั้น ยกเลิกหรือทิ้งคำตอบเก่า รวมrestore/login/profile/wallet/library/admin requests ห้ามนำ_meปัจจุบันไปผสมresponseของคนเก่า

4. **sessionหมดอายุบนCreator studioแล้วหน้าพัง** — creator_dashboard_view.dart:60 และmain.dart. user!.idถูกอ่านหลังexpire แต่Navigatorยังเก็บpushedroute. Guardหน้าที่ต้องloginและล้าง/เปลี่ยนnavigationที่เกี่ยวข้องเมื่อsessionหมดอายุ ทดสอบexpiryจากหน้าซ้อนทุกหน้าที่ต้องมีบัญชี

5. **ปัดฟีดค้างแล้วเล่นวิดีโอพร้อมกันสองตัว** — feed_view.dart:70, episode_video.dart:75. ส่งcurrentpageactiveลงFilmPage/ตัวเล่น ยกเลิกpendingloadและหยุดหน้าที่ไม่active ทดสอบslow/heldswipeให้มีplayingไม่เกิน1ตัวทั้งfeedและplayer รวมเปลี่ยนtab/route

## ความถูกต้องของบัญชี การซื้อ และรายการข้อมูล

6. **401จากrequestเก่าลบtokenใหม่** — services/api_client.dart. ก่อนclear/expireต้องเทียบrequesttoken/sessiongenerationกับsessionปัจจุบัน responseของAห้ามlogoutB และไม่ใช้การretrywriteอัตโนมัติโดยไม่มีidempotency

7. **ต่อPlusหลายครั้งได้ช่วงวันทับกัน** — backend/src/models/subscriptions.js:38. ปัจจุบันซื้อสามครั้งแล้วครั้ง2/3ได้วันเริ่ม/สิ้นสุดเหมือนกัน ให้นับpaidcoverageที่ซื้อไว้ล่วงหน้าทั้งหมด กำหนดinclusive/exclusiveวันให้ชัด และทดสอบ3ครั้งขึ้นไปทั้งserial/concurrent

8. **เปลี่ยนroleแล้วรายได้ย้อนหลังเปลี่ยน** — models/creator.js:3. Creatorที่รายได้28กลายเป็น12หลังpromoteเป็นAdminทั้งที่ไม่มีunlockใหม่ ใช้allocation/beneficiaryที่บันทึกตอนซื้อ ไม่ตีความcreator_share/admin_shareจากroleปัจจุบัน เพิ่มmigrationถ้าต้องเก็บsnapshotเพิ่มเติม

9. **Wallet refreshไม่อ่านยอดปัจจุบันจากserver** — wallet_controller.dart:load และ ApiRepository. โหลดแค่history/packs/subscription แต่balanceมาจากuserที่loginครั้งก่อน ให้โหลดGET/walletหรือmeและอัปเดตอย่างปลอดภัยตามsessionเดียวกัน ทดสอบยอดเปลี่ยนจากอีกdevice/sessionและnetworkfailure

10. **ไม่มีpaginationทำให้ข้อมูลถูกตัด** — ApiRepository.films()/transactionsOf(), backendfilmsdefault50/historydefault50, creator/adminlists100. เพิ่มpagination/has_more/totalหรือcursorให้UIโหลดต่อได้ รายการUnlockedต้องอ่านสิทธิ์โดยตรง ไม่อนุมานจากledger50แถวล่าสุด ทดสอบ51หนังและunlockเก่าที่อยู่หลัง50topup

11. **Profileไม่อัปเดตรายการหลังsave/unlock/follow** — ApiRepository.toggleSave()/refreshLibrary(), ProfileView OnInitกับIndexedStack. iconเปลี่ยนแต่_watchlistIdsยังเก่า และOnInitทำครั้งเดียว ให้update/invalidatecacheที่เกี่ยวข้องและrefreshเมื่อกลับเข้าtabอย่างถูกต้อง เพิ่มloading/error/retryไม่กลืนerrorให้ดูเหมือนว่าง

12. **publiccreatorprofile/Followingใช้ข้อมูลผิดคนและcacheไม่ครบ** — followingOf(userId)ไม่ใช้userId คืนรายการของviewerแม้ขอดูคนอื่น; profile/creatorsearchอาศัย_usersจากหนังที่เคยโหลดและไม่โหลดbio/profileเต็ม. เพิ่มAPI/contractสำหรับprofile/followcounts/creatorsearchที่จำเป็น หรือแสดงเฉพาะข้อมูลที่มีจริง ห้ามนำcacheของviewerไปอ้างเป็นสถิติcreatorคนอื่น

13. **คำตอบSearch/Feed/Filterเก่าทับคำตอบใหม่** — film_search_controller.dart:apply, feed_controller.dart:load/selectTab, filters_view.dart:_refreshCount. ใช้requestid/cancel/debounceตามเหมาะสม ครอบคลุมdata/error/loading/countและdispose ทดสอบตอบกลับสลับลำดับ รวมfiltercountล้มเหลวไม่เป็นunhandledexception

14. **หน้าPlusแสดงวัน/ข้อความไม่ตรงระบบจริง** — plus_view.dart:45–46ใช้now+30daysแต่backendcalendarเดือนและอาจมีprepaidcoverage. แสดงauthoritativeserverdates/quoteและยอดpaidcoverageจริง คำนวณdaysleftให้ตรงenddateinclusive แก้ข้อความrenewsเมื่อไม่มีautomaticrenewal และsupportcreatorsเมื่อยังไม่มีallocationของsubscription อย่าเพิ่มการแบ่งsubscriptionโดยพลการเพื่อแก้copy

## Upload, CRUD และ media

15. **UIรับราคา999แต่backendรับ500** — upload_view.dart:113 กับcontrollers/films.js:168/episodes.js:109. กำหนดขอบเขตเดียวในAPI/UI/docs ทดสอบ500/501/999และeditingด้วย

16. **แก้filmหลายfieldไม่atomic** — UploadController.updateเปลี่ยนราคาทีละตอนก่อนmetadata ถ้าตอนถัดไปหรือmetadataผิดจะเปลี่ยนไปบางส่วนทั้งที่formแจ้งfail. ทำbatchowned-filmendpointที่validateทั้งหมดและtransactionเดียว หรือออกแบบpartialresult/recoveryชัดเจน ต้องคงข้อมูลเดิมเมื่อvalidationsfail

17. **เข้าEditแล้วโหลดตอนล้มเหลวไม่มีerror/retryและsaveได้ก่อนพร้อม** — UploadView._loadEpisodes()ไม่มีcatch ถูกเรียกแบบไม่awaitจากinitState; emptyprice-listผ่านevery(). เพิ่มloading/error/retry ปิดsaveจนข้อมูลครบ และvalidateความยาวtitle/promptตามbackendก่อนส่ง

18. **ตรวจขนาดไฟล์หลังอ่านเข้าmemoryหมดแล้ว** — services/video_picker.dart:23 และupload_view.dart:88. ตรวจsize/จำนวน/ขนาดรวมจากmetadataก่อนreadAsBytes ใช้stream/pathuploadเมื่อplatformรองรับ หลีกเลี่ยงเก็บหลายไฟล์200MBพร้อมกัน เพิ่มprogress/cancelและcleanupที่สอดคล้องกัน

19. **ตรวจMP4แค่12ไบต์จึงรับไฟล์ที่ไม่มีวิดีโอ** — backend/services/media.js:16–21. มีprobeส่งftyp/isom12Bสำเร็จ201และadminapprove200 ให้ตรวจcontainer/tracks/codecที่รองรับอย่างเหมาะสม มีcorrupt/truncatedtests และรองรับfragmentedMP4จริงด้วย ห้ามใช้duration0เป็นหลักฐานเสียเพียงอย่างเดียว

20. **VideoPlayerControllerรั่วเมื่อinitializeล้มเหลว** — episode_video.dart:151. nextถูกassignเป็น_videoหลังinitializeจึงdisposeไม่ถึงinstanceที่fail. มีprobeallocated1/disposed0. ใช้ownership+finallycleanupสำหรับcontrollerที่ยังไม่ติดตั้ง รวมretryและออกจากหน้าระหว่างโหลด

21. **ลบ/เพิ่มตอนเลขไม่ต่อเนื่องแล้วPlayerเลือกตอนผิด** — film_page.dart:171, episode_video.dart:135. ใช้episode_countเป็นmaxepisodeNoและบวก1 ทั้งที่APIรับเลข1,3,8และลบโดยไม่renumber. ให้เดินตามepisodeIDs/listที่เรียงจริง รักษาidentityสิทธิ์เดิม ทดสอบลบตอนแรก/กลาง/ท้ายและsparseexplicitnumbers

22. **Creator studioไม่refreshหลังupload** — creator_dashboard_view.dart:195. awaitผลnavigationแล้วreloadอย่างเหมาะสม การwatchUploadControllerอย่างเดียวไม่เปลี่ยนcompleted_futureเดิม ทดสอบuploadสำเร็จกลับมาแล้วเห็นfilm/statusใหม่

23. **สคริปต์importคลิปชื่อชนกันได้** — backend/scripts/import-demo-clips.js. ก.mp4/ข.mp4ถูกsanitizeเป็นdemo__.mp4เหมือนกัน จึงcopyทับและหลายตอนชี้ไฟล์เดียวโดยไม่ตั้งใจ ใช้ชื่อunique/hash ตรวจcollisionในdryrun และทดสอบrerunโดยไม่ทับmediaที่อ้างอิง

## Admin และส่วนเสริม Catalog

24. **ปุ่มTake downในpendingqueueใช้ไม่ได้แน่นอน** — admin_view.dart:341–409 ให้แสดงเฉพาะactionที่backendtransitionอนุญาต pendingมีapprove/reject; approvedจึงtakedown พร้อมdisableactionขณะส่งเพื่อไม่ยิงซ้ำ

25. **Catalogยังทำให้corefeedรอ** — ApiRepository._matchingCatalogFilmsรอ_catalogLoading. ส่งcoredataก่อนแล้วappendoptionalอย่างboundedfailure ไม่รอทุกplatform และตั้งtimeoutที่clientอย่างเหมาะสม เมื่อเปิดCATALOGแล้วproviderล่มcoreต้องยังแสดงได้

26. **CatalogRetryครั้งแรกไม่โหลดplatformsใหม่** — CatalogView:90เรียกsearchขณะplatform=null. ทำretryตามrequestที่ล้มเหลว รวมplatformsuccess/dramafailure/paginationfailure และป้องกันerror/loadingเก่าทับrequestใหม่

27. **Catalogเปลี่ยนพาร์ตแล้วerrorไม่ถูกรับ/cleanupไม่ครบ** — catalog_video.dart:_onPartEndedเรียก_openPartโดยไม่await/catch; initializeleakเหมือนcoreplayer; retryทุกerrorทันทีแม้401/403/429. รวมerrorpathทุกpart ป้องกันlistenerเก่า disposependingcontroller และretryเฉพาะที่เหมาะสม/เคารพRetry-After พร้อมปุ่มtryagainและรักษาตำแหน่งเมื่อทำได้

28. **บัญชีที่ลบแล้วยังใช้Catalogquotaได้** — backend/routes/catalog.js:2ใช้requireTokenแทนDB-backedauth. Probe core401แต่catalogepisode200. ใช้policyบัญชี/สิทธิ์เดียวกับcore หรือrevocationที่ให้ผลเทียบเท่า โดยไม่เปิดguestเป็นdefault

## Contract, ขอบเขตหน้าจอ และงานส่ง

29. **PasswordvalidationAPI/UIไม่ตรงและtrimรหัสผ่านเงียบ ๆ** — registerUI8+letter+number แต่API6และยอมรับ123456; generictext()trimก่อนhash/verify. เลือกpolicyregistrationเดียวและvalidateทั้งสองฝั่ง รักษารหัสผ่านตามที่ผู้ใช้ป้อน ไม่trimเงียบ ๆ แต่loginต้องยังรองรับบัญชีseedเดิม1111/6666ที่เอกสารกำหนด

30. **lookups/searchscopeยังเป็นข้อมูลคงที่หรือไม่ตรงคำใบ้** — Upload/Filters/Onboardingใช้mockGenres/mockAiToolsทั้งที่มีGET/lookups. ดึงcanonicalvaluesจากbackendพร้อมcache/errorfallbackตามที่กำหนด และทำprompt/creatorsearchจริงตามUIหรือแก้คำใบ้ให้ตรงสิ่งที่ค้นหาได้

31. **EpisodeCRUDในแอปยังไม่ครบ** — Editมีแต่metadata/ราคาที่มีอยู่ ไม่มีเพิ่ม/ลบตอนรายตอนของfilmเดิมทั้งที่backendมีroute. เพิ่มrepository/controller/UIสำหรับงานที่เอกสารระบุ ทดสอบownership/paid-episode-deleteconflict ห้ามบอกCRUDครบจากendpointอย่างเดียว

32. **Adminยังเปิดดูหนังpendingก่อนreviewไม่ได้จากหน้าจอ** — เพิ่มpreview/episode list/creditdetailsผ่านprotectedplaybackสำหรับadminก่อนตัดสินapprove/reject รวมเปิดหนังจากreport; ไม่เปิดuploadsเป็นpublic

33. **Adminworkflowบางส่วนมีAPIแต่ไม่มีUI** — จัดการuserrolesตามเอกสารและรายการrejected/taken_downพร้อมrestoreตามpolicyที่backendรองรับ ปัจจุบันมีแค่queue/reports/live อย่าเพิ่มการลบบัญชีแบบทำลายledger/สิทธิ์โดยไม่มีข้อกำหนด

34. **Settings/onboardingไม่จำค่าหลังเปิดใหม่** — language/defaultspeed/haptics/favoritegenres/onboardedอยู่memory. เก็บdevicepreferencesในlocalpersistenceและrestoreก่อนตัดสินonboarding แยกdeviceprefsกับuseraccountstate งานนี้เป็นคุณภาพใช้งาน ไม่ใช่ข้อบังคับเพิ่มpayment/cloud

35. **ฟีเจอร์local/ยังไม่รองรับต้องแสดงตามจริง** — notifications/forgotpassword/views/dailychartsยังไม่มีbackend, commentlikes/watchprogressเป็นlocal, repliesกลายเป็นflatcomments, sharecopyข้อความไม่มีdeeplink. เลือกซ่อน/ติดป้ายหรือทำเพิ่มหลังcore หลีกเลี่ยงUIอ้างความสามารถที่ยังไม่มี; trendingที่sortviewcount0ควรใช้metricจริงหรือเปลี่ยนlabel

36. **Testsบางข้อยอมให้500ผ่านและcoverageเป็นเลขคงที่** — endpoints.test.js:81,91ต้องassertexpectedstatus/bodyและreject5xx เสริมsuccess/negativecasesจริงและcoverageของmountedroutesตามเหมาะสม เพิ่มregressionsของข้อ1–30 ไม่แก้ด้วยลดassertionหรือปิดauth

37. **คลิปและเดโมยังไม่พร้อมส่งครบ** — เตรียมคลิปที่ทีมมีสิทธิ์ใช้10–20คลิปตามแผน มีseed/playablemediaที่setupได้ตามREADME ไม่พึ่งexternalprovider รายงานTemporarygeneratedclipsแยกจากชุดส่งจริง และแก้scriptcollisionก่อนนำเข้า

38. **ยังไม่มีหลักฐานE2E/deviceครบ** — ต้องลองผ่านUIจริงสมัคร/login/guestpreview/topup/unlock/reopen/subscribe/expiry/upload/nativepicker/adminapprove/reject/takedown/creator/admintotals รวมnetworkfailure/retry ทดสอบplay/seek/securestorage/layoutบนอุปกรณ์เป้าหมายและbuildจริง (Androidหรือแพลตฟอร์มที่ส่ง) อย่าอ้างว่ารองรับiOSถ้ายังไม่ตั้งค่าAPI/transportและทดสอบ

39. **เอกสาร/CI/migrationverificationต้องตามสถานะจริง** — แก้README/API/checklistที่บอกoneplayer/sessionexpiry/catalogindependentว่าเสร็จให้ตรงหลักฐาน ตั้งCIทำnpmci+MariaDBtests+Flutteranalyze/testsและbuildที่ใช้ส่ง ทดสอบmigrationกับschemaเดิม/ข้อมูลเดิมและรันซ้ำอย่างปลอดภัย ไม่importDROPseedทับข้อมูลจริง

40. **งานเพิ่มเมื่อเปิดใช้นอกlocaldemo** — กำหนดtimeouts/cancel/retryที่ไม่ทำให้ซื้อซ้ำ, login/registerratelimitและcatalogquotabudget, configvalidation/secret, HTTPSและจำกัดcleartextเฉพาะdebug, DBuserแยกจากroot, backupDBกับmediaและgracefulshutdown/observability. เลือกตามเป้าหมายdeploymentจริง ไม่ถือว่าทั้งหมดเป็นเงื่อนไขรายวิชาหรือบังคับเพิ่มระบบจ่ายเงินจริง

## เกณฑ์ส่งกลับหลังแก้

- สรุปแต่ละข้อ:แก้แล้ว/ไม่เกี่ยวข้องพร้อมเหตุผล/ค้าง พร้อมไฟล์และregressionevidence
- รันnpmtest --prefixbackend, flutteranalyze, fluttertest และbuildแพลตฟอร์มที่ส่ง ผลผ่านเดิมไม่ได้ทดแทนregressionใหม่
- หลักฐานก่อนแก้ที่subjectนี้:backend166/166ผ่าน, Flutter253/253ผ่าน, analyzerclean. Cycle1มีbackend4และmobile3reproductions; cycle2เพิ่มbackend3และmobile11probesที่assertพฤติกรรมเสีย ไม่ใช่testsรับรองว่าพฤติกรรมถูกต้อง
- ทดสอบDBเฉพาะฐานทิ้งได้*_testตามharnessที่ตรวจแล้ว เก็บข้อมูลshortreelและไฟล์ของผู้ใช้
- แยกmanual/devicegatesที่ยังทำไม่ได้อย่างตรงไปตรงมา ไม่ประกาศว่าทั้งระบบครบเพียงเพราะunit/widget/integrationtestsเขียว

รายงานนี้ตรวจพบเฉพาะขอบเขตsource/หลักฐานที่เข้าถึงได้ ไม่ใช่คำรับรองว่าไม่มีบั๊กอื่น รอบรีวิวไม่ได้แก้sourceหรือข้อมูลจริง
