/*
 * ESP32 Exercise Sensor - BLE firmware (multitasking version)
 *
 * Protocol (all values little-endian):
 *   Service   4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *   Live R    beb5483e-36e1-4688-b7f5-ea07361b26a8 (NOTIFY)  8 bytes:  u32 ms_since_start, u32 reps
 *   Live H    beb5483e-36e1-4688-b7f5-ea07361b26a9 (NOTIFY) 12 bytes:  u32 ms_since_start, f32 heart rate, f32 SpO2
 *   Control   beb5483e-36e1-4688-b7f5-ea07361b26aa (WRITE)   1 byte:   0x01=start, 0x02=stop
 *   Summary   beb5483e-36e1-4688-b7f5-ea07361b26ab (NOTIFY) 40 bytes:  u32 duration_ms,
 *               u32 heartCount, f32 avg, f32 min, f32 max,
 *               u32 spCount,    f32 avg, f32 min, f32 max,
 *               u32 reps
 *   Status    beb5483e-36e1-4688-b7f5-ea07361b26ac (READ)    1 byte:   1 = session running, 0 = idle
 *             (the app reads this after every (re)connect to resync its UI)
 *
 * Reconnecting: if the app drops mid-session, the session KEEPS RUNNING for
 * SESSION_GRACE_MS so the app can reconnect and press Stop normally. If it
 * doesn't come back in time, the session is dropped.
 *
 * Threading model (who owns what):
 *   - loop() task (core 1): BLE commands, accelerometer / rep counting,
 *       session stats, and ALL BLE notifications.
 *   - pulseOxTask (core 0): the MAX30102 and everything that touches I2C.
 *       It never touches BLE or the session stats. It only sends finished
 *       (HR, SpO2) averages to loop() through a queue.
 *   Because each piece of state has exactly one owner, no mutexes are needed.
 *
 * Works with the ESP32 Arduino core 2.x and 3.x (built-in BLE library).
 */
 

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DFRobot_MAX30102.h>
#include <Wire.h>

// ---------- Configuration (edit these) ----------
#define DEVICE_NAME   "ECE190ExerciseSensor"
#define SERVICE_UUID  "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LIVE_R_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define LIVE_H_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define CONTROL_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26aa"
#define SUMMARY_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26ab"
#define STATUS_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26ac"

#define CMD_START 0x01
#define CMD_STOP  0x02

// Which core runs the pulse oximeter task. 0 = truly parallel with loop().
// If you ever see "Task watchdog got triggered" in the serial output, set this to 1.
#define OX_CORE 0

// How long a session keeps running after the app disconnects, waiting for it
// to reconnect. 0 = drop the session immediately on disconnect.
#define SESSION_GRACE_MS 3000UL

// Wait this long after a disconnect before advertising again, so the BLE
// stack has finished cleaning up the old connection.
#define ADV_RESTART_DELAY_MS 300UL

// ---------- BLE state ----------
BLEServer*         server       = nullptr;
BLECharacteristic* liveRChar    = nullptr;
BLECharacteristic* liveHChar    = nullptr;
BLECharacteristic* summaryChar  = nullptr;
BLECharacteristic* statusChar   = nullptr;

volatile bool    deviceConnected = false;
volatile uint8_t pendingCmd      = 0;   // set in BLE callbacks, handled in loop()
volatile uint32_t disconnectedAtMs = 0; // ehrn the last disconnect happened
volatile bool    advRestartPending = false; // loop() restarts advertising

// ---------- Session state (shared, so volatile) ----------
volatile bool     sessionActive = false;
volatile uint32_t sessionId     = 0;    // bumped on every start; tags pulse-ox results
uint32_t          sessionStartMs = 0;

// Session statistics: owned and updated ONLY by the loop() task.
uint32_t heartCount = 0;
double   heartSum   = 0;
float    heartMin   = 0;
float    heartMax   = 0;

