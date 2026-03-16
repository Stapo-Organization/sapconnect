<?php

namespace App\Exceptions;

use Exception;

class SapException extends Exception
{
    protected $sapError;

    public function __construct($message, $code = 0, $sapError = null)
    {
        parent::__construct($message, $code);
        $this->sapError = $sapError;
    }

    public function getSapError()
    {
        return $this->sapError;
    }
}
