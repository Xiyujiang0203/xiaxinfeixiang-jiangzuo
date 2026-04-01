# xiaxinfeixiang — 厦信飞翔讲座

[中文](README.zh-CN.md)

**Current release: v0.3.0**

> Android app for browsing and managing lectures on the XMU "厦信飞翔" platform (`unify.xmu.edu.cn`).

## Screenshots

<p align="center">
  <img src="home.jpg" alt="Home" width="32%" height="450" style="object-fit: cover;" />
  <img src="detail.jpg" alt="Detail" width="32%" height="450" style="object-fit: cover;" />
  <img src="profile.jpg" alt="Profile" width="32%" height="450" style="object-fit: cover;" />
</p>

## Features

- **Lectures (sign-up)** — full list from `GetUserActivities`; each row shows host, sign-up start (from `GetUserActivityCategory` when needed), venue, and **derived status** (not started / open / registered / ended, etc.) merged from the category API so it matches your account
- **My sign-ins** — lectures you have already checked in to (`MySignIn`)
- **Lecture detail** — host, venue, sign-up window, sessions, description (HTML stripped), **one-tap sign-up** (`SignUp`) when the server allows it
- **Status banner** on detail — same rules as the list: sign-up phase and registration state
- **Alarms** — Android alarm 20 / 10 / 2 minutes before sign-up or lecture start
- **Calendar** — add sign-up or lecture start reminders
- **Share** — lecture summary via the system share sheet
- **Profile** — avatar, name, student ID, phone, email
- **Cookie** — stored with `shared_preferences`

## Platform

Android only (cleartext to campus HTTP; Web is not supported for API calls).

## Get Cookie (Wireshark)

1. Install [Wireshark](https://www.wireshark.org/).
2. Open WeChat (PC), sign in to the "厦信飞翔" official account.
3. Capture on your active interface; trigger any in-app page load.
4. Filter by `http` or the unify host; open a request → **HTTP** → copy the full `Cookie` header.

## Run

```bash
flutter pub get
flutter run
```

## Build release APK

```bash
flutter build apk --release
```

Default artifact: `build/app/outputs/flutter-apk/app-release.apk`  
GitHub Actions / releases use: `xiaxinfeixiang-lecture.apk` (same binary, renamed).

## Releases

Tags `v*` on `main` build and attach `xiaxinfeixiang-lecture.apk` (see `.github/workflows/android.yml`).

## Set Cookie

Use the cookie icon (top-right) or **我的 → Cookie**, paste the full cookie string, save.  
Example: `deviceKey=951b74c7-f351-4704-a20c-b434f85ddcbe`  
Cookies expire; capture a new one if requests fail.
