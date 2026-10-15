# Installing Memory Garden for free

No $99 Apple Developer Program, no App Store, no paid push. Three phones are involved:

| Phone | Gets | How |
|---|---|---|
| **Yours** | Alerts about your girlfriend's practice | The free **ntfy** app (App Store). Memory Garden itself is optional. |
| **Girlfriend's** | Memory Garden (Midnight Den 🦝), plus alerts about Mom | **SideStore** (refreshes itself) and **ntfy** |
| **Mom's** | Memory Garden (Gilded Atelier) | **SideStore** |

Total one-time effort is about 20–30 minutes per phone, with the phone plugged into your Mac.

---

## 0. One-time setup on your Mac

1. Install **Xcode 26** from the Mac App Store and open it once to accept the licence.
2. Install XcodeGen: `brew install xcodegen` (Homebrew: https://brew.sh).
3. In Xcode, go to **Settings → Accounts → +** and add your Apple ID. A free account is fine; Xcode creates a "Personal Team" for it.
4. Clone this repo and run:
   ```bash
   xcodegen generate
   open MemoryGarden.xcodeproj
   ```
5. Select the **MemoryGarden** target, open **Signing & Capabilities**, and choose your Personal Team as the Team. Do the same for the **MemoryGardenWidgets** target.
   - If Xcode says the bundle ID is unavailable, change `APP_BUNDLE_ID` and `APP_GROUP_ID` in `project.yml` (for example to `com.yourname.memorygarden`), then run `xcodegen generate` again.
   - If Xcode refuses the **Time Sensitive Notifications** capability on a free team, delete the `com.apple.developer.usernotifications.time-sensitive` line in `project.yml` and regenerate. Reminders still arrive; they just can't break through Focus modes.

## 1. Your own phone, straight from Xcode (fastest for testing)

1. Plug the iPhone into the Mac and tap **Trust**.
2. On the iPhone, open **Settings → Privacy & Security → Developer Mode**, turn it on, and restart.
3. In Xcode, pick your iPhone as the run destination and press **▶ Run**.
4. The first launch is blocked. On the iPhone, open **Settings → General → VPN & Device Management → [your Apple ID] → Trust**.

> Free signing lasts **7 days**. To refresh, plug the phone in and press Run again; your data is kept. For phones you can't plug in every week, use SideStore (next section).

## 2. Girlfriend's and Mom's phones: SideStore (refreshes itself, lowest effort)

SideStore installs apps with a free Apple ID and **re-signs them on the phone itself** every few days, so nobody has to plug in weekly. The only computer step is the first install.

### 2a. Build the app file (IPA) on your Mac
```bash
./distribution/build-ipa.sh      # → build/MemoryGarden.ipa
```

### 2b. Install SideStore (once per phone, phone plugged into your Mac)
1. On the iPhone, set a **passcode** if it has none. The VPN step requires it.
2. Download **iloader** from its official sources only: https://github.com/nab138/iloader or https://iloader.app.
3. Open iloader with the phone connected, sign in with an Apple ID and choose **Install SideStore**. iloader also places the pairing file on the phone automatically.
   - Use a **free Apple ID made just for this** (one per phone is simplest) rather than anyone's main account.
4. On the iPhone, open **Settings → General → VPN & Device Management** and trust the developer profile.
5. Install **LocalDevVPN** from the App Store. SideStore uses it to refresh apps on Wi-Fi.
6. Open SideStore, go to **Settings**, and sign in with the same Apple ID.

> The official SideStore docs are at https://docs.sidestore.io. If anything above changed, follow those.

### 2c. Install Memory Garden
- **Phone nearby:** AirDrop `build/MemoryGarden.ipa` to it, then tap **Share → SideStore** (or *Open in SideStore*), then **Install**.
- **Phone far away (Mom):** send the `.ipa` over WhatsApp or Google Drive. On the phone, save it to **Files**, open SideStore, go to **My Apps → +**, and pick the file.

### 2d. Keep it alive
- SideStore refreshes apps in the background whenever **LocalDevVPN is connected on Wi-Fi**. Its widget shows the days left; add it to the Home Screen.
- If 7 days pass without a refresh, Memory Garden won't open until you open SideStore and tap **Refresh All**. **Nothing is lost.**

### Free-account limits (designed around them)
- **3 active apps per phone:** SideStore, Memory Garden and Memory Garden's widget extension count as exactly 3. That's why the app has only **one** extension. Don't sideload other apps with the same Apple ID on that phone.
- **10 new app IDs per week:** reinstalling many times in a row can hit this. Wait a few days, or use the "refresh" option instead of reinstalling.

### Optional: one-tap updates
SideStore can't read private GitHub repos, so:
1. Create a small **public** repo, for example `memory-garden-releases`.
2. Upload `distribution/icon.png` and `distribution/sidestore-source.json` to it, with `YOUR-GITHUB-USER` replaced.
3. For each new version, create a GitHub Release (tag `v0.1.0`), attach `MemoryGarden.ipa`, and update `version`, `date` and `size` in the JSON. The script prints the size.
4. On each phone, open **SideStore → Sources → +** and paste the raw URL of `sidestore-source.json`. Updates then appear in SideStore.

## 3. Alerts between people: ntfy (free)

1. Install **ntfy** from the App Store on **your** phone and on your **girlfriend's** phone.
2. On the girlfriend's phone, in Memory Garden, go to **Den → Your circle → Add** (for example "Ali"). A QR code and a topic name appear.
3. On your phone, open ntfy, tap **+**, enter the topic (for example `mg-k3x…`) on server **ntfy.sh**, and subscribe. Or just open the shared link.
4. Tap **Send a test alert** in Memory Garden. It should pop up on your phone within seconds.
5. Do the same on **Mom's** phone, adding the girlfriend as Mom's supporter, and subscribe to that topic in ntfy on the girlfriend's phone.
6. Optional: in **Your circle**, enter the trainee's WhatsApp number (country code, no `+`, for example `923001234567`). Alerts then get a **"Send a cheer 💌"** button that opens WhatsApp. It's free because it uses the supporter's own WhatsApp.

Without a server, supporters get **"✨ done today"** alerts, sent straight from the phone. For **"🌙 not yet today"** and the Sunday summary, set up the free server below, because a phone can't report what it didn't do.

## 4. Optional: free Supabase server (for "not yet today" and weekly summaries)

1. Create a free project at https://supabase.com. Pick a region near Pakistan, such as Mumbai or Singapore.
2. Go to **Database → Extensions** and enable **pg_net** and **pg_cron**.
3. Go to **Authentication → Sign In / Providers** and turn on **Allow anonymous sign-ins**.
4. In **SQL Editor**, paste all of `backend/supabase/migrations/001_init.sql` and run it.
5. In **Project Settings → API**, copy the **Project URL** and the **anon public** key. Then either:
   - put them in `App/Resources/Backend.plist` before building (simplest), or
   - type them on each phone under **Settings → Circle server**.
6. Open **Den → Your circle** on each trainee's phone. It should say "Server connected".

Notes:
- The anon key is meant to be public. Row-level security means each phone can only touch its own rows, and the server only ever stores practised yes/no, counts and ntfy topics.
- Free projects **pause after 7 days without activity**. Daily practice keeps the project awake. If it does pause, open the dashboard and click **Restore**.
- Holidays: set `paused_until` on the trainee's row in **Table Editor** to stop "not yet" alerts until that date.

## 5. Day-1 checklist (the capability spike)

After the first SideStore install, check each of these on the phone and note the results:

- [ ] Notifications arrive. Go to **Settings → tap Version 5× → Debug tools → Fire test reminders**, then lock the phone.
- [ ] **Done / Snooze / Tonight** buttons work on a reminder: long-press the notification.
- [ ] The widget shows real data, not the sample. If Debug tools says "App Group unavailable", the widget falls back to sample data. Report it, because a SideStore update usually fixes it.
- [ ] The Lock Screen Live Activity appears when you open the app before finishing the quest.
- [ ] On iOS 26: a reminder set to **Alarm** rings while the phone is on silent.
- [ ] ntfy test alert arrives on the supporter's phone.

## Troubleshooting

| Problem | Fix |
|---|---|
| App won't open ("no longer available") | Open SideStore and tap **Refresh All** while on Wi-Fi with LocalDevVPN connected. |
| SideStore refresh fails | Open LocalDevVPN and tap **Connect**. Use Wi-Fi, not cellular. If it still fails, regenerate the pairing file with iloader. |
| "Maximum number of apps" | The free account allows 3 active apps per phone. Remove other sideloaded apps signed with that Apple ID. |
| No reminders | Check **iPhone Settings → Notifications → Memory Garden** is on, then open the app once; it re-plans 7 days ahead each time it opens. |
| Supporter gets nothing | Check the topic matches exactly in ntfy, then send a test alert from **Your circle**. |

## If you ever decide to pay ($99/yr)

The code doesn't change. You'd get **TestFlight**, where builds last 90 days and you install through a link with no SideStore, real push notifications, CloudKit sync, and no 7-day refresh. The App Store route also needs a privacy policy and general-wellness wording, which `docs/PRIVACY.md` and the app already follow.