uint32_t spCount = 0;
double   spSum   = 0;
float    spMin   = 0;
float    spMax   = 0;

uint32_t repCount = 0;

// ---------- Queue: pulseOxTask -> loop() ----------
struct VitalsMsg {
  uint32_t sid;      // sessionId this reading belongs to
  float    hr;
  float    spo2;
};
QueueHandle_t vitalsQueue = nullptr;

/* ------- PULSE OXIMETER (owned by pulseOxTask) --------  */
DFRobot_MAX30102 particleSensor;

// Sensor measurements
int32_t SPO2;
int32_t heartRate;
int8_t SPO2Valid;
int8_t heartRateValid;

// IR stability
uint32_t previousIR = 0;
uint32_t currentIR = 0;

const float IR_CHANGE_PERCENT = 8.0;

bool firstReading = true;
int stableCount = 0;

const int REQUIRED_STABLE_WINDOWS = 3;

// Measurement averaging
const int DATASET_SIZE = 5;

int32_t heartRateData[DATASET_SIZE];
int32_t SPO2Data[DATASET_SIZE];

int dataCount = 0;

// Previous accepted averages for outlier checking
float previousHRMean = 0;
float previousSPO2Mean = 0;

bool havePreviousAverage = false;

uint32_t oxSid = 0;   // last sessionId the pulse-ox task has seen

/*
  Wrist rep counter: ESP32 + ADXL335  (owned by loop())

  Wiring: VIN -> 3V3, GND -> GND, X -> GPIO34, Y -> GPIO35, Z -> GPIO32
  (leave 3Vo and ST unconnected)

  Axes as worn:
    Y = along the forearm, toward the fingers
    X = through the wrist, back to front (out of the back of the wrist)
    Z = across the wrist (thumb to pinky)

  How a rep is counted:
    1. Remove gravity, convert to m/s^2, and integrate once to get speed.
    2. A "phase" starts when speed rises above START_V and ends when it falls
       back under END_V. It only counts if its peak speed passes minPeak
       (so small wobbles are ignored).
    3. A rep is a phase in one direction followed by a phase back the other
       way. It is counted when the movement returns to where it started, so
       begin each set in the same position.
       In mixed mode there is no single direction, so any two phases count.

  Live readout: the line printed every PRINT_MS shows the current speed.
  Lower PRINT_MS for more readings (10 = 100 per second, the sensor's rate).
  Set PLOT to true to use the Serial Plotter instead.
*/

const int PIN_X = 34, PIN_Y = 35, PIN_Z = 32;

// Printing
const unsigned long PRINT_MS = 1000;           // time between live readings; smaller = more prints
const bool SHOW_LIVE = true;                  // print the live speed readout
const bool SHOW_PHASES = true;                // print every phase (+/- is its direction)
const bool PLOT = false;                      // true = Serial Plotter output (speed and threshold)

// Sensor scaling (ADXL335 at about 3.3 V)
const float ZERO_MV = 1650.0f;
const float MV_PER_G = 330.0f;
const float GRAVITY = 9.81f;
const unsigned long SAMPLE_US = 10000;        // 100 samples per second

// Integration
const float GRAV_ALPHA = 0.01f;               // slow average that tracks gravity (about 1 s)
const float LEAK = 1.0f;                      // per second: bleeds off integration drift
const float STILL_G = 0.08f;                  // smoothed movement under this counts as "still" (raise if "(still)" never shows)
const unsigned long STILL_MS = 150;
const float SHORT_ALPHA = 0.03f;              // average of the last third of a second, used to judge stillness
const float LEVEL_ALPHA = 0.1f;               // smooths the stillness level so ADC noise doesn't break it
const float ZUPT_MAX_V = 0.30f;               // m/s: only reset speed to 0 when it is already low

