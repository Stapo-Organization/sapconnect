<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class FinancePaymentAlert extends Notification implements ShouldQueue
{
    use Queueable;

    public clone clone;
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
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
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
}
