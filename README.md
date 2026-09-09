# Attendiphi by MetaPhi 🚀

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Hosting-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Live App](https://img.shields.io/badge/Live-attendiphi--by--metaphi.web.app-10B981?style=flat&logo=google-chrome&logoColor=white)](https://attendiphi-by-metaphi.web.app/#/daily-attendance)

> **Attendiphi by MetaPhi** is an enterprise-grade, real-time QR attendance verification, chapter meeting management, and visitor tracking platform designed for fast, tamper-resistant check-ins.

---

## 🌐 Live Application

- **Production Portal**: [https://attendiphi-by-metaphi.web.app](https://attendiphi-by-metaphi.web.app/#/daily-attendance)
- **Alternate / Dev URL**: [https://qr-checkin-dev.web.app](https://qr-checkin-dev.web.app/#/daily-attendance)

---

## ✨ Key Features

### 1. 📊 Daily Attendance & Live Sync
- **Real-Time KPI Dashboard**: Instant visibility into *Total Active Members*, *Total Check-Ins*, *Members Present*, *Substitutes*, and *Absentees*.
- **Live Status Feed**: Auto-updating Firestore streams with a live indicator.
- **Geofence Proximity Badge**: Displays user distance from venue with color-coded verification chips.
- **Substitute Preview**: Embedded selfie preview modal and substitute badges for verified guest replacements.
- **Administrative Overrides**: Manual verification toggles, attendance type updates, and record edit audit logs.

### 2. 📅 Attendance Overview Matrix
- Multi-session matrix tracking historical Thursday meetings across all chapter members.
- Visual attendance status indicators: `Present`, `Substitute (S)`, and `Absent (A)`.
- Fluid horizontal scrolling optimized for dense multi-month records.

### 3. 🏷️ Meeting QR Standee Display & Generator
- Dynamic QR generation tied to specific meeting sessions and venue geofence coordinates.
- Clean printable standee view with full-resolution QR codes for on-venue registration.
- Standee PDF export capability for chapter signage.

### 4. 👥 Visitor & Guest Management
- Comprehensive visitor database tracking name, phone number, company, business category, and inviter.
- Member leaderboard ranking based on verified visitor invitations.
- Status filters, search by contact or company, and visitor check-in attribution.

### 5. 📇 Member Directory & Account Governance
- Complete roster management: activate, deactivate, edit, or archive member profiles.
- Integrated visitor contribution counts per member.
- Fast multi-field filtering by name, phone, and membership standing.

### 6. 🛡️ Role-Based Access Control (RBAC)
- Super Admin, Admin, and Viewer access tiers.
- Automated credential generator with one-click clipboard copying and customized welcome email templates.

### 7. 🔒 Fraud Prevention & Check-In Validation
- **Geofence Proximity Engine**: Validates device GPS coordinates against venue latitude/longitude within allowed radius thresholds.
- **Session Locking**: Check-ins restricted to valid meeting days (e.g. Thursdays).
- **Single-Device Safeguard**: Prevents duplicate submissions for the same member in a single session.
- **Live Photo Capture**: Camera-based selfie capture with automatic image compression for substitute attendees.

---

## 🏗️ Architecture & Technology Stack

Attendiphi is architected using **Feature-First Clean Architecture** principles:

```
lib/
├── app/                  # Application configuration, theme, routes
│   ├── router/           # GoRouter setup & route definitions
│   └── theme/            # App colors, typography (Poppins), and component themes
├── core/                 # Shared widgets, utilities, constants, errors, loggers
├── features/             # Business modules
│   ├── admin/            # Dashboard, overview matrix, visitors, members, admins
│   ├── checkin/          # Mobile check-in submission flow & results
│   ├── employee/         # Member data models & repositories
│   ├── location/         # GPS proximity validation & permissions
│   ├── qr_checkin/       # Standee generator, camera QR scanner
│   └── substitute/       # Selfie capture & substitute management
└── main.dart             # Application bootstrap & flavor entry point
```

### Tech Stack:
- **Framework**: [Flutter](https://flutter.dev) (Web & Mobile ready)
- **Language**: [Dart](https://dart.dev)
- **State Management**: [Flutter Riverpod](https://riverpod.dev)
- **Routing**: [GoRouter](https://pub.dev/packages/go_router) with persistent shell layouts
- **Backend & Database**: Firebase Cloud Firestore
- **Authentication**: Firebase Authentication
- **Typography & UI**: Google Fonts (`Poppins`), Material 3, Custom Glassmorphic Cards
- **Deployment**: Firebase Hosting (Multi-Site Configuration)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+ recommended)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Google Chrome (for Flutter Web development)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/omkaranarse/Attendiphi-by-metaphi.git
   cd Attendiphi-by-metaphi
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run locally on Chrome:**
   ```bash
   flutter run -d chrome
   ```

4. **Run static analysis:**
   ```bash
   flutter analyze
   ```

5. **Run test suite:**
   ```bash
   flutter test
   ```

---

## 📦 Build & Deployment

### Build Web Release Bundle
```bash
flutter build web --release
```

### Deploy to Firebase Hosting
Deploy to both production and developer hosting targets:
```bash
firebase deploy --only hosting
```

Or deploy to a specific target:
```bash
# Production domain (attendiphi-by-metaphi.web.app)
firebase deploy --only hosting:attendiphi

# Dev domain (qr-checkin-dev.web.app)
firebase deploy --only hosting:dev
```

---

## 🧭 Routes Reference

| Route | Description |
|---|---|
| `/` | Admin Login |
| `/admin-reset-password` | Password Recovery |
| `/daily-attendance` | Live Daily Attendance Dashboard |
| `/attendance-overview` | Historical Multi-Week Attendance Matrix |
| `/visitors` | Visitor Directory & Records |
| `/members` | Member Management & Rankings |
| `/qr-standee` | Meeting Standee QR Display |
| `/admins` | Admin User Management & RBAC |
| `/scanner` | Mobile Check-In Scanner |
| `/checkin-permission` | Geofence Proximity & Location Verification |
| `/checkin/:locationId` | Attendee / Substitute / Visitor Form |
| `/photo-capture` | Substitute Live Selfie Capture |
| `/checkin-result` | Check-in Confirmation Screen |

> Legacy URLs (such as `#/attendiphi-by-metaphi/*` and `#/admin-dashboard`) automatically redirect to the clean routes above for seamless backward compatibility.

---

## 📄 License

This project is proprietary and confidential.  
Developed by **[MetaPhi](https://metaphi.in)**. All rights reserved.