// Rep detection
const float START_V = 0.06f;                  // m/s: a phase starts above this
const float END_V = 0.03f;                    // m/s: a phase ends below this
const unsigned long MIN_PHASE_MS = 200;
const unsigned long MAX_PHASE_MS = 5000;
const unsigned long REP_TIMEOUT_MS = 5000;    // a lone half rep is dropped after this
const int PHASES_PER_REP = 2;                 // used in mixed mode only
const float RETURN_FACTOR = 0.6f;             // the slower return phase needs only this share of minPeak
const unsigned long MERGE_MS = 400;           // same-direction phases this close together are one movement

float minPeak = 0.20f;                        // m/s: a phase must reach this speed

enum Axis { AX_X, AX_Y, AX_Z, AX_MIX };
Axis mode = AX_Y;
const char* AXIS_NAME[] = {"X (through the wrist)", "Y (along the forearm)", "Z (across the wrist)", "mixed (all axes)"};
const char AXIS_CH[3] = {'X', 'Y', 'Z'};

float gEst[3], aAvg[3], vel[3] = {0, 0, 0}, axPeak[3];
float stillLevel = 0;
bool stillNow = false;
float pv[3] = {0, 0, 0};                      // velocity at the fastest moment of the current phase
float peak = 0, speedNow = 0;
bool ready = false, inPhase = false;
unsigned long lastUs = 0, stillSince = 0, phaseStart = 0, lastPhaseEnd = 0;
int phases = 0;
int pendingSign = 0;                          // direction of an unfinished rep: +1, -1, or 0 for none

float readG(int pin) {
  float mv = (analogReadMilliVolts(pin) + analogReadMilliVolts(pin) +
              analogReadMilliVolts(pin) + analogReadMilliVolts(pin)) / 4.0f;
  return (mv - ZERO_MV) / MV_PER_G;
}

float currentSpeed() {
  switch (mode) {
    case AX_X: return fabsf(vel[0]);
    case AX_Y: return fabsf(vel[1]);
    case AX_Z: return fabsf(vel[2]);
    default:   return sqrtf(vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2]);
  }
}

void resetReps() {
  repCount = 0; phases = 0; pendingSign = 0; inPhase = false;
  for (int i = 0; i < 3; i++) vel[i] = 0;
}

// Make the next update() start fresh (no stale timing or gravity estimate).
void resetAccelState() {
  lastUs = 0; ready = false; stillSince = 0; stillLevel = 0; stillNow = false;
}

void countRep(int best) {
  repCount++;
  Serial.printf("REP %lu   peak %.2f m/s   main axis %c   (back at start position)\n",
                repCount, peak, AXIS_CH[best]);
  if (deviceConnected) sendLive_R(millis() - sessionStartMs, repCount);
}

void endPhase(unsigned long now) {
  int best = 0;
  for (int i = 1; i < 3; i++) if (axPeak[i] > axPeak[best]) best = i;

  if (mode == AX_MIX) {                     // no single direction: any two phases make a rep
    phases++;
    lastPhaseEnd = now;
    if (SHOW_PHASES) Serial.printf("  phase %.2f m/s\n", peak);
    if (phases >= PHASES_PER_REP) { phases = 0; countRep(best); }
    return;
  }

  // Direction of this phase along the chosen axis (+1 or -1)
  int sgn = pv[(int)mode] >= 0 ? 1 : -1;
  if (SHOW_PHASES) Serial.printf("  phase %c%.2f m/s\n", sgn > 0 ? '+' : '-', peak);

  if (pendingSign == 0) {
    pendingSign = sgn;                      // first half of a rep
  } else if (sgn != pendingSign) {
    pendingSign = 0;                        // came back the other way: rep complete
    countRep(best);
  } else if (now - lastPhaseEnd > MERGE_MS) {
    pendingSign = sgn;                      // the return was missed, so start fresh
  }                                         // otherwise: a fragment of the same movement, ignore
  lastPhaseEnd = now;
}

