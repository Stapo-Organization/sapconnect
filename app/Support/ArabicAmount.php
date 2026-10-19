<?php

namespace App\Support;

/**
 * Saudi-riyal amount in Arabic words for invoices («التفقيط»):
 * 8335.69 → «فقط ثمانية آلاف وثلاثمائة وخمسة وثلاثون ريالاً سعودياً و69 هللة لا غير».
 * Handles 0 … 999,999,999,999 with the correct counted-noun forms
 * (ألف/ألفان/آلاف/ألفاً, مائة/مائتان/ثلاثمائة …).
 */
class ArabicAmount
{
    private const ONES = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    private const TEENS = ['عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
    private const TENS = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    private const HUNDREDS = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];

    /** [singular, dual, plural (3-10), accusative (11-99), dual in construct (before a noun)] */
    private const SCALES = [
        1_000_000_000 => ['مليار', 'ملياران', 'مليارات', 'ملياراً', 'مليارا'],
        1_000_000     => ['مليون', 'مليونان', 'ملايين', 'مليوناً', 'مليونا'],
        1_000         => ['ألف', 'ألفان', 'آلاف', 'ألفاً', 'ألفا'],
    ];

    public static function riyals(float $amount): string
    {
        $amount   = round(abs($amount), 2);
        $riyals   = (int) floor($amount);
        $halalas  = (int) round(($amount - $riyals) * 100);
        if ($halalas === 100) {
            $riyals++;
            $halalas = 0;
        }

        $halalaText = $halalas . ' ' . ($halalas >= 3 && $halalas <= 10 ? 'هللات' : 'هللة');
        if ($riyals === 0) {
            return 'فقط ' . ($halalas > 0 ? $halalaText : 'صفر ريال سعودي') . ' لا غير';
        }

        $text = self::withNoun($riyals, ['ريال سعودي', 'ريالان سعوديان', 'ريالات سعودية', 'ريالاً سعودياً']);
        if ($halalas > 0) {
            $text .= ' و' . $halalaText;
        }
        return 'فقط ' . $text . ' لا غير';
    }

    /**
     * Whole number in words (masculine). $beforeNoun: the number is followed by
     * a counted noun (ريال), so a closing scale word takes the construct form
     * (أحد عشر ألف ريال، ألفا ريال، مائتا ريال).
     */
    public static function words(int $n, bool $beforeNoun = false): string
    {
        if ($n === 0) {
            return 'صفر';
        }
        $parts = [];
        foreach (self::SCALES as $value => $forms) {
            if ($n >= $value) {
                $count = intdiv($n, $value);
                $n %= $value;
                $parts[] = self::counted($count, $forms, $beforeNoun && $n === 0);
            }
        }
        if ($n > 0) {
            $parts[] = self::below1000($n, $beforeNoun);
        }
        return implode(' و', $parts);
    }

    /** "count noun" with the right Arabic noun form; 1 and 2 use the noun alone. */
    private static function withNoun(int $n, array $forms): string
    {
        if ($n === 1) {
            return $forms[0] . ' واحد';
        }
        if ($n === 2) {
            return $forms[1];
        }
        return self::words($n, true) . ' ' . self::nounFor($n, $forms);
    }

    /** A scale group ("ثلاثة آلاف"); $closing = last group and a noun follows. */
    private static function counted(int $count, array $forms, bool $closing = false): string
    {
        if ($count === 1) {
            return $forms[0];
        }
        if ($count === 2) {
            return $closing ? $forms[4] : $forms[1];
        }
        $noun = self::nounFor($count, $forms);
        if ($closing && $noun === $forms[3]) {
            $noun = $forms[0]; // accusative → construct: أحد عشر ألف ريال
        }
        return self::below1000($count, true) . ' ' . $noun;
    }

    /** The counted noun follows the last two digits of the number. */
    private static function nounFor(int $n, array $forms): string
    {
        $last2 = $n % 100;
        if ($last2 >= 3 && $last2 <= 10) {
            return $forms[2];
        }
        if ($last2 >= 11) {
            return $forms[3];
        }
        return $forms[0]; // x00, x01, x02 → singular (مائة ألف، مائتا ريال …)
    }

    private static function below1000(int $n, bool $beforeNoun = false): string
    {
        $parts = [];
        if ($n >= 100) {
            // exact 200 before a noun → construct «مائتا»: مائتا ألف، مائتا ريال
            $parts[] = ($beforeNoun && $n === 200) ? 'مائتا' : self::HUNDREDS[intdiv($n, 100)];
            $n %= 100;
        }
        if ($n > 0) {
            if ($n < 10) {
                $parts[] = self::ONES[$n];
            } elseif ($n < 20) {
                $parts[] = self::TEENS[$n - 10];
            } else {
                $ones = $n % 10;
                $parts[] = $ones ? self::ONES[$ones] . ' و' . self::TENS[intdiv($n, 10)] : self::TENS[intdiv($n, 10)];
            }
        }
        return implode(' و', $parts);
    }
}
