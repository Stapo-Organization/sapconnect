<?php

namespace App\Services\ShipGo;

/** Thrown when a requested statement period holds too many lines for one PDF. */
class StatementTooLargeException extends \RuntimeException
{
    public function __construct(public int $lines, public int $max)
    {
        parent::__construct("Statement has {$lines} lines (max {$max}). Choose a shorter period.");
    }
}