void trackPhase(float s, unsigned long now) {
  if (!inPhase) {
    if (s > START_V) {
      inPhase = true;
      phaseStart = now;
      peak = s;
      for (int i = 0; i < 3; i++) { axPeak[i] = 0; pv[i] = vel[i]; }
    }
  } else {
    if (s > peak) {
      peak = s;
      for (int i = 0; i < 3; i++) pv[i] = vel[i];   // remember which way we were moving
    }
    for (int i = 0; i < 3; i++) axPeak[i] = fmaxf(axPeak[i], fabsf(vel[i]));

    unsigned long dur = now - phaseStart;
    bool returned = s < END_V;
    if (returned || dur > MAX_PHASE_MS) {
      inPhase = false;
      // The slower return half of a rep needs only part of the minimum speed
      float need = minPeak;
      if (mode != AX_MIX && pendingSign != 0) need *= RETURN_FACTOR;
      if (returned && peak >= need && dur >= MIN_PHASE_MS) endPhase(now);
    }
  }
  // Drop a lone half rep if the second half never comes
  if (now - lastPhaseEnd > REP_TIMEOUT_MS) { phases = 0; pendingSign = 0; }
}

void update() {
  unsigned long nowUs = micros();
  if (lastUs == 0) { lastUs = nowUs; return; }
  if (nowUs - lastUs < SAMPLE_US) return;
  float dt = (nowUs - lastUs) / 1e6f;
  if (dt > 0.05f) dt = 0.05f;               // safety: never integrate over a long stall
  lastUs = nowUs;
  unsigned long now = millis();

  float a[3] = { readG(PIN_X), readG(PIN_Y), readG(PIN_Z) };
  if (!ready) { for (int i = 0; i < 3; i++) gEst[i] = aAvg[i] = a[i]; ready = true; }

  // Remove gravity and offsets with a slow average; what's left is movement
  float lin[3], devSq = 0;
  for (int i = 0; i < 3; i++) {
    gEst[i] += GRAV_ALPHA * (a[i] - gEst[i]);
    lin[i] = a[i] - gEst[i];
    aAvg[i] += SHORT_ALPHA * (a[i] - aAvg[i]);
    float d = a[i] - aAvg[i];
    devSq += d * d;
  }

  // "Still" = the reading barely differs from its own last third of a second.
  // Unlike the gravity estimate, this isn't thrown off by a recent tilt, and the
  // smoothing keeps single noisy readings from breaking it.
  stillLevel += LEVEL_ALPHA * (sqrtf(devSq) - stillLevel);
  if (stillLevel < STILL_G) { if (stillSince == 0) stillSince = now; }
  else stillSince = 0;
  bool still = stillSince != 0 && now - stillSince >= STILL_MS;
  stillNow = still;

  // Integrate acceleration into speed (m/s), with a leak against drift
  float v2 = 0;
  for (int i = 0; i < 3; i++) {
    vel[i] += lin[i] * GRAVITY * dt;
    vel[i] *= 1.0f - LEAK * dt;
    v2 += vel[i] * vel[i];
  }
  // Zero-velocity reset: only when already slow, so steady slow movement isn't wiped
  if (still && sqrtf(v2) < ZUPT_MAX_V) {
    for (int i = 0; i < 3; i++) {
      vel[i] = 0;
      gEst[i] = aAvg[i];  // snap gravity to what we're reading, clearing any leftover error
    }
  }

  speedNow = currentSpeed();
  trackPhase(speedNow, now);
}

void livePrint() {
  static unsigned long last = 0;
  unsigned long now = millis();
  if (now - last < PRINT_MS) return;
  last = now;

  if (PLOT) {
    Serial.printf("speed:%.3f threshold:%.3f\n", speedNow, minPeak);
  } else if (SHOW_LIVE) {
    Serial.printf("speed %.2f m/s | X %+.2f  Y %+.2f  Z %+.2f | reps %lu%s\n",
                  speedNow, vel[0], vel[1], vel[2], repCount, stillNow ? "  (still)" : "");
  }
}

