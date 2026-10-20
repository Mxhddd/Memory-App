# Installing Memory Garden (free, no Mac needed)

**The friendly version of this manual is a web page:** https://mxhddd.github.io/Memory-App/
Open it on MaoMao's Windows laptop. It shows a QR code that takes each iPhone to its own steps, and it has a one-tap **Add Memory Garden to SideStore** button.

**Why not the App Store or TestFlight?** Both need Apple's paid Developer Program ($99 a year), and so does AltStore PAL (which also only works in the EU, Japan and Brazil). The free route is **SideStore**: it installs the app with a free Apple ID and re-signs it every 7 days, on the phone itself.

| Who | Gets | How |
|---|---|---|
| **You** | The release and, optionally, "trained today" pings | Push one tag. The free **ntfy** app for pings. |
| **MaoMao** | Memory Garden in **Midnight Den** 🦝 | SideStore, set up once from her Windows laptop |
| **Salma** | Memory Garden in **Gilded Atelier** ✒️ | SideStore, set up on the same laptop |

---

## Part 1 — You, once (2 minutes)

1. **Publish the version.** On GitHub: **Actions → Build iOS app → Run workflow**, tick **Publish a release**, then **Run workflow**. The version comes from `MARKETING_VERSION` in `project.yml`. (Pushing a tag such as `v0.5.1` does the same.) The run takes about 5 minutes. It builds the app on a GitHub Mac and creates a release in this repo with:
   - `MemoryGarden.ipa`: the app.
   - `sidestore-source.json`: the SideStore source. Its permanent link is
     `https://github.com/Mxhddd/Memory-App/releases/latest/download/sidestore-source.json`
   - `MemoryGarden-Windows-Setup.zip`: the laptop helper.
   - `icon.png`.

   No tokens or secrets are needed. The workflow then checks the links itself.
2. **Turn on the install page** (one click, the first time only). The **Install site** workflow puts the guide on the `gh-pages` branch. In the repo, go to **Settings → Pages → Build and deployment → Deploy from a branch → `gh-pages` / (root) → Save**. A minute later, https://mxhddd.github.io/Memory-App/ is live.
3. **Later updates:** bump `MARKETING_VERSION` and run the workflow again (or ask Claude). The phones see an **Update** button in SideStore.

> Every push also builds the app as a compile check. The file is under **Actions → the run → Artifacts**.

---

## Part 2 — Each iPhone, once (about 30 minutes)

**You need:**
- the Windows laptop (64-bit Windows 10 or 11) and the phone's cable;
- the iPhone on **iOS 18 or newer**, with a **passcode** set;
- **Wi-Fi**;
- an **Apple ID for that phone**.

