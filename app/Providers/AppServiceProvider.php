<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Force HTTPS to prevent Livewire/Asset protocol mismatch
        \Illuminate\Support\Facades\URL::forceScheme('https');

        // Implicitly grant "Super Admin" role all permissions
        \Illuminate\Support\Facades\Gate::before(function ($user, $ability) {
            return $user->hasRole('Super Admin') ? true : null;
        });

        // Explicitly register Policies for Spatie Models
        \Illuminate\Support\Facades\Gate::policy(\Spatie\Permission\Models\Role::class, \App\Policies\RolePolicy::class);
        \Illuminate\Support\Facades\Gate::policy(\Spatie\Permission\Models\Permission::class, \App\Policies\PermissionPolicy::class);

        \Dedoc\Scramble\Scramble::afterOpenApiGenerated(function (\Dedoc\Scramble\Support\Generator\OpenApi $openApi) {
            $openApi->secure(
                \Dedoc\Scramble\Support\Generator\SecurityScheme::http('bearer')
            );
        });
        \Illuminate\Support\Facades\Event::listen(
            \Illuminate\Auth\Events\Login::class,
            \App\Listeners\UpdateLastLogin::class
        );

        // Register SCM Observers
        \App\Models\Shipment::observe(\App\Observers\ShipmentObserver::class);

        // Register custom Retail widgets for Livewire
        \Livewire\Livewire::component('app.filament.retail-widgets.store-sales-widget', \App\Filament\RetailWidgets\StoreSalesWidget::class);
    }
}
