# Installing Memory Garden (free, no Mac needed)

GitHub builds the app in the cloud. Your girlfriend sets up both iPhones (hers and her mom's) once on her **Windows laptop**. After that, updates and refreshes happen on the phones by themselves.

| Who | Gets | How |
|---|---|---|
| **You** | Pings when your girlfriend trains | The free **ntfy** app (App Store). No computer needed. |
| **Girlfriend** | Memory Garden 🦝, plus pings about Mom | **SideStore** + **ntfy** (one-time setup on her laptop) |
| **Mom** | Memory Garden (Gilded Atelier) | **SideStore** (set up on the same laptop) |

---

## Part 1 — You, once (about 5 minutes, on any computer or a phone browser)

### 1a. Create the public download repo
1. On GitHub, click **New repository**. Name it `memory-garden-releases`, make it **Public**, and tick **Add a README**.
   - Only the finished app file goes here. The code stays private.

### 1b. Let the build publish into it
1. Go to GitHub → your avatar → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
   - Repository access: **Only select repositories** → `memory-garden-releases`.
   - Permissions: **Contents: Read and write**.
2. Copy the token. In the private **Memory-App** repo, go to **Settings → Secrets and variables → Actions → New repository secret**.
   - Name: `RELEASES_TOKEN`, value: the token.

### 1c. Publish a version
- In Memory-App, go to **Releases → Draft a new release** and create the tag `v0.2.0` on the branch. Or ask Claude to push the tag.
- The **Build iOS app** workflow (about 10 minutes) builds the app and puts it in `memory-garden-releases`, along with `sidestore-source.json`.
- Your source link is: `https://raw.githubusercontent.com/<your-username>/memory-garden-releases/main/sidestore-source.json`

> Every push also builds the app, as a compile check. The file is under **Actions → the run → Artifacts** if you ever want it directly.

---

## Part 2 — Girlfriend's Windows laptop, once per phone (about 20 minutes each)

### 2a. Install on the laptop (first time only)
1. **iTunes from Apple's website**: https://www.apple.com/itunes/ → "Download iTunes for Windows". Use the website version, not the Microsoft Store one, because it includes the iPhone USB driver.
2. **iloader** from its only official sources: https://iloader.app or https://github.com/nab138/iloader/releases. Install it.

### 2b. Set up a phone
1. On the iPhone, set a **passcode** if it has none (Settings → Face ID & Passcode). The setup needs one.
2. Plug the iPhone into the laptop with a cable. On the phone, tap **Trust** and enter the passcode.
3. Open **iloader**.
   1. Sign in with an Apple ID. A **free, separate Apple ID per phone** is best (make one at appleid.apple.com), so nobody's main account is used.
   2. Choose **Install SideStore**. iloader installs it and places the pairing file automatically.
4. On the iPhone, go to **Settings → General → VPN & Device Management**, tap the Apple ID, then **Trust**.
5. Install **LocalDevVPN** from the App Store, open it, and tap **Connect**. SideStore uses it to refresh apps over Wi-Fi.
6. Open **SideStore** and sign in with the same Apple ID if it asks.
7. In SideStore, go to **Sources → +** and paste the source link from step 1c. Open the source and tap **Get** on Memory Garden.
8. Unplug the phone. Done: open Memory Garden and pick a style.

Repeat 2b with Mom's phone. If possible, use a second free Apple ID for her phone.

### 2c. After that (no laptop needed)
- **Refresh:** SideStore re-signs apps in the background every few days when the phone is on Wi-Fi and LocalDevVPN is connected. Add SideStore's widget to see the days left. If 7 days pass without a refresh, open SideStore and tap **Refresh All**. **No data is lost**.
- **Updates:** when a new version is published, SideStore shows an **Update** button. One tap.

### Free-account limits (the app is designed around them)
- **3 active apps per phone per Apple ID.** SideStore, Memory Garden and its widget use exactly 3, so don't sideload other apps with the same Apple ID on that phone.
- **10 new app installs per Apple ID per week.** Updates and refreshes don't count; reinstalling from scratch does.

---

## Part 3 — Alerts between you (free, ntfy)

1. Install **ntfy** from the App Store on **your** phone and your **girlfriend's** phone.
2. On the girlfriend's phone, open Memory Garden → **Progress → Your circle**, type your name, and tap **Add**. A QR code and topic appear. Tap **Send the link** and send it to you.
3. On your phone, open ntfy, tap **+**, enter the topic on server **ntfy.sh** (or open the link), and **Subscribe**. Then tap **Send a test alert** in Memory Garden.
4. On **Mom's** phone, add your girlfriend the same way. She subscribes on her phone.
5. Optional: enter the trainee's WhatsApp number in **Your circle** (country code, no `+`, e.g. `923001234567`). Alerts then get a free **"Send a cheer 💌"** button.

Without a server you get **"✨ trained today"** pings. For **"🌙 not yet today"** and Sunday summaries, add the free Supabase server below, because a phone can't report a session that didn't happen.

## Part 4 — Optional free server (Supabase)

1. Create a free project at https://supabase.com. Mumbai or Singapore are the nearest regions.
2. Go to **Database → Extensions** and enable **pg_net** and **pg_cron**.
3. Go to **Authentication → Sign In / Providers** and turn on **Allow anonymous sign-ins**.
4. In **SQL Editor**, paste all of `backend/supabase/migrations/001_init.sql` and click **Run**.
5. Under **Project Settings → API**, copy the **Project URL** and the **anon public** key. Then on each phone, open Memory Garden → **Settings → Circle server** and paste them.
   - Alternatively, put them in `App/Resources/Backend.plist` before tagging a release.

Free projects pause after 7 quiet days. Daily training keeps the project awake; if it does pause, click **Restore** in the dashboard.

## Day-1 checklist

- [ ] The app opens and onboarding works.
- [ ] Notifications arrive. Go to **Settings → tap Version 5× → Debug tools → Fire test reminders**, then lock the phone.
- [ ] **Done / Snooze / Tonight** buttons work: long-press a reminder notification.
- [ ] Add the Home Screen widget. It shows real progress, not sample data. If **Debug tools** says "App Group unavailable", tell Claude.
- [ ] n-back speaks letters (sound on, not silent).
- [ ] ntfy test alert arrives on the supporter's phone.

## Troubleshooting

| Problem | Fix |
|---|---|
| iloader doesn't see the iPhone | Reinstall iTunes from apple.com, try another cable or port, and tap **Trust** on the phone. |
| "Maximum number of apps" | The free Apple ID allows 3 active apps on that phone. Remove other sideloaded apps signed with that ID. |
| App won't open ("no longer available") | Open SideStore and tap **Refresh All** on Wi-Fi with LocalDevVPN connected. |
| Refresh keeps failing | In LocalDevVPN tap **Connect**, then retry on Wi-Fi. Still failing? Plug into the laptop and re-run iloader to refresh the pairing file. |
| Build failed on GitHub | Open **Actions → the red run** and share the log with Claude. |

## Developer note (only if you have a Mac)
```bash
brew install xcodegen && xcodegen generate && open MemoryGarden.xcodeproj
```
Pick your free Personal Team under **Signing & Capabilities** and press Run.
