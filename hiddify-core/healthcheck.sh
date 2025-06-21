#!/bin/sh

# Check if hiddify process is running
if ! pgrep -f "HiddifyCli" > /dev/null; then
    echo "UNHEALTHY: HiddifyCli process not running"
    exit 1
fi

# Check if RedSocks process is running
if ! pgrep -f "redsocks" > /dev/null; then
    echo "UNHEALTHY: RedSocks process not running"
    exit 1
fi

# Check hiddify specific log 
if [ -f "/hiddify/logs/hiddify.log" ]; then
    CURRENT_TIME=$(date +%s)
    ERROR_COUNT=0
    
    tail -n 20 "/hiddify/logs/hiddify.log" | while read line; do
        if echo "$line" | grep -i "error\|failed\|timeout" | grep -v "connection test" > /dev/null; then
            LOG_TIMESTAMP=$(echo "$line" | cut -d' ' -f1-2)
            if [ -n "$LOG_TIMESTAMP" ]; then
                LOG_TIME=$(date -d "$LOG_TIMESTAMP" +%s 2>/dev/null || echo "0")
                if [ $((CURRENT_TIME - LOG_TIME)) -le 10 ]; then
                    ERROR_COUNT=$((ERROR_COUNT + 1))
                fi
            fi
        fi
    done
    
    if [ $ERROR_COUNT -gt 10 ]; then
        echo "UNHEALTHY: Too many errors in hiddify logs ($ERROR_COUNT errors in last 10 seconds)"
        exit 1
    fi
fi

# Test proxy connectivity by checking if port is listening
if ! netstat -ln | grep ":12334" > /dev/null; then
    echo "UNHEALTHY: Proxy port 12334 not listening"
    exit 1
fi

# Test RedSocks port
if ! netstat -ln | grep ":12345" > /dev/null; then
    echo "UNHEALTHY: RedSocks port 12345 not listening"
    exit 1
fi

echo "HEALTHY: All checks passed"
exit 0