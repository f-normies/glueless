#!/bin/sh

mkdir -p /hiddify/logs
LOG_FILE="/hiddify/logs/glueless.log"
HIDDIFY_LOG="/hiddify/logs/hiddify.log"
REDSOCKS_LOG="/hiddify/logs/redsocks.log"
HIDDIFY_PIPE="/hiddify/logs/hiddify.pipe"
REDSOCKS_PIPE="/hiddify/logs/redsocks.pipe"

log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') [GLUELESS] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

setup_log_pipes() {
    mkfifo "$HIDDIFY_PIPE" 2>/dev/null || true
    mkfifo "$REDSOCKS_PIPE" 2>/dev/null || true
    
    # Start background processes to handle pipe logging
    # HiddifyCli pipe logger
    while true; do
        if [ -p "$HIDDIFY_PIPE" ]; then
            while read line; do
                if [ -n "$line" ]; then
                    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
                    # Clean up the line: remove duplicate timestamps but keep color codes
                    local clean_line=$(echo "$line" | sed 's/^+[0-9]* [0-9-]* [0-9:]* //')
                    echo "$timestamp [HIDDIFY] $clean_line" | tee -a "$HIDDIFY_LOG" >> "$LOG_FILE"
                fi
            done < "$HIDDIFY_PIPE"
        fi
        sleep 1
    done &
    HIDDIFY_LOGGER_PID=$!
    
    # RedSocks pipe logger
    while true; do
        if [ -p "$REDSOCKS_PIPE" ]; then
            while read line; do
                if [ -n "$line" ]; then
                    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
                    echo "$timestamp [REDSOCKS] $line" | tee -a "$REDSOCKS_LOG" >> "$LOG_FILE"
                fi
            done < "$REDSOCKS_PIPE"
        fi
        sleep 1
    done &
    REDSOCKS_LOGGER_PID=$!
}

get_server_ip() {
    if [ -f "/hiddify/proxy-config.json" ]; then
        # Extract server IP from outbounds section, skip DNS servers
        sed -n '/"outbounds"/,/]/p' /hiddify/proxy-config.json | grep -o '"server": "[^"]*"' | head -1 | cut -d'"' -f4
    else
        echo ""
    fi
}

cleanup() {
    log_message "Initiating cleanup..."
    # Stop RedSocks
    pkill redsocks 2>/dev/null || true
    # Stop logger processes
    kill $HIDDIFY_LOGGER_PID 2>/dev/null || true
    kill $REDSOCKS_LOGGER_PID 2>/dev/null || true
    # Clean up pipes
    rm -f "$HIDDIFY_PIPE" "$REDSOCKS_PIPE" 2>/dev/null || true
    # Clean iptables rules
    iptables -t nat -F OUTPUT 2>/dev/null || true
    iptables -t nat -F REDSOCKS 2>/dev/null || true
    iptables -t nat -X REDSOCKS 2>/dev/null || true
    log_message "Cleanup completed"
    exit 0
}

trap cleanup TERM INT

# Setup logging pipes
log_message "Setting up logging infrastructure..."
setup_log_pipes

# Start HiddifyCli
log_message "Starting HiddifyCli..."
if [ -f "/hiddify/hiddify-config.json" ]; then
    /hiddify/HiddifyCli run --config /hiddify/proxy-config.json -d /hiddify/hiddify-config.json > "$HIDDIFY_PIPE" 2>&1 &
else
    /hiddify/HiddifyCli run --config /hiddify/proxy-config.json > "$HIDDIFY_PIPE" 2>&1 &
fi
HIDDIFY_PID=$!

log_message "Checking if SOCKS5 proxy is ready..."
for i in $(seq 1 10); do
    if netstat -ln | grep ":12334" > /dev/null; then
        log_message "SOCKS5 proxy is ready on port 12334"
        break
    fi
    log_message "Waiting for SOCKS5 proxy... ($i/10)"
    sleep 1
done

# Start RedSocks
log_message "Starting RedSocks..."
redsocks -c /hiddify/redsocks.conf > "$REDSOCKS_PIPE" 2>&1 &
REDSOCKS_PID=$!

# Iptables rules
log_message "Setting up iptables rules..."
iptables -t nat -N REDSOCKS 2>/dev/null || true
iptables -t nat -F REDSOCKS

SERVER_IP=$(get_server_ip)
if [ -n "$SERVER_IP" ]; then
    log_message "Excluding VPN server IP: $SERVER_IP"
    iptables -t nat -A REDSOCKS -d "$SERVER_IP/32" -j RETURN
else
    log_message "[WARNING] Could not determine server IP from config"
fi

# Skip local addresses and proxy ports
iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN  
iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN

# Skip proxy ports to avoid loops
iptables -t nat -A REDSOCKS -p tcp --dport 12334 -j RETURN
iptables -t nat -A REDSOCKS -p tcp --dport 12335 -j RETURN
iptables -t nat -A REDSOCKS -p tcp --dport 12345 -j RETURN
iptables -t nat -A REDSOCKS -p tcp --dport 16450 -j RETURN
iptables -t nat -A REDSOCKS -p tcp --dport 16756 -j RETURN

# Redirect all other TCP traffic to RedSocks
iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-port 12345

# Apply the chain to OUTPUT
iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

log_message "GlueLESS is running!"

# Monitor processes
while kill -0 $HIDDIFY_PID 2>/dev/null; do
    sleep 30
    if ! kill -0 $REDSOCKS_PID 2>/dev/null; then
        log_message "[ERROR] RedSocks process died unexpectedly"
        break
    fi
    if ! kill -0 $HIDDIFY_LOGGER_PID 2>/dev/null; then
        log_message "[WARNING] HiddifyCli logger died, restarting..."
        setup_log_pipes
    fi
    if ! kill -0 $REDSOCKS_LOGGER_PID 2>/dev/null; then
        log_message "[WARNING] RedSocks logger died, restarting..."
        setup_log_pipes
    fi
done

wait $HIDDIFY_PID
