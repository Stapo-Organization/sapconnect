<?php
$content = file_get_contents('app/Models/Brand.php');
$content = str_replace(
    "return 'https://ppte.sa/imghd/brands/P' . \$this->code . '.png';",
    "\$firstProduct = \$this->products()->first();
        if (\$firstProduct && strlen(\$firstProduct->item_code) >= 4) {
            \$prefix = substr(\$firstProduct->item_code, 0, 4);
            return 'https://ppte.sa/imghd/brands/' . \$prefix . '.png';
        }
        return 'https://ppte.sa/imghd/brands/P' . \$this->code . '.png';",
    $content
);
file_put_contents('app/Models/Brand.php', $content);
echo "Brand.php patched.\n";
