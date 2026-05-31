<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class ZooboxiSyncLog extends Model
{
    use HasFactory;

    protected $table = 'zooboxi_sync_logs';

    protected $fillable = [
        'sync_type',
        'direction',
        'status',
        'records_total',
        'records_synced',
        'records_failed',
        'error_message',
        'details',
        'started_at',
        'completed_at',
    ];

    protected $casts = [
        'details' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    // ─── Factory Methods ────────────────────────────────────────

    /**
     * Start a new sync log entry.
     */
    public static function startSync(string $type, string $direction = 'push'): self
    {
        return self::create([
            'sync_type' => $type,
            'direction' => $direction,
            'status' => 'running',
            'started_at' => now(),
        ]);
    }

    // ─── Instance Methods ───────────────────────────────────────

    /**
     * Mark the sync as completed.
     */
    public function markCompleted(int $total, int $synced, int $failed = 0, ?array $details = null): void
    {
        $this->update([
            'status' => $failed > 0 && $synced === 0 ? 'failed' : 'completed',
            'records_total' => $total,
            'records_synced' => $synced,
            'records_failed' => $failed,
            'details' => $details,
            'completed_at' => now(),
        ]);
    }

    /**
     * Mark the sync as failed.
     */
    public function markFailed(string $errorMessage, ?array $details = null): void
    {
        $this->update([
            'status' => 'failed',
            'error_message' => $errorMessage,
            'details' => $details,
            'completed_at' => now(),
        ]);
    }

    // ─── Scopes ─────────────────────────────────────────────────

    /**
     * Filter by sync type.
     */
    public function scopeOfType(Builder $query, string $type): Builder
    {
        return $query->where('sync_type', $type);
    }

    /**
     * Get latest sync of each type.
     */
    public static function latestByType(): array
    {
        $types = ['products', 'stock', 'prices', 'orders'];
        $results = [];

        foreach ($types as $type) {
            $results[$type] = self::where('sync_type', $type)
                ->latest('started_at')
                ->first();
        }

        return $results;
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Get the duration of the sync in seconds.
     */
    public function getDurationAttribute(): ?int
    {
        if (!$this->completed_at) {
            return null;
        }
        return $this->started_at->diffInSeconds($this->completed_at);
    }

    /**
     * Get a human-readable status label.
     */
    public function getStatusLabelAttribute(): string
    {
        return match ($this->status) {
            'running' => '🔄 جاري...',
            'completed' => '✅ مكتمل',
            'failed' => '❌ فشل',
            default => $this->status,
        };
    }
}
