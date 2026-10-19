<?php

namespace App\Filament\Resources\InventoryCountingResource\Pages;

use App\Filament\Resources\InventoryCountingResource;
use Filament\Resources\Pages\ViewRecord;
use Filament\Infolists\Infolist;
use Filament\Infolists\Components;

class ViewInventoryCounting extends ViewRecord
{
    protected static string $resource = InventoryCountingResource::class;

    protected static string $view = 'filament.resources.inventory-counting.view';

    /** Full-count entries list: one shelf, and/or an item search (name, code, barcode). */
    public ?string $fcShelf = null;

    public string $fcSearch = '';

    /** Item-by-item comparison with SAP: which list is open (match | over | short), and its search. */
    public string $fcCmp = 'short';

    public string $fcCmpSearch = '';

    /** A wall-to-wall count run from the HUB board gets its live progress view instead. */
    private function isBoardCount(): bool
    {
        return $this->record->counting_type === 'full' && $this->record->phase !== null;
    }

    public function getView(): string
    {
        return $this->isBoardCount() ? 'filament.resources.inventory-counting.full-count' : static::$view;
    }

    /** Entries can be corrected while the count runs, by the roles that run it. */
    public function canEditEntries(): bool
    {
        return $this->isBoardCount() && $this->record->isInProgress()
            && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager']);
    }

    private function entry(array $arguments): \App\Models\InventoryCountingLine
    {
        return \App\Models\InventoryCountingLine::where('inventory_counting_id', $this->record->id)->findOrFail($arguments['line'] ?? 0);
    }

    /** Fix a counted entry: quantity, shelf or the item itself (a wrong product scanned). */
    public function editLineAction(): \Filament\Actions\Action
    {
        return \Filament\Actions\Action::make('editLine')
            ->modalHeading(__('Edit entry'))
            ->modalWidth('lg')
            ->visible(fn () => $this->canEditEntries())
            ->fillForm(function (array $arguments) {
                $l = $this->entry($arguments);
                return ['item_code' => $l->item_code, 'location_code' => $l->location_code, 'counted_quantity' => (float) $l->counted_quantity, 'reason' => null];
            })
            ->form([
                \Filament\Forms\Components\Select::make('item_code')
                    ->label(__('Item'))
                    ->required()
                    ->searchable()
                    ->getSearchResultsUsing(function (string $search) {
                        $like = '%' . $search . '%';
                        return \App\Models\Product::where('item_code', 'like', $like)->orWhere('piece_barcode', 'like', $like)
                            ->orWhere('zb_name_ar', 'like', $like)->orWhere('item_name', 'like', $like)
                            ->limit(30)->get()->mapWithKeys(fn ($p) => [$p->item_code => $p->item_code . ' · ' . ($p->zb_name_ar ?: $p->item_name)])->all();
                    })
                    ->getOptionLabelUsing(fn ($value) => ($p = \App\Models\Product::where('item_code', $value)->first()) ? $value . ' · ' . ($p->zb_name_ar ?: $p->item_name) : $value),
                \Filament\Forms\Components\Select::make('location_code')
                    ->label(__('Shelf'))
                    ->required()
                    ->searchable()
                    ->options(fn () => \App\Models\StoreLocation::where('warehouse_code', $this->record->warehouse_code)
                        ->orderBy('sort')->orderBy('code')->pluck('code', 'code')->put(\App\Services\Counting\FullCountService::MISSING_LOCATION, __('Missing sweep'))->all()),
                \Filament\Forms\Components\TextInput::make('counted_quantity')
                    ->label(__('Pieces'))
                    ->numeric()->minValue(0)->maxValue(100000)->required(),
                \Filament\Forms\Components\TextInput::make('reason')
                    ->label(__('Reason for the change'))
                    ->maxLength(200),
            ])
            ->action(function (array $data, array $arguments) {
                $l = $this->entry($arguments);
                $before = sprintf('%s @ %s × %s', $l->item_code, $l->location_code ?? '—', rtrim(rtrim(number_format((float) $l->counted_quantity, 3, '.', ''), '0'), '.'));
                $qty = (float) $data['counted_quantity'];
                $changes = ['location_code' => $data['location_code'], 'counted_quantity' => $qty];

                if ($data['item_code'] !== $l->item_code) {
                    $p = \App\Models\Product::where('item_code', $data['item_code'])->firstOrFail();
                    $book = (float) (\App\Models\InventoryCountingSnapshot::where('inventory_counting_id', $this->record->id)
                        ->where('item_code', $p->item_code)->value('system_qty') ?? 0);
                    $changes += ['item_code' => $p->item_code, 'item_name' => $p->item_name, 'piece_barcode' => $p->piece_barcode, 'system_quantity' => $book, 'expiries' => null];
                }
                if (abs($qty - (float) $l->counted_quantity) > 0.0001) {
                    // A carton breakdown no longer adds up to a typed quantity.
                    $changes += ['cartons' => null, 'pack_size' => null, 'loose' => null];
                    $exp = $changes['expiries'] ?? $l->expiries;
                    if (is_array($exp) && count($exp) === 1) {
                        $exp[0]['qty'] = $qty;
                        $changes['expiries'] = $exp;
                    } elseif (is_array($exp) && count($exp) > 1) {
                        $changes['expiries'] = null; // the split no longer matches; dates unknown
                    }
                }

                $after = sprintf('%s @ %s × %s', $changes['item_code'] ?? $l->item_code, $changes['location_code'] ?? '—', rtrim(rtrim(number_format($qty, 3, '.', ''), '0'), '.'));
                if ($before === $after) {
                    return;
                }
                $note = trim(($l->investigation_note ? $l->investigation_note . "\n" : '') . sprintf('[%s %s] %s → %s%s',
                    now()->format('Y-m-d H:i'), auth()->user()->name, $before, $after, filled($data['reason'] ?? null) ? ' · ' . $data['reason'] : ''));
                $l->update($changes + ['investigation_note' => $note]);

                \Filament\Notifications\Notification::make()->title(__('Entry updated'))->success()->send();
            });
    }

