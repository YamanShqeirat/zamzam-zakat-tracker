# ZamZam — Zakat Al Mal Tracker

<p align="center">
  <img src="Assets/AppIcon_Dark.png" width="128" height="128" alt="ZamZam App Icon" style="border-radius: 28px;">
</p>

<p align="center">
  <em>An automated, personal Zakat al-Mal tracker for iOS</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26.2%2B-blue" alt="iOS 26.2+">
  <img src="https://img.shields.io/badge/Xcode-26%2B-orange" alt="Xcode 26+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

---

## What is ZamZam?

ZamZam is an iOS app that automates Zakat al-Mal (obligatory annual charity) calculation and tracking. It pulls your financial account balances daily, tracks nisab against live gold prices, counts your hawl (lunar year) cycle, and notifies you when Zakat is due.

**This app is a calculation tool, not a scholarly authority.** It implements a specific set of jurisprudential rules (see below) — always consult a qualified scholar for rulings specific to your situation.

### Features

- **Automated balance syncing** via [SimpleFIN Bridge](https://beta-bridge.simplefin.org) — supports thousands of banks, brokerages, and credit unions
- **Live nisab calculation** — 85 grams of gold at current market price, updated daily via [GoldAPI.io](https://www.goldapi.io)
- **Hijri lunar calendar** — hawl tracking uses the Umm al-Qura Islamic calendar (~354 days), not the Gregorian calendar
- **Continuous hawl tracking with reset** — if your wealth drops below nisab at any daily check, the hawl resets and restarts when wealth returns to nisab
- **Budget and investments tracking** — a monthly income/expense grid, net-worth breakdown, and per-account balance history alongside the zakat side of the app
- **Charts throughout** — wealth vs nisab, giving history, the Hijri calendar infographic, asset distribution, account balances, income vs expenses, and expenses by category
- **A home screen widget for every chart** — glanceable status without opening the app (see [Widgets](#widgets))
- **Smart notifications** — reminders at 30 days, 7 days, and when zakat is due
- **Payment recording** — track when and where you paid your zakat
- **Manual asset entry** — for physical cash, gold, silver, and anything SimpleFIN can't see

### Jurisprudential Rules Used

| Rule | Implementation |
|------|---------------|
| Nisab standard | 85 grams of gold |
| Hawl (lunar year) | Umm al-Qura Islamic calendar |
| Nisab tracking mode | Continuous — any dip below nisab resets the hawl |
| Zakat rate | 2.5% of total zakatable wealth at hawl completion |
| Retirement accounts | Zakatable amount = current value minus early withdrawal penalties |
| Brokerage holdings | Fully zakatable (stocks, ETFs, crypto, cash) |
| Bank balances | Fully zakatable |

If your school of thought or scholar advises different rules (bookend nisab tracking, debt deductions, grace periods, etc.), you can fork this repo and modify the `ZakatEngine` accordingly.

---

## Using the app

Five tabs, each with one job:

| Tab | What's there |
|-----|--------------|
| **Overview** | Year summary (income, expenses, balance, % of income spent), net worth and zakatable wealth, net-worth breakdown by asset group, a zakat status glance — and the app's asset controls: **Manage**, **Add asset**, **Refresh** |
| **Budget** | The monthly income/expense entry grid, plus income vs expenditure, income vs expenses by month, and expenses by category |
| **Investments** | Savings & investments distribution and per-account balance history. Read-only |
| **Zakat** | The hawl countdown ring, nisab status, payment recording, and the analytics cards inline — at a glance, wealth vs nisab, the Hijri calendar, and giving history |
| **Settings** | SimpleFIN connection, GoldAPI key, notification preferences, CSV export, reset |

**Asset management lives in exactly one place: the Overview tab.** Adding, editing, deleting, and refreshing assets all start there (Manage pushes the full asset list); no other screen duplicates those controls. Settings still holds the SimpleFIN *connection* itself, since that's a credential rather than an asset.

---

## Widgets

Every chart in the app has a home screen widget, all rendering from a cached snapshot in the App Group container — no database access and no network calls from the widget process.

| Widget | Sizes | Shows |
|--------|-------|-------|
| **Zakat Tracker** | Small, Medium | Hawl countdown ring (small); wealth distribution donut with legend (medium) |
| **Hijri Calendar** | Small, Medium | The 12-month lunar ring with today's position and a moon tracking the year; medium adds hawl day *x* of *y* |
| **Wealth vs Nisab** | Medium, Large | Zakatable wealth over time against the nisab threshold |
| **Zakat Given** | Small, Medium | Lifetime zakat paid (small); giving per Hijri year (medium) |
| **Account Balances** | Medium, Large | Each account's end-of-month balance; large adds the month-over-month change per account |
| **Income vs Expenses** | Small, Medium, Large | Year totals and share of income spent (small); the twelve months side by side (medium/large) |
| **Expenses by Category** | Medium, Large | This year's spending per category, largest first, in each category's colour |

The snapshot is rewritten on every foreground refresh and on the daily background sync, then all timelines reload. **Open the app once after installing an update** — widgets show their empty state until the app has written a snapshot.

---

## Prerequisites

Before you build, you'll need:

1. **A Mac** with [Xcode 26+](https://developer.apple.com/xcode/) installed — the project targets iOS 26.2 and uses synchronized folder groups
2. **An Apple Developer account** — free accounts work for personal use (7-day sideloading). A [$99/year paid account](https://developer.apple.com/programs/) lets you install permanently
3. **A SimpleFIN Bridge account** — [$15/year](https://beta-bridge.simplefin.org) for automated balance syncing. Connect your banks and brokerages through their dashboard
4. **A GoldAPI.io account** — [free tier](https://www.goldapi.io) provides ~300 requests/month (the app needs ~30)

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/YamanShqeirat/zamzam-zakat-tracker.git
cd zamzam-zakat-tracker
```

### 2. Open in Xcode

```bash
open zakat-al-mal-app.xcodeproj
```

### 3. Rename the bundle identifiers and App Group

The project ships with bundle identifiers and an App Group under the `com.yamanshqeirat.*` namespace. Apple requires these to be globally unique, so a fresh clone **will not build until you rename them** to your own reverse-DNS namespace (e.g. `com.yourname.*`).

Find-and-replace `yamanshqeirat` with your namespace in these locations:

| File | What to change |
|------|----------------|
| `zakat-al-mal-app/Services/SharedAppGroup.swift` | App Group identifier |
| `ZakatWidget/SharedAppGroup.swift` | App Group identifier (must match the line above) |
| `zakat-al-mal-app/zakat-al-mal-app.entitlements` | App Group entry |
| `ZakatWidgetExtension.entitlements` | App Group entry |
| `zakat-al-mal-app/Services/BackgroundSyncService.swift` | `BGTask` identifier `com.yamanshqeirat.zakat-al-mal-app.dailysync` |
| `zakat-al-mal-app.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` for both the app and widget targets, and `INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers` (the app's Info.plist is generated, so the identifier lives in build settings and must match `BackgroundSyncService.swift`) |

### 4. Configure signing

In Xcode:
- Select the project in the navigator (top-level blue icon)
- Select the **zakat-al-mal-app** target
- Go to the **Signing & Capabilities** tab
- Under **Team**, select your Apple Developer account
- Xcode will automatically create a provisioning profile

Repeat for the **ZakatWidgetExtension** target.

### 5. Register the App Group

The main app and widget share data through an App Group, which must be registered under your Apple Developer account:

1. Go to the [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list/applicationGroup)
2. Create a new App Group with the identifier you used in step 3 (e.g. `group.com.yourname.zakat-al-mal-app`)
3. In Xcode → **zakat-al-mal-app** target → **Signing & Capabilities** → click **+ Capability** → add **App Groups**, then check the group you just created
4. Repeat for the **ZakatWidgetExtension** target — both must point at the same group

### 6. Get your API keys

**SimpleFIN:**
1. Sign up at [beta-bridge.simplefin.org](https://beta-bridge.simplefin.org)
2. Connect your financial institutions (banks, brokerages, credit unions)
3. Create a **Setup Token** in the SimpleFIN dashboard
4. You'll paste this into the app on first launch

**GoldAPI.io:**
1. Sign up at [goldapi.io](https://www.goldapi.io)
2. Copy your API key from the dashboard
3. Add it to the app's Settings screen on first launch

### 7. Build and run

1. Connect your iPhone or select a simulator
2. Press `Cmd + R` or click the Play button
3. On first launch, go to Settings and configure SimpleFIN and GoldAPI
4. Add any manual assets (physical cash, gold, silver)

If running on a physical device for the first time, you may need to trust the developer certificate: **Settings → General → VPN & Device Management → [your email] → Trust**.

---

## Architecture

ZamZam follows MVVM with a clean domain layer that has zero Apple framework dependencies (except Foundation).

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│     SwiftUI Views + WidgetKit           │
├─────────────────────────────────────────┤
│          ViewModel Layer                │
│     @Observable classes                 │
├─────────────────────────────────────────┤
│          Domain Layer                   │
│  ZakatEngine · HawlTracker · NisabMon  │
│  (Pure Swift, no framework deps)        │
├─────────────────────────────────────────┤
│          Data Layer                     │
│  SwiftData · SimpleFIN · GoldAPI        │
│  Keychain · Background Sync             │
└─────────────────────────────────────────┘
```

### Key Domain Objects

- **`ZakatEngine`** — Core calculation orchestrator. Computes zakatable wealth, evaluates hawl status, calculates the 2.5% obligation.
- **`HawlTracker`** — Manages the Hijri lunar year cycle. Computes hawl start/end dates, days remaining, and whether the hawl is complete.
- **`NisabMonitor`** — Computes the nisab threshold (85g gold × current price per gram) and checks whether total wealth meets it.
- **`BudgetCalculator`** — Pure aggregation over the budget models. Every figure the Budget and Overview screens show (and every budget widget) is derived here, so a typed monthly amount and itemised transactions never double-count.

### Data Flow

1. **SimpleFIN** syncs account balances daily via background refresh
2. **GoldAPI** fetches the current gold price once per day
3. **NisabMonitor** computes the threshold from the gold price
4. **ZakatEngine** sums zakatable assets, checks against nisab, evaluates hawl
5. **WidgetSnapshotBuilder** projects the results — plus the wealth, giving, account, and budget series behind each chart — into the App Group container, then reloads every widget timeline
6. **Widgets** read that snapshot; they never touch SwiftData or the network
7. **Notifications** fire at hawl milestones and when zakat becomes due

---

## Project Structure

```
zakat-al-mal-app/
├── zakat-al-mal-app/       # Main app target
│   ├── Domain/             # ZakatEngine, HawlTracker, NisabMonitor, BudgetCalculator
│   ├── Models/             # SwiftData models (Asset, HawlRecord, BudgetEntry, etc.)
│   ├── Services/           # SimpleFIN + GoldAPI clients, Keychain, background sync,
│   │                       #   SharedAppGroup, WidgetSnapshotBuilder
│   ├── ViewModels/         # Dashboard, Asset, Payment view models
│   ├── Views/              # SwiftUI screens (one per tab) + Components/
│   └── Assets.xcassets/    # Colors, app icon
└── ZakatWidget/            # WidgetKit extension — one file per widget,
                            #   plus WidgetSupport.swift and a copy of SharedAppGroup.swift
```

`ZakatWidget/SharedAppGroup.swift` is a verbatim copy of the app's version — the two targets each compile their own. If you change the snapshot shape, change both.

---

## Customization

### Changing jurisprudential rules

The domain layer is intentionally isolated. To adapt the app for a different school of thought:

- **Bookend nisab tracking** (Hanafi/Maliki): In `ZakatEngine.evaluateHawl()`, remove the mid-year nisab check. Only evaluate at hawl start and end.
- **Grace period** (Shafi'i/Hanbali): Add a configurable grace period (0–7 days) before a nisab dip resets the hawl.
- **Debt deductions**: Add a `debtPolicy` to `ZakatEngine` that subtracts debts before calculating zakatable wealth.

### Adding new asset types

Add a new case to `AssetCategory` in `Models/Asset.swift` and update the `zakatableAmount` computed property if the new type has special rules (like the penalty deduction for retirement accounts).

### Using a different gold price API

Implement the `GoldPriceService` protocol with your preferred provider. The app uses one daily request, so any free-tier API will work.

### Adding a chart and its widget

1. Add the series to `SharedAppGroup.Snapshot` and its `write`/`read` — in **both** copies of `SharedAppGroup.swift`.
2. Aggregate it in `WidgetSnapshotBuilder.snapshot(state:assets:context:)`, capping the series so the payload stays small.
3. Add sample values to `ZakatWidgetEntry.sampleSnapshot` so the widget gallery has something to draw.
4. Create a `Widget` in `ZakatWidget/` (reuse `ZakatWidgetProvider` — every widget reads the same snapshot) and register it in `ZakatWidgetBundle`.

Both targets use Xcode's synchronized folder groups, so new files are picked up without touching the project file.

---

## Costs

| Item | Cost | Required? |
|------|------|-----------|
| Apple Developer Program | $99/year | For permanent install. Free account works with 7-day re-signing |
| SimpleFIN Bridge | $15/year | For automated balance syncing. You can skip this and use manual entry only |
| GoldAPI.io | Free | Free tier is more than sufficient |

**Minimum cost for full automation: $114/year.** Manual-entry-only mode is free (with a free Apple Developer account and re-signing weekly).

---

## Contributing

Contributions are welcome. Some areas where help would be especially valuable:

- **Madhab-specific rule sets** — implementing the `MadhabRuleSet` protocol from the original architecture for Hanafi, Maliki, Shafi'i, and Hanbali schools
- **Localization** — Arabic, Urdu, Malay, Turkish, French translations
- **Additional financial integrations** — direct API clients for specific brokerages
- **Silver nisab option** — 612.36g silver as an alternative nisab standard
- **Debt tracking and deduction** — madhab-specific debt deduction rules
- **Zakat al-Fitr** — separate tracking for the annual per-person charity at Eid

Please open an issue before starting significant work so we can discuss approach.

---

## Disclaimer

This app assists with Zakat calculation based on a specific set of jurisprudential rules. It is **not** a fatwa, scholarly opinion, or religious authority. Always consult a qualified scholar — such as those at [AMJA](https://www.amjaonline.org) or [FCNA](https://fiqhcouncil.org) — for rulings specific to your situation.

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <em>May Allah accept your Zakat and bless your wealth.</em>
</p>