// ---------- BLE callbacks ----------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    deviceConnected = true;
    advRestartPending = false;
  }
  void onDisconnect(BLEServer*) override {
    // Set the timestamp BEFORE the flag so loop() never sees a stale time.
    disconnectedAtMs = millis();
    advRestartPending = true;        // loop() restarts advertising shortly
    deviceConnected = false;
  }
};

class ControlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    auto v = c->getValue();          // std::string (core 2.x) or String (core 3.x)
    if (v.length() > 0) pendingCmd = (uint8_t)v[0];
  }
};

// ---------- BLE senders (call ONLY from loop()) ----------
void sendLive_R(uint32_t tMs, uint32_t value) {
  uint8_t buf[8];
  memcpy(buf + 0, &tMs,   4);
  memcpy(buf + 4, &value, 4);
  liveRChar->setValue(buf, sizeof(buf));
  liveRChar->notify();
}

void sendLive_H(uint32_t tMs, float h_value, float sp_value) {
  uint8_t buf[12];
  memcpy(buf + 0, &tMs,   4);
  memcpy(buf + 4, &h_value, 4);
  memcpy(buf + 8, &sp_value, 4);
  liveHChar->setValue(buf, sizeof(buf));
  liveHChar->notify();
}

// ---------- Vitals hand-off (loop() side) ----------
// Pull finished pulse-ox averages off the queue and fold them into the stats.
void drainVitals() {
  VitalsMsg m;
  while (xQueueReceive(vitalsQueue, &m, 0) == pdTRUE) {
    // Ignore readings from a previous session or after stop.
    if (!sessionActive || m.sid != sessionId) continue;

    heartCount++;
    spCount++;
    heartSum += m.hr;
    spSum += m.spo2;

    if (m.hr < heartMin) heartMin = m.hr;
    if (m.hr > heartMax) heartMax = m.hr;
    if (m.spo2 < spMin) spMin = m.spo2;
    if (m.spo2 > spMax) spMax = m.spo2;

    if (deviceConnected) sendLive_H(millis() - sessionStartMs, m.hr, m.spo2);
  }
}


// Keep the readable Status characteristic in sync with the session state.
void updateStatus() {
  if (!statusChar) return;
  uint8_t s = sessionActive ? 1 : 0;
  statusChar->setValue(&s, 1);
}

// ---------- Session logic (loop() side) ----------
void startSession() {
  heartCount = 0;
  heartSum = 0;
  heartMin = 3.4e38f;
  heartMax = -3.4e38f;
  spCount = 0;
  spSum = 0;
  spMin = 3.4e38f;
  spMax = -3.4e38f;
  resetReps();
  resetAccelState();
  xQueueReset(vitalsQueue);
  sessionStartMs = millis();
  sessionId = sessionId + 1;   // tells the pulse-ox task to reset its own state
  sessionActive = true;        // set last, after everything above is ready
  updateStatus();
  Serial.println("Session started");
}

void sendSummary() {
  uint32_t duration = millis() - sessionStartMs;
  float havg = heartCount ? (float)(heartSum / heartCount) : 0.0f;
  float hmn  = heartCount ? heartMin : 0.0f;
  float hmx  = heartCount ? heartMax : 0.0f;
  float savg = spCount ? (float)(spSum / spCount) : 0.0f;
  float smn  = spCount ? spMin : 0.0f;
  float smx  = spCount ? spMax : 0.0f;

  uint8_t buf[40];
  memcpy(buf + 0,  &duration, 4);
  memcpy(buf + 4,  &heartCount,   4);
  memcpy(buf + 8,  &havg,         4);
  memcpy(buf + 12, &hmn,          4);
  memcpy(buf + 16, &hmx,          4);
  memcpy(buf + 20, &spCount,      4);
  memcpy(buf + 24, &savg,         4);
  memcpy(buf + 28, &smn,          4);
  memcpy(buf + 32, &smx,          4);
  memcpy(buf + 36, &repCount,     4);

  summaryChar->setValue(buf, sizeof(buf));
  summaryChar->notify();
  Serial.printf("Session stopped\n");
}

