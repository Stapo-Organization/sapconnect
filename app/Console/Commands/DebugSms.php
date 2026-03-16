<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Services\SMS\TaqnyatService;

class DebugSms extends Command
{
    protected $signature = 'debug:sms {mobile}';
    protected $description = 'Test SMS sending and check user settings';

    public function handle()
    {
        $mobile = $this->argument('mobile');
        $this->info("Checking user with mobile: $mobile");

        $user = User::where('mobile_number', $mobile)->first();

        if (!$user) {
            $this->error("User not found!");
        } else {
            $this->info("User found: {$user->name}");
            $this->info("Receive SMS Setting: " . ($user->receive_sms_on_zid_import ? 'TRUE' : 'FALSE'));
        }

        $this->info("Attempting to send test SMS...");

        $service = new TaqnyatService();
        $result = $service->sendSms($mobile, "Test SMS from Debug Command at " . now());

        if ($result) {
            $this->info("SMS sent successfully!");
        } else {
            $this->error("SMS failed to send.");
        }
    }
}
