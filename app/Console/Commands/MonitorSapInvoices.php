<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\SapInvoice;
use App\Models\EmailNotification;
use App\Models\User;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;
use App\Mail\SapInvoiceDelayAlert;

class MonitorSapInvoices extends Command
{
    protected $signature = 'sap:monitor-invoices';
    protected $description = 'Monitor if SAP invoices are delayed during operational hours';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        try {
            $now = Carbon::now();
            $hour = $now->hour;

            // Only run between 9 AM and 11:59 PM (23:59)
            if ($hour < 9) {
                // Not in operational hours
                if ($automation) {
                    $automation->update(['last_run_status' => 'success']);
                }
                return;
            }

            // Get the last invoice created_at
            $lastInvoice = SapInvoice::orderBy('created_at', 'desc')->first();
            
            if (!$lastInvoice) {
                 if ($automation) {
                    $automation->update(['last_run_status' => 'success']);
                 }
                 return; 
            }

            $lastTime = $lastInvoice->created_at;
            $diffMinutes = $lastTime->diffInMinutes($now);

            if ($diffMinutes > 30) {
                // It has been more than 30 minutes since the last invoice was synced
                $this->triggerAlert($lastTime, $diffMinutes);
            } else {
                // healthy state, clear the spam prevention cache so if it goes down later, it can alert immediately
                $this->triggerRecoveryIfNeeded($lastTime);
                Cache::forget('sap_delay_alert_sent');
            }

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => "Checked invoices successfully."]);
            }

        } catch (\Exception $e) {
            $msg = "Error monitoring invoices: " . $e->getMessage();
            Log::error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }

    private function triggerRecoveryIfNeeded($lastTime)
    {
        if (!Cache::has('sap_delay_alert_sent')) {
            return; // Was healthy anyway
        }

        $template = EmailNotification::where('event_name', 'sap_invoice_recovery')->first();
        if (!$template || !$template->is_active) {
            return;
        }

        $emails = [];
        if (!empty($template->cc_emails)) {
            $emails = array_merge($emails, $template->cc_emails);
        }

        if (!empty($template->recipient_roles)) {
            $roles = $template->recipient_roles;
            $users = User::whereHas('roles', function($q) use ($roles) {
                $q->whereIn('name', $roles);
            })->pluck('email')->toArray();
            $emails = array_merge($emails, $users);
        }

        $emails = array_unique(array_filter($emails));

        if (empty($emails)) {
            Log::warning("No valid emails found for sap_invoice_recovery notification.");
            return;
        }

        Mail::to($emails)->send(new \App\Mail\SapInvoiceRecoveryAlert($template, $lastTime->toDateTimeString()));
        
        Log::info("Sent SAP Invoice Recovery Alert to: " . implode(',', $emails));
    }

    private function triggerAlert($lastTime, $diffMinutes)
    {
        // Spam prevention: Only send once per hour during an ongoing outage
        if (Cache::has('sap_delay_alert_sent')) {
            Log::info("SAP Delay Alert suppressed (spam prevention). Delay is $diffMinutes min.");
            return;
        }

        $template = EmailNotification::where('event_name', 'sap_invoice_delay')->first();
        if (!$template || !$template->is_active) {
            Log::warning("sap_invoice_delay email template not found or inactive.");
            return;
        }

        $emails = [];
        // Add CC emails
        if (!empty($template->cc_emails)) {
            $emails = array_merge($emails, $template->cc_emails);
        }

        // Add users by role
        if (!empty($template->recipient_roles)) {
            $roles = $template->recipient_roles;
            // Assuming Spatie roles or basic role logic
            $users = User::whereHas('roles', function($q) use ($roles) {
                $q->whereIn('name', $roles);
            })->pluck('email')->toArray();
            $emails = array_merge($emails, $users);
        }

        $emails = array_unique(array_filter($emails));

        if (empty($emails)) {
            Log::warning("No valid emails found for sap_invoice_delay notification.");
            return;
        }

        Mail::to($emails)->send(new SapInvoiceDelayAlert($template, $lastTime->toDateTimeString(), $diffMinutes));
        
        Log::info("Sent SAP Invoice Delay Alert to: " . implode(',', $emails));

        // Cache exactly for 60 minutes
        Cache::put('sap_delay_alert_sent', true, 60);
    }
}