void stopSession() {
  if (!sessionActive) return;
  drainVitals();               // count any readings that finished just before stop
  sessionActive = false;
  updateStatus();
  sendSummary();
}




// ---------- Pulse oximeter (pulseOxTask side) ----------
void resetOxState() {
  firstReading = true;
  stableCount = 0;
  dataCount = 0;
  havePreviousAverage = false;
}

// One pass of the pulse-ox logic. This may block for a while inside the
// library call, which is fine: it only blocks THIS task, not loop().
// Every `return` just means "try again on the next pass".
void pulseOxStep(uint32_t sid) {
  // New session? Reset this task's own state.
  if (sid != oxSid) {
    oxSid = sid;
    resetOxState();
  }

  // Calculate heart rate and SpO2
  particleSensor.heartrateAndOxygenSaturation(
    &SPO2,
    &SPO2Valid,
    &heartRate,
    &heartRateValid
  );

  // Get current IR reading
  currentIR = particleSensor.getIR();

  // Initialize first IR reading
  if (firstReading) {
    previousIR = currentIR;
    firstReading = false;
    Serial.println("Establishing signal stability...");
    return;
  }

  // Calculate percentage change in IR
  float IRchange =
    abs((int32_t)currentIR - (int32_t)previousIR)
    * 100.0 / previousIR;

  previousIR = currentIR;

  // Detect sudden pressure or movement changes
  if (IRchange > IR_CHANGE_PERCENT) {
    Serial.println("SIGNAL UNSTABLE - Resetting dataset");
    stableCount = 0;
    dataCount = 0;
    havePreviousAverage = false;
    return;
  }

  // Require consecutive stable measurement windows
  if (stableCount < REQUIRED_STABLE_WINDOWS) {
    stableCount++;
    Serial.print("Stabilizing: ");
    Serial.print(stableCount);
    Serial.print("/");
    Serial.println(REQUIRED_STABLE_WINDOWS);
    return;
  }

  // Check library validity flags
  if (!heartRateValid || !SPO2Valid || SPO2 < 85) {
    Serial.println("Invalid measurement - discarded");
    return;
  }

  // Reject unusually different measurements
  if (havePreviousAverage) {
    float HRdifference   = fabsf((float)heartRate - previousHRMean);
    float SPO2difference = fabsf((float)SPO2 - previousSPO2Mean);

    if (HRdifference > previousHRMean * 0.20 ||
        SPO2difference > 2.0) {
      Serial.println("Outlier detected - discarded");
      return;
    }
  }

  // Store accepted measurements
  heartRateData[dataCount] = heartRate;
  SPO2Data[dataCount] = SPO2;
  dataCount++;

  Serial.print("Accepted measurements: ");
  Serial.print(dataCount);
  Serial.print("/");
  Serial.println(DATASET_SIZE);

  // Calculate averages after collecting DATASET_SIZE measurements
  if (dataCount >= DATASET_SIZE) {
    int32_t heartRateSum = 0;
    int32_t SPO2Sum = 0;

    for (int i = 0; i < DATASET_SIZE; i++) {
      heartRateSum += heartRateData[i];
      SPO2Sum += SPO2Data[i];
    }

    float averageHR   = (float)heartRateSum / DATASET_SIZE;
    float averageSPO2 = (float)SPO2Sum / DATASET_SIZE;

    // Save averages for future outlier checking
    previousHRMean = averageHR;
    previousSPO2Mean = averageSPO2;
    havePreviousAverage = true;

    Serial.println();
    Serial.println("========== RESULTS ==========");
    Serial.print("Average Heart Rate: ");
    Serial.print(averageHR, 1);
    Serial.println(" BPM");
    Serial.print("Average SpO2: ");
    Serial.print(averageSPO2, 1);
    Serial.println(" %");
    Serial.println("=============================");
    Serial.println();

    // Hand the result to loop(); it updates the stats and sends the BLE notification.
    VitalsMsg m = { sid, averageHR, averageSPO2 };
    xQueueSend(vitalsQueue, &m, 0);

    // Reset dataset for next measurement
    dataCount = 0;
  }
}

