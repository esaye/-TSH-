#!/bin/bash
# Start TSH web server for GSF Nationals
# The server will listen on port 7779 (set in GSF-Nationals-2026/config.tsh)
cd /home/ebrimasaye/Development/TSH
exec perl tsh.pl GSF-Nationals-2026
