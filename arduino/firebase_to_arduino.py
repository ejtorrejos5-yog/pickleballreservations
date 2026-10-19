"""
LPC Pickleball Court - Firebase to Arduino LCD Bridge
======================================================
Connects 1 LCD via Arduino to 1 dedicated court.
Polls Firebase Realtime DB and streams court status & countdown timer
directly to the 16x2 I2C LCD via USB Serial.

Architecture:
  1 LCD = 1 Court.
  Each court display runs this script with its designated court assignment.

Usage:
  python firebase_to_arduino.py --court 1
  python firebase_to_arduino.py --court 2 --port COM4
  python firebase_to_arduino.py (interactive court picker)
"""

import sys
import time
import argparse
import requests
import serial
import serial.tools.list_ports

# Ensure console logs are flushed immediately
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(line_buffering=True)

# ─────────────────────────────────────────────────────────────
#  DEFAULT CONFIG
# ─────────────────────────────────────────────────────────────
DEFAULT_BAUD       = 9600
POLL_INTERVAL_SEC  = 2  # Poll Firebase every 2 seconds

FIREBASE_DB_URL = "https://pickleball-hub-af5f8-default-rtdb.firebaseio.com"

# Standard court presets (mapping short numbers / friendly names to Firestore IDs)
COURT_PRESETS = {
    "1": {
        "court_id": "nTiDjaUFXFlKcqWa8Y8M",
        "alt_ids": ["court_1", "nTiDjaUFXFlKcqWa8Y8M"],
        "display_name": "COURT 1",
    },
    "2": {
        "court_id": "F9etMsllvoRpT7a7xN3O",
        "alt_ids": ["court_2", "F9etMsllvoRpT7a7xN3O"],
        "display_name": "COURT 2",
    },
    "3": {
        "court_id": "dNydjbXGbKHu6f8kFEoM",
        "alt_ids": ["court_3", "dNydjbXGbKHu6f8kFEoM"],
        "display_name": "COURT 3",
    },
    "4": {
        "court_id": "3i6TMY5z2tqrGdDhqGQ1",
        "alt_ids": ["court_4", "3i6TMY5z2tqrGdDhqGQ1"],
        "display_name": "COURT 4",
    },
}


def parse_arguments():
    parser = argparse.ArgumentParser(description="LPC Pickleball LCD Bridge (1 LCD per Court)")
    parser.add_argument(
        "--court",
        type=str,
        default="1",
        help="Court number (1, 2, 3, 4) or court ID. Default is 1.",
    )
    parser.add_argument(
        "--port",
        type=str,
        default=None,
        help="Serial COM port (e.g. COM3). Auto-detected if omitted.",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=DEFAULT_BAUD,
        help="Serial baud rate (default 9600).",
    )
    return parser.parse_args()


def resolve_court_config(court_arg: str):
    """Resolve court argument into IDs and display name."""
    clean_arg = court_arg.strip().lower()

    # Check preset numeric key ("1", "2", "3", "4")
    for key, data in COURT_PRESETS.items():
        if clean_arg in [key, f"court_{key}", f"court {key}", f"court{key}"]:
            return data["court_id"], data["alt_ids"], data["display_name"]

    # Check match by direct court_id
    for key, data in COURT_PRESETS.items():
        if court_arg in data["alt_ids"] or court_arg == data["court_id"]:
            return data["court_id"], data["alt_ids"], data["display_name"]

    # Fallback for custom or newly added court
    return court_arg, [court_arg], court_arg.upper()[:7]


def auto_detect_serial_port(preferred_port: str | None = None) -> str:
    """Find the best matching serial COM port."""
    if preferred_port:
        return preferred_port

    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("[Bridge] No COM ports detected. Defaulting to COM3.")
        return "COM3"

    # Prioritize Arduino or USB serial devices
    for p in ports:
        desc = (p.description or "").lower()
        if "arduino" in desc or "ch340" in desc or "usb-serial" in desc or "ftdi" in desc:
            print(f"[Bridge] Found device: {p.device} ({p.description})")
            return p.device

    # Otherwise return the first available COM port
    chosen = ports[0].device
    print(f"[Bridge] Using COM port: {chosen} ({ports[0].description})")
    return chosen


def open_serial_connection(port: str, baud: int) -> serial.Serial:
    """Open serial port and wait for Arduino Uno boot sequence."""
    print(f"[Bridge] Opening {port} at {baud} baud...")
    while True:
        try:
            ser = serial.Serial(port, baud, timeout=2)
            # Allow Arduino 3.5 seconds to complete boot and I2C initialization
            time.sleep(3.5)
            # Drain any boot messages
            while ser.in_waiting:
                boot_msg = ser.readline().decode("utf-8", errors="ignore").strip()
                if boot_msg:
                    print(f"[Arduino] {boot_msg}")
            print(f"[Bridge] Serial port {port} is ready!")
            return ser
        except serial.SerialException as e:
            print(f"[Bridge] Waiting for Arduino on {port}: {e}")
            time.sleep(3)


