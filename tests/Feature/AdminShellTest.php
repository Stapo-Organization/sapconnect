<?php

namespace Tests\Feature;

use App\Filament\Resources\ProductResource\Pages\ListProducts;
use App\Livewire\Admin\TableViews;
use App\Models\AdminSavedView;
use App\Models\User;
use App\Support\AdminShell;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * «مساحة العمل» admin shell: the rail/panel sidebar, the home page, and saved
 * table views (save, open, ownership).
 */
class AdminShellTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.env' => 'local']);
        Role::findOrCreate('Super Admin', 'web');
        $this->owner = User::create(['name' => 'محمد', 'email' => 'owner@example.test', 'password' => bcrypt('x')]);
        $this->owner->assignRole('Super Admin');
    }

    private function browseAs(User $user): static
    {
        return $this->withSession([auth()->guard('web')->getName() => $user->getAuthIdentifier()]);
    }

    public function test_home_is_the_workspace_with_rail_and_command_box(): void
    {
        $this->browseAs($this->owner)->get('/admin')
            ->assertOk()
            ->assertSee('mt-rail', false)
            ->assertSee('mt-home-command', false)
            ->assertSee('mt-cmd-overlay', false);
    }

    public function test_old_widget_dashboard_moved_to_insights(): void
    {
        $this->browseAs($this->owner)->get('/admin/insights')->assertOk();
    }

    public function test_list_pages_carry_the_saved_views_bar(): void
    {
        $this->browseAs($this->owner)->get('/admin/products')
            ->assertOk()
            ->assertSee('mt-views', false)
            ->assertSee('mt-density', false);
    }

    public function test_path_keys_file_screens_by_admin_path(): void
    {
        $this->assertSame('shipments', AdminShell::pathKey('https://x.test/admin/shipments?tableSearch=a'));
        $this->assertSame('', AdminShell::pathKey('https://x.test/admin'));
        $this->assertSame('@docs/api', AdminShell::pathKey('/docs/api'));
        $this->assertNull(AdminShell::pathKey(null));
    }

    public function test_saved_view_keeps_only_table_state(): void
    {
        $this->assertSame(
            'tableSearch=x&tableFilters%5Bbrand%5D%5Bvalue%5D=7',
            TableViews::cleanQuery('?tableSearch=x&page=3&sv=2&foo=1&tableFilters[brand][value]=7')
        );
        $this->assertSame(['a' => true, 'b' => ['c' => false]], TableViews::cleanColumns(['a' => 1, 'b' => ['c' => 0], 3 => true]));
    }

    public function test_saving_a_view_stores_it_and_opens_it(): void
    {
        $this->actingAs($this->owner);

        Livewire::test(TableViews::class, ['pageClass' => ListProducts::class, 'baseUrl' => '/admin/products'])
            ->call('save', 'دجاج', '?tableSearch=Chicken&page=2', ['item_name' => true], false, true)
            ->assertRedirectContains('sv=');

        $view = AdminSavedView::sole();
        $this->assertSame('tableSearch=Chicken', $view->query);
        $this->assertTrue($view->is_pinned);
        $this->assertSame(['item_name' => true], $view->columns);
        $this->assertStringContainsString('tableSearch=Chicken&sv=' . $view->id, $view->url());
    }

    public function test_others_can_open_a_shared_view_but_never_change_it(): void
    {
        $shared = AdminSavedView::create([
            'user_id' => $this->owner->id, 'page_class' => ListProducts::class,
            'name' => 'مشترك', 'query' => 'tableSearch=a', 'is_shared' => true,
        ]);
        $private = AdminSavedView::create([
            'user_id' => $this->owner->id, 'page_class' => ListProducts::class,
            'name' => 'خاص', 'query' => 'tableSearch=b',
        ]);
        $colleague = User::create(['name' => 'خالد', 'email' => 'k@example.test', 'password' => bcrypt('x')]);
        $colleague->assignRole('Super Admin');
        $this->actingAs($colleague);

        $bar = Livewire::test(TableViews::class, ['pageClass' => ListProducts::class, 'baseUrl' => '/admin/products']);
        $ids = $bar->instance()->views->pluck('id')->all();
        $this->assertContains($shared->id, $ids);
        $this->assertNotContains($private->id, $ids);

        $bar->call('rename', $shared->id, 'تغيير')->call('delete', $shared->id)->call('togglePin', $shared->id);
        $this->assertSame('مشترك', $shared->fresh()->name);
        $this->assertFalse($shared->fresh()->is_pinned);

        $bar->call('open', $shared->id)->assertRedirectContains('sv=' . $shared->id);
    }
}
