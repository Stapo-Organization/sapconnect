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
                ->label('رفع تقرير مبيعات')
                ->icon('heroicon-o-arrow-up-tray')
                ->color('primary')
                ->modalIcon('heroicon-o-document-arrow-up')
                ->modalHeading('رفع تقرير مبيعات')
                ->modalDescription('نحلّل الملف أولاً بدون ما نكتب أي شيء في SAP: نقسّمه على العملاء، نخصم المرتجعات من المبيعات، ونتأكد إن كل العملاء والأصناف موجودين. بعد ما تراجع الأرقام يظهر لك زر «ارفع إلى SAP».')
                ->modalWidth('2xl')
                ->modalSubmitActionLabel('حلّل الملف')
                ->form([
                    Forms\Components\FileUpload::make('file')
                        ->label('ملف التقرير (Excel أو CSV)')
                        ->helperText('كل سطر = صنف مُباع. الأعمدة المطلوبة: كود الصنف، المستودع، الكمية، السعر. كود العميل (BP Code) ونسبة الخصم (Disc.%) تُقرأ إذا وُجدت.')
                        ->required()
                        ->disk('local')
                        ->directory('draft_invoices/uploads')
                        ->visibility('private')
                        ->preserveFilenames()
                        ->storeFiles(true)
                        ->maxSize(12288) // Livewire temporary-upload cap (12 MB)
                        ->acceptedFileTypes([
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                            'application/vnd.ms-excel',
                            'text/csv',
                            'text/plain',
                        ]),

                    Forms\Components\Grid::make(3)->schema([
                        Forms\Components\DatePicker::make('doc_date')
                            ->label('تاريخ المسودات')
                            ->default(now())
                            ->native(false)
                            ->displayFormat('Y-m-d')
                            ->required(),
                        Forms\Components\TextInput::make('chunk_size')
                            ->label('أسطر لكل مسودة')
                            ->numeric()->minValue(1)->maxValue(500)->default(200)->required(),
                        Forms\Components\TextInput::make('expense_code')
                            ->label('كود مصروف الشحن')
                            ->numeric()
                            ->default(fn () => config('draft_invoices.default_expense_code'))
                            ->helperText('يُستخدم فقط إذا الملف فيه عمود شحن.'),
                    ]),

                    Forms\Components\Section::make('خيارات متقدمة')
                        ->collapsed()
                        ->compact()
                        ->schema([
                            Forms\Components\Grid::make(2)->schema([
                                Forms\Components\TextInput::make('card_code')
                                    ->label('كود عميل واحد لكل الملف')
                                    ->placeholder('فاضي = من عمود BP Code')
                                    ->helperText('اتركه فاضي إذا الملف فيه أكثر من عميل؛ يُقسَّم تلقائياً.'),
                                Forms\Components\TextInput::make('warehouse_filter')
                                    ->label('مستودع واحد فقط')
                                    ->placeholder('مثال: RUH003'),
                                Forms\Components\TextInput::make('tax_code')
                                    ->label('كود الضريبة')
                                    ->placeholder('فاضي = الافتراضي في SAP'),
                                Forms\Components\Placeholder::make('company_db')
                                    ->label('قاعدة بيانات SAP')
                                    ->content(fn () => config('draft_invoices.default_db')),
                            ]),
                            Forms\Components\Toggle::make('with_batches')
                                ->label('إسناد أقرب دفعة انتهاءً (FEFO) للأصناف المُدارة بالدفعات')
                                ->default(false),
                        ]),
                ])
                ->action(function (array $data) {
                    $run = DraftInvoiceImportResource::startAnalysis($data);

                    Notification::make()
                        ->title('بدأ تحليل الملف #' . $run->id)
                        ->body('يأخذ من دقيقة لعدة دقائق حسب حجم الملف. افتح «مراجعة» لمتابعة النتيجة.')
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
                    <div dir="rtl" style="line-height:1.9;font-size:.875rem">
                        <ol style="list-style:decimal;padding-inline-start:1.25rem;margin:0">
                            <li><b>ارفع التقرير</b> (Excel أو CSV، كل سطر = صنف مُباع). أول خطوة دائماً <b>تحليل</b> بدون أي كتابة في SAP.</li>
                            <li><b>العملاء:</b> إذا الملف فيه أكثر من عميل (عمود BP Code) تُقسَّم المسودات لكل عميل، ولا تختلط مبيعات عميلين في مسودة واحدة.</li>
                            <li><b>المرتجعات</b> (كمية بالسالب) ما تُرفع: تُخصم من مبيعات نفس العميل لنفس الصنف — بيع 100 ومرتجع 10 = 90 في المسودة. الأولوية لنفس الطلب، ثم نفس السعر.</li>
                            <li><b>السعر</b> من عمود Unit Price كما هو، و<b>الخصم</b> من عمود Disc.% كنسبة خصم على السطر. الوحدة دائماً حبة، ومركز التكلفة = المستودع.</li>
                            <li><b>الأسطر المكررة</b> حرفياً تُرفع كما هي، وتظهر في تقرير Excel (ورقة Duplicate lines بأعمدة الملف الأصلي) لتُرسل للعميل للمراجعة.</li>
                            <li>إذا فيه <b>عميل أو صنف غير موجود في SAP</b> يتوقف الرفع حتى تصحّح الملف.</li>
                            <li>راجع الأرقام من «مراجعة»، ثم اضغط <b>«ارفع إلى SAP»</b>. المسودة لا تُرحّل حتى تفتحها في SAP وتضغط Add.</li>
                            <li>الرفع آمن من التكرار: لو انقطع أو فشلت مسودة، اضغط الرفع مرة ثانية وتُكمَل الناقصة فقط.</li>
                        </ol>
                    </div>
                ')),
        ];
    }
}
