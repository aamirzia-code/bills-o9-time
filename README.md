# Bills O9 Time

Personal bill organizer, expense tracker and budget planner (Flutter — iOS and Android from one codebase). All data stays on the device in a private SQLite database.

## Features

- **Bills** — Upcoming / Overdue / Calendar / Recurring / Paid tabs with search and month totals; repeats daily, weekly, monthly or yearly, every N units, on a fixed day of the month; Auto Paid bills; "Increased/Reduced by" vs last payment; reminders before and on the due date; payment history
- **Home** — spending this month with projection from bills still due, 2-week planner, missed-to-pay alert, monthly PDF report, recent transactions
- **Budget** — monthly and category budgets, savings goals and debt payoff (with templates), Summary with income budget, allocation and remaining to allocate
- **Accounts** — net worth over 3/6/12 months, accounts by type, monthly trends
- **Insights** — spending and income distribution, month-over-month change, savings rate, 6-month income vs expenses; PDF/CSV export
- Dark (default) and light themes, any currency symbol (default `Rs`)
- Web preview with sample data: open the PWA with `?demo=1` on a browser that has no data yet

## Getting it on your phone

Every push to `main` runs **Actions → Build app** and publishes a **Release** containing:

- `BillsO9Time.ipa` — iPhone. On your Mac: install [Sideloadly](https://sideloadly.io), plug in the iPhone, drag the `.ipa` in, sign in with your Apple ID, Start. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID; also turn on Settings → Privacy & Security → Developer Mode. Free Apple IDs must re-install every 7 days (your data is kept if you re-install over the existing app).
- `BillsO9Time.apk` — Android. Open the release page on the phone, download, allow "Install unknown apps", install.

### Web / PWA (additional option)

Live at **https://aamirzia-code.github.io/bills-o9-time/** (deployed by the same workflow). On iPhone: open in Safari → Share → Add to Home Screen. Data is stored in that browser only (SQLite in WebAssembly + IndexedDB). Reminder notifications are app-only for now; web push needs the optional sync server on the roadmap.

## Develop locally (Mac)

```bash
flutter create --platforms=ios,android --org com.aatech --project-name bills_o9_time .
python3 tool/patch_platforms.py
flutter pub get
flutter run            # with the iPhone plugged in (sign in Xcode with your Apple ID)
```

The `android/` and `ios/` folders are generated, then patched by `tool/patch_platforms.py` (notification permissions, desugaring, app name, iOS 13 target).

## Roadmap

- Optional cloud sync / backup (off by default)
- Face ID / fingerprint lock, home-screen widgets
- Family sharing, bank statement import, AI insights
