<?php

namespace App\Notifications;

use App\Models\Supplier;
use App\Models\User;
use App\Notifications\Channels\FcmChannel;
use App\Support\NotificationPreferences;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class ContractExpiryAlert extends Notification implements ShouldQueue
{
    use Queueable;

    public Supplier $supplier;
    public int $daysRemaining;

    /**
     * Create a new notification instance.
     */
    public function __construct(Supplier $supplier, int $daysRemaining)
    {
        $this->supplier = $supplier;
        $this->daysRemaining = $daysRemaining;
    }

    /**
     * Get the notification's delivery channels.
     *
     * جرس Filament (database) قناة مستقلة تبقى دائماً؛ البريد و Push يخضعان
     * لتفضيل قناة المستخدم لحدث 'contract_expiry'.
     */
    public function via(object $notifiable): array
    {
        $channels = ['database'];

        if (! $notifiable instanceof User) {
            return array_merge($channels, ['mail']);
        }

        $prefs = NotificationPreferences::channelsFor($notifiable, 'contract_expiry');
        if ($prefs['email'] ?? false) {
            $channels[] = 'mail';
        }
        if ($prefs['push'] ?? false) {
            $channels[] = FcmChannel::class;
        }

        return $channels;
    }

    /**
     * Push (FCM) representation — يُرسل عبر FcmChannel عند تفعيل قناة التطبيق.
     *
     * @return array{title:string, body:string, data:array}
     */
    public function toFcm(object $notifiable): array
    {
        return [
            'title' => 'قرب انتهاء عقد مورّد',
            'body'  => "عقد المورّد {$this->supplier->name} ينتهي خلال {$this->daysRemaining} يوم",
            'data'  => ['type' => 'contract_expiry', 'supplier_id' => (string) $this->supplier->id],
        ];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $urgency = $this->daysRemaining <= 7 ? 'URGENT: ' : '';

        return (new MailMessage)
            ->subject("{$urgency}Contract Expiring - {$this->supplier->name}")
            ->greeting("Hello,")
            ->line("The contract for supplier **{$this->supplier->name}** (SAP: {$this->supplier->sap_code}) is expiring in **{$this->daysRemaining} days**.")
            ->line("Contract Reference: {$this->supplier->contract_ref}")
            ->line("End Date: {$this->supplier->end_date}")
            ->line("Renewal Conditions: " . ($this->supplier->renewal_conditions ?? 'Not specified'))
            ->action('View Supplier', url("/admin/suppliers/{$this->supplier->id}/edit"))
            ->line('Please review and take necessary action for contract renewal.');
    }

    /**
     * Get the database representation of the notification (Filament bell icon).
     */
    public function toDatabase(object $notifiable): array
    {
        $icon = $this->daysRemaining <= 7 ? '🔴' : ($this->daysRemaining <= 15 ? '🟡' : '🟢');

        return [
            'title' => "{$icon} Contract Expiring: {$this->supplier->name}",
            'body' => "Contract for {$this->supplier->name} expires in {$this->daysRemaining} days (End: {$this->supplier->end_date})",
            'supplier_id' => $this->supplier->id,
            'days_remaining' => $this->daysRemaining,
            'end_date' => $this->supplier->end_date,
            'contract_ref' => $this->supplier->contract_ref,
        ];
    }
}
