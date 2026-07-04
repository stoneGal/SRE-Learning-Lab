#!/bin/bash
set -euo pipefail

LOG_FILE="/home/ubuntu/monitor.log"
THRESHOLD_CPU=80
THRESHOLD_DISK=80
THRESHOLD_MEM=80
INTERVAL=30
CONSECUTIVE_CPU=0

get_cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1
}

get_disk() {
    df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1
}

get_mem() {
    free | awk 'NR==2 {printf "%.0f", $3/$2*100}'
}

log_message() {
    local MESSAGE=$1
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP | $MESSAGE" | tee -a "$LOG_FILE"
}

cleanup() {
    echo ""
    log_message "Monitor stopped by user"
    exit 0
}

trap cleanup SIGINT SIGTERM

log_message "Monitor started"

while true; do
    CPU=$(get_cpu)
    DISK=$(get_disk)
    MEM=$(get_mem)
    STATUS="OK"

    if [ "$CPU" -gt "$THRESHOLD_CPU" ]; then
        CONSECUTIVE_CPU=$((CONSECUTIVE_CPU + 1))
        if [ "$CONSECUTIVE_CPU" -ge 3 ]; then
            STATUS="ALERT"
            log_message "CPU: ${CPU}% | DISK: ${DISK}% | MEM: ${MEM}% | STATUS: $STATUS - CPU HIGH FOR 3 CONSECUTIVE CHECKS"
        else
            log_message "CPU: ${CPU}% | DISK: ${DISK}% | MEM: ${MEM}% | STATUS: WARNING - CPU check ${CONSECUTIVE_CPU}/3"
        fi
    elif [ "$DISK" -gt "$THRESHOLD_DISK" ]; then
        STATUS="ALERT"
        CONSECUTIVE_CPU=0
        log_message "CPU: ${CPU}% | DISK: ${DISK}% | MEM: ${MEM}% | STATUS: $STATUS - DISK HIGH"
    elif [ "$MEM" -gt "$THRESHOLD_MEM" ]; then
        STATUS="ALERT"
        CONSECUTIVE_CPU=0
        log_message "CPU: ${CPU}% | DISK: ${DISK}% | MEM: ${MEM}% | STATUS: $STATUS - MEM HIGH"
    else
        CONSECUTIVE_CPU=0
        log_message "CPU: ${CPU}% | DISK: ${DISK}% | MEM: ${MEM}% | STATUS: $STATUS"
    fi

    sleep $INTERVAL
done
