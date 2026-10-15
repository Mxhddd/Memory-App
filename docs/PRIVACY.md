# Privacy

Memory Garden is a private app for two people. It follows GDPR-style practice, because Pakistan's Personal Data Protection Bill is still not enacted.

## What stays on the phone (never leaves it)
- Game results, learning curves and trends
- Personal memory cards, including any photos
- Check-ins (sleep, stress, mood), memory-slip log, questionnaire answers (PHQ-9, GAD-7, everyday-memory items)
- Reminders you set

All of this is stored locally with SwiftData. There is no iCloud sync, no analytics, no ads, no tracking and no third-party SDKs.

## What can leave the phone (only if you add supporters)
| Data | Where | Why |
|---|---|---|
| "Practised today: yes/no", number of steps, weekly streak | Your own free Supabase project (optional) | So supporters can get "done" and "not yet" alerts |
| Display name, companion name, timezone, optional WhatsApp number | Same | Alert wording, local times, the "Send a cheer" link |
| Supporter label and ntfy topic | Same | Where to send alerts |
| A short alert text ("✨ Ayesha's den got cozier today") | ntfy.sh, to the supporter's phone | The alert itself |

**Never shared:** scores, answers, cards, photos, check-ins, questionnaire results, or the "talk to your doctor" card.

ntfy topics are unguessable random names (about 128 bits). Anyone who has a topic can read its alerts, which is why alerts carry only completion status. To revoke a supporter, use **Your circle → New link** or delete them.

## Consent and control
- Each person owns their data. Sharing is off until you add a supporter, and you can revoke it at any time.
- Any "please mention it to your doctor" card is shown **only to you**. It is never sent to supporters.
- **Export:** go to Settings → Export my data (JSON).
- **Delete:** go to Settings → Delete everything. This removes local data and, if a server is configured, your server account and rows. It cannot be undone.

## Not a medical device
Memory Garden is for memory training and general wellness. It does not diagnose, treat or predict any condition. If you notice changes in your memory, talk to your doctor.
