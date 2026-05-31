<?php
$u = \App\Models\User::find(4);
if ($u) {
    preg_match('/Duplicate entry/', ''); // just in case
    $u->email = 'm.alosaimi@ppte.sa';
    if (empty($u->mobile_number)) {
        $u->mobile_number = null; // force null
    }
    $u->save();
    echo "User 4 updated successfully\n";
} else {
    echo "User 4 not found\n";
}