void pulseOxTask(void*) {
  for (;;) {
    if (!sessionActive) {
      vTaskDelay(pdMS_TO_TICKS(50));
      continue;
    }
    pulseOxStep(sessionId);
    vTaskDelay(1);   // always give the idle task (and watchdog) a chance to run
  }
}





// ---------- Arduino ----------
void setup() {
  Serial.begin(115200);
  delay(300);

  vitalsQueue = xQueueCreate(8, sizeof(VitalsMsg));

  // Setting up bluetooth service
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(100);
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  liveHChar = service->createCharacteristic(LIVE_H_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  liveHChar->addDescriptor(new BLE2902());

  liveRChar = service->createCharacteristic(LIVE_R_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  liveRChar->addDescriptor(new BLE2902());

  summaryChar = service->createCharacteristic(SUMMARY_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  summaryChar->addDescriptor(new BLE2902());

  statusChar = service->createCharacteristic(STATUS_UUID, BLECharacteristic::PROPERTY_READ);
  updateStatus();

  BLECharacteristic* control = service->createCharacteristic(
      CONTROL_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  control->setCallbacks(new ControlCallbacks());

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);   // lets the app filter scans by service
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("Advertising as " DEVICE_NAME);

  // - - - - - - - - - - - - - - - -
  // ------ PULSE OXIMETER ---------
  // - - - - - - - - - - - - - - - -
  Wire.begin(21, 22);

  bool oxOk = false;
  for (int i = 0; i < 5 && !oxOk; i++) {
    oxOk = particleSensor.begin();
    if (!oxOk) {
      Serial.println("MAX30102 not found!");
      delay(500);
    }
  }

  if (oxOk) {
    particleSensor.sensorConfiguration(
      60,
      SAMPLEAVG_8,
      MODE_MULTILED,
      SAMPLERATE_400,
      PULSEWIDTH_411,
      ADCRANGE_16384
    );
    Serial.println("MAX30102 initialized!");
    Serial.println("Place finger gently on sensor.");
  } else {
    Serial.println("Continuing without pulse oximeter (reps only).");
  }

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  // From here on, ONLY pulseOxTask touches Wire / particleSensor.
  if (oxOk) {
    xTaskCreatePinnedToCore(pulseOxTask, "pulseOx", 8192, nullptr, 1, nullptr, OX_CORE);
  }
}

void loop() {
  // After a disconnect, advertise again from here (not inside the BLE callback),
  // once the stack has had a moment to settle.
  if (advRestartPending && (millis() - disconnectedAtMs) >= ADV_RESTART_DELAY_MS) {
    advRestartPending = false;
    BLEDevice::startAdvertising();
    Serial.println("Advertising again - waiting for the app to reconnect");
  }
 
  // The app is gone mid-session: keep running for a grace period so it can
  // reconnect, then give up and drop the session.
  if (sessionActive && !deviceConnected &&
      (millis() - disconnectedAtMs) >= SESSION_GRACE_MS) {
    sessionActive = false;
    updateStatus();
    Serial.println("Session dropped: app did not reconnect in time");
  }

  // Handle commands from the app (kept out of the BLE callback on purpose).
  uint8_t cmd = pendingCmd;
  if (cmd) {
    pendingCmd = 0;
    if (cmd == CMD_START && !sessionActive) startSession();
    else if (cmd == CMD_STOP)               stopSession();
  }

  if (!sessionActive) {
    updateStatus();
    delay(10);
    return;
  }

  // Accelerometer + rep counting: runs at full speed because the slow
  // pulse-ox library call now lives in its own task.
  update();
  livePrint();

  // Collect any finished heart rate / SpO2 results.
  drainVitals();

  delay(1);
}
