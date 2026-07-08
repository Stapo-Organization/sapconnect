<?php

namespace App\Filament\Resources\DraftInvoiceImportResource\Pages;

use App\Filament\Resources\DraftInvoiceImportResource;
use Filament\Actions;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;

class ListDraftInvoiceImports extends ListRecords
{
    protected static string $resource = DraftInvoiceImportResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('launch')
                ->label('رفع تقرير → مسودات فواتير')
                ->icon('heroicon-o-arrow-up-tray')
                ->color('success')
                ->modalHeading('استيراد تقرير مبيعات كمسودات فواتير SAP')
                ->modalDescription('كل مستودع يُقسَّم لمسودات (chunk أسطر/مسودة). المسودة لا تترحّل في SAP حتى تفتحها وتضغط Add يدوياً.')
                ->modalWidth('2xl')
                ->modalSubmitActionLabel('ابدأ')
                ->form([
                    Forms\Components\FileUpload::make('file')
                        ->label('ملف التقرير (Excel/CSV)')
                        ->required()
                        ->disk('local')
                        ->directory('draft_invoices/uploads')
                        ->visibility('private')
                        ->preserveFilenames()
                        ->storeFiles(true)
                        ->acceptedFileTypes([
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                            'application/vnd.ms-excel',
                            'text/csv',
                            'text/plain',
                        ]),

                    Forms\Components\Grid::make(2)->schema([
                        Forms\Components\TextInput::make('company_db')
                            ->label('قاعدة بيانات SAP')
                            ->default(fn () => session('sap_company_db', config('draft_invoices.default_db')))
                            ->required(),
                        Forms\Components\TextInput::make('card_code')
                            ->label('كود العميل (BP)')
                            ->placeholder('اتركه فاضي ليُؤخذ من عمود BP Code')
                            ->helperText('مثال: CAPP0004'),
                        Forms\Components\DatePicker::make('doc_date')
                            ->label('تاريخ المستند')
                            ->default(now())
                            ->required(),
                        Forms\Components\TextInput::make('chunk_size')
                            ->label('أسطر لكل مسودة (chunk)')
                            ->numeric()->minValue(1)->default(200)->required()
                            ->helperText('27 ألف سطر لمستودع واحد لا تنفع في POST واحد.'),
                        Forms\Components\TextInput::make('expense_code')
                            ->label('كود مصاريف الشحن (Freight)')
                            ->numeric()
                            ->default(fn () => config('draft_invoices.default_expense_code'))
                            ->helperText('يُجمع الشحن ويُرسل في هيدر كل مسودة. اتركه فاضي لتجاهل الشحن.'),
                        Forms\Components\TextInput::make('tax_code')
                            ->label('كود الضريبة (اختياري)')
                            ->placeholder('اتركه فاضي ليستخدم الافتراضي في SAP'),
                        Forms\Components\TextInput::make('warehouse_filter')
                            ->label('مستودع واحد فقط (اختياري)')
                            ->placeholder('مثال: UZH002 — جرّب الأصغر أولاً')
                            ->helperText('ينفع تختبر مستودع صغير قبل تشغيل الكل.'),
                    ]),

                    Forms\Components\Toggle::make('no_batches')
                        ->label('بدون باتشات (لا تُسند دفعات للأصناف)')
                        ->default(false)
                        ->helperText('فعّلها لملفات مثل Panda اللي ما تبي لها اختيار باتشات.'),

                    Forms\Components\Toggle::make('dry_run')
                        ->label('معاينة فقط (Dry Run) — لا يكتب أي شيء في SAP')
                        ->default(true)
                        ->helperText('شغّلها أول مرة دائماً عشان تراجع المخرجات قبل الترحيل الفعلي.'),
                ])
                ->action(function (array $data) {
                    $run = DraftInvoiceImportResource::startRun($data);

                    Notification::make()
                        ->title('بدأت العملية #' . $run->id)
                        ->body($run->mode === 'post'
                            ? 'يتم إنشاء المسودات في SAP بالخلفية. حدّث الجدول لمتابعة الحالة.'
                            : 'يتم تجهيز المعاينة بالخلفية. حمّل ملف «المعاينة» عند اكتمالها.')
                        ->success()
                        ->send();
                }),

            Actions\Action::make('instructions')
                ->label('تعليمات')
                ->icon('heroicon-o-information-circle')
                ->color('gray')
                ->modalHeading('كيف تعمل أداة مسودات الفواتير')
                ->modalSubmitAction(false)
                ->modalCancelActionLabel('إغلاق')
                ->modalContent(new \Illuminate\Support\HtmlString('
                    <div dir="rtl" class="space-y-3 text-sm">
                        <div class="p-3 bg-blue-50 border-r-4 border-blue-500 rounded">
                            ترفع تقرير مبيعات مسطّح (كل سطر = صنف مُباع) فيتحوّل إلى <b>مسودات</b> فواتير SAP
                            (Drafts / oInvoices). المسودة آمنة: لا تترحّل محاسبياً/مخزنياً حتى تفتحها وتضغط <b>Add</b> يدوياً في SAP.
                        </div>
                        <ul class="list-disc list-inside space-y-1 text-gray-700">
                            <li>التجميع <b>لكل مستودع</b>، ويُقسَّم المستودع لمسودات بحجم «أسطر لكل مسودة».</li>
                            <li><b>السعر</b> يُؤخذ كما هو من عمود Unit Price في الملف (بدون إعادة حساب من SAP).</li>
                            <li>الأصناف المُدارة بالباتش: تُسند أقرب الباتشات انتهاءً (FEFO) من رصيد نفس المستودع.</li>
                            <li>الشحن (Freight) يُجمع ويُرسل في <b>هيدر</b> كل مسودة كمصروف إضافي.</li>
                            <li><b>Dry Run</b> أولاً: يولّد معاينة كاملة + تقرير استثناءات بدون أي كتابة في SAP.</li>
                            <li>إعادة التشغيل آمنة: المسودات المُرحّلة سابقاً تُتخطّى تلقائياً (لا تكرار).</li>
                            <li>للملفات الكبيرة (مثل RUH ~27 ألف سطر) يعمل العامل في الخلفية. لو بقيت الحالة «بالانتظار»، انسخ أمر SSH من «تفاصيل» وشغّله.</li>
                        </ul>
                    </div>
                ')),
        ];
    }
}
