<?php

namespace App\Services;

use App\Models\EmailNotification;
use App\Models\User;
use App\Models\EmailLog;
use App\Mail\DynamicNotificationMail;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;

class EmailNotificationService
{
    /**
     * Dispatch an email notification based on the database template.
     *
     * @param string $eventName The unique code for the event (e.g., 'stock_transfer_created')
     * @param array $variables Key-value pairs of data to replace in the subject/body (e.g., ['{doc_num}' => 12345])
     * @param array $context Additional context used to determine roles (e.g., ['from_warehouse' => 'W01', 'to_warehouse' => 'W02'])
     * @return bool
     */
    public static function dispatch(string $eventName, array $variables = [], array $context = []): bool
    {
        try {
            $template = EmailNotification::where('event_name', $eventName)->where('is_active', true)->first();

            // If the template doesn't exist or is not active, silently skip.
            if (!$template) {
                return false;
            }

            // Parse text
            $subjectAr = self::parseVariables($template->subject_ar ?? '', $variables);
            $subjectEn = self::parseVariables($template->subject_en ?? '', $variables);
            $bodyAr = self::parseVariables($template->body_ar ?? '', $variables);
            $bodyEn = self::parseVariables($template->body_en ?? '', $variables);

            // Determine Recipients
            $recipients = self::determineRecipients($template->recipient_roles, $context);
            
            // Add static CCs
            $ccEmails = $template->cc_emails ?? [];
            foreach ($ccEmails as $cc) {
                if (filter_var($cc, FILTER_VALIDATE_EMAIL)) {
                    $recipients[] = trim($cc);
                }
            }

            $recipients = array_unique(array_filter($recipients));

            if (empty($recipients)) {
                return false;
            }

            // Dispatch Mail
            try {
                Mail::to($recipients)->send(new DynamicNotificationMail(
                    $subjectAr,
                    $subjectEn,
                    $bodyAr,
                    $bodyEn
                ));

                EmailLog::create([
                    'recipient' => implode(', ', $recipients),
                    'subject' => $subjectAr . ' | ' . $subjectEn,
                    'status' => 'success',
                    'sent_at' => now(),
                ]);
            } catch (\Exception $mail_e) {
                EmailLog::create([
                    'recipient' => implode(', ', $recipients),
                    'subject' => $subjectAr . ' | ' . $subjectEn,
                    'status' => 'failed',
                    'error_message' => $mail_e->getMessage(),
                    'sent_at' => now(),
                ]);
                throw $mail_e;
            }

            return true;

        } catch (\Exception $e) {
            Log::error("EmailNotificationService Failed for event $eventName: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Replace dynamic variables like {doc_num} with their actual values.
     */
    protected static function parseVariables(string $text, array $variables): string
    {
        if (empty($text)) return '';
        
        foreach ($variables as $key => $value) {
            $placeholder = '{' . $key . '}';
            $text = str_replace($placeholder, $value, $text);
        }

        return $text;
    }

    /**
     * Resolve user emails based on system roles and business logic (like Warehouses).
     */
    protected static function determineRecipients(?array $roles, array $context): array
    {
        if (empty($roles)) {
            return [];
        }

        $emails = [];

        foreach ($roles as $role) {
            switch ($role) {
                case 'sender_warehouse':
                    if (isset($context['from_warehouse'])) {
                        $whUsers = User::whereNotNull('email')->where(function($q) use ($context) {
                            $q->whereJsonContains('warehouse_code', $context['from_warehouse'])
                              ->orWhere('warehouse_code', $context['from_warehouse']);
                        })->pluck('email')->toArray();
                        $emails = array_merge($emails, $whUsers);
                    }
                    break;

                case 'receiver_warehouse':
                    if (isset($context['to_warehouse'])) {
                        $whUsers = User::whereNotNull('email')->where(function($q) use ($context) {
                            $q->whereJsonContains('warehouse_code', $context['to_warehouse'])
                              ->orWhere('warehouse_code', $context['to_warehouse']);
                        })->pluck('email')->toArray();
                        $emails = array_merge($emails, $whUsers);
                    }
                    break;
                
                case 'system_admin':
                    // Here we can fetch super admins if we have a role. For now, fetch users with null warehouse (super level)
                    // Or users mapped specifically as admins. As a placeholder, we get admin@muntajat.sa or mahgoub@ppte.sa type accounts.
                    $adminUsers = User::where('email', 'mahgoub@ppte.sa')
                        ->orWhere('email', 'like', 'admin%')
                        ->pluck('email')->toArray();
                    $emails = array_merge($emails, $adminUsers);
                    break;

                case 'operator':
                    $operatorUsers = User::role('Operator')->whereNotNull('email')->pluck('email')->toArray();
                    $emails = array_merge($emails, $operatorUsers);
                    break;
            }
        }

        return $emails;
    }
}
