#!/usr/bin/env sh

CONTROLLER_NAME="PLAYSTATION(R)3 Controller"  # Exact name of your controller
IDLE_LIMIT=300  # Time in seconds (5 mins)
GRACE_PERIOD=5  # Grace period after reconnection in seconds
LAST_EVENT_TIME=$(date +%s) # Initialize idle timer

# Function to dynamically get the event device for the controller
get_event_device() {
    # Escape parentheses specifically for grep
    ESCAPED_NAME=$(echo "$CONTROLLER_NAME" | sed 's/(/\\(/g; s/)/\\)/g')
    # Use the escaped controller name in the grep pattern
    grep -E "Name=\"$ESCAPED_NAME\"" -A 4 /proc/bus/input/devices | grep -Eo 'event[0-9]+' | head -n 1
}

# Function to monitor the controller
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
    
    LAST_EVENT_TIME=$(date +%s)  # Reset idle timer on reconnection

    # Introduce a grace period to allow stabilization
    echo "Initializing..."
    sleep $GRACE_PERIOD
    echo "Done. Starting to monitor inputs."

    # Run evtest to detect input events
    evtest "$CONTROLLER_DEVICE" | while read -r line; do
        CURRENT_TIME=$(date +%s)
        DEADZONE_THRESHOLD=150

        # Handle joystick axis events with deadzone filtering
        handle_abs_event() {
            local axis_value=$1
            local axis_name=$2

            # Ensure axis_value is an integer
            if ! [[ "$axis_value" =~ ^-?[0-9]+$ ]]; then
                echo "Invalid axis value: $axis_value"
                return
            fi

            # Check if the movement exceeds the deadzone
            if [ "$axis_value" -gt "$DEADZONE_THRESHOLD" ] || [ "$axis_value" -lt $((255 - DEADZONE_THRESHOLD)) ]; then
                LAST_EVENT_TIME=$CURRENT_TIME  # Reset idle timer
                echo "Movement detected on $axis_name value $axis_value. Resetting idle timer to $IDLE_LIMIT s."
            fi
        }

        # Main event handling logic for analog axis
        if echo "$line" | grep -q "EV_ABS"; then
            for axis in ABS_X ABS_Y ABS_RX ABS_RY; do
                if echo "$line" | grep -q "$axis"; then
                    value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
                    handle_abs_event "$value" "$axis"
                fi
            done
        fi

        # Button or key press events reset idle timer
        if echo "$line" | grep -q "EV_KEY"; then
            # Extract the button name from the line
            button_name=$(echo "$line" | awk -F'BTN_' '{print "BTN_" $2}' | awk '{print $1}')

            # Remove the closing parenthesis if it exists in the button name
            button_name=$(echo "$button_name" | sed 's/)//')

            # Extract the key value (0 or 1)
            key_value=$(echo "$line" | awk -F'value ' '{print $2}' | awk '{print $1}')
            echo "Key press detected on $button_name with value $key_value. Resetting idle timer to $IDLE_LIMIT s."
            LAST_EVENT_TIME=$CURRENT_TIME # Reset idle timer
        fi

        # Calculate idle time
        IDLE_TIME=$((CURRENT_TIME - LAST_EVENT_TIME))
        if [ "$IDLE_TIME" -ge "$IDLE_LIMIT" ]; then
            echo "Controller idle for $IDLE_LIMIT seconds. Turning off Bluetooth."
            bluetoothctl power off && sleep 1 && bluetoothctl power on
            break  # Stop monitoring; the controller is off
        fi
    done
}

# Main loop to handle persistent monitoring and reconnection
while true; do
    monitor_controller
    sleep 5  # Check every 5 seconds for reconnection
done
