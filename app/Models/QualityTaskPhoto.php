<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class QualityTaskPhoto extends Model
{
    protected $fillable = [
        'quality_task_instance_id', 'checklist_item_key',
        'disk', 'path', 'original_name', 'size', 'uploaded_by',
    ];

    protected $appends = ['url'];

    public function instance()
    {
        return $this->belongsTo(QualityTaskInstance::class, 'quality_task_instance_id');
    }

    public function uploader()
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function getUrlAttribute(): string
    {
        return Storage::disk($this->disk ?? 'public')->url($this->path);
    }
}
