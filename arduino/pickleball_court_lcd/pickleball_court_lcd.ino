// ============================================================
//  LPC Pickleball Court - LCD Display Controller
//  Hardware : Arduino Uno + I2C 16x2 LCD (address 0x27 / 0x3F)
//  Protocol : Serial 9600 baud  (from Python bridge on PC)
//
//  Supported commands (sent as a single newline-terminated line):
//    SET_COURT:<courtId>|<Display Name>
//        -> Assign which court this unit monitors.
//           e.g.  SET_COURT:court_1|COURT 1
//
//    CHECKIN:<courtId>|<PlayerName>|<remainingSeconds>[|<NextPlayer>]
//        -> Court just became occupied. Start countdown.
//           Optional 4th segment: name of next player shown on time-up.
//           e.g.  CHECKIN:court_1|Gabriel|3600|Ana
//
//    AVAILABLE:<courtId>
//        -> Court is now free.
//           e.g.  AVAILABLE:court_1
//
//    CUSTOM:<courtId>|<line1>|<line2>
//        -> Admin override: show any two lines on the LCD.
//           e.g.  CUSTOM:court_1|COURT CLOSED|Back at 5 PM
// ============================================================

#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// LCD Setup (try 0x3F if 0x27 shows blank screen)
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Admin-configurable: which court does this unit own?
String assignedCourtId  = "court_1";
String courtDisplayName = "COURT 1";

// Runtime state
bool   isOccupied       = false;
String playerName       = "";
String nextPlayerName   = "";   // Shown when timer reaches zero
long   remainingSeconds = 0;
unsigned long lastTickMs = 0;

// Admin custom message override
bool   customOverride   = false;
String customLine1      = "";
String customLine2      = "";

// Custom clock icon (char index 0)
byte clockIcon[8] = {
  0b01110,
  0b10101,
  0b10111,
  0b10001,
  0b10001,
  0b01110,
  0b00000,
  0b00000
};

// ─────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);
  Serial.println("ARDUINO_BOOTING");
  
  Wire.begin();
  #if defined(WIRE_HAS_TIMEOUT)
  Wire.setWireTimeout(250000, true);
  #endif

  lcd.init();
  lcd.backlight();
  lcd.createChar(0, clockIcon);

  showBootScreen();
  delay(1000);
  showAvailableScreen();

  Serial.println("ARDUINO_READY:" + assignedCourtId);
}

// ─────────────────────────────────────────────────────────────
void loop() {
  // 1. Read incoming serial command
  if (Serial.available() > 0) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() > 0) {
      processCommand(line);
    }
  }

  // 2. Skip auto-update while admin custom override is active
  if (customOverride) return;

  // 3. Tick countdown every second while occupied
  if (isOccupied && remainingSeconds > 0) {
    if (millis() - lastTickMs >= 1000UL) {
      lastTickMs = millis();
      remainingSeconds--;
      renderTimerRow();
      if (remainingSeconds <= 0) {
        showTimeUpScreen();
      }
    }
  }
}

bool isCourtMatch(String courtId) {
  return true; // Always accept commands sent directly over USB cable to this Arduino
}

