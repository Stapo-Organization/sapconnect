<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Automation;
use App\Models\EmailNotification;

class MonitorFeatureSeeder extends Seeder
{
    public function run()
    {
        // 1. Register Automation
        Automation::updateOrCreate(
            ['command_signature' => 'sap:monitor-invoices'],
            [
                'name' => 'Monitoring SAP Invoices Delay',
                'code' => 'monitor_sap_invoices_delay',
                'schedule_frequency' => 'everyMinute',
                'is_active' => true,
            ]
        );

        // 2. Register Delay Email Notification Template
        EmailNotification::updateOrCreate(
            ['event_name' => 'sap_invoice_delay'],
            [
                'is_active' => true,
                'subject_ar' => 'عاجل: توقف استلام فواتير SAP من المعارض',
                'subject_en' => 'URGENT: SAP Invoices Delay Alert',
                'body_ar' => 'نود إشعاركم بأنه لم يتم استلام أي فواتير جديدة من ساب (SAP) خلال الـ {delay_minutes} دقيقة الماضية.',
                'body_en' => 'Please be advised that no new SAP invoices have been received for the last {delay_minutes} minutes.',
                'cc_emails' => ['mahgoub@ppte.sa'],
                'recipient_roles' => ['admin'],
            ]
        );

        // 3. Register Recovery Email Notification Template
        EmailNotification::updateOrCreate(
            ['event_name' => 'sap_invoice_recovery'],
            [
                'is_active' => true,
                'subject_ar' => 'تم الحل: استئناف استلام فواتير SAP بنجاح',
                'subject_en' => 'RESOLVED: SAP Invoices Sync Recovered',
                'body_ar' => 'تم استئناف استلام فواتير المبيعات من ساب (SAP) بنجاح والنظام الآن يعمل بشكل طبيعي.',
                'body_en' => 'SAP sales invoices sync has been successfully recovered and operations are back to normal.',
                'cc_emails' => ['mahgoub@ppte.sa'],
                'recipient_roles' => ['admin'],
            ]
        );
    }
}
