<?php
$t = \App\Models\EmailNotification::where('event_name', 'stock_transfer_created')->first();
if ($t) {
    $roles = $t->recipient_roles ?? [];
    if (!in_array('operator', $roles)) {
        array_push($roles, 'operator');
        $t->recipient_roles = $roles;
        $t->save();
        echo "Updated template roles with 'operator'\n";
    } else {
        echo "Already has operator role\n";
    }
} else {
    echo "stock_transfer_created template not found\n";
}
