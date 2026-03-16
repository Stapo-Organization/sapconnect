<?php

namespace App\Services\SAP;

use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class CsvParserService
{
    /**
     * Parses a CSV file and validates its headers.
     *
     * @param string $filePath
     * @return array
     * @throws \Exception
     */
    public function parse(string $filePath): array
    {
        $realPath = $this->resolvePath($filePath);

        // Fix line endings for MAC/Unix/Windows compat
        ini_set('auto_detect_line_endings', true);

        $rows = array_map('str_getcsv', file($realPath));
        if (empty($rows)) {
            throw new \Exception("CSV file is invalid or empty.");
        }

        $header = array_shift($rows);
        if (empty($header)) {
            throw new \Exception("CSV file is empty or invalid header.");
        }

        $header = array_map('trim', $header);

        // Remove BOM from first header if present
        if (isset($header[0])) {
            $header[0] = preg_replace('/^\xEF\xBB\xBF/', '', $header[0]);
        }

        Log::info("CsvParserService: Header Detected", ['header' => $header]);

        return [
            'header' => $header,
            'rows'   => $rows
        ];
    }

    /**
     * Maps the parsed CSV rows to an associative array using the provided mapping.
     *
     * @param array $headers
     * @param array $rows
     * @param array $mapping The mapping rules from SapImport
     * @return array
     */
    public function mapData(array $headers, array $rows, array $mapping): array
    {
        $mappedData = [];

        foreach ($rows as $index => $row) {
            // Skip empty rows (all columns empty)
            if (empty(array_filter($row, function ($v) { return trim($v) !== ''; }))) {
                continue;
            }

            if (count($row) !== count($headers)) {
                Log::warning("CsvParserService: Row $index count mismatch", ['expected' => count($headers), 'actual' => count($row), 'row' => $row]);
                continue;
            }

            $rowAssoc = array_combine($headers, $row);
            $item = [];

            foreach ($mapping as $map) {
                $csvKey = trim($map['csv_header']);
                $sapKey = $map['sap_field'];

                $value = $this->extractValueFromRow($rowAssoc, $csvKey);

                if ($value !== null) {
                    $value = $this->formatValue($sapKey, $value);
                    data_set($item, $sapKey, $value);
                }
            }

            if (!empty($item)) {
                $mappedData[] = $item;
            }
        }

        return $mappedData;
    }

    private function resolvePath(string $filePath): string
    {
        if (file_exists($filePath)) {
            return $filePath;
        }

        if (Storage::disk('local')->exists($filePath)) {
            return Storage::disk('local')->path($filePath);
        }

        if (Storage::exists($filePath)) {
            return Storage::path($filePath);
        }

        throw new \Exception("File not found at path: $filePath. Please try uploading again.");
    }

    private function extractValueFromRow(array $rowAssoc, string $csvKey)
    {
        if (isset($rowAssoc[$csvKey])) {
            return $rowAssoc[$csvKey];
        }

        // Try case-insensitive lookup
        $lowerKey = strtolower($csvKey);
        foreach (array_keys($rowAssoc) as $hKey) {
            if (strtolower($hKey) === $lowerKey) {
                return $rowAssoc[$hKey];
            }
        }

        return null;
    }

    private function formatValue(string $sapKey, $value)
    {
        // Clean Date? If SAP field contains 'Date'
        if (str_contains($sapKey, 'Date') && strlen($value) > 10) {
            return substr($value, 0, 10);
        }

        if (is_numeric($value)) {
            return strpos($value, '.') !== false ? (float) $value : (int) $value;
        }

        return $value;
    }
}
