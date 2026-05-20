# UniDrive 🚗

**A University-Exclusive Ride-Sharing Platform Built with Flutter & Firebase**

UniDrive is a secure, closed-ecosystem carpooling application designed specifically for university students. It connects student drivers who have empty seats with student passengers looking for safe, affordable commutes to and from campus. 

## ✨ Key Features

* **Verified Student Access:** Walled-garden authentication restricts registration to active university emails only.
* **Dual-Mode Interface:** Seamlessly switch between **Passenger Mode** (green theme) and **Driver Mode** (purple theme).
* **Smart Routing & Geocoding:** Integrated with Mapbox API for accurate address autocomplete, destination prediction, and route polyline rendering.
* **Real-Time Ride Matching:** Live Firestore streams allow instant booking requests, acceptances, and status updates.
* **Safety First ("Pink Ride"):** A backend-enforced, female-only ride filter ensures a comfortable and secure commuting option.
* **Integrated Chat:** In-app messaging connects matched drivers and passengers instantly.

## 🛠️ Technology Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Authentication, Cloud Firestore, Cloud Messaging)
* **Maps & Navigation:** OpenStreetMap (via `flutter_map`) & Mapbox APIs
* **Architecture:** State management and real-time NoSQL data syncing

## 🚀 Getting Started

To run this project locally, you will need Flutter installed on your machine and a physical Android device or emulator.

### Prerequisites
* Flutter SDK (v3.0.0 or higher)
* A valid `google-services.json` file from Firebase (placed in `android/app/`)
* A Mapbox Secret Access Token

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/your-username/unidrive-app.git](https://github.com/your-username/unidrive-app.git)