    /** Remove an entry counted by mistake (a duplicate scan, the wrong shelf twice). */
    public function deleteLineAction(): \Filament\Actions\Action
    {
        return \Filament\Actions\Action::make('deleteLine')
            ->requiresConfirmation()
            ->modalHeading(__('Delete entry?'))
            ->modalDescription(fn (array $arguments) => ($l = \App\Models\InventoryCountingLine::find($arguments['line'] ?? 0))
                ? sprintf('%s · %s · %s', $l->location_code ?? '—', $l->item_code, rtrim(rtrim(number_format((float) $l->counted_quantity, 3, '.', ''), '0'), '.'))
                : null)
            ->color('danger')
            ->visible(fn () => $this->canEditEntries())
            ->action(function (array $arguments) {
                $l = $this->entry($arguments);
                \Illuminate\Support\Facades\Log::info('full-count entry deleted from admin', [
                    'counting_id' => $this->record->id, 'by' => auth()->id(), 'line' => $l->only(['id', 'item_code', 'location_code', 'counted_quantity', 'counted_by', 'count_round', 'created_at']),
                ]);
                $l->delete();
                \Filament\Notifications\Notification::make()->title(__('Entry deleted'))->success()->send();
            });
    }

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\EditAction::make()
                ->visible(fn () => ! $this->isBoardCount() && $this->record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])),
            \Filament\Actions\Action::make('complete')
                ->label(__('Mark as Completed'))
                ->icon('heroicon-o-check-circle')
                ->color('success')
                ->requiresConfirmation()
                // A board count closes only through its approval in the app (book snapshot, recount queues).
                ->visible(fn () => ! $this->isBoardCount() && $this->record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager']))
                ->action(function () {
                    $this->record->markAsCompleted();
                    // Calculate variances
                    $service = new \App\Services\Counting\VarianceCalculationService();
                    $summary = $service->calculateForSession($this->record);
                    \Filament\Notifications\Notification::make()
                        ->title(__('Inventory count completed'))
                        ->body("Match: {$summary['match']} | Over: {$summary['over']} | Short: {$summary['short']}")
                        ->success()
                        ->send();
                    $this->redirect($this->getResource()::getUrl('view', ['record' => $this->record]));
                }),
        ];
    }
}
