<?php

namespace App\Http\Resources\Sap;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ItemPieceBarcodeResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // $this->resource is the item array from SAP
        $barcodes = $this['ItemBarCodeCollection'] ?? [];
        $pieceBarcode = null;

        // Logic to find Piece Barcode (FreeText == "Piece")
        foreach ($barcodes as $barcode) {
            if (isset($barcode['FreeText']) && $barcode['FreeText'] === 'Piece') {
                $pieceBarcode = $barcode['Barcode'];
                break;
            }
        }

        // Fallback: If no explicit "Piece" barcode, and only one barcode exists, maybe use it?
        // User strictly asked for "show this 800... as Piece_Barcode", implying logic relies on "Piece".
        // We will stick to strict check for now unless user asks otherwise.

        return [
            'ItemCode' => $this['ItemCode'] ?? null,
            'ItemName' => $this['ItemName'] ?? null,
            'ForeignName' => $this['ForeignName'] ?? null,
            'ItemsGroupCode' => $this['ItemsGroupCode'] ?? null,
            'InventoryUOM' => $this['InventoryUOM'] ?? null,
            'SalesItemsPerUnit' => $this['SalesItemsPerUnit'] ?? null,
            'Piece_Barcode' => $pieceBarcode,
        ];
    }
}
