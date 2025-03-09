#!/bin/bash
# Weighted random payload selection

RANDOM=$$  # Seed with PID
RAND=$(($RANDOM % 100 + 1))

if [ $RAND -le 30 ]; then
    echo "./performance-reports/20250309_141332/payloads/clean.json"
elif [ $RAND -le 60 ]; then
    echo "./performance-reports/20250309_141332/payloads/dummy-secret.json"
else
    echo "./performance-reports/20250309_141332/payloads/real-secret.json"
fi
