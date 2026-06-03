<div class="space-y-6 text-sm leading-relaxed" dir="rtl">

    {{-- مقدمة --}}
    <div class="bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-xl p-5">
        <h3 class="text-lg font-bold text-purple-800 dark:text-purple-300 mb-2">🎯 ما هو تصنيف ABC؟</h3>
        <p class="text-purple-700 dark:text-purple-400">
            تصنيف ABC هو منهجية مبنية على <strong>مبدأ باريتو (80/20)</strong> لتقسيم المنتجات حسب قيمتها في المبيعات. يساعدك على معرفة أي منتجات تستحق اهتماماً أكبر في الجرد والمراقبة.
        </p>
    </div>

    {{-- شرح الفئات --}}
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">

        {{-- فئة A --}}
        <div class="bg-red-50 dark:bg-red-900/20 border-2 border-red-300 dark:border-red-700 rounded-xl p-5 text-center">
            <div class="w-16 h-16 bg-red-100 dark:bg-red-900/40 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-3xl font-black text-red-600 dark:text-red-400">A</span>
            </div>
            <h4 class="font-bold text-red-800 dark:text-red-300 text-base mb-2">المنتجات الأعلى قيمة</h4>
            <p class="text-red-600 dark:text-red-400 text-2xl font-bold mb-1">80%</p>
            <p class="text-red-700 dark:text-red-500 text-xs mb-3">من إجمالي قيمة المبيعات</p>
            <div class="bg-red-100 dark:bg-red-900/30 rounded-lg p-3 text-right">
                <p class="text-red-700 dark:text-red-400 text-xs space-y-1">
                    <span class="block">• عادةً <strong>10-20%</strong> من عدد المنتجات</span>
                    <span class="block">• تُجرد <strong>4 مرات</strong> كل ربع</span>
                    <span class="block">• تسامح: <strong>2%</strong> فقط</span>
                    <span class="block">• أي فرق فيها يؤثر على أرباحك بشكل كبير</span>
                </p>
            </div>
        </div>

        {{-- فئة B --}}
        <div class="bg-amber-50 dark:bg-amber-900/20 border-2 border-amber-300 dark:border-amber-700 rounded-xl p-5 text-center">
            <div class="w-16 h-16 bg-amber-100 dark:bg-amber-900/40 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-3xl font-black text-amber-600 dark:text-amber-400">B</span>
            </div>
            <h4 class="font-bold text-amber-800 dark:text-amber-300 text-base mb-2">المنتجات المتوسطة</h4>
            <p class="text-amber-600 dark:text-amber-400 text-2xl font-bold mb-1">15%</p>
            <p class="text-amber-700 dark:text-amber-500 text-xs mb-3">من إجمالي قيمة المبيعات</p>
            <div class="bg-amber-100 dark:bg-amber-900/30 rounded-lg p-3 text-right">
                <p class="text-amber-700 dark:text-amber-400 text-xs space-y-1">
                    <span class="block">• عادةً <strong>20-30%</strong> من عدد المنتجات</span>
                    <span class="block">• تُجرد <strong>مرتين</strong> كل ربع</span>
                    <span class="block">• تسامح: <strong>5%</strong></span>
                    <span class="block">• تحتاج مراقبة دورية معتدلة</span>
                </p>
            </div>
        </div>

        {{-- فئة C --}}
        <div class="bg-gray-50 dark:bg-gray-700/30 border-2 border-gray-300 dark:border-gray-600 rounded-xl p-5 text-center">
            <div class="w-16 h-16 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-3">
                <span class="text-3xl font-black text-gray-600 dark:text-gray-400">C</span>
            </div>
            <h4 class="font-bold text-gray-800 dark:text-gray-300 text-base mb-2">المنتجات المنخفضة</h4>
            <p class="text-gray-600 dark:text-gray-400 text-2xl font-bold mb-1">5%</p>
            <p class="text-gray-700 dark:text-gray-500 text-xs mb-3">من إجمالي قيمة المبيعات</p>
            <div class="bg-gray-100 dark:bg-gray-700/50 rounded-lg p-3 text-right">
                <p class="text-gray-700 dark:text-gray-400 text-xs space-y-1">
                    <span class="block">• عادةً <strong>50-70%</strong> من عدد المنتجات</span>
                    <span class="block">• تُجرد <strong>مرة واحدة</strong> كل ربع</span>
                    <span class="block">• تسامح: <strong>10%</strong></span>
                    <span class="block">• منتجات بطيئة الحركة أو منخفضة القيمة</span>
                </p>
            </div>
        </div>
    </div>

    {{-- كيف يُحسب التصنيف --}}
    <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-5">
        <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">📊 كيف يُحسب التصنيف؟</h3>
        <div class="space-y-3 text-gray-700 dark:text-gray-400">
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 rounded-full flex items-center justify-center font-bold text-sm">1</span>
                <p>النظام يجمع <strong>إجمالي مبيعات كل منتج في آخر 12 شهر</strong> من بيانات الفواتير (SAP Invoices).</p>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 rounded-full flex items-center justify-center font-bold text-sm">2</span>
                <p>يُرتب المنتجات تنازلياً حسب قيمة المبيعات (السعر × الكمية).</p>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 rounded-full flex items-center justify-center font-bold text-sm">3</span>
                <p>يحسب النسبة التراكمية: أول المنتجات اللي تمثل <strong>80% من القيمة = A</strong>، التالي <strong>15% = B</strong>، الباقي <strong>5% = C</strong>.</p>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 rounded-full flex items-center justify-center font-bold text-sm">4</span>
                <p>المنتجات اللي <strong>ما عندها مبيعات</strong> تُصنف تلقائياً كفئة <strong>C</strong>.</p>
            </div>
        </div>
    </div>

    {{-- الأعمدة --}}
    <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-5">
        <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">📋 شرح الأعمدة في الجدول</h3>
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="border-b border-gray-200 dark:border-gray-700">
                        <th class="text-right py-2 px-3 font-semibold text-gray-700 dark:text-gray-300">العمود</th>
                        <th class="text-right py-2 px-3 font-semibold text-gray-700 dark:text-gray-300">الشرح</th>
                    </tr>
                </thead>
                <tbody>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">قيمة المبيعات السنوية</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">إجمالي ما باعه هذا المنتج في هذا الفرع خلال آخر 12 شهر (بالريال)</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">كمية المبيعات</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">عدد الوحدات المباعة خلال آخر 12 شهر</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">المخزون الحالي</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">كمية المخزون المسجلة في النظام وقت التصنيف</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">عدد مرات الجرد</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">كم مرة تم جرد هذا المنتج في الدورة الحالية</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">آخر جرد</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">تاريخ آخر مرة تم فيها جرد هذا المنتج ("Never" = لم يُجرد أبداً)</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">آخر فرق %</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">نسبة الفرق من آخر عملية جرد. <span class="text-green-600 dark:text-green-400">أخضر ≤2%</span> | <span class="text-amber-600 dark:text-amber-400">أصفر ≤10%</span> | <span class="text-red-600 dark:text-red-400">أحمر >10%</span></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    {{-- نصيحة --}}
    <div class="bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800 rounded-xl p-5">
        <h3 class="text-lg font-bold text-emerald-800 dark:text-emerald-300 mb-2">💡 نصائح</h3>
        <ul class="list-disc list-inside space-y-2 text-emerald-700 dark:text-emerald-400">
            <li>استخدم فلتر <strong>"Never Counted"</strong> لعرض المنتجات اللي لم تُجرد بعد — هذي أولويتك.</li>
            <li>ركز على المنتجات فئة <strong>A</strong> اللي عندها فرق عالي (أحمر) — هذي أكبر تأثير مالي.</li>
            <li>التصنيف يتحدث تلقائياً كل <strong>سبت الساعة 3 صباحاً</strong>. يمكنك إعادة تصنيف يدوياً من صفحة "Cycle Plans".</li>
            <li>البيانات <strong>للقراءة فقط</strong> — التصنيف يتم تلقائياً بناءً على فواتير SAP.</li>
        </ul>
    </div>

</div>