def send_command(ser: serial.Serial, cmd: str):
    """Send command string to Arduino and print acknowledgement."""
    full = cmd.strip() + "\n"
    try:
        ser.write(full.encode("utf-8"))
        print(f"[Bridge] >> Sent: {cmd}")
        time.sleep(0.15)
        while ser.in_waiting:
            ack = ser.readline().decode("utf-8", errors="ignore").strip()
            if ack:
                print(f"[Arduino] << {ack}")
    except Exception as e:
        print(f"[Bridge] Send error: {e}")


def fetch_court_status(court_id: str, alt_ids: list[str]) -> dict | None:
    """Poll Firebase for status of the assigned court."""
    ids_to_try = [court_id] + [cid for cid in alt_ids if cid != court_id]
    for cid in ids_to_try:
        try:
            resp = requests.get(f"{FIREBASE_DB_URL}/court_status/{cid}.json", timeout=3)
            if resp.status_code == 200 and resp.json() is not None:
                data = resp.json()
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return None


def fetch_lcd_override(court_id: str, alt_ids: list[str]) -> dict | None:
    """Poll Firebase for custom message overrides for this court."""
    ids_to_try = [court_id] + [cid for cid in alt_ids if cid != court_id]
    for cid in ids_to_try:
        try:
            resp = requests.get(f"{FIREBASE_DB_URL}/lcd_override/{cid}.json", timeout=2)
            if resp.status_code == 200 and resp.json():
                data = resp.json()
                if isinstance(data, dict) and data.get("enabled", False):
                    return data
        except Exception:
            pass
    return None


def fetch_lcd_command(court_id: str, alt_ids: list[str]) -> dict | None:
    """Poll for immediate hardware commands like RESTART."""
    ids_to_try = [court_id] + [cid for cid in alt_ids if cid != court_id] + ["global"]
    for cid in ids_to_try:
        try:
            resp = requests.get(f"{FIREBASE_DB_URL}/lcd_command/{cid}.json", timeout=2)
            if resp.status_code == 200 and resp.json():
                data = resp.json()
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return None


def report_status(court_id: str, alt_ids: list[str], port: str, connected: bool):
    """Heartbeat to Firebase so Admin dashboard shows connection status."""
    now_ms = int(time.time() * 1000)
    payload = {
        "connected": connected,
        "port": port,
        "lastSeen": now_ms,
        "courtId": court_id,
    }
    targets = set([court_id] + alt_ids + ["global"])
    for cid in targets:
        try:
            requests.patch(f"{FIREBASE_DB_URL}/arduino_status/{cid}.json", json=payload, timeout=1.5)
        except Exception:
            pass


