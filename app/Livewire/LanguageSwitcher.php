<?php

namespace App\Livewire;

use Livewire\Component;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Facades\App;

class LanguageSwitcher extends Component
{
    public function toggle()
    {
        $current = App::getLocale();
        $target = $current === 'ar' ? 'en' : 'ar';

        Session::put('locale', $target);
        App::setLocale($target);

        $this->redirect(request()->header('Referer'));
    }

    public function render()
    {
        return view('livewire.language-switcher');
    }
}
