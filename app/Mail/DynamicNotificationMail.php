<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class DynamicNotificationMail extends Mailable
{
    use Queueable, SerializesModels;

    public $subjectAr;
    public $subjectEn;
    public $bodyAr;
    public $bodyEn;

    /**
     * Create a new message instance.
     */
    public function __construct(string $subjectAr, string $subjectEn, string $bodyAr, string $bodyEn)
    {
        $this->subjectAr = $subjectAr;
        $this->subjectEn = $subjectEn;
        $this->bodyAr = $bodyAr;
        $this->bodyEn = $bodyEn;
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        // Default to Arabic subject, or combined if needed.
        $subject = $this->subjectAr;
        if (trim($this->subjectEn) && trim($this->subjectEn) !== trim($this->subjectAr)) {
            $subject .= ' | ' . $this->subjectEn;
        }

        return new Envelope(
            from: new \Illuminate\Mail\Mailables\Address(config('mail.from.address', 'system@muntajat.sa'), 'نظام الاشعارات الآلي'),
            subject: $subject,
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.dynamic_notification',
            with: [
                'bodyAr' => $this->bodyAr,
                'bodyEn' => $this->bodyEn,
            ]
        );
    }

    /**
     * Get the attachments for the message.
     *
     * @return array<int, \Illuminate\Mail\Mailables\Attachment>
     */
    public function attachments(): array
    {
        return [];
    }
}
