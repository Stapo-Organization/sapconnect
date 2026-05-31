<?php
/**
 * Sync Logger — writes sync results to wp_zooboxi_sync_logs.
 */
class Zooboxi_Logger
{
    public static function start(string $syncType, string $direction = 'pull'): int
    {
        global $wpdb;
        $wpdb->insert($wpdb->prefix . 'zooboxi_sync_logs', [
            'sync_type'  => $syncType,
            'direction'  => $direction,
            'status'     => 'running',
            'started_at' => current_time('mysql', true),
        ]);
        return (int) $wpdb->insert_id;
    }

    public static function complete(int $logId, int $synced, int $failed = 0, int $total = 0): void
    {
        global $wpdb;
        $wpdb->update($wpdb->prefix . 'zooboxi_sync_logs', [
            'status'         => $failed > 0 ? 'partial' : 'completed',
            'records_total'  => $total ?: $synced + $failed,
            'records_synced' => $synced,
            'records_failed' => $failed,
            'completed_at'   => current_time('mysql', true),
        ], ['id' => $logId]);
    }

    public static function fail(int $logId, string $message): void
    {
        global $wpdb;
        $wpdb->update($wpdb->prefix . 'zooboxi_sync_logs', [
            'status'        => 'failed',
            'error_message' => $message,
            'completed_at'  => current_time('mysql', true),
        ], ['id' => $logId]);
    }

    public static function get_latest(string $syncType = ''): ?object
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_sync_logs';
        $where = $syncType ? $wpdb->prepare("WHERE sync_type = %s", $syncType) : '';
        return $wpdb->get_row("SELECT * FROM {$table} {$where} ORDER BY id DESC LIMIT 1");
    }

    public static function get_recent(int $limit = 20): array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_sync_logs';
        return $wpdb->get_results("SELECT * FROM {$table} ORDER BY id DESC LIMIT {$limit}");
    }
}
