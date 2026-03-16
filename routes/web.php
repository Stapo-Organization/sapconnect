<?php

use Illuminate\Support\Facades\Route;

Route::redirect('/developer/docs', '/docs/api');
Route::get('/', function () {
    return redirect('/admin');
});