**Apple ID tips:**
- A separate free Apple ID per phone is best (make one at https://account.apple.com/account), so nobody's main account is used.
- Write down the email and password.
- Keep the phone it texts codes to nearby.

### On the laptop
1. **Get the laptop ready.** Download `MemoryGarden-Windows-Setup.zip` from the latest release (or from the button on the install page). Right-click → **Extract All**, then double-click **Setup-MemoryGarden**.
   - The helper installs Apple's iPhone driver (**iTunes from apple.com**, not the Microsoft Store version) and **iloader**, then opens the guide.
   - If Windows says *"Windows protected your PC"*: **More info → Run anyway**.
   - By hand instead: install [iTunes for Windows](https://www.apple.com/itunes/download/win64), then [iloader](https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.msi) (official site: https://iloader.app).
2. **Plug in the iPhone.** Unlock it, plug it in, tap **Trust** on the phone and enter the passcode.
3. **Install SideStore.** Open **iloader** → sign in with the phone's Apple ID (the email is case-sensitive) → pick the iPhone → **Install SideStore (Stable)**. Wait for it to finish, then unplug.

### On the iPhone
4. **Trust and Developer Mode.**
   - Settings → General → **VPN & Device Management** → Developer App → the Apple ID → **Trust**.
   - Then Settings → **Privacy & Security** → (bottom) **Developer Mode** → On. The phone restarts; tap **Turn On** and enter the passcode.
5. **LocalDevVPN.** Install [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) from the App Store, open it and tap **Connect**. SideStore uses it to install and refresh over Wi-Fi.
6. **SideStore.** Open it and sign in with the same Apple ID. In **My Apps**, tap the **7 DAYS** button next to SideStore once. Accept the certificate prompt if one appears.
7. **Add Memory Garden.** On the install page, tap **Add Memory Garden to SideStore**. It opens `sidestore://source?url=…`, which SideStore handles. Open the source and tap **Get**.
   - No button? In SideStore go to **Sources → +**, paste the source link from Part 1, and tap **Add**.
8. **Open Memory Garden.** MaoMao picks **Midnight Den**; Salma picks **Gilded Atelier**. Allow notifications.

Repeat with Salma's phone, ideally with a second free Apple ID.

### Nice extras (2 minutes)
- **Widgets:** touch and hold the Home Screen → **Edit → Add Widget → Memory Garden**.
  - *Flashcard* lets you answer a card right there.
  - *Trail* shows today's steps; it works in StandBy too.
  - *Reminders* has Done buttons.
- **Control Center:** swipe down → **+** → **Add a Control** → Memory Garden. The options are Start training, Review a card, and Reminder done. Controls can also go on the Lock Screen or the Action button.
- **Live Activity:** today's trail shows on the Lock Screen. During a study timer, a countdown shows in the Dynamic Island.
- **Siri and Shortcuts:**
  - "What's next in Memory Garden?"
  - "Start training in Memory Garden"
  - "Add a reminder in Memory Garden"
- **Notifications:** long-press the daily "Recall one card" notification and type the answer.
- **Spotlight:** search a card, palace or lesson name.
- **Quick actions:** long-press the app icon.

---

## After that (no laptop needed)

- **Refresh every 7 days.** A free Apple ID signs apps for 7 days.
  - SideStore renews them in the background when the phone is on Wi-Fi with LocalDevVPN connected.
  - Memory Garden shows the days left in **Settings**, shows a banner on Today in the last 2 days, and sends a reminder 48 and 24 hours before.
  - By hand: connect LocalDevVPN → SideStore → **My Apps → Refresh All**.
  - If it runs out, the app just won't open until refreshed. **No data is lost.**
- **Updates:** SideStore shows an **Update** button. One tap; progress stays.

### Free Apple ID limits
- **3 apps per phone** at a time, and SideStore counts as one.
- **10 new App IDs per 7 days.** SideStore, Memory Garden and its widget extension use 3. Updates and refreshes don't use new ones.
- So don't sideload other apps with the same Apple ID on that phone.

### What a free account can't do (and the app doesn't need)
- No push from a server, no Time Sensitive notifications, no iCloud, no Siri capability.
- Memory Garden schedules everything locally, uses App Shortcuts (which work without the Siri capability), and keeps data on the phone.

---

## Part 3 — Alerts between you (free, ntfy)

1. Install **ntfy** from the App Store on **your** phone and on **MaoMao's** phone.
2. On MaoMao's phone, open Memory Garden → **Progress → Your circle**, type your name and tap **Add**. A QR code and topic appear. Tap **Send the link** and send it to you.
3. On your phone, open ntfy, tap **+**, enter the topic on server **ntfy.sh** (or open the link), and tap **Subscribe**. Then tap **Send a test alert** in Memory Garden.
4. On **Salma's** phone, add MaoMao the same way; MaoMao subscribes on her phone.
5. Optional: enter the trainee's WhatsApp number in **Your circle** (country code, no `+`, e.g. `923001234567`). Alerts then get a free **"Send a cheer 💌"** button.

Without a server you get **"✨ trained today"** pings. For **"🌙 not yet today"** and Sunday summaries, add the free Supabase server below, because a phone can't report a session that didn't happen.

## Part 4 — Optional free server (Supabase)

1. Create a free project at https://supabase.com. Mumbai or Singapore are the nearest regions.
2. Go to **Database → Extensions** and enable **pg_net** and **pg_cron**.
3. Go to **Authentication → Sign In / Providers** and turn on **Allow anonymous sign-ins**.
4. In **SQL Editor**, paste all of `backend/supabase/migrations/001_init.sql` and click **Run**.
5. Under **Project Settings → API**, copy the **Project URL** and the **anon public** key. On each phone, open Memory Garden → **Settings → Circle server** and paste them.
   - Alternatively, put them in `App/Resources/Backend.plist` before tagging a release.

Free projects pause after 7 quiet days. Daily training keeps the project awake; if it does pause, click **Restore** in the dashboard.

---

## Day-1 checklist

- [ ] The app opens and onboarding works.
- [ ] **Settings** shows "App signature renews in N days", and it matches SideStore's counter.
- [ ] Notifications arrive. Go to **Settings → tap Version 5× → Debug tools → Fire test reminders**, then lock the phone.
- [ ] Long-press a reminder notification: **Done / Snooze / Tonight** work.
- [ ] The **Flashcard widget** shows a real card (add a starter pack in the Vault first). Show answer → Got it works without opening the app.
- [ ] Start a word sprint: the study countdown shows on the Lock Screen and in the Dynamic Island.
- [ ] Control Center → **Start training** opens the next step.
- [ ] Siri or Shortcuts: "What's next in Memory Garden?" answers.
- [ ] n-back speaks the letters, even with the silent switch on.
- [ ] The ntfy test alert arrives on the supporter's phone.

If **Debug tools** says "App Group unavailable", the widgets show sample data. Tell Claude.

## Troubleshooting

| Problem | Fix |
|---|---|
| iloader doesn't see the iPhone | Unlock it, tap **Trust**, try another cable or port. Reinstall iTunes from apple.com and restart the laptop. |
| "Untrusted Developer" | Settings → General → VPN & Device Management → Trust. |
| No "Developer Mode" in Settings | It appears once SideStore is installed. Restart the phone and look under Privacy & Security. |
| The Add button doesn't open SideStore | Use **Sources → +** in SideStore and paste the source link. |
| "Maximum number of apps" | The free Apple ID allows 3 apps on that phone. Remove other sideloaded apps signed with it. |
| App won't open ("no longer available") | Its 7 days ran out: connect LocalDevVPN, then SideStore → **Refresh All**. Data is kept. |
| Refresh keeps failing | Be on Wi-Fi with LocalDevVPN connected. Still failing? Plug into the laptop and run iloader again to renew the pairing. |
| Build or release failed on GitHub | Open **Actions → the red run** and share the log with Claude. A re-run is safe: it replaces the release files. |

## Developer note (only if you have a Mac)
```bash
brew install xcodegen && xcodegen generate && open MemoryGarden.xcodeproj
```
Pick your free Personal Team under **Signing & Capabilities** and press Run.
