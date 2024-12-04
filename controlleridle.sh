#!/usr/bin/env sh

CONTROLLER_NAME="PLAYSTATION(R)3 Controller"
IDLE_LIMIT=300
GRACE_PERIOD=5
LAST_EVENT_TIME=$(date +%s)

# Function to dynamically get the event device for the controller
get_event_device() {
    # Escape parentheses specifically for grep
    ESCAPED_NAME=$(echo "$CONTROLLER_NAME" | sed 's/(/\\(/g; s/)/\\)/g')
    grep -E "Name=\"$ESCAPED_NAME\"" -A 4 /proc/bus/input/devices | grep -Eo 'event[0-9]+' | head -n 1
}

monitor_controller() {
    CONTROLLER_EVENT=$(get_event_device)
    if [ -z "$CONTROLLER_EVENT" ]; then
        echo "Controller not found. Waiting for reconnection..."
        return 1
    fi

    CONTROLLER_DEVICE="/dev/input/$CONTROLLER_EVENT"
    echo "Controller '$CONTROLLER_NAME' detected at $CONTROLLER_DEVICE"

    if [ ! -e "$CONTROLLER_DEVICE" ]; then
        echo "Controller device $CONTROLLER_DEVICE does not exist. Waiting for reconnection..."
        return 1
    fi

    LAST_EVENT_TIME=$(date +%s)
    echo "Initializing..."
    sleep $GRACE_PERIOD
    echo "Done. Starting to monitor inputs."

    # Use `read` with a timeout to avoid busy-waiting
    while IFS= read -r -t 1 line; do # Read with 1 second timeout
        CURRENT_TIME=$(date +%s)
        DEADZONE_THRESHOLD=150

        # Handle joystick axis events with deadzone filtering
        if [[ "$line" =~ ^EV_ABS.*ABS_(X|Y|RX|RY).*value ]]; then
            value="${line##*value }"
            value="${value%% *}"  # remove trailing spaces
            if (( value > DEADZONE_THRESHOLD || value < 255 - DEADZONE_THRESHOLD )); then
                LAST_EVENT_TIME=$CURRENT_TIME
            fi
        elif [[ "$line" =~ ^EV_KEY.*BTN_ ]]; then
            LAST_EVENT_TIME=$CURRENT_TIME
        fi

        IDLE_TIME=$((CURRENT_TIME - LAST_EVENT_TIME))
        if (( IDLE_TIME >= IDLE_LIMIT )); then
            echo "Controller idle for $IDLE_LIMIT seconds. Turning off Bluetooth."
            bluetoothctl power off && sleep 1 && bluetoothctl power on
            break
        fi
    done < <(timeout 600 evtest "$CONTROLLER_DEVICE") # Timeout after 10 minutes
}

while true; do
    monitor_controller
    sleep 60  # Check every 60 seconds for reconnection (increased from 5)
done