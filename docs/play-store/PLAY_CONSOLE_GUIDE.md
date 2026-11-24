# Publishing Teleprompter on Google Play

Everything you need to fill in Play Console for the first release, in the order Play Console asks for it.

| | |
|---|---|
| Package name | `in.sundarprakash.teleprompter` (permanent once uploaded) |
| Version | 1.0.1 (version code 2) |
| AAB | `dist/teleprompter-1.0.1-2.aab` (signed with the upload key) |
| Upload key | `~/AndroidKeys/teleprompter-upload.jks` (alias `upload`), password in `~/AndroidKeys/teleprompter-key.properties` |
| Upload cert SHA-256 | `5B:AA:00:07:5D:20:43:43:99:63:5E:EC:97:46:73:3B:C6:E8:64:67:93:45:06:47:4B:41:9C:DE:65:2E:49:7D` |
| Website | https://teleprompter.sundarprakash.in |
| Privacy policy | https://teleprompter.sundarprakash.in/privacy |
| Support email | support@sundarprakash.in |

> **Back up the upload key now.** Copy `teleprompter-upload.jks` and its password into a password manager or other safe place. You need it to sign every future update. Because Play App Signing is on (the default), Google can reset a lost upload key, but that takes days.

---

## 0. Before you start

1. **Deploy the website first** (see [`WEBSITE_DEPLOY.md`](WEBSITE_DEPLOY.md)). Play checks that the privacy-policy URL loads.
2. **Set up the support mailbox.** In Cloudflare: *sundarprakash.in → Email → Email Routing → Routing rules → create* `support@sundarprakash.in` → forward to your inbox. Play shows this address publicly.
3. **Testing requirement for new personal accounts.** If your developer account is a *personal* account created after Nov 2023, Play requires a **closed test with at least 12 testers opted in for 14 continuous days** before you can apply for production access. Organisation accounts are exempt. Plan for this.

## 1. Create the app

*Home → Create app*

| Field | Value |
|---|---|
| App name | `Teleprompter: Script & Camera` |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | **Free** (can't be changed to paid later) |
| Declarations | Tick Developer Program Policies and US export laws |

## 2. Store listing

*Grow users → Store presence → Main store listing*

**App name** (max 30): `Teleprompter: Script & Camera`

> **Title rule:** Google Play's metadata policy doesn't allow "free", "no ads", "best", "#1" or similar promotional words in the **title, icon or developer name**, and it discourages price or promotional text on graphics. That's why the title stays clean and premium, and the "every feature included, no ads" message goes in the descriptions.

**Short description** (max 80):
```
Read on cue, record on camera, float over any app. No ads, every feature open.
```

**Full description** (max 4000): paste [`full-description.txt`](full-description.txt).

**Graphics**

| Asset | File / spec |
|---|---|
| App icon (512×512 PNG) | `dist/play-store/icon-512.png` |
| Feature graphic (1024×500) | `dist/play-store/feature-graphic-1024x500.png` |
| Phone screenshots (2–8, required) | Upload all 8 from `dist/play-store/screenshots-final/` **in filename order** (01 → 08). 1080×1920 PNG. Regenerate with `poster-generator/` if you retake screenshots. |
| 7" / 10" tablet screenshots | Optional. Skip for now; you can add them later. |

**Store settings** (*Store presence → Store settings*)

| Field | Value |
|---|---|
| App category | **Productivity** |
| Tags | Teleprompter, Video recording, Productivity |
| Email | support@sundarprakash.in |
| Website | https://teleprompter.sundarprakash.in |
| Phone | Leave empty (optional) |

## 3. App content (Policy → App content)

### Privacy policy
`https://teleprompter.sundarprakash.in/privacy`

### Ads
**No, my app does not contain ads.**

### App access
**All functionality is available without special access.** (No login.)

### Content rating
Start the questionnaire. Email: support@sundarprakash.in. Category: **"All other app types"** (Utility, Productivity, Communication or Other).

| Question | Answer |
|---|---|
| Violence, fear, sexuality, language, controlled substances, gambling, crude humour | **No** to all |
| Does the app allow users to interact or exchange content with other users? | **No** (sharing through Android's share sheet to other apps doesn't count) |
| Does the app share the user's current physical location with other users? | **No** |
| Does the app allow users to purchase digital goods? | **No** |
| Is the app a web browser or search engine? | **No** |
| Is the app primarily a news or educational product? | **No** |

Expected result: **Everyone / PEGI 3 / IARC 3+**.

### Target audience and content
- Target age groups: **13–15, 16–17, 18 and over**. Don't tick under-13 groups; that would put the app under the stricter Families policy.
- Could the app unintentionally appeal to children? **No**.

### News app
**No.**

### Data safety
This is accurate because the app has **no INTERNET permission and no SDKs that transmit data**. Under Play's definitions, data processed only on the device (camera, mic, scripts) is not "collected".

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |

That's the whole form. Play then shows **"No data collected · No data shared"** on the listing. (Security practices like encryption in transit and deletion requests don't apply when nothing is collected.)

### Government apps · Financial features · Health
**Not applicable / No** for each.

### Foreground service permissions (required)
The floating overlay runs a `specialUse` foreground service, so Play asks you to declare it.

- Type: **Special use**
- Task description (paste):
  ```
  When the user taps "Float over other apps", Teleprompter shows the user's script in a small floating window above other apps (for example a video call or camera app) so they can read it while recording or presenting. A foreground service keeps that window alive and scrolling while Teleprompter is in the background. It starts only after an explicit user action, shows a persistent notification, and stops when the user closes the window. No data is collected or transmitted.
  ```
- User impact if deferred or interrupted: **The floating script disappears or stops scrolling mid-recording or mid-presentation.**
- **Video link (required):** record a 20–40 s screen recording showing Prompter → menu → *Float over other apps* → permission prompt → the floating script over another app → closing it. Upload to YouTube as **Unlisted** and paste the link.

### Other declarations
- Photo and video permissions: **not needed** (the app doesn't use READ_MEDIA_IMAGES/VIDEO).
- "Display over other apps" (SYSTEM_ALERT_WINDOW) has no declaration form. The FGS declaration above covers the feature.
- Account deletion URL: **not needed** (no accounts).

## 4. Release

1. *Test and release → Setup → App integrity*: keep **Play App Signing** on (Google-managed key). Upload the AAB below; Play registers your upload key automatically.
2. Testing track:
   - **Personal account (new):** *Testing → Closed testing → Create track* → add an email list of 12+ testers → upload the AAB → roll out. Share the opt-in link; wait 14 days with 12+ testers opted in → *Dashboard → Apply for production*.
   - **Organisation account:** you can go straight to *Production* (an internal test with your own device first is still a good idea).
3. Upload `dist/teleprompter-1.0.1-2.aab`.
4. Release name: `1.0.1`
5. Release notes (en-US, max 500):
   ```
   Welcome to Teleprompter 1.0.1, the first release on Google Play!
   • Import scripts from PDF, Word, SRT, TXT and Markdown
   • Five reading modes, with your pace set in seconds per line
   • Record yourself with the front camera while you read
   • Float your script over any app, or use picture-in-picture
   • Customise everything: fonts, spacing, colours, mirror/flip, display profiles
   Every feature is free. No ads, no sign-up, no tracking.
   ```
6. *Countries/regions*: add all (or start with India).
7. *Review release → Start rollout*. First reviews usually take 1–7 days.

### Debug symbols
- Native symbols are already **inside the AAB**, so Play won't warn about them.
- Dart code is obfuscated. Keep `dist/teleprompter-1.0.1-2-dart-symbols.zip` to decode Dart stack traces later (`flutter symbolize -i <trace> -d app.android-arm64.symbols`). Don't upload it to Play.

## 5. Future updates

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.2+3`). The number after `+` must always increase.
2. Build:
   ```bash
   export PATH="$HOME/development/flutter/bin:$PATH"
   export JAVA_HOME=/opt/homebrew/opt/openjdk@21
   export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
   flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`, signed via `android/key.properties`.
3. If a new version starts handling data differently (for example adding analytics or network features), update the privacy policy, the Data safety form and the website *before* release.
