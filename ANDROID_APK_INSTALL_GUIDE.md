# Android APK Install Guide - The Sourcing Manager OS

This guide explains how to install and verify the production Android application for field testing.

## 1. Prerequisites
- An Android smartphone (Android 8.0 or higher recommended).
- USB cable or a secure file transfer method (e.g., Google Drive, Slack, or internal server).
- **The APK file**: `app-release.apk` (Universal) or `app-arm64-v8a-release.apk` (Optimized).

## 2. Transferring the APK to Mobile
1. Connect your phone to your computer via USB.
2. Set the USB mode to **File Transfer** on the phone.
3. Copy the APK file from your computer to the `Downloads` folder on your phone.
4. (Alternative) Upload the APK to a secure cloud drive and download it directly onto the phone.

## 3. Enabling Unknown App Installation
Android blocks apps from outside the Google Play Store by default.
1. Open **Settings** on your phone.
2. Go to **Apps** > **Special app access** > **Install unknown apps** (this varies slightly by Android version).
3. Select the app you will use to open the APK (e.g., **Files**, **Chrome**, or **Drive**).
4. Toggle **Allow from this source** to ON.

## 4. Installing the App
1. Open the file manager app (e.g., "Files" or "My Files") on your phone.
2. Navigate to the folder where you saved the APK.
3. Tap the APK file.
4. Tap **Install** when prompted.
5. Once finished, tap **Open** to launch the app.

## 5. Post-Installation Verification (Dataless Constitution)
To ensure the app is safe and compliant with the Sourcing Manager OS security standards, verify the following:

### **Login & Connectivity**
1. Ensure the app reaches the login screen and correctly connects to the **Production Supabase** backend.
2. Training Mode should be clearly labeled if enabled.

### **Security Check (No PII Exposure)**
Verify that **NONE** of the following information is visible in the UI:
- [ ] Raw phone numbers of customers or brokers.
- [ ] Masked phone numbers (e.g., 98765XXXXX).
- [ ] Clickable WhatsApp links or buttons.
- [ ] `tel:` links that open the phone dialer directly.
- [ ] Contact export or "Save to Contacts" buttons.

### **Role-Based Access**
1. **Sourcing Manager**: Verify access to the Action Hub, Broker CRM, and site visit tracking.
2. **Broker**: Verify only own leads and performance metrics are visible.
3. **Caller**: Verify only assigned leads are visible, and calls are initiated via the **Secure Call** bridge (ID-only).

## 6. Troubleshooting
- **App not installed**: This often means an existing version of the app is already installed with a different signature. Uninstall the previous version first.
- **Parse error**: The APK might be corrupted or the Android version is too old.
- **Connection Error**: Ensure the phone has internet access and the Supabase production URL is reachable.
