<?php

namespace App\Services\Mrsool;

use RuntimeException;

/**
 * A rejected Mrsool call. Carries the HTTP status plus the Arabic message the
 * API returned (errors[0].message), so the branch app can show it verbatim.
 */
class MrsoolException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $httpStatus = 0,
        public readonly array $errors = [],
    ) {
        parent::__construct($message, $httpStatus);
    }
}
