# 🚨 Intrusion Detection System  
### Real-Time PIR Motion Detection • ESP8266 NodeMCU • Firebase • Flutter App

This repository contains a full **Intrusion Detection System** built using a **PIR sensor**, **ESP8266 NodeMCU**, **Firebase** backend, and a **Flutter mobile app** for real-time alerts.

The system detects motion near a door or restricted zone and instantly updates Firebase while triggering **push notifications** to your phone.

---

## 📌 Features

### 🔹 Hardware (ESP8266 + PIR)
- Detects motion using a PIR sensor (HC-SR501)
- Sends real-time motion alerts to Firebase
- Device heartbeat every 10 seconds
- Wi-Fi auto-reconnect + online/offline status tracking
- Secure credential separation using `secret.h`

### 🔹 Software (Flutter Mobile App)
- Firebase Realtime DB listener
- Displays motion alerts & logs
- Shows device online/offline status
- Clean UI for monitoring entry events

### 🔹 Firebase Backend
- Realtime Database (logs + live status)
- Firebase Authentication (email/password)
- Cloud Messaging (FCM) push alerts
- Secure rule structure

---

## 📂 Project Structure
pir_motion_app/
│
├── Arduino/
│ ├── Door_Alert/
│ │ ├── Door_Alert.ino # Main intrusion detection firmware
│ │ ├── secret.h # Wi-Fi + Firebase credentials (ignored)
│ │ └── secret_example.h # (Optional) placeholder file for repo
│
├── lib/ # Flutter app source
├── android/ # Flutter Android config
├── ios/ # Flutter iOS config
├── firebase/ # Firebase setup files (no secrets)
├── build/ # Flutter build artifacts
├── README.md # This documentation
├── LICENSE # MIT License
└── .gitignore 

## 🛠 Hardware Requirements

- **ESP8266 NodeMCU (LOLIN / Wemos)**
- **PIR Motion Sensor** (HC-SR501)
- **USB Cable** (for power + firmware upload)
- Jumper wires
- Optional: LED/Buzzer for physical alerts

## 🔌 Wiring Diagram

| PIR Pin | NodeMCU Pin |
|--------|--------------|
| VCC    | 5V or 3.3V   |
| GND    | GND          |
| OUT    | D5 (GPIO14)  |
