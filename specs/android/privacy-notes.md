# Benkyo for Android: Privacy Policy Notes

Inputs for the public policy ([docs/privacy-policy.md](../../docs/privacy-policy.md)), the Play Console
Data safety form and permission declarations. Linked from [requirements.md](requirements.md).
**Rule:** any change to permissions, storage or network behavior updates this file and the policy in
the same change.

## Data inventory

| Data | Stored | Leaves device? | Req |
|---|---|---|---|
| Tasks | drift DB, app-private | No | R4 |
| Session log | drift DB | No | R1.6 |
| Settings / prefs | drift DB | No | R1.8, R8 |
| Scheduled notifications | drift DB + system alarms | No | R6 |
| Custom backgrounds | copied to app-private files | No | R3.4 |
| Spotify presets | drift DB | Only the link, passed to the Spotify app by intent | R7 |
| All of the above | — | Android Auto Backup, if the user enabled it (see D-P2) | — |

## Permissions (manifest)

| Permission | Why | Notes |
|---|---|---|
| `POST_NOTIFICATIONS` | Timer, task and reminder notifications | Runtime prompt on Android 13+, in context (R6.6). |
| `SCHEDULE_EXACT_ALARM` | Exact delivery (R6.4) | User grants it in system settings, so **no Play declaration needed**. Do **not** use `USE_EXACT_ALARM`: Play restricts it to alarm-clock and calendar apps and requires a declaration. |
| `RECEIVE_BOOT_COMPLETED` | Reschedule after reboot (R6.5) | |
| *(none)* photo picker | Custom backgrounds (R3.3) | The system photo picker needs no permission. Never add `READ_MEDIA_*`. |
| *(none)* keep screen on | Clock mode (R2.5) | Window flag, no `WAKE_LOCK` needed. |
| `INTERNET` | — | **Do not add.** Flutter adds it to debug builds only; check the release manifest. |
| `<queries>` for Spotify | Check that Spotify is installed (R7.4) | Package visibility, not a permission. Disclosed in policy §5. |

## Decisions

| # | Decision |
|---|---|
| D-P1 | Ongoing timer notification uses the system chronometer, with **no foreground service** (R1.13). **If a foreground service becomes necessary:** add `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE`, the special-use justification in the Play Console ("shows the user's running study timer"), and a line in policy §4. |
| D-P2 | Keep Android Auto Backup **on** so users keep data when they change phones, and disclose it (policy §5). Backup is done by Android and controlled by the user, not sent to us. |
| D-P3 | No analytics, crash reporting or ads SDKs. Adding any of them is a policy change (policy §1 and the Data safety form). |

## Play Console: Data safety answers

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all user data encrypted in transit? | Not applicable (nothing is transmitted). |
| Do you provide a way for users to request that their data be deleted? | Data is deleted in-app or by uninstalling; no developer-held data. |

Verify before submission: confirm in the current Play Console help that Android Auto Backup and
intents passed to other apps do not count as "collection" (this matches the current guidance as we
understand it).

## In-app link (required by Play)

- **R8.3 (added to requirements):** Settings shows a "Privacy policy" link that opens the hosted URL in the browser.

## Hosting checklist

The policy must be at a public HTTPS URL, with no login or geo-blocking, on a normal webpage (not a PDF).

**Option A: GitHub Pages** (recommended, because the policy is versioned with the code)
1. Repo `castero411/benkyo` must be **public**, or the account needs a paid plan for Pages on private repos.
2. Settings → Pages → Source: *Deploy from a branch* → `main` / `/docs`.
3. URL: `https://castero411.github.io/benkyo/privacy-policy` (Markdown is rendered automatically, no front matter needed).
4. Open the URL in a private window to confirm it loads without login.

**Option B: Notion**
1. Import `docs/privacy-policy.md` (Import → Markdown), or paste it.
2. Share → Publish → **Publish to web**. Turn off editing, comments and search-engine blocking.
3. Use the `*.notion.site` URL. Downside: it isn't versioned with the code, so keep the repo file as the source.

**Before publishing, replace the placeholders:** `{{EFFECTIVE_DATE}}`, `{{APPLICATION_ID}}`,
`{{DEVELOPER_NAME}}`, `{{CONTACT_EMAIL}}`. The contact email will be public.
