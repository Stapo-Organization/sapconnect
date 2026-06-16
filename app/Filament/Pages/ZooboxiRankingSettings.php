<?php

namespace App\Filament\Pages;

use App\Models\ZooboxiSetting;
use Filament\Actions\Action;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Facades\Artisan;

/**
 * Owner control for the composite ranking weights used by intelligence:build-products.
 * Super-admin only. Saved to zooboxi_settings; applied on the nightly build or on demand.
 */
class ZooboxiRankingSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-adjustments-horizontal';
    protected static ?string $slug = 'zooboxi-ranking-settings';
    protected static ?int $navigationSort = 2;
    protected static string $view = 'filament.pages.zooboxi-ranking-settings';

    public ?array $data = [];

    private const KEYS = [
        'rank_w_avail'     => ['التوفّر — هل بكمية كافية مقابل الطلب', 0.30],
        'rank_w_pop'       => ['الشعبية — سرعة البيع', 0.26],
        'rank_w_margin'    => ['الهامش — الربحية', 0.14],
        'rank_w_clearance' => ['دفعة التصريف — تفريغ المتكدّس', 0.24],
        'rank_w_freshness' => ['الجِدّة — وصل حديثاً', 0.06],
    ];

    public static function canAccess(): bool
    {
        return auth()->check() && auth()->user()->hasRole('Super Admin');
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canAccess();
    }

    public static function getNavigationLabel(): string
    {
        return 'أوزان الترتيب الذكي';
    }

    public function getTitle(): string
    {
        return 'أوزان الترتيب الذكي (Zooboxi)';
    }

    public function mount(): void
    {
        $state = [];
        foreach (self::KEYS as $key => [$label, $default]) {
            $state[$key] = (float) ZooboxiSetting::get($key, $default);
        }
        $this->form->fill($state);
    }

    public function form(Form $form): Form
    {
        $fields = [];
        foreach (self::KEYS as $key => [$label, $default]) {
            $fields[] = TextInput::make($key)
                ->label($label)
                ->numeric()->step(0.01)->minValue(0)->maxValue(1)->required();
        }

        return $form
            ->schema([
                Section::make('أوزان درجة الترتيب المركّبة')
                    ->description('يُفضَّل أن يكون مجموع الأوزان ≈ 1.00. ارفع «التصريف» لتفريغ المتكدّس أسرع، أو «الهامش» للربح، أو «التوفّر» لإبراز ما يصل بسرعة.')
                    ->schema($fields)
                    ->columns(2),
            ])
            ->statePath('data');
    }

    public function submit(): void
    {
        $data = $this->form->getState();
        $sum = 0.0;
        foreach (array_keys(self::KEYS) as $key) {
            $val = (float) ($data[$key] ?? 0);
            $sum += $val;
            ZooboxiSetting::set($key, (string) $val);
        }

        Notification::make()
            ->title('تم حفظ الأوزان')
            ->body('مجموع الأوزان = ' . round($sum, 2) . '. تُطبَّق في البناء الليلي، أو اضغط «أعد البناء الآن».')
            ->success()
            ->send();
    }

    protected function getHeaderActions(): array
    {
        return [
            Action::make('rebuild')
                ->label('🔄 أعد البناء الآن')
                ->color('warning')
                ->requiresConfirmation()
                ->modalHeading('إعادة بناء درجات الترتيب')
                ->modalDescription('يُعيد حساب ترتيب كل المنتجات بالأوزان الحالية (بضع ثوانٍ).')
                ->action(function () {
                    try {
                        @ini_set('memory_limit', '1024M');
                        Artisan::call('intelligence:build-products');
                        Notification::make()
                            ->title('أُعيد بناء الترتيب')
                            ->body('طُبِّقت الأوزان الجديدة على كل المنتجات.')
                            ->success()->send();
                    } catch (\Throwable $e) {
                        Notification::make()->title('فشل البناء')->body($e->getMessage())->danger()->send();
                    }
                }),
        ];
    }
}
