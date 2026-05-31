<?php

namespace App\Filament\Resources\SuggestedStockTransferResource\Pages;

use App\Filament\Resources\SuggestedStockTransferResource;
use Filament\Resources\Pages\ListRecords;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use App\Jobs\CalculateStockOpportunitiesJob;
use Illuminate\Support\Facades\Response;

class ListSuggestedStockTransfers extends ListRecords
{
    protected static string $resource = SuggestedStockTransferResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('export_csv')
                ->label('تصدير التوصيات (إكسل)')
                ->icon('heroicon-o-document-arrow-down')
                ->color('success')
                ->action(function () {
                    $records = \App\Models\SuggestedStockTransfer::with(['product', 'sourceWarehouse'])->orderBy('id', 'desc')->get();
                    
                    // UTF-8 BOM for Microsoft Excel Arabic support
                    $csvData = "\xEF\xBB\xBF"; 
                    $csvData .= "رقم الصنف,اسم الصنف,من مستودع,إلى مستودع,نوع التوزيع,الكمية المقترحة للنقل,سرعة مبيعات المصدر (يومي),المخزون المتبقي فالمصدر,سرعة مبيعات الهدف (يومي),المخزون المتوفر بالهدف\n";

                    foreach ($records as $record) {
                        $productName = $record->product?->item_name ? str_replace('"', '""', $record->product->item_name) : '';
                        $transferType = str_contains(strtolower($record->sourceWarehouse?->warehouse_name ?? ''), 'store') ? 'عرضي' : 'مركزي';
                        
                        $csvData .= sprintf(
                            '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"' . "\n",
                            $record->item_code,
                            $productName,
                            $record->source_warehouse,
                            $record->target_warehouse,
                            $transferType,
                            $record->suggested_quantity,
                            number_format($record->source_ads, 2),
                            $record->source_stock,
                            number_format($record->target_ads, 2),
                            $record->target_stock
                        );
                    }

                    return Response::streamDownload(function () use ($csvData) {
                        echo $csvData;
                    }, 'Smart_Stock_Transfers_' . date('Y_m_d_H_i') . '.csv', [
                        'Content-Type' => 'text/csv; charset=UTF-8',
                    ]);
                }),
                
            Action::make('calculate_now')
                ->label('تشغيل المحرك الذكي للاقتراحات')
                ->icon('heroicon-o-sparkles')
                ->color('warning')
                ->requiresConfirmation()
                ->modalDescription('سيتم حذف الاقتراحات المعلقة وإعادة حسابها بناءً على أحدث بيانات المخزون والمبيعات. هل تريد المتابعة؟')
                ->action(function () {
                    $beforeCount = \App\Models\SuggestedStockTransfer::where('status', 'pending')->count();
                    
                    try {
                        CalculateStockOpportunitiesJob::dispatchSync();
                    } catch (\Exception $e) {
                        Notification::make()
                            ->title('فشل تشغيل المحرك')
                            ->body('خطأ: ' . $e->getMessage())
                            ->danger()
                            ->send();
                        return;
                    }
                    
                    $afterCount = \App\Models\SuggestedStockTransfer::where('status', 'pending')->count();
                    $diff = $afterCount - $beforeCount;
                    $diffText = $diff > 0 ? "+{$diff} اقتراح جديد" : ($diff < 0 ? abs($diff) . " اقتراح أقل" : "نفس العدد");
                    
                    Notification::make()
                        ->title('✅ تم تشغيل المحرك الذكي بنجاح')
                        ->body("النتائج: {$afterCount} اقتراح ({$diffText})\nالوقت: " . now()->format('Y-m-d H:i:s'))
                        ->success()
                        ->duration(10000)
                        ->send();
                }),
        ];
    }
}
