# Mobile Game Factory

مصنع ألعاب Godot 4.7.2 قابل للتشغيل والتوسعة. ينتج ثلاث تجارب مستقلة من محرك مشترك: Zombie Survivor وSpace Survivor وNinja Survivor. كل نسخة لها هوية، خلفية، أيقونة، شخصيات متحركة، أسلوب قتال وحفظ واسم حزمة منفصل.

## الحلقة الحالية

`Kill → Coins → Upgrade → Stronger enemies → Gems → Permanent upgrades → Repeat`

- 10 مراحل، مدة المرحلة 45 ثانية نشطة، وزعيم في المرحلتين 5 و10.
- سبع عائلات ترقيات: Damage وAttack Speed وCrit وHP وNew Weapon وCompanion وSpecial Ability.
- عملات الجولة لا تدخل البنك إلا عند شاشة النتائج. نقاط الاستعادة تمنع ضياعها أو تكرارها.
- Rewarded Ads لها خدمة معاملات كاملة واختبار DEBUG واضح، لكن مزود إعلانات حقيقي وبيانات AdMob مؤجلان عمدًا.

## تشغيل المشروع

افتح `godot/masterGame/project.godot` في Godot 4.7.2 Standard. التحكم بالسحب على شاشة اللمس أو WASD/الأسهم؛ Space يشغل القدرة بعد فتحها.

الأوامر التالية تُشغّل من جذر المستودع، ويمكن استبدال `python` بمسار Python محلي حديث:

```powershell
python automation/factory.py doctor
python -m unittest discover -s automation/tests
python automation/factory.py qa
python automation/factory.py simulate-engine zombieSurvivor
python automation/factory.py build zombieSurvivor --seed 42
python automation/factory.py batch --seed 42
```

الأسماء المدعومة: `zombieSurvivor` و`spaceSurvivor` و`ninjaSurvivor`. أمر `generate` لا يغيّر نسخة Godot النشطة إلا عند إضافة `--activate`. البناء دائمًا يتم في staging معزول ولا يعيد استخدام APK قديم عند الفشل.

## إضافة نسخة جديدة

1. انسخ أحد ملفات `configs/presets` وغيّر `metadata.id` واسم العرض وهوية اللعب.
2. اجعل الاسم فريدًا وآمنًا؛ المدقق يرفض المسارات، المعرفات المكررة، الترقيات مجهولة التأثير، الأسلحة المفقودة ودورات prerequisites.
3. أضف الخلفية والأيقونة وملف حركة rig للهوية الجديدة، ثم شغّل `validate` و`qa` و`simulate-engine` قبل البناء.
4. لا تعتبر تقرير المحاكاة موافقة متجر أو اختبار احتفاظ؛ هو قياس آلي للمنطق والاتزان فقط.

## الصور والحركة

- الخلفيات الثلاث مولدة محليًا بواسطة بيئة ComfyUI منفصلة داخل `.tools/comfy`، ولم يتغير تثبيت ComfyUI الأصلي.
- أوزان FLUX.2/Qwen/VAE المحلية تطابقت SHA256 مع صفحات المصدر الرسمية ومسجلة في `automation/assets/model_inventory.json`.
- محاولة sprite sheet مولدة آليًا رُفضت لعدم ثبات الوضعيات. الحركة المعتمدة عبارة عن rig أصلي متعدد الطبقات: 3 اتجاهات وidle/run/attack/hit/death/boss telegraph، بإجمالي 540 إطارًا لكل هوية.
- `automation/assets/package_reviewed_art.py` ينسخ فقط الخلفيات التي اجتازت المراجعة إلى اللعبة ويحفظ provenance. `validate_rigs.py` يفحص الشفافية والحدود وتنوع الوضعيات.

## الاختبار والأدلة

كل تشغيل اختبار ينشئ مجلدًا جديدًا داخل `generated/qa` به السجلات ونتيجة قابلة للقراءة آليًا وبصمات المصدر. المشغل يعامل أخطاء scripts وتسريب ObjectDB وغياب علامة اكتمال الاختبار كفشل حتى لو أعاد Godot exit code يساوي صفرًا.

- `regression`: دورة اللعب والحفظ والاستعادة والترقيات والإعلانات الوهمية والنسخ المختلفة.
- `stress`: 1200 ثانية محاكاة فيزيائية وحدود الأعداء والمقذوفات والجثث.
- `render_check --render`: صور فعلية للقائمة واللعب والترقيات والمتجر.
- `engine_balance`: أربع بذور ثابتة بمحرك Godot الحقيقي وسياسة حركة معلنة، وليست لعبًا بشريًا.

## Android

البناء يحتاج Android SDK وJDK 17 وGodot Export Templates. المخرجات داخل `builds/android/<variant>/<build-id>`، ومع كل APK manifest يحتوي package وبصمة artifact والمصدر والـconfig. النسخ الحالية DEBUG فقط.

قبل إصدار حقيقي لا بد من: هاتف/محاكي Android فعلي لاختبار اللمس والأداء والاستعادة، مفاتيح production signing، وربط SDK إعلانات حقيقي ومعرفات الوحدات وسياسة الخصوصية. لا توجد عملية نشر تلقائي على Google Play، ولا توجد نسبة تشابه تضمن قبول المتجر.

## الاستعادة

الحفظ منفصل لكل لعبة، ويكتب ذريًا مع نسخة احتياطية. عند تلف الملف الأساسي تُحمّل النسخة الصحيحة؛ وعند فشل تسوية جولة يحتفظ المشروع بالـpending ledger ويمنع بدء جولة جديدة حتى تنجح إعادة المحاولة. فشل شراء أو مكافأة لا يخصم شيئًا ولا يعرض نجاحًا وهميًا.
