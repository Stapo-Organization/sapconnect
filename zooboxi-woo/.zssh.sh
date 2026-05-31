#!/bin/bash
# Server check script for Zooboxi
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -i /Users/mohamedmahgoub/.ssh/id_rsa storezooboxi@62.138.14.178 "$@"
