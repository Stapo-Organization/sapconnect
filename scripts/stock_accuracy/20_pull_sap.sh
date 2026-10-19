#!/usr/bin/env bash
# GET-only pulls from SAP Service Layer (PPTC_V5_PROD) → storage/analysis/raw/sap/*.ndjson.gz
# Groups run in parallel (max 4 SAP sessions); each group is sequential.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$ROOT/storage/analysis/raw/sap"; LOG="$OUT/logs"; mkdir -p "$OUT" "$LOG"
WH="${WH:-RUH010}"; SINCE="${SINCE:-2026-07-01}"
PHP="php -d memory_limit=2G -d error_reporting=E_ALL&~E_DEPRECATED $HERE/php/pull.php"
pull() { # name resource page [extra args...]
  local name="$1" res="$2" page="$3"; shift 3
  $PHP --resource="$res" --page="$page" --out="$OUT/$name.ndjson.gz" "$@" >"$LOG/$name.json" 2>"$LOG/$name.log"
  echo "$(date +%H:%M:%S) $name rc=$? $(cat "$LOG/$name.json" 2>/dev/null | head -c 200)"
}
DOCSEL='DocEntry,DocNum,DocDate,DocTime,CardCode,Cancelled,DocumentStatus,Comments,JournalMemo,Reference2,CreationDate,UpdateDate,UpdateTime,SalesPersonCode,DocumentLines'
(
  pull items Items 100 --select='ItemCode,ItemName,ForeignName,ItemsGroupCode,InventoryItem,TreeType,ManageBatchNumbers,InventoryUOM,SalesUnit,SalesItemsPerUnit,PurchaseUnit,PurchaseItemsPerUnit,UoMGroupEntry,InventoryUoMEntry,DefaultSalesUoMEntry,DefaultPurchasingUoMEntry,DefaultCountingUoMEntry,CountingItemsPerUnit,QuantityOnStock,AvgStdPrice,CreateDate,UpdateDate,UpdateTime,BarCode,ItemBarCodeCollection,ItemWarehouseInfoCollection' --filter="startswith(ItemCode,'P')" --orderby=ItemCode
) &
(
  pull stock_transfers_$WH StockTransfers 200 --select='DocEntry,DocNum,DocDate,DueDate,TaxDate,DocumentStatus,FromWarehouse,ToWarehouse,Comments,JournalMemo,Reference1,Reference2,CreationDate,UpdateDate,StockTransferLines' --filter="(FromWarehouse eq '$WH' or ToWarehouse eq '$WH') and DocDate ge '$SINCE'" --orderby=DocEntry
  pull uom_sample_invoices Invoices 200 --select="$DOCSEL" --filter="DocDate ge '2026-09-21' and Cancelled eq 'tNO'" --orderby='DocEntry desc' --max-pages=15
  pull delivery_notes_probe DeliveryNotes 200 --select="$DOCSEL" --filter="DocDate ge '$SINCE' and Cancelled eq 'tNO'" --orderby=DocEntry --max-pages=80
  pull returns_probe Returns 200 --select="$DOCSEL" --filter="DocDate ge '$SINCE' and Cancelled eq 'tNO'" --orderby=DocEntry --max-pages=40
) &
(
  pull gen_entries InventoryGenEntries 100 --select="$DOCSEL" --filter="DocDate ge '$SINCE'" --orderby=DocEntry
  pull gen_exits InventoryGenExits 100 --select="$DOCSEL" --filter="DocDate ge '$SINCE'" --orderby=DocEntry
) &
(
  pull inventory_postings_headers InventoryPostings 200 --select='DocumentEntry,DocumentNumber,Series,PostingDate,CountDate,CountTime,Remarks,Reference2,JournalRemark' --filter="PostingDate ge '2026-01-01'" --orderby=DocumentEntry
  pull inventory_countings_headers InventoryCountings 200 --select='DocumentEntry,DocumentNumber,Series,CountDate,CountTime,DocumentStatus,Remarks,Reference2,CountingType' --filter="CountDate ge '2025-07-01'" --orderby=DocumentEntry
) &
wait
echo "all pulls finished"; ls -la "$OUT"/*.ndjson.gz
