<?php

namespace App\Livewire;

use App\Models\Product;
use App\Models\InventoryCounting;
use App\Models\InventoryCountingLine;
use Livewire\Component;
use Filament\Notifications\Notification;

class InventoryScanner extends Component
{
    public ?int $countingId = null;
    public string $barcode = '';
    public array $items = [];
    public bool $isReadOnly = false;

    public function mount(?int $countingId = null, bool $isReadOnly = false): void
    {
        $this->countingId = $countingId;
        $this->isReadOnly = $isReadOnly;

        // Load existing lines if editing/viewing
        if ($countingId) {
            $counting = InventoryCounting::with('lines')->find($countingId);
            if ($counting) {
                $this->items = $counting->lines->map(function ($line) {
                    return [
                        'line_id' => $line->id,
                        'item_code' => $line->item_code,
                        'item_name' => $line->item_name,
                        'piece_barcode' => $line->piece_barcode,
                        'counted_quantity' => (float) $line->counted_quantity,
                        'image_url' => $line->image_url,
                    ];
                })->toArray();
            }
        }
    }

    public function scanBarcode(): void
    {
        if ($this->isReadOnly) return;

        $code = trim($this->barcode);
        if (empty($code)) return;

        // Look up product by barcode or item_code
        $product = Product::where('piece_barcode', $code)
            ->orWhere('item_code', $code)
            ->first();

        if (!$product) {
            Notification::make()
                ->title(__('Product not found'))
                ->body(__('No product found for barcode') . ': ' . $code)
                ->danger()
                ->send();
            $this->barcode = '';
            return;
        }

        // Check if already scanned — if so, increment quantity
        $existingIndex = collect($this->items)->search(fn ($item) => $item['item_code'] === $product->item_code);

        if ($existingIndex !== false) {
            $this->items[$existingIndex]['counted_quantity'] += 1;
        } else {
            $this->items[] = [
                'line_id' => null,
                'item_code' => $product->item_code,
                'item_name' => $product->item_name,
                'piece_barcode' => $product->piece_barcode,
                'counted_quantity' => 1,
                'image_url' => $product->image_url,
            ];
        }

        $this->barcode = '';

        // Auto-save if editing existing counting
        if ($this->countingId) {
            $this->saveLines();
        }
    }

    public function updateQuantity(int $index, $quantity): void
    {
        if ($this->isReadOnly) return;

        $qty = max(0, (float) $quantity);
        if (isset($this->items[$index])) {
            $this->items[$index]['counted_quantity'] = $qty;

            // Auto-save if editing
            if ($this->countingId) {
                $this->saveLines();
            }
        }
    }

    public function removeItem(int $index): void
    {
        if ($this->isReadOnly) return;

        // Delete from DB if it has a line_id
        if (isset($this->items[$index]['line_id']) && $this->items[$index]['line_id']) {
            InventoryCountingLine::where('id', $this->items[$index]['line_id'])->delete();
        }

        array_splice($this->items, $index, 1);
    }

    public function saveLines(): void
    {
        if (!$this->countingId) return;

        $counting = InventoryCounting::find($this->countingId);
        if (!$counting || $counting->isCompleted()) return;

        // Sync items to database
        $existingIds = [];

        foreach ($this->items as &$item) {
            if ($item['line_id']) {
                // Update existing line
                $line = InventoryCountingLine::find($item['line_id']);
                if ($line) {
                    $line->update(['counted_quantity' => $item['counted_quantity']]);
                    $existingIds[] = $line->id;
                }
            } else {
                // Create new line
                $line = $counting->lines()->create([
                    'item_code' => $item['item_code'],
                    'item_name' => $item['item_name'],
                    'piece_barcode' => $item['piece_barcode'],
                    'counted_quantity' => $item['counted_quantity'],
                ]);
                $item['line_id'] = $line->id;
                $existingIds[] = $line->id;
            }
        }

        // Remove lines that were deleted from the UI
        $counting->lines()->whereNotIn('id', $existingIds)->delete();
    }

    public function getItemsForCreate(): array
    {
        return $this->items;
    }

    public function render()
    {
        return view('livewire.inventory-scanner');
    }
}
