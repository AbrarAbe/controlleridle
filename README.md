# Bluetooth Controller Idle Timeout Script

This script monitors input events from a Bluetooth game controller on a Linux system and powers off the controller after a specified period of inactivity. It uses the ``evtest`` utility to detect events and applies a deadzone to analog inputs to avoid unintended disconnections due to minor stick drift.

Features :
- Detects input events from a specified Bluetooth controller.
- Automatically powers off the controller after a configurable idle timeout.
- Ignores minor stick drift with configurable deadzone thresholds.
- Dynamically finds the input event device for the controller by name.

## Requirements
- Linux system.
- ``evtest`` utility installed.
- A Bluetooth game controller.

## Installation
1. Clone or download this repository.
2. Ensure ``evtest`` is installed :

#### Ubuntu
```bash
sudo apt install evtest
``` 
#### Fedora
```bash
sudo dnf install evtest
``` 
#### Arch
```bash
sudo pacman -S evtest
``` 

## Configuration
Edit the script to configure the following parameters:

### Controller Name

List device input names :

```bash
grep -E 'Name' /proc/bus/input/devices
```
example output :

```bash
N: Name="Power Button"
N: Name="Asus Wireless Radio Control"
N: Name="HDA Intel PCH Headphone"
N: Name="PLAYSTATION(R)3 Controller Motion Sensors"
N: Name="PLAYSTATION(R)3 Controller"
```
Look for the ``Name=`` field corresponding to your controller.

Set the name of your controller as shown in ``/proc/bus/input/devices``:

```bash
CONTROLLER_NAME="PLAYSTATION\(R\)3 Controller"
```
### Idle Timeout

Specify the idle timeout in seconds:

```bash
IDLE_LIMIT=$((5 * 60))  # Time in seconds
```

### Deadzone Threshold

Define the deadzone for analog stick drift:

```bash
DEADZONE_THRESHOLD=15
```
## Usage

The script will:
- Detect your controller's input event device automatically.
- Monitor input activity and turn off the controller after the specified idle time.

### Manual Execution

Run the script manually with root privileges:

```bash
sudo ./controlleridle.sh
```

### Run at Startup Using systemd

#### 1. Create a Systemd Service File

- Create a service file for the script:

```bash 
sudo nano /etc/systemd/system/controlleridle.service
```

Add the following content to the file:

```ini
[Unit]
Description=Controller Idle Timeout Service
After=network.target

[Service]
ExecStart=/path/to/controlleridle.sh
Restart=on-failure
Environment=CONTROLLER_NAME="PLAYSTATION\(R\)3 Controller"
Environment=IDLE_TIMEOUT=300
Environment=DEADZONE_THRESHOLD=15
StandardOutput=journal
StandardError=journal
User=root

[Install]
WantedBy=multi-user.target
```

#### 2. Reload systemd Daemon
Reload the systemd daemon to recognize the new service:

```bash
sudo systemctl daemon-reload
```

#### 3. Enable the Service
Enable the service to start automatically at boot:

```bash
sudo systemctl enable controlleridle.service
```

#### 4. Start the Service
Start the service immediately:

```bash
sudo systemctl start controlleridle.service
```

#### 5. Check Service Status
Verify that the service is running:

```bash
sudo systemctl status controlleridle.service
```

### Hyprland Spesific
For hyprland, use the following in your ``hyprland.conf`` to run at startup.

```bash
exec-once = /path/to/controlleridle.sh
```

## Debugging

To see logs from the script, use:

```bash
sudo journalctl -u controlleridle.service
```

If the service fails, ensure the path to the script is correct and matches the ``ExecStart`` line in the service file.

## Limitations
- Minor analog stick drift could prevent the controller from timing out if the deadzone threshold is too low.