// ─────────────────────────────────────────────────────────────
//  Command parser
// ─────────────────────────────────────────────────────────────
void processCommand(String cmd) {

  // SET_COURT:<id>|<name>
  if (cmd.startsWith("SET_COURT:")) {
    String body = cmd.substring(10);
    int sep = body.indexOf('|');
    if (sep != -1) {
      assignedCourtId  = body.substring(0, sep);
      courtDisplayName = body.substring(sep + 1);
    } else {
      assignedCourtId  = body;
      courtDisplayName = body;
    }
    isOccupied       = false;
    remainingSeconds = 0;
    customOverride   = false;
    showAvailableScreen();
    Serial.println("ACK_SET_COURT:" + assignedCourtId);
    return;
  }

  // CHECKIN:<courtId>|<player>|<seconds>[|<nextPlayer>]
  if (cmd.startsWith("CHECKIN:")) {
    String body = cmd.substring(8);
    int p1 = body.indexOf('|');
    int p2 = body.indexOf('|', p1 + 1);
    if (p1 == -1 || p2 == -1) return;

    String courtId = body.substring(0, p1);
    if (!isCourtMatch(courtId)) return;

    playerName       = body.substring(p1 + 1, p2);
    remainingSeconds = body.substring(p2 + 1).toInt();

    // Optional 4th segment: next player
    int p3 = body.indexOf('|', p2 + 1);
    if (p3 != -1) {
      nextPlayerName = body.substring(p3 + 1);
      nextPlayerName.trim();
    } else {
      nextPlayerName = "";
    }

    isOccupied     = true;
    customOverride = false;
    lastTickMs     = millis();

    triggerRestartEffect("PLAYER CHECK-IN", playerName);
    if (remainingSeconds <= 0) {
      showTimeUpScreen();
    } else {
      renderCheckinScreen();
    }
    Serial.println("ACK_CHECKIN:" + courtId);
    return;
  }

  // AVAILABLE:<courtId>
  if (cmd.startsWith("AVAILABLE:")) {
    String courtId = cmd.substring(10);
    if (!isCourtMatch(courtId)) return;

    isOccupied       = false;
    remainingSeconds = 0;
    playerName       = "";
    nextPlayerName   = "";
    customOverride   = false;
    triggerRestartEffect("COURT CLEARED", "Now Available");
    showAvailableScreen();
    Serial.println("ACK_AVAILABLE:" + courtId);
    return;
  }

  // CUSTOM:<courtId>|<line1>|<line2>
  if (cmd.startsWith("CUSTOM:")) {
    String body = cmd.substring(7);
    int p1 = body.indexOf('|');
    int p2 = body.indexOf('|', p1 + 1);
    if (p1 == -1) return;

    String courtId = body.substring(0, p1);
    if (!isCourtMatch(courtId)) return;

    customLine1 = (p2 != -1) ? body.substring(p1 + 1, p2) : body.substring(p1 + 1);
    customLine2 = (p2 != -1) ? body.substring(p2 + 1) : "";
    customOverride = true;

    triggerRestartEffect("UPDATING DISPLAY", "Applying edits..");
    showCustomScreen();
    Serial.println("ACK_CUSTOM:" + courtId);
    return;
  }

  // RESTART:<courtId>  — restart LCD animation and refresh
  if (cmd.startsWith("RESTART:")) {
    String courtId = cmd.substring(8);
    if (!isCourtMatch(courtId)) return;

    triggerRestartEffect("REBOOTING LCD...", courtDisplayName);
    lcd.init();
    lcd.backlight();
    if (customOverride) {
      showCustomScreen();
    } else if (isOccupied && remainingSeconds > 0) {
      renderCheckinScreen();
    } else {
      showAvailableScreen();
    }
    Serial.println("ACK_RESTART:" + courtId);
    return;
  }

  // CLEAR_CUSTOM:<courtId>  — revert to auto mode
  if (cmd.startsWith("CLEAR_CUSTOM:")) {
    String courtId = cmd.substring(13);
    if (courtId != assignedCourtId) return;

    customOverride = false;
    triggerRestartEffect("RESETTING...", "Auto Mode Active");
    if (isOccupied && remainingSeconds > 0) {
      renderCheckinScreen();
    } else {
      showAvailableScreen();
    }
    Serial.println("ACK_CLEAR_CUSTOM:" + courtId);
    return;
  }
}

// ─────────────────────────────────────────────────────────────
//  LCD Screen helpers
// ─────────────────────────────────────────────────────────────
void triggerRestartEffect(String title, String subtitle) {
  lcd.clear();
  lcd.noBacklight();
  delay(120);
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print(padCenter(title, 16));
  lcd.setCursor(0, 1);
  lcd.print(padCenter(subtitle, 16));
  delay(650);
  lcd.clear();
}

void showBootScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  LPC Pickleball");
  lcd.setCursor(0, 1);
  lcd.print("  Initializing..");
}

void showAvailableScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  String header = "[" + courtDisplayName + "]";
  header = padCenter(header, 16);
  lcd.print(header);
  lcd.setCursor(0, 1);
  lcd.print("  >> AVAILABLE <<");
}

void renderCheckinScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  String prefix   = courtDisplayName.substring(0, min((unsigned int)2, courtDisplayName.length())) + ":";
  String row0     = prefix + playerName;
  if (row0.length() > 16) row0 = row0.substring(0, 16);
  lcd.print(row0);
  renderTimerRow();
}

void renderTimerRow() {
  lcd.setCursor(0, 1);
  lcd.write(byte(0));  // clock icon

  long h = remainingSeconds / 3600;
  long m = (remainingSeconds % 3600) / 60;
  long s = remainingSeconds % 60;

  char buf[16];
  if (h > 0) {
    sprintf(buf, " %02ld:%02ld:%02ld left", h, m, s);
  } else {
    sprintf(buf, " %02ld:%02ld left   ", m, s);
  }
  lcd.print(buf);
}

void showTimeUpScreen() {
  isOccupied = false;
  lcd.clear();
  lcd.setCursor(0, 0);
  String header = "[" + courtDisplayName + "]";
  header = padCenter(header, 16);
  lcd.print(header);
  lcd.setCursor(0, 1);
  if (nextPlayerName.length() > 0) {
    // Show next player instead of generic message
    String nextRow = "Next:" + nextPlayerName;
    if (nextRow.length() > 16) nextRow = nextRow.substring(0, 16);
    nextRow = padCenter(nextRow, 16);
    lcd.print(nextRow);
  } else {
    lcd.print(" TIME UP! VACATE");
  }
}

void showCustomScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  String row0 = customLine1;
  if (row0.length() > 16) row0 = row0.substring(0, 16);
  lcd.print(row0);
  lcd.setCursor(0, 1);
  String row1 = customLine2;
  if (row1.length() > 16) row1 = row1.substring(0, 16);
  lcd.print(row1);
}

String padCenter(String s, int targetLen) {
  if ((int)s.length() >= targetLen) return s.substring(0, targetLen);
  int totalPad = targetLen - s.length();
  int leftPad  = totalPad / 2;
  int rightPad = totalPad - leftPad;
  String result = "";
  for (int i = 0; i < leftPad;  i++) result += " ";
  result += s;
  for (int i = 0; i < rightPad; i++) result += " ";
  return result;
}
