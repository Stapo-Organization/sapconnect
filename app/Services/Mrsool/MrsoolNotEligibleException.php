<?php

namespace App\Services\Mrsool;

use RuntimeException;

/**
 * One of OUR guards refused the courier request (kill switch, pilot gate, COD,
 * daily cap, an already-active delivery…). Distinct from MrsoolException so the
 * controller can answer 422 for our refusals and 502 for upstream ones — and so
 * a stray QueryException is never mistaken for a business rule.
 */
class MrsoolNotEligibleException extends RuntimeException
{
}
