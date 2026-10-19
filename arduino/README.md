# LPC Pickleball – Arduino LCD Controller

This folder contains the embedded firmware and PC bridge script for the
**16x2 I2C LCD** mounted at each pickleball court.

---

## Folder Structure

```
arduino/
├── pickleball_court_lcd/
│   └── pickleball_court_lcd.ino   ← Upload this to Arduino Uno
├── firebase_to_arduino.py          ← Run this on the PC connected via USB
└── README.md
```

---

## Hardware Required

| Part | Details |
|------|---------|
| Arduino Uno | Any revision |
| 16x2 I2C LCD | Module with PCF8574 backpack (blue potentiometer on back) |
| USB-A to USB-B cable | Arduino Uno cable |
| Jumper wires (4) | Female-to-Male |

### Wiring (LCD I2C → Arduino Uno)

| LCD Pin | Arduino Pin |
|---------|-------------|
| GND     | GND         |
| VCC     | 5V          |
| SDA     | A4          |
| SCL     | A5          |

> If the screen stays blank after upload, turn the small blue pot on the
> LCD backpack with a screwdriver to adjust **contrast**.

---

## Step 1 — Upload Arduino Sketch

1. Open **Arduino IDE**
2. Install library: **Sketch → Include Library → Manage Libraries**
   - Search for `LiquidCrystal I2C` → Install (by Frank de Brabander)
3. Open `pickleball_court_lcd/pickleball_court_lcd.ino`
4. Select **Tools → Board → Arduino Uno**
5. Select the correct **Port** (e.g. COM3)
6. Click **Upload**

> **I2C Address:** Default is `0x27`. If the screen is blank after
> adjusting contrast, change line 13 in the `.ino` file to `0x3F`.

---

## Step 2 — Configure the Python Bridge

Edit the **CONFIG** section at the top of `firebase_to_arduino.py`:

```python
SERIAL_PORT        = "COM3"         # ✅ Arduino detected on COM3
TARGET_COURT_ID    = "court_1"      # Match a court ID in Firebase
COURT_DISPLAY_NAME = "COURT 1"      # Shown on LCD (keep short)
FIREBASE_DB_URL    = "https://pickleball-hub-af5f8-default-rtdb.firebaseio.com"
```

> For **Court 2**, use `court_2` / `"COURT 2"`, etc.
> Each Arduino unit should run its own copy of the bridge with a different court ID.

---

## Step 3 — Install Python Dependencies

```powershell
pip install pyserial requests
```

If `pip` is not recognised, use:
```powershell
python -m pip install pyserial requests
```

---

## Step 4 — Run the Bridge

```powershell
cd arduino
python firebase_to_arduino.py
```

Leave this terminal open while the system is running.

---

## How It All Connects

```
Admin scans QR in Flutter app
        │
        ▼
CourtService.updateCourtStatus()
        │ writes court_status/court_1
        ▼
Firebase Realtime Database
        │ polled every 3 seconds
        ▼
firebase_to_arduino.py  (Python Bridge on PC)
        │ USB Serial (9600 baud)
        ▼
Arduino Uno
        │
        ▼
16x2 I2C LCD  →  shows player name + countdown timer
```

---

## LCD Display Examples

**Available:**
```
  [COURT 1]       
  >> AVAILABLE <<
```

**Player checked in (e.g. Gabriel, 1 hour):**
```
C1:Gabriel
⏰ 59:59 left
```

**Time expired:**
```
  [COURT 1]
 TIME UP! VACATE
```
