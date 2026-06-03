<div class="space-y-6 text-sm leading-relaxed" dir="rtl">

    {{-- مقدمة --}}
    <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-xl p-5">
        <h3 class="text-lg font-bold text-blue-800 dark:text-blue-300 mb-2">🎯 ما هو الجرد الدوري؟</h3>
        <p class="text-blue-700 dark:text-blue-400">
            الجرد الدوري هو نظام ذكي لفحص المخزون بشكل منتظم <strong>دون إيقاف العمل</strong>. بدلاً من جرد كامل مرة واحدة (الذي يتطلب أيام عمل كاملة)، يتم جرد مجموعة صغيرة من المنتجات كل أسبوع بنظام دوري حتى يُغطى كامل المخزون.
        </p>
    </div>

    {{-- كيف يعمل --}}
    <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-5">
        <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">⚙️ كيف يعمل النظام؟</h3>
        <div class="space-y-3">
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 rounded-full flex items-center justify-center font-bold text-sm">1</span>
                <div>
                    <p class="font-semibold text-gray-800 dark:text-gray-200">تصنيف ABC</p>
                    <p class="text-gray-600 dark:text-gray-400">النظام يحلل مبيعات آخر 12 شهر ويصنف كل منتج إلى فئة A (عالي القيمة) أو B (متوسط) أو C (منخفض) تلقائياً.</p>
                </div>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 rounded-full flex items-center justify-center font-bold text-sm">2</span>
                <div>
                    <p class="font-semibold text-gray-800 dark:text-gray-200">إنشاء خطة لكل فرع</p>
                    <p class="text-gray-600 dark:text-gray-400">تُنشئ خطة جرد دوري لكل مستودع/فرع، وتحدد: كم منتج يُجرد أسبوعياً، وكم مرة تُجرد كل فئة خلال الدورة.</p>
                </div>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 rounded-full flex items-center justify-center font-bold text-sm">3</span>
                <div>
                    <p class="font-semibold text-gray-800 dark:text-gray-200">توليد القوائم الأسبوعية تلقائياً</p>
                    <p class="text-gray-600 dark:text-gray-400">كل يوم الساعة 6 صباحاً، النظام يفحص الخطط النشطة وينشئ قائمة جرد جديدة للمنتجات المستحقة، مع أولوية للمنتجات التي لم تُجرد أو عندها فروقات سابقة.</p>
                </div>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 rounded-full flex items-center justify-center font-bold text-sm">4</span>
                <div>
                    <p class="font-semibold text-gray-800 dark:text-gray-200">الجرد الأعمى (Blind Count)</p>
                    <p class="text-gray-600 dark:text-gray-400">مدير الفرع يجرد المنتجات في التطبيق <strong>بدون رؤية الكمية النظامية</strong>. هذا يضمن دقة العد دون تحيز.</p>
                </div>
            </div>
            <div class="flex items-start gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 rounded-full flex items-center justify-center font-bold text-sm">5</span>
                <div>
                    <p class="font-semibold text-gray-800 dark:text-gray-200">تقرير الفروقات</p>
                    <p class="text-gray-600 dark:text-gray-400">عند إكمال الجرد، النظام يحسب الفروقات تلقائياً ويُنشئ تقريراً مفصلاً بنسبة الدقة والمنتجات المخالفة. <strong>القرار إداري بحت</strong> — النظام لا يعدّل SAP.</p>
                </div>
            </div>
        </div>
    </div>

    {{-- إعدادات الخطة --}}
    <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-5">
        <h3 class="text-lg font-bold text-gray-800 dark:text-gray-200 mb-3">📋 شرح إعدادات الخطة</h3>
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="border-b border-gray-200 dark:border-gray-700">
                        <th class="text-right py-2 px-3 font-semibold text-gray-700 dark:text-gray-300">الإعداد</th>
                        <th class="text-right py-2 px-3 font-semibold text-gray-700 dark:text-gray-300">القيمة الموصى بها</th>
                        <th class="text-right py-2 px-3 font-semibold text-gray-700 dark:text-gray-300">الشرح</th>
                    </tr>
                </thead>
                <tbody>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">الحد الأسبوعي</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">120 منتج</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">عدد المنتجات المراد جردها كل أسبوع (≈ 3 ساعات عمل بمعدل 1.5 دقيقة/منتج)</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">طول الدورة</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">13 أسبوع</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">مدة الدورة الكاملة (13 أسبوع = ربع سنة). بعد انتهاء الدورة تبدأ دورة جديدة.</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">تكرار فئة A</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">4 مرات / دورة</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">المنتجات الأعلى قيمة في المبيعات تُجرد 4 مرات كل ربع (مرة كل 3 أسابيع تقريباً)</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">تكرار فئة B</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">2 مرة / دورة</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">المنتجات المتوسطة تُجرد مرتين كل ربع</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">تكرار فئة C</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">1 مرة / دورة</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">المنتجات المنخفضة تُجرد مرة واحدة كل ربع</td>
                    </tr>
                    <tr class="border-b border-gray-100 dark:border-gray-800">
                        <td class="py-2 px-3 font-semibold text-gray-800 dark:text-gray-200">تسامح A / B / C</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">2% / 5% / 10%</td>
                        <td class="py-2 px-3 text-gray-600 dark:text-gray-400">نسبة الفرق المقبولة لكل فئة. فروقات ضمن التسامح لا تظهر كمخالفات.</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    {{-- مثال عملي --}}
    <div class="bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800 rounded-xl p-5">
        <h3 class="text-lg font-bold text-emerald-800 dark:text-emerald-300 mb-2">💡 مثال عملي</h3>
        <p class="text-emerald-700 dark:text-emerald-400 mb-3">
            فرع فيه <strong>2,000 منتج</strong> (A: 300 | B: 400 | C: 1,300):
        </p>
        <ul class="list-disc list-inside space-y-1 text-emerald-700 dark:text-emerald-400">
            <li>الحد الأسبوعي: <strong>120 منتج</strong></li>
            <li>كل أسبوع يُجرد: ~35 منتج A + ~25 منتج B + ~60 منتج C</li>
            <li>خلال 13 أسبوع: كل منتجات A تُجرد 4 مرات، B مرتين، C مرة واحدة</li>
            <li>الجهد الأسبوعي: <strong>≈ 3 ساعات</strong> فقط</li>
        </ul>
    </div>

    {{-- أزرار الإجراءات --}}
    <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl p-5">
        <h3 class="text-lg font-bold text-amber-800 dark:text-amber-300 mb-2">🔧 الأزرار المتاحة</h3>
        <div class="space-y-2 text-amber-700 dark:text-amber-400">
            <p><strong>▶ Generate Now:</strong> ينشئ قائمة جرد أسبوعية فورية بدون انتظار الجدول التلقائي.</p>
            <p><strong>🔄 Re-classify ABC:</strong> يعيد حساب تصنيف ABC بناءً على أحدث بيانات المبيعات.</p>
            <p><strong>✏️ Edit:</strong> تعديل إعدادات الخطة (الحد الأسبوعي، التكرارات، التسامح).</p>
        </div>
    </div>

</div>
