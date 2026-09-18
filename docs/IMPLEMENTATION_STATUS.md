# Implementation evidence

آخر تحديث: 2026-09-18. لا نشر أو توقيع إنتاجي أو ربط AdMob مصرح به.

| Ticket | الحالة | الدليل الحالي |
|---|---|---|
| T00 | DONE | مشغل اختبار معزول، فشل متعمد مثبت، فحص أخطاء وتسريب وبصمات مصدر. آخر regression: `generated/qa/20260918T200330683245Z`. |
| T01–T03 | DONE_DESKTOP | حالات تشغيل صريحة، تجميد combat، offer tokens، 7 عائلات، حفظ ذري/backup/pending ledger، إيصالات exactly-once. 23 اختبار Python وGodot regression ناجحان. |
| T04–T05 | DONE_DESKTOP | 10×45 ثانية، زعيما 5/10، شاشات menu/pause/tutorial/results/shop/revive/settings، أهداف لمس كبيرة ومسارات رجوع صريحة. |
| T06 | DONE_DESKTOP | ComfyUI منفصل يعمل على RTX 5070؛ 3 خلفيات مراجعة؛ 1620 إطار rig مع 3 اتجاهات/6 حالات/6 أدوار. فحص rigs ناجح. |
| T07 | DONE_DESKTOP | SFX وموسيقى أصلية إجرائية، Music/SFX buses، mute/reduced flash، stress 1200s ناجح: `generated/qa/20260918T092651338719Z`. الأداء على Android غير مختبر. |
| T08 | DONE_DIAGNOSTIC | نموذج Python يحسب كل عائلات التأثيرات والملكية والمتطلبات والدرع والـspread ويعلن حدود الحركة؛ `engine_balance` يشغل actors والمدير والترقيات الحقيقية، والنسخ الثلاث نجحت في 4 بذور. التقارير تشخيص وليست لعبًا بشريًا. |
| T09 | DONE_DEBUG | staging معزول ومنقى من أصول الهويات الأخرى، بصمات config/source/assets، package/save/icon مستقل، artifact جديد ذريًا. آخر APKs موقعة debug بـv2/v3: `20260918T200344486499Z_31b52a3d2f0f` و`20260918T200410342712Z_99b0e361bde8` و`20260918T200432420267Z_abc9bf8b64d9`. |
| T10 | DONE_DESKTOP | Zombie ranged، Space spread+shield+EMP، Ninja melee+dash؛ خلفيات وأيقونات وحركات منفصلة؛ حلقات كاملة ونتائج engine balance لكل نسخة. |
| T11 | BLOCKED_DEVICE | `adb devices` فارغ و`emulator -list-avds` فارغ بتاريخ 2026-09-18. لا يجوز وصف desktop QA كاختبار هاتف. Production signing وAdMob مؤجلان. |
| T12 | DONE | README محدث بأوامر المصنع، إضافة نسخة، الصور، QA، الاستعادة، Android والقيود الصريحة. |

حدود صادقة: لا يوجد جهاز Android متاح، ولا مزود إعلان حي، ولا credentials إنتاجية، ولا ضمان بنسبة تشابه أو قبول Google Play. هذه أمور خارج كود اللعبة الحالي.
