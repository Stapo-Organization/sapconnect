<?php

namespace App\Notifications;

use App\Models\User;
use App\Notifications\Channels\FcmChannel;
use App\Support\NotificationPreferences;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class FinancePaymentAlert extends Notification implements ShouldQueue
{
    use Queueable;

    public $shipment;
    public $po;
    public $line;
    public $dueAmount;
    public $dueDate;

    /**
     * Create a new notification instance.
     */
    public function __construct($shipment, $po, $line, $dueAmount, $dueDate)
    {
        $this->shipment = $shipment;
        $this->po = $po;
        $this->line = $line;
        $this->dueAmount = $dueAmount;
        $this->dueDate = $dueDate;
    }

    /**
     * Get the notification's delivery channels.
     *
     * جرس Filament (database) قناة مستقلة تبقى دائماً؛ البريد و Push يخضعان
     * لتفضيل قناة المستخدم لحدث 'finance_payment_due'.
     *
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        $channels = ['database'];

        if (! $notifiable instanceof User) {
            return array_merge($channels, ['mail']);
        }

        $prefs = NotificationPreferences::channelsFor($notifiable, 'finance_payment_due');
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
            'title' => 'استحقاق دفعة مورّد',
            'body'  => "دفعة مستحقة على أمر الشراء #{$this->po->id} بقيمة " . number_format($this->dueAmount, 2) . " {$this->po->currency}",
            'data'  => ['type' => 'finance_payment_due', 'purchase_order_id' => (string) $this->po->id],
        ];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject("Finance Alert: Payment Due for PO #{$this->po->id}")
            ->greeting("Hello,")
            ->line("A payment milestone has been reached because shipment #{$this->shipment->id} status changed to '{$this->shipment->status}'.")
            ->line("Purchase Order: {$this->po->id} ({$this->po->currency})")
            ->line("Milestone Met: {$this->line->condition}")
            ->line("Payment Percentage: {$this->line->percentage}%")
            ->line("Due Amount: " . number_format($this->dueAmount, 2) . " {$this->po->currency}")
            ->line("Due Date: {$this->dueDate}")
            ->action('View Purchase Order', url("/admin/purchase-orders/{$this->po->id}"))
            ->line('Please review and process the payment accordingly.');
    }

    /**
     * Get the database representation of the notification (Filament bell icon).
     *
     * @return array<string, mixed>
     */
    public function toDatabase(object $notifiable): array
    {
        return [
            'title' => "Payment Due: PO #{$this->po->id}",
            'body' => "Shipment #{$this->shipment->id} status changed to '{$this->shipment->status}'. Amount due: " . number_format($this->dueAmount, 2) . " {$this->po->currency}",
            'shipment_id' => $this->shipment->id,
            'purchase_order_id' => $this->po->id,
            'condition' => $this->line->condition,
            'percentage' => $this->line->percentage,
            'due_amount' => $this->dueAmount,
            'due_date' => $this->dueDate,
            'currency' => $this->po->currency,
        ];
    }
}
