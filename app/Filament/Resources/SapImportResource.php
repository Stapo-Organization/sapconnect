<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SapImportResource\Pages;
use App\Models\SapImport;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Maatwebsite\Excel\Facades\Excel; // We will use generic PHP instead of this if easier, but let's stick to native
use Illuminate\Support\Facades\Storage;

class SapImportResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected static ?string $model = SapImport::class;

    protected static ?string $navigationIcon = 'heroicon-o-arrow-up-tray';
    
    public static function getNavigationLabel(): string
    {
        return __('SAP Importer');
    }

    public static function getModelLabel(): string
    {
        return __('SAP Importer');
    }

    public static function getPluralModelLabel(): string
    {
        return __('SAP Importer');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('SAP Management');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Configuration'))
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->label(__('Profile Name'))
                            ->placeholder(__('e.g. Stock Take Upload')),
                        Forms\Components\TextInput::make('resource')
                            ->required()
                            ->label(__('SAP Resource'))
                            ->placeholder(__('e.g. InventoryCountings'))
                            ->datalist(function () {
                                // Simple list of common ones or dynamic
                                return ['InventoryCountings', 'Orders', 'Invoices', 'BusinessPartners', 'Items'];
                            }),
                        Forms\Components\Select::make('import_mode')
                            ->label(__('Import Mode'))
                            ->options([
                                'Single' => __('Single Record per Row (Simple)'),
                                'Document' => __('Grouped Document (Advanced)'),
                            ])
                            ->default('Single')
                            ->required()
                            ->helperText(__('Single: 1 Request per Row. Document: Multiple Rows grouped into 1 Request (e.g. with Lines/Batches).')),
                        Forms\Components\Toggle::make('auto_batch_enrichment')
                            ->label(__('Auto-Assign Batches (Smart Enrichment)'))
                            ->helperText(__('If enabled, missing batches will be auto-filled from SAP (Expiry > 2026).'))
                            ->columnSpanFull(),
                    ])->columns(2),

                Forms\Components\Section::make(__('User Inputs (Global Parameters)'))
                    ->description(__('Define fields that the user must fill out manually when running the import (e.g. Count Date, Branch ID).'))
                    ->schema([
                        Forms\Components\Repeater::make('prompts')
                            ->label(__('Prompts'))
                            ->schema([
                                Forms\Components\TextInput::make('label')
                                    ->required()
                                    ->label(__('Input Label'))
                                    ->placeholder(__('e.g. Count Date')),
                                Forms\Components\TextInput::make('key')
                                    ->required()
                                    ->label(__('SAP Field Key'))
                                    ->placeholder(__('e.g. CountDate')),
                                Forms\Components\Select::make('type')
                                    ->label(__('Type'))
                                    ->options([
                                        'text' => __('Text'),
                                        'number' => __('Number'),
                                        'date' => __('Date'),
                                        'time' => __('Time'),
                                    ])
                                    ->default('text')
                                    ->required(),
                                Forms\Components\TextInput::make('default')
                                    ->label(__('Default Value')),
                            ])
                            ->columns(2)
                            ->defaultItems(0)
                            ->addActionLabel(__('Add Input Field')),
                    ])->collapsible(),

                Forms\Components\Section::make(__('CSV Mapping'))
                    ->schema([
                        Forms\Components\Repeater::make('mapping')
                            ->label(__('Mapping'))
                            ->schema([
                                Forms\Components\TextInput::make('csv_header')
                                    ->required()
                                    ->label(__('CSV Header Name'))
                                    ->placeholder(__('e.g. ItemCode')),
                                Forms\Components\TextInput::make('sap_field')
                                    ->required()
                                    ->label(__('SAP Field (Dot Notation)'))
                                    ->placeholder(__('e.g. InventoryCountingLines.ItemCode'))
                                    ->datalist(function (Forms\Get $get) {
                                        $resource = $get('../../resource');
                                        if (!$resource)
                                            return [];

                                        // Simple Auto-Discovery for Root Fields + Common Lists
                                        return cache()->remember("sap_schema_flat_{$resource}", 60, function () use ($resource) {
                                            try {
                                                $sap = app(\App\Services\SAP\SapClient::class);
                                                $data = $sap->get($resource, ['$top' => 1]);
                                                $item = $data['value'][0] ?? null;
                                                if (!$item)
                                                    return [];

                                                // Flatten keys for suggestions? Or just root.
                                                // Let's do Root + 1 Level for convenience
                                                $suggestions = array_keys($item);
                                                foreach ($item as $key => $val) {
                                                    if (is_array($val) && isset($val[0])) {
                                                        $subKeys = array_keys($val[0]);
                                                        foreach ($subKeys as $k) {
                                                            $suggestions[] = "$key.$k";
                                                            // Check 2nd level (Batches)
                                                            if (is_array($val[0][$k]) && isset($val[0][$k][0])) {
                                                                $subSubKeys = array_keys($val[0][$k][0]);
                                                                foreach ($subSubKeys as $kk) {
                                                                    $suggestions[] = "$key.$k.$kk";
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                return $suggestions;
                                            } catch (\Exception $e) {
                                                return [];
                                            }
                                        });
                                    }),
                            ])
                            ->columns(2)
                            ->defaultItems(1),
                    ]),

                Forms\Components\Section::make(__('Preview'))
                    ->schema([
                        Forms\Components\Placeholder::make('payload_preview')
                            ->label(__('Sample Payload (Result)'))
                            ->content(function (Forms\Get $get) {
                                $mapping = $get('mapping');
                                $mode = $get('import_mode');
                                if (!$mapping || !is_array($mapping))
                                    return __('No mapping defined.');

                                // Sample Data Map (User Requested)
                                $samples = [
                                    'sap code' => 'P17900018',
                                    'itemcode' => 'P17900018',
                                    'product name' => 'Acana Dry Food',
                                    'batch number' => '2024742L2',
                                    'expiry date' => '2026-09-14',
                                    'qty' => 2,
                                    'quantity' => 2,
                                    'warehouse' => 'RUH008',
                                    'whscode' => 'RUH008',
                                    'count date' => '2025-12-18',
                                ];

                                $item = [];
                                foreach ($mapping as $map) {
                                    $key = $map['sap_field'] ?? null;
                                    $header = $map['csv_header'] ?? '';

                                    if ($key) {
                                        $lowerHeader = strtolower($header);
                                        $val = $samples[$lowerHeader] ?? "[$header Value]";

                                        // Auto-cast numeric for preview realism
                                        if (is_numeric($val))
                                            $val = (float) $val;

                                        data_set($item, $key, $val);
                                    }
                                }

                                if ($mode === 'Document') {
                                    // Simulate Document Structure for Inventory Counting (Auto-Sum Preview)
                                    // If we have Lines.Batches, we should highlight that structure.
                                    // But since we are generating from 1 row, data_set creates the arrays.
                                    // Example: InventoryCountingLines.0.BatchNumbers.0.Quantity
                                    // If the user mapped "InventoryCountingLines.BatchNumbers.BatchNumber" (using dot notation without indices)
                                    // data_set interprets it as nested objects, unless we used explicit indices or the Service logic.
                                    // THE SERVICE LOGIC handles the merging.
                                    // The Mapping "InventoryCountingLines.ItemCode" usually produces "InventoryCountingLines": {"ItemCode": ...}
                                    // VALID SAP Payload requires "InventoryCountingLines": [ { ... } ]
                                    // The Service transforms this.
                                    // TO SHOW A VALID PREVIEW, we should probably wrap standard collections in arrays.
                    
                                    // Heuristic: If key is "InventoryCountingLines", wrap it in [].
                                    foreach ($item as $k => $v) {
                                        if (is_array($v) && \Illuminate\Support\Str::endsWith($k, 'Lines')) {
                                            $item[$k] = [$v];
                                            // Deep wrap? 
                                            // Usually BatchNumbers is inside Lines.
                                        }
                                    }
                                    // If we have deeply nested batch numbers from flat mapping:
                                    // User maps: InventoryCountingLines.BatchNumbers.BatchNumber
                                    // Result Item: ['InventoryCountingLines' => ['BatchNumbers' => ['BatchNumber' => ...]]]
                                    // Desired: ['InventoryCountingLines' => [ ['BatchNumbers' => [ ['BatchNumber' => ... ] ] ] ]]
                                    // This is getting complicated to simulate perfectly.
                                    // Let's just show the raw object and a note.
                                }

                                return new \Illuminate\Support\HtmlString(
                                    '<div class="text-xs text-gray-500 mb-2">Preview based on sample data. Arrays [] are implied in Document mode.</div>' .
                                    '<pre class="text-xs bg-gray-100 p-2 rounded">' .
                                    json_encode($item, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) .
                                    '</pre>'
                                );
                            }),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')->label(__('Name'))->sortable()->searchable(),
                Tables\Columns\TextColumn::make('resource')->label(__('Resource'))->sortable(),
                Tables\Columns\TextColumn::make('import_mode')->label(__('Import Mode')),
                Tables\Columns\TextColumn::make('created_at')->label(__('Created At'))->dateTime(),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),

                Tables\Actions\Action::make('download_template')
                    ->label(__('Download Template'))
                    ->icon('heroicon-o-document-arrow-down')
                    ->color('info')
                    ->action(function (SapImport $record) {
                        $headers = collect($record->mapping)->pluck('csv_header')->toArray();
                        if (empty($headers)) {
                            \Filament\Notifications\Notification::make()->title(__('No mappings defined'))->danger()->send();
                            return;
                        }

                        $callback = function () use ($headers) {
                            $file = fopen('php://output', 'w');
                            fputcsv($file, $headers); // Headers
            
                            // Sample Data Map
                            $samples = [
                                'sap code' => 'P17900018',
                                'itemcode' => 'P17900018',
                                'product name' => 'Acana Dry Food',
                                'batch number' => '2024742L2',
                                'expiry date' => '2026-09-14',
                                'qty' => 2,
                                'quantity' => 2,
                                'warehouse' => 'RUH008',
                                'whscode' => 'RUH008',
                                'count date' => '2025-12-18',
                                'uom' => 'PC',
                                'uomcode' => 'PC',
                            ];

                            $sampleRow = [];
                            foreach ($headers as $header) {
                                $lower = strtolower($header);
                                $sampleRow[] = $samples[$lower] ?? "[$header Sample]";
                            }
                            fputcsv($file, $sampleRow);

                            fclose($file);
                        };

                        $headersStr = implode(',', $headers); // Simple fallback/filename
            
                        return response()->stream($callback, 200, [
                            "Content-type" => "text/csv",
                            "Content-Disposition" => "attachment; filename={$record->resource}_template.csv",
                            "Pragma" => "no-cache",
                            "Cache-Control" => "must-revalidate, post-check=0, pre-check=0",
                            "Expires" => "0"
                        ]);
                    })
                    ->authorize('downloadTemplate'),

                Tables\Actions\Action::make('run_import')
                    ->label(__('Run Import'))
                    ->icon('heroicon-o-play')
                    ->color('success')
                    ->form(function (SapImport $record) {
                        $schema = [];

                        // Dynamic Prompts
                        if ($record->prompts && is_array($record->prompts)) {
                            foreach ($record->prompts as $prompt) {
                                $label = $prompt['label'] ?? __('Field');
                                $key = "params." . ($prompt['key'] ?? 'unknown');
                                $type = $prompt['type'] ?? 'text';
                                $default = $prompt['default'] ?? null;

                                $field = null;
                                if ($type === 'date')
                                    $field = Forms\Components\DatePicker::make($key);
                                elseif ($type === 'time')
                                    $field = Forms\Components\TimePicker::make($key);
                                elseif ($type === 'number')
                                    $field = Forms\Components\TextInput::make($key)->numeric();
                                else
                                    $field = Forms\Components\TextInput::make($key);

                                $field->label($label)->required();
                                if ($default)
                                    $field->default($default);

                                $schema[] = $field;
                            }
                        }

                        // Special: Add CostingCode for Inventory Counting
                        if (stripos($record->resource, 'InventoryCountings') !== false || stripos($record->name, 'Inventory') !== false) {
                            $schema[] = Forms\Components\TextInput::make('params.CostingCode')
                                ->label(__('Costing Code'))
                                ->placeholder(__('e.g. 202'))
                                ->required();
                        }

                        $schema[] = Forms\Components\FileUpload::make('file')
                            ->label(__('Upload CSV file'))
                            ->acceptedFileTypes(['text/csv', 'application/vnd.ms-excel', 'text/plain'])
                            ->required()
                            ->disk('local')
                            ->directory('sap_imports')
                            ->visibility('private')
                            ->preserveFilenames()
                            ->storeFiles(true);

                        $schema[] = Forms\Components\Checkbox::make('dry_run')
                            ->label(__('Preview Payload Only (Dry Run)'))
                            ->helperText(__('Check this to see the JSON payload without sending to SAP.'))
                            ->default(true); // Default to Preview for safety
            
                        // Loading Overlay
                        $schema[] = Forms\Components\Placeholder::make('loading_indicator')
                            ->label('')
                            ->content(new \Illuminate\Support\HtmlString('
                                <div 
                                    x-data="{ 
                                        steps: [\'Running Checks...\', \'Validating Data...\', \'Preparing JSON...\', \'Finalizing Payload...\'], 
                                        step: 0
                                    }"
                                    x-init="setInterval(() => { step = (step + 1) % steps.length }, 1800)"
                                    class="fixed inset-0 bg-gray-900/80 z-[100] flex flex-col items-center justify-center space-y-4 transition-opacity duration-300"
                                    style="display: none;" 
                                    wire:loading.flex
                                >
                                    <!-- Animated Dots -->
                                    <div class="flex space-x-2">
                                        <div class="w-3 h-3 bg-white rounded-full animate-bounce [animation-delay:-0.3s]"></div>
                                        <div class="w-3 h-3 bg-white rounded-full animate-bounce [animation-delay:-0.15s]"></div>
                                        <div class="w-3 h-3 bg-white rounded-full animate-bounce"></div>
                                    </div>
                                    
                                    <!-- Cycling Text -->
                                    <div class="text-white font-medium text-lg tracking-wide" x-text="steps[step]"></div>
                                    <div class="text-white/60 text-sm">Please wait while we process your file...</div>
                                </div>
                            '));

                        return $schema;
                    })
                    ->action(function (array $data, SapImport $record, \Filament\Tables\Actions\Action $action) {
                        try {
                            $filePath = $data['file'];
                            // Extract Params
                            $params = $data['params'] ?? [];
                            $dryRun = $data['dry_run'] ?? false;

                            // Resolve absolute path from storage
                            $absolutePath = Storage::disk('local')->path($filePath);

                            $importer = new \App\Services\SapImportService();

                            // Explicitly set the database from Session to ensure isolation
                            // This overrides any constructor default
                            $targetDb = session('sap_company_db', config('sap.company_db'));
                            $importer->setDatabase($targetDb);

                            // Process
                            $result = $importer->process($record, $absolutePath, $params, $dryRun);

                            // Cleanup
                            if (Storage::disk('local')->exists($filePath)) {
                                Storage::disk('local')->delete($filePath);
                            }

                            if ($dryRun) {
                                // Show Preview
                                // Handle new array return format ['preview' => ...]
                                $previewData = $result['preview'] ?? $result;
                                $json = json_encode($previewData, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

                                // Save to file for full viewing
                                Storage::disk('local')->put('last_payload_preview.json', $json);

                                // Increase limit significantly
                                $limit = 50000;
                                $preview = mb_substr($json, 0, $limit) . (strlen($json) > $limit ? "\n... (truncated)" : "");

                                $body = "
                                <div class='relative group' x-data='{ copied: false }'>
                                    <div class='flex justify-between items-center mb-2'>
                                        <div class='text-xs text-gray-400'>Full payload saved to <code>storage/app/private/last_payload_preview.json</code></div>
                                        <button 
                                            type='button'
                                            @click=\"window.navigator.clipboard.writeText(\$el.parentElement.nextElementSibling.innerText); copied = true; setTimeout(() => copied = false, 2000)\"
                                            class='px-2 py-1 text-xs font-medium text-white bg-gray-600 rounded-md hover:bg-gray-500 transition-colors duration-200'
                                            title='Copy Payload'
                                        >
                                            <span x-show='!copied'>Copy</span>
                                            <span x-show='copied' class='text-green-400' style='display: none;'>Copied!</span>
                                        </button>
                                    </div>
                                    <pre style='max-height: 400px; overflow: auto; background: #333; color: #fff; padding: 10px; border-radius: 5px; font-size: 0.8em; margin-top: 5px;'>{$preview}</pre>
                                </div>
                                ";

                                \Filament\Notifications\Notification::make()
                                    ->title('Payload Preview ' . (isset($result['skipped']) && count($result['skipped']) > 0 ? '(With Skips)' : ''))
                                    ->body($body)
                                    ->persistent() // Helper to keep it open
                                    ->warning() // Color
                                    ->send();

                                $action->halt(); // Stop success notification
                            } else {
                                $count = $result['count'] ?? 0;
                                $skipped = $result['skipped'] ?? [];

                                if (!empty($skipped)) {
                                    $skippedCount = count($skipped);
                                    $skippedHtml = "<ul class='mt-2 list-disc list-inside text-sm text-red-100'>";
                                    foreach ($skipped as $s) {
                                        $item = $s['ItemCode'] ?? 'Unknown';
                                        $reason = $s['Reason'] ?? 'Unknown';
                                        $skippedHtml .= "<li><strong>$item</strong>: $reason</li>";
                                    }
                                    $skippedHtml .= "</ul>";

                                    \Filament\Notifications\Notification::make()
                                        ->title(__('Import Partial Success: :count Processed, :skipped Skipped', ['count' => $count, 'skipped' => $skippedCount]))
                                        ->body(new \Illuminate\Support\HtmlString(__('The following items were skipped due to validation errors:') . "<br>$skippedHtml"))
                                        ->persistent()
                                        ->danger()
                                        ->send();
                                } else {
                                    \Filament\Notifications\Notification::make()
                                        ->title(__('Import processed successfully'))
                                        ->body(__('Processed :count records/documents.', ['count' => $count]))
                                        ->success()
                                        ->send();
                                }
                            }

                        } catch (\Throwable $e) {
                            \Filament\Notifications\Notification::make()
                                ->title(__('Import Failed'))
                                ->body($e->getMessage())
                                ->danger()
                                ->send();
                        }
                    })
                    ->authorize('runImport'),

                Tables\Actions\Action::make('instructions')
                    ->label('تعليمات')
                    ->icon('heroicon-o-exclamation-circle')
                    ->color('warning')
                    ->modalHeading(fn(SapImport $record) => 'تعليمات استخدام: ' . ($record->name ?? $record->resource))
                    ->modalContent(function (SapImport $record) {
                        // Check if it's Inventory Counting or similar
                        if (stripos($record->resource, 'InventoryCountings') !== false || stripos($record->name, 'Inventory') !== false || stripos($record->name, 'جرد') !== false) {
                            return new \Illuminate\Support\HtmlString('
                                <div class="space-y-4 text-right" dir="rtl">
                                    <div class="p-4 bg-blue-50 border-r-4 border-blue-500 rounded">
                                        <h3 class="font-bold text-blue-800 text-lg mb-2">📦 أداة جرد المخزون (Inventory Counting)</h3>
                                        <p class="text-blue-700">
                                            تُستخدم هذه الأداة لرفع نتائج الجرد الفعلي للمخزون ومطابقتها مع نظام SAP Business One بشكل آلي ودقيق.
                                        </p>
                                    </div>
            
                                    <div class="space-y-2">
                                        <h4 class="font-bold text-gray-800 text-lg border-b pb-2">📋 خطوات الاستخدام:</h4>
                                        <ol class="list-decimal list-inside space-y-2 text-gray-700 mr-4">
                                            <li>
                                                <span class="font-semibold text-gray-900">تحميل القالب:</span> 
                                                اضغط على زر <span class="text-blue-600 font-mono text-xs p-1 bg-gray-100 rounded">Download Template</span> لتحميل ملف Excel الجاهز.
                                            </li>
                                            <li>
                                                <span class="font-semibold text-gray-900">تعبئة البيانات:</span> 
                                                قم بتعبئة الأعمدة المطلوبة في الملف:
                                                <ul class="list-disc list-inside mr-6 mt-1 text-sm text-gray-600">
                                                    <li><code class="text-purple-600">ItemCode</code>: رمز الصنف.</li>
                                                    <li><code class="text-purple-600">WarehouseCode</code>: رمز المستودع (مثلاً RUH008).</li>
                                                    <li><code class="text-purple-600">CountedQuantity</code>: الكمية الفعلية التي تم عدها.</li>
                                                    <li><code class="text-purple-600">BatchNumber</code>: (اختياري) رقم التشغيلة للأصناف التي تدار بالدفعات.</li>
                                                </ul>
                                            </li>
                                            <li>
                                                <span class="font-semibold text-gray-900">التشغيل:</span> 
                                                اضغط على زر <span class="text-green-600 font-mono text-xs p-1 bg-gray-100 rounded">Run Import</span>. سيطلب منك النظام رفع الملف وتحديد بعض الخيارات الإضافية مثل تاريخ الجرد.
                                            </li>
                                        </ol>
                                    </div>
            
                                    <div class="p-4 bg-yellow-50 border-r-4 border-yellow-500 rounded mt-4">
                                        <h4 class="font-bold text-yellow-800 mb-1">⚠️ ملاحظات هامة:</h4>
                                        <ul class="list-disc list-inside text-yellow-800 text-sm space-y-1">
                                            <li>تأكد من اختيار <strong>تاريخ الجرد</strong> الصحيح عند التشغيل.</li>
                                            <li>في حال تفعيل خيار <span class="font-semibold">Auto-Assign Batches</span>، سيقوم النظام باختيار الدفعات الأقرب للانتهاء (Expiry > 2026) تلقائياً للأصناف التي لم تحدد لها دفعة.</li>
                                            <li>يمكنك استخدام خيار <span class="font-semibold">Dry Run</span> لتجربة الملف والتأكد من صحة البيانات قبل إرسالها فعلياً إلى SAP.</li>
                                        </ul>
                                    </div>
                                </div>
                            ');
                        }

                        // Default Instructions
                        return new \Illuminate\Support\HtmlString('
                            <div class="text-right" dir="rtl">
                                <h3 class="font-bold text-lg mb-2">' . __('General Instructions') . '</h3>
                                <p>' . __('Download the template, fill in the data, then upload it using the Run Import button.') . '</p>
                            </div>
                        ');
                    })
                    ->modalSubmitAction(false)
                    ->modalCancelActionLabel(__('Close')),
            ])
            ->bulkActions([
                Tables\Actions\DeleteBulkAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSapImports::route('/'),
            'create' => Pages\CreateSapImport::route('/create'),
            'edit' => Pages\EditSapImport::route('/{record}/edit'),
        ];
    }
}
