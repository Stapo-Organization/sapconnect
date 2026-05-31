#!/usr/bin/env python3
import paramiko
import sys

# Replace locally disabled email block to remote server
host = "62.138.14.178"
user = "sapapimuntajat"
password = "h23N1KXMIL#$94"
path = "sapconnect_app/app/Services/StockTransferService.php"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(host, username=user, password=password)
    sftp = ssh.open_sftp()
    remote_file = sftp.file(path, "r")
    content = remote_file.read().decode('utf-8')
    remote_file.close()
    
    # replace the exact block
    to_replace = """// Notify sender warehouse users for new transfers
            if (!empty($newTransferIds)) {
                $this->notifyNewTransfers($newTransferIds);
            }"""
    replacement = """// Notify sender warehouse users for new transfers
            // DISABLED TEMPORARILY DURING FULL SYNC TO AVOID EMAIL SPAM
            // if (!empty($newTransferIds)) {
            //     $this->notifyNewTransfers($newTransferIds);
            // }"""
    
    if to_replace in content:
        content = content.replace(to_replace, replacement)
        remote_file = sftp.file(path, "w")
        remote_file.write(content.encode('utf-8'))
        remote_file.close()
        print("Successfully patched StockTransferService.php on the server.")
    else:
        print("String not found, perhaps already patched.")
    
    sftp.close()
    ssh.close()
except Exception as e:
    print(f"Error: {e}")
