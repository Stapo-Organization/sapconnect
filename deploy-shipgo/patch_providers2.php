<?php
// Move the limited-role sidebar swap from Panel::bootUsing (too early) to Filament::serving().
[$_, $app] = $argv;
$file = "$app/app/Providers/Filament/AdminPanelProvider.php";
$src = file_get_contents($file);
$old = "            ->authMiddleware([\n                Authenticate::class,\n                \\App\\Http\\Middleware\\RestrictLimitedPanelRoles::class,\n            ])\n            // Limited roles (see App\\Support\\PanelAccess) get a sidebar with only their resources.\n            ->bootUsing(function (Panel \$panel): void {\n                \$user = auth()->user();\n                if (\$user && \\App\\Support\\PanelAccess::isLimited(\$user)) {\n                    \$panel->navigation(fn (\\Filament\\Navigation\\NavigationBuilder \$builder): \\Filament\\Navigation\\NavigationBuilder => \$builder\n                        ->items(\\App\\Support\\PanelAccess::navigationItems(\$user)));\n                }\n            });\n    }\n}";
$new = "            ->authMiddleware([\n                Authenticate::class,\n                \\App\\Http\\Middleware\\RestrictLimitedPanelRoles::class,\n            ]);\n    }\n\n    /**\n     * Limited roles (see App\\Support\\PanelAccess) get a sidebar with only their\n     * resources. This must run on the ServingFilament event: the panel itself\n     * boots in SetUpPanel, before the session middleware, when auth()->user()\n     * is still unknown in a real browser request.\n     */\n    public function boot(): void\n    {\n        \\Filament\\Facades\\Filament::serving(function (): void {\n            \$user = auth()->user();\n            if (\$user && \\App\\Support\\PanelAccess::isLimited(\$user)) {\n                \\Filament\\Facades\\Filament::getCurrentPanel()?->navigation(\n                    fn (\\Filament\\Navigation\\NavigationBuilder \$builder): \\Filament\\Navigation\\NavigationBuilder => \$builder\n                        ->items(\\App\\Support\\PanelAccess::navigationItems(\$user))\n                );\n            }\n        });\n    }\n}";
if (str_contains($src, 'Filament::serving(')) { echo "already patched\n"; exit(0); }
if (substr_count($src, $old) !== 1) { fwrite(STDERR, "ANCHOR NOT FOUND\n"); exit(1); }
copy($file, $file . '.bak-accountant2');
file_put_contents($file, str_replace($old, $new, $src));
echo "AdminPanelProvider.php: patched (backup .bak-accountant2)\n";
passthru(PHP_BINARY . ' -l ' . escapeshellarg($file));
