#!/usr/bin/env sh

IDLE_LIMIT=$((5 * 60))  # Time in seconds
LAST_EVENT_TIME=$(date +%s)
CONTROLLER_NAME="PLAYSTATION\\(R\\)3 Controller" # Exact name of your controller (with proper escaping for parentheses)

# Function to dynamically get the event device for the controller
get_event_device() {
    grep -E "Name=\"$CONTROLLER_NAME\"" -A 4 /proc/bus/input/devices | grep -Eo 'event[0-9]+' | head -n 1
}

CONTROLLER_EVENT=$(get_event_device)
if [ -z "$CONTROLLER_EVENT" ]; then
    echo "Controller '$CONTROLLER_NAME' not found. Exiting."
    exit 1
fi

CONTROLLER_DEVICE="/dev/input/$CONTROLLER_EVENT"
echo "Controller detected at $CONTROLLER_DEVICE"

if [ ! -e "$CONTROLLER_DEVICE" ]; then
    echo "Controller device $CONTROLLER_DEVICE does not exist. Exiting."
    exit 1
fi

echo "Monitoring events from $CONTROLLER_DEVICE..."

# Monitor the input events
sudo evtest --grab "$CONTROLLER_DEVICE" 2>/dev/null | while read -r line; do
    CURRENT_TIME=$(date +%
    DEADZONE_THRESHOLD=170

    # Handle joystick axis events with deadzone filtering
    handle_abs_event() {
        local axis_value=$1
        local axis_name=$2

        # Ensure axis_value is an integer
        if ! [[ "$axis_value" =~ ^[0-9]+$ ]]; then
            echo "Invalid axis value: $axis_value"
            return
        fi

        # Check if the movement exceeds the deadzone
        if [ "$axis_value" -gt "$DEADZONE_THRESHOLD" ] && [ "$axis_value" -lt $((255 - DEADZONE_THRESHOLD)) ]; then
            LAST_EVENT_TIME=$(date +%s)  # Reset idle timer
            echo "Movement detected on $axis_name. Resetting idle timer."
        fi
    }

    # Main event handling logic for analog axis
    if echo "$line" | grep -q "EV_ABS"; then
        if echo "$line" | grep -q "ABS_X"; then
            value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
            handle_abs_event "$value" "ABS_X"
        fi

        if echo "$line" | grep -q "ABS_Y"; then
            value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
            handle_abs_event "$value" "ABS_Y"
        fi

        if echo "$line" | grep -q "ABS_RX"; then
            value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
            handle_abs_event "$value" "ABS_RX"
        fi

        if echo "$line" | grep -q "ABS_RY"; then
            value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
            handle_abs_event "$value" "ABS_RY"
        fi
    fi

    #  D-Pad Events
    if echo "$line" | grep -q "EV_KEY"; then
        echo "Input detected: $line"
        echo "Reset idle timer to $IDLE_LIMIT"
        LAST_EVENT_TIME=$CURRENT_TIME  # Reset idle timer on button input
    fi

    # Action Pad Events
    if echo "$line" | grep -q "EV_KEY"; then
        echo "Input detected: $line"
        echo "Reset idle timer to $IDLE_LIMIT"
        LAST_EVENT_TIME=$CURRENT_TIME  # Reset idle timer on button input
    fi

    # Calculate idle time
    IDLE_TIME=$((CURRENT_TIME - LAST_EVENT_TIME))
    if [ "$IDLE_TIME" -ge "$IDLE_LIMIT" ]; then
        echo "Controller idle for $IDLE_LIMIT seconds. Turning off Bluetooth."
        bluetoothctl power off && sleep 1 && bluetoothctl power on
        exit 0
    fi
done
