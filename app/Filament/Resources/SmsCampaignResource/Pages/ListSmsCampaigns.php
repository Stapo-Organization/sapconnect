<?php

namespace App\Filament\Resources\SmsCampaignResource\Pages;

use App\Filament\Resources\SmsCampaignResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListSmsCampaigns extends ListRecords
{
    protected static string $resource = SmsCampaignResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('usage_guide')
                ->label('دليل الاستخدام')
                ->icon('heroicon-o-information-circle')
                ->color('gray')
                ->modalHeading('طريقة استخدام حملات الرسائل القصيرة')
                ->modalContent(new \Illuminate\Support\HtmlString('
                    <div class="prose max-w-none" dir="rtl">
                        <h3>1. إنشاء حملة</h3>
                        <p>اضغط على <strong>New Sms Campaign</strong> وأدخل اسم الحملة ونص الرسالة.</p>
                        
                        <h3>2. المتغيرات في الرسالة</h3>
                        <p>يمكنك استخدام متغيرات في نص الرسالة عن طريق وضع اسم العمود من ملف الإكسل بين قوسين معقوفين.</p>
                        <p><strong>مثال:</strong> "مرحباً {Name}، رصيد نقاطك هو {Balance}"</p>
                        
                        <h3>3. ملف المستلمين</h3>
                        <p>قم برفع ملف Excel أو CSV. <strong>يجب</strong> أن يحتوي الملف على صف عناوين (Header Row).</p>
                        <p>النظام يتعرف تلقائياً على رقم الجوال إذا كان اسم العمود "Phone" أو "Mobile" أو "Jawwal". في حال عدم وجود هذه الأسماء، سيتم استخدام العمود الأول كرقم الجوال.</p>
                        <p><strong>مثال لهيكلة الملف:</strong></p>
                        <table class="w-full text-sm border-collapse border border-gray-300">
                            <tr class="bg-gray-100">
                                <th class="border border-gray-300 p-2">Mobile</th>
                                <th class="border border-gray-300 p-2">Name</th>
                                <th class="border border-gray-300 p-2">Balance</th>
                            </tr>
                            <tr>
                                <td class="border border-gray-300 p-2">9665xxxxxxxx</td>
                                <td class="border border-gray-300 p-2">محمد أحمد</td>
                                <td class="border border-gray-300 p-2">500</td>
                            </tr>
                        </table>
                        
                        <h3>4. الاختبار والإرسال</h3>
                        <p>بعد حفظ الحملة، استخدم زر <strong>Test Send</strong> (أيقونة الطائرة الورقية) لإرسال رسالة تجريبية إلى جوالك للتأكد من النص.</p>
                        <p>بعد التأكد، اضغط على زر <strong>Send to All</strong> (أيقونة الصاروخ) لبدء الإرسال لجميع العملاء في الملف.</p>
                    </div>
                '))
                ->modalSubmitAction(false)
                ->modalCancelAction(fn($action) => $action->label('إغلاق')),
            Actions\CreateAction::make(),
        ];
    }
}
