# AdShell

AdShell is Android utility app to manage other Android devices using ADB and Fastboot directly from your phone. No PC needed. Just connect your phone to the target device using OTG or Type-C to Type-C cable.

We make this because sometimes we need to run ADB or Fastboot command on the go, but we don't bring laptop. 

## Planned Features

- **Built-in Shell/Terminal**: Type your adb and fastboot command directly.
- **Saved Commands**: Save favorite command as shortcut. Just click to run, no need to type again.
- **Device Info**: See target model, serial, battery, and OS version easily.
- **App Manager**: Install APK to target device, or disable/uninstall bloatware fast.
- **File Manager**: Browse, push, and pull files from target device.
- **Power Menu**: 1-click reboot to system, recovery, or bootloader.
- **Screen Capture**: Take screenshot or record target screen and save to your phone.
- **Wireless Switch**: Send `adb tcpip 5555` to enable wireless ADB. Unplug cable and keep connected via WiFi.
- **Backup**: Backup and restore data.
- **Logcat**: View live system log for debugging.

## Tech Stack

- Flutter (Material 3 UI for native Android feel)
- USB Host API (to speak raw ADB/Fastboot protocol over USB)
