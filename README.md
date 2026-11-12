# Bills O9 Time

Personal bill organizer, expense tracker and budget planner (Flutter — iOS and Android from one codebase). All data stays on the device in a private SQLite database.

## Features (v1)

- **Bills & reminders** — recurring bills (weekly, 2-weekly, monthly, quarterly, yearly, one-time), local notifications at 9 AM before and on the due date, mark paid / skip, payment history, overdue badge
- **Expenses & income** — categories, accounts (cash, bank, card, wallet) with running balances, monthly view
- **Budgets** — overall monthly limit with a safe-to-spend-per-day figure, per-category limits
- **Reports** — 6-month income vs expenses, category breakdown, month-over-month change, savings rate; export monthly PDF report and CSV
- **Goals & debts** — savings goals and debt payoff with progress, monthly amount needed to hit a date, interest estimate
- Light / dark mode, any currency symbol (default `Rs`)

## Getting it on your phone

Every push to `main` runs **Actions → Build app** and publishes a **Release** containing:

- `BillsO9Time.ipa` — iPhone. On your Mac: install [Sideloadly](https://sideloadly.io), plug in the iPhone, drag the `.ipa` in, sign in with your Apple ID, Start. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID; also turn on Settings → Privacy & Security → Developer Mode. Free Apple IDs must re-install every 7 days (your data is kept if you re-install over the existing app).
- `BillsO9Time.apk` — Android. Open the release page on the phone, download, allow "Install unknown apps", install.

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
