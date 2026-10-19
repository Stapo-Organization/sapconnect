<?php

namespace Tests\Unit;

use App\Support\ArabicAmount;
use PHPUnit\Framework\TestCase;

class ArabicAmountTest extends TestCase
{
    public static function cases(): array
    {
        return [
            [8335.69,    'فقط ثمانية آلاف وثلاثمائة وخمسة وثلاثون ريالاً سعودياً و69 هللة لا غير'],
            [18975,      'فقط ثمانية عشر ألفاً وتسعمائة وخمسة وسبعون ريالاً سعودياً لا غير'],
            [1,          'فقط ريال سعودي واحد لا غير'],
            [2,          'فقط ريالان سعوديان لا غير'],
            [3,          'فقط ثلاثة ريالات سعودية لا غير'],
            [200,        'فقط مائتا ريال سعودي لا غير'],
            [2000,       'فقط ألفا ريال سعودي لا غير'],
            [11000,      'فقط أحد عشر ألف ريال سعودي لا غير'],
            [1200003,    'فقط مليون ومائتا ألف وثلاثة ريالات سعودية لا غير'],
            [0.5,        'فقط 50 هللة لا غير'],
        ];
    }

    /** @dataProvider cases */
    public function test_riyals_in_words(float $amount, string $expected): void
    {
        $this->assertSame($expected, ArabicAmount::riyals($amount));
    }
}
