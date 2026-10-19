<?php

namespace App\Support;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;
use Throwable;

/**
 * Record search for the command palette. Resources are listed centrally so no
 * resource class has to change; each entry only uses columns that really
 * exist, and every result respects the resource's own access rules.
 */
class AdminSearch
{
    /** resource => [columns searched, title column, subtitle column] */
    private const SOURCES = [
        \App\Filament\Resources\ProductResource::class => [['item_code', 'item_name', 'piece_barcode', 'zb_name_ar', 'foreign_name'], 'item_name', 'item_code'],
        \App\Filament\Resources\ZooboxiOrderResource::class => [['woo_order_number', 'customer_name', 'customer_phone'], 'woo_order_number', 'customer_name'],
        \App\Filament\Resources\PurchaseOrderResource::class => [['po_number', 'sap_doc_num', 'pq_ref', 'factory_name'], 'po_number', 'doc_date'],
        \App\Filament\Resources\ShipmentResource::class => [['mbl', 'hbl', 'commercial_invoice_no', 'customs_manifest_no', 'order_description'], 'mbl', 'order_description'],
        \App\Filament\Resources\SupplierResource::class => [['name', 'sap_code'], 'name', 'sap_code'],
        \App\Filament\Resources\MuntajatCustomerResource::class => [['card_code', 'card_name', 'card_foreign_name', 'phone1'], 'card_name', 'card_code'],
        \App\Filament\Resources\ShipGoCustomerResource::class => [['card_code', 'card_name'], 'card_name', 'card_code'],
        \App\Filament\Resources\CustomerResource::class => [['card_code', 'card_name', 'phone1'], 'card_name', 'card_code'],
        \App\Filament\Resources\ProductRegistrationResource::class => [['item_code', 'item_name', 'name_ar', 'certificate_number'], 'item_name', 'item_code'],
        \App\Filament\Resources\SapInvoiceResource::class => [['doc_num', 'card_code'], 'doc_num', 'card_code'],
        \App\Filament\Resources\MuntajatInvoiceResource::class => [['doc_num', 'card_code', 'card_name'], 'doc_num', 'card_name'],
        \App\Filament\Resources\BrandResource::class => [['code', 'name'], 'name', 'code'],
        \App\Filament\Resources\WarehouseResource::class => [['warehouse_code', 'warehouse_name'], 'warehouse_name', 'warehouse_code'],
    ];

    private const PER_SOURCE = 4;

    private const MAX_TOTAL = 16;

    /** @return array<int, array{group: string, title: string, sub: ?string, url: string}> */
    public static function search(string $q): array
    {
        $q = trim($q);
        if (mb_strlen($q) < 2) {
            return [];
        }
        $like = '%' . str_replace(['%', '_'], ['\%', '\_'], $q) . '%';
        $out = [];

        foreach (self::SOURCES as $resource => [$columns, $titleCol, $subCol]) {
            if (count($out) >= self::MAX_TOTAL) {
                break;
            }
            try {
                if (! class_exists($resource) || ! $resource::canViewAny()) {
                    continue;
                }
                /** @var class-string<Model> $model */
                $model = $resource::getModel();
                $table = (new $model)->getTable();
                $cols = array_values(array_filter($columns, fn ($c) => self::hasColumn($table, $c)));
                if (! $cols) {
                    continue;
                }
                $rows = $model::query()
                    ->where(function (Builder $w) use ($cols, $like) {
                        foreach ($cols as $c) {
                            $w->orWhere($c, 'like', $like);
                        }
                    })
                    ->limit(self::PER_SOURCE)
                    ->get();

                foreach ($rows as $row) {
                    $title = (string) ($row->{$titleCol} ?? '') ?: '#' . $row->getKey();
                    $url = $resource::getGlobalSearchResultUrl($row)
                        ?? $resource::getUrl('index', ['tableSearch' => $row->{$cols[0]} ?? $q]);
                    $sub = $row->{$subCol} ?? null;
                    $out[] = [
                        'group' => AdminShell::screenLabel(AdminShell::pathKey($resource::getUrl('index'))) ?? $resource::getPluralModelLabel(),
                        'title' => $title,
                        'sub' => $sub instanceof \DateTimeInterface ? $sub->format('Y-m-d') : (filled($sub) ? (string) $sub : null),
                        'url' => $url,
                    ];
                }
            } catch (Throwable $e) {
                report($e);
            }
        }

        return array_slice($out, 0, self::MAX_TOTAL);
    }

    private static function hasColumn(string $table, string $column): bool
    {
        $cols = Cache::remember("admin-search.cols.$table", 3600, fn () => Schema::getColumnListing($table));

        return in_array($column, $cols, true);
    }
}
