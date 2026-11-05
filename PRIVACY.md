# Privacy Policy

Better Traffic Lights does not collect or transmit personal data. It contains no analytics, advertising, account system, or telemetry SDK, and it makes no network requests.

## Data accessed

To locate and operate standard window controls, Better Traffic Lights reads the following while it runs:

- visible standard windows and their close, minimize, and zoom controls;
- window position, size, layer, and minimized state;
- window titles, used only to match Accessibility windows to local WindowServer records;
- current pointer position, used to reveal the overlay and drive hover magnification.

This information is processed in memory for positioning, occlusion checks, hover animation, and user-triggered window actions. It is not sent to a server or written to project files.

## Local preferences

The app stores the overlay switches, button size, and spacing in the current user's macOS `UserDefaults` preferences. It does not store window titles, pointer history, or usage history.

## Logs

Diagnostic logs contain technical lifecycle and overlay counts. They do not record application names, window titles, or file contents.

## Accessibility permission

macOS Accessibility permission is used to:

- discover standard window controls;
- read window and button positions and states;
- perform the native close, minimize, and zoom actions when a user clicks an overlay button.

You can revoke this permission at any time under **System Settings > Privacy & Security > Accessibility**. Better Traffic Lights stops showing and operating overlay controls after permission is revoked.
