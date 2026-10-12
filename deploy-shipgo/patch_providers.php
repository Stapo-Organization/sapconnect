<?php
// Surgical patch of the two provider files on the server (they have diverged from git,
// so we only replace exact anchor blocks; abort if an anchor is missing).
[$_, $app] = $argv;
$patches = [
    "$app/app/Providers/AppServiceProvider.php" => [[
        "        \\Illuminate\\Support\\Facades\\Gate::before(function (\$user, \$ability) {\n            return \$user->hasRole('Super Admin') ? true : null;\n        });",
        "        \\Illuminate\\Support\\Facades\\Gate::before(function (\$user, \$ability, array \$arguments = []) {\n            if (\$user->hasRole('Super Admin')) {\n                return true;\n            }\n            // Limited roles (e.g. Accountant) are denied everything except their own resources.\n            return \\App\\Support\\PanelAccess::gate(\$user, \$ability, \$arguments);\n        });",
    ]],
    "$app/app/Providers/Filament/AdminPanelProvider.php" => [[
        "            ->authMiddleware([\n                Authenticate::class,\n            ]);",
        "            ->authMiddleware([\n                Authenticate::class,\n                \\App\\Http\\Middleware\\RestrictLimitedPanelRoles::class,\n            ])\n            // Limited roles (see App\\Support\\PanelAccess) get a sidebar with only their resources.\n            ->bootUsing(function (Panel \$panel): void {\n                \$user = auth()->user();\n                if (\$user && \\App\\Support\\PanelAccess::isLimited(\$user)) {\n                    \$panel->navigation(fn (\\Filament\\Navigation\\NavigationBuilder \$builder): \\Filament\\Navigation\\NavigationBuilder => \$builder\n                        ->items(\\App\\Support\\PanelAccess::navigationItems(\$user)));\n                }\n            });",
    ], [
        "->visible(fn(): bool => !auth()->user()->hasRole('Branch Manager')),",
        "->visible(fn(): bool => !auth()->user()->hasRole('Branch Manager') && !\\App\\Support\\PanelAccess::isLimited(auth()->user())),",
    ]],
];
foreach ($patches as $file => $pairs) {
    $src = file_get_contents($file);
    if (str_contains($src, 'PanelAccess')) { echo basename($file), ": already patched\n"; continue; }
    foreach ($pairs as [$old, $new]) {
        if (substr_count($src, $old) !== 1) { fwrite(STDERR, "ANCHOR NOT FOUND in $file:\n$old\n"); exit(1); }
        $src = str_replace($old, $new, $src);
    }
    copy($file, $file . '.bak-accountant');
    file_put_contents($file, $src);
    echo basename($file), ": patched (backup .bak-accountant)\n";
}
// syntax check
foreach (array_keys($patches) as $f) { passthru(PHP_BINARY . ' -l ' . escapeshellarg($f)); }