def main():
    args = parse_arguments()
    court_id, alt_ids, display_name = resolve_court_config(args.court)
    port = auto_detect_serial_port(args.port)

    print("\n" + "=" * 60)
    print("  LPC PICKLEBALL - ARDUINO LCD COURT CONTROLLER")
    print("=" * 60)
    print(f"  Assigned Court : {display_name} (ID: {court_id})")
    print(f"  Aliases        : {', '.join(alt_ids)}")
    print(f"  Serial Port    : {port} @ {args.baud} baud")
    print(f"  Firebase DB    : {FIREBASE_DB_URL}")
    print("=" * 60 + "\n")

    ser = open_serial_connection(port, args.baud)

    # Initialize assigned court identity on Arduino Uno
    send_command(ser, f"SET_COURT:{court_id}|{display_name}")
    report_status(court_id, alt_ids, port, True)

    last_state_key    = None
    last_override_key = None
    last_cmd_ts       = 0
    last_heartbeat    = 0
    last_synced_rem   = -1

    print(f"[Bridge] Active! Monitoring {display_name} in Firebase...")
    print("[Bridge] Press Ctrl+C in this terminal to stop.\n")

    while True:
        try:
            now_sec = time.time()
            now_ms  = int(now_sec * 1000)

            # 1. Periodic Heartbeat every 5 seconds
            if now_sec - last_heartbeat >= 5:
                report_status(court_id, alt_ids, port, True)
                last_heartbeat = now_sec

            # 2. Check for RESTART command from Admin panel
            cmd_data = fetch_lcd_command(court_id, alt_ids)
            if cmd_data and cmd_data.get("command") == "RESTART":
                cmd_ts = cmd_data.get("timestamp", 0)
                if cmd_ts > last_cmd_ts:
                    last_cmd_ts = cmd_ts
                    send_command(ser, f"RESTART:{court_id}")
                    last_state_key = None
                    last_override_key = None
                    last_synced_rem = -1
                    print(f"[Bridge] LCD RESTART triggered for {display_name}.")

            # 3. Check for Admin Custom Message Override & Court Status
            override = fetch_lcd_override(court_id, alt_ids)
            data     = fetch_court_status(court_id, alt_ids)

            is_occupied = data is not None and data.get("isOccupied", False)
            player_name  = (data.get("reservedByName") or "Player").strip() if is_occupied else ""
            booked_until = data.get("bookedUntil", 0) if is_occupied else 0
            occupied_since = data.get("occupiedSince", 0) if is_occupied else 0
            next_player  = (data.get("nextPlayerName") or "").strip() if is_occupied else ""
            rem_seconds  = max(0, int((booked_until - now_ms) / 1000)) if is_occupied else 0

            # Determine if this is a genuine custom message (not just empty or default court name)
            is_real_custom = False
            line1 = ""
            line2 = ""
            set_at = 0
            if override and override.get("enabled", False):
                line1 = (override.get("line1") or "").strip()[:16]
                line2 = (override.get("line2") or "").strip()[:16]
                set_at = override.get("setAt", 0)
                is_real_custom = bool(line2) or (bool(line1) and line1.upper() not in [display_name.upper(), "COURT 1", "COURT 2", "COURT 3", "COURT 4"])

            # Clean up lingering placeholder override in Firebase if it's not a real custom message
            if override and override.get("enabled", False) and not is_real_custom:
                try:
                    requests.patch(f"{FIREBASE_DB_URL}/lcd_override/{court_id}.json", json={"enabled": False}, timeout=1)
                except Exception:
                    pass

            # PRIORITY RULE:
            # If an active player check-in is running (isOccupied == True and rem_seconds > 0):
            # Show the live countdown unless the admin deliberately created a new custom override AFTER check-in
            show_custom = False
            if is_real_custom:
                if not is_occupied:
                    show_custom = True
                elif set_at > occupied_since:
                    show_custom = True

            if show_custom:
                override_key = f"CUSTOM_{line1}_{line2}_{set_at}"
                if last_override_key != override_key:
                    send_command(ser, f"CUSTOM:{court_id}|{line1}|{line2}")
                    last_override_key = override_key
                    last_state_key    = None
                    print(f"[Bridge] CUSTOM OVERRIDE -> L1: '{line1}' | L2: '{line2}'")

            elif is_occupied:
                # Clear custom override on Arduino if reverting to court session
                if last_override_key is not None:
                    send_command(ser, f"CLEAR_CUSTOM:{court_id}")
                    last_override_key = None
                    last_state_key    = None

                # State key represents the booking session
                state_key = f"CHECKIN_{player_name}_{booked_until}_{next_player}"

                # Send CHECKIN when session starts, or if a new booking begins
                if last_state_key != state_key:
                    if next_player:
                        cmd = f"CHECKIN:{court_id}|{player_name}|{rem_seconds}|{next_player}"
                    else:
                        cmd = f"CHECKIN:{court_id}|{player_name}|{rem_seconds}"

                    send_command(ser, cmd)
                    last_state_key  = state_key
                    last_synced_rem = rem_seconds

                    m = rem_seconds // 60
                    s = rem_seconds % 60
                    nxt = f" (Next: {next_player})" if next_player else ""
                    print(f"[Bridge] Status: OCCUPIED by {player_name} | {m:02d}:{s:02d} left{nxt}")

            else:
                # Court is FREE / AVAILABLE
                if last_override_key is not None:
                    send_command(ser, f"CLEAR_CUSTOM:{court_id}")
                    last_override_key = None
                    last_state_key    = None

                state_key = "AVAILABLE"
                if last_state_key != state_key:
                    send_command(ser, f"AVAILABLE:{court_id}")
                    last_state_key = state_key
                    last_synced_rem = -1
                    print(f"[Bridge] Status: AVAILABLE on {display_name}")

        except serial.SerialException as se:
            print(f"[Bridge] Serial connection lost: {se}. Reconnecting...")
            time.sleep(2)
            ser = open_serial_connection(port, args.baud)
            last_state_key = None
        except KeyboardInterrupt:
            print("\n[Bridge] Stopping LCD bridge...")
            report_status(court_id, alt_ids, port, False)
            ser.close()
            break
        except Exception as ex:
            print(f"[Bridge] Loop warning: {ex}")

        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    main()
