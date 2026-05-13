# Zakat Tracker — Personal-Use Build Spec

Use this prompt with an AI coding assistant (Claude Code, Cursor, etc.) to build a fully functional personal iOS Zakat al-Mal tracker. This document is the complete specification.

---

## PROJECT OVERVIEW

Build an iOS app called **Zakat Tracker** for personal use. It automates Zakat al-Mal calculation by pulling live account balances from three financial institutions via SimpleFIN Bridge, tracking the hijri (lunar) hawl cycle, and computing the 2.5% obligation when conditions are met.

This is a single-user personal tool — no multi-madhab support, no onboarding wizard, no charity directory, no App Store distribution. The goal is "set it and forget it": balances sync daily, the app tracks whether wealth exceeds nisab across a full lunar year, and it notifies the user when Zakat is due.

### Core Principles

- **Calculation tool, not a scholarly authority.** Include a disclaimer on the dashboard: "This app assists with Zakat calculation. Consult a qualified scholar for specific rulings."
- **Jurisprudential accuracy over convenience.** Hawl uses the Hijri lunar calendar (~354 days). Nisab is tied to live gold price, not a static dollar amount.
- **Automated by default, manual as fallback.** SimpleFIN syncs daily. Manual entry available for assets SimpleFIN can't see (physical cash, gold/silver, etc.).

---

## TECH STACK

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI (iOS 17+) |
| Architecture | MVVM with @Observable |
| Persistence | SwiftData |
| Financial Data | SimpleFIN Bridge REST API ($15/year) |
| Gold Price | GoldAPI.io (free tier — ~300 requests/month) |
| Calendar | Hijri (Islamic lunar) via Foundation's `Calendar(identifier: .islamicUmmAlQura)` |
| Widget | WidgetKit + App Groups |
| Keychain | For storing SimpleFIN access URL |

---

## FINANCIAL ACCOUNTS

Three linked accounts via SimpleFIN, plus manual entry:

| Account | Institution | Type | What's Zakatable |
|---------|------------|------|-----------------|
| Brokerage | Brokerage A | Investment | Full balance (stocks, ETFs, cash) |
| Brokerage | Brokerage B | Investment | Full balance (stocks, ETFs, crypto, cash) |
| Banking | Bank/Credit Union | Checking/Savings | Full balance |
| Manual | Physical cash, gold, silver | Various | User-entered amounts |

### Future: Retirement Accounts

Not currently held, but when added: **zakatable amount = current value minus early withdrawal penalties.** The app should have a retirement account type that accepts total value and penalty percentage as inputs, then computes the zakatable portion.

---

## DATA MODELS

### Asset

```swift
import SwiftData
import Foundation

@Model
final class Asset {
    var id: UUID
    var name: String                    // e.g. "Brokerage Account", "Physical Gold"
    var category: AssetCategory
    var source: AssetSource
    var currentBalance: Decimal         // Latest balance from SimpleFIN or manual
    var lastSyncedAt: Date?             // nil for manual-only assets
    var simplefinAccountId: String?     // SimpleFIN account identifier
    var isActive: Bool
    var notes: String?
    
    // Retirement-specific (for future use)
    var earlyWithdrawalPenaltyPercent: Decimal?  // e.g. 10.0 for 10%
    
    var zakatableAmount: Decimal {
        switch category {
        case .retirement:
            let penalty = earlyWithdrawalPenaltyPercent ?? 0
            return currentBalance * (1 - penalty / 100)
        default:
            return currentBalance
        }
    }
    
    init(name: String, category: AssetCategory, source: AssetSource, 
         currentBalance: Decimal = 0) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.source = source
        self.currentBalance = currentBalance
        self.isActive = true
    }
}

enum AssetCategory: String, Codable, CaseIterable {
    case cash              // Physical cash on hand
    case bankAccount       // Checking/savings
    case brokerage         // Stocks, ETFs, mutual funds
    case crypto            // Cryptocurrency
    case gold              // Physical gold
    case silver            // Physical silver
    case retirement        // 401k, IRA (future use)
    case receivable        // Money owed to you
    case other             // Catch-all
}

enum AssetSource: String, Codable {
    case simplefin          // Auto-synced via SimpleFIN
    case manual             // User-entered
}
```

### NisabSnapshot

```swift
@Model
final class NisabSnapshot {
    var id: UUID
    var date: Date
    var goldPricePerGram: Decimal       // USD per gram
    var nisabThresholdUSD: Decimal       // goldPricePerGram * 85
    var totalZakatableWealth: Decimal    // Sum of all asset zakatableAmounts
    var isAboveNisab: Bool              // totalZakatableWealth >= nisabThresholdUSD
    
    init(date: Date, goldPricePerGram: Decimal, totalZakatableWealth: Decimal) {
        self.id = UUID()
        self.date = date
        self.goldPricePerGram = goldPricePerGram
        self.nisabThresholdUSD = goldPricePerGram * 85
        self.totalZakatableWealth = totalZakatableWealth
        self.isAboveNisab = totalZakatableWealth >= (goldPricePerGram * 85)
    }
}
```

### HawlRecord

```swift
@Model
final class HawlRecord {
    var id: UUID
    var hawlStartDate: Date             // Hijri date when wealth first exceeded nisab
    var hawlEndDate: Date               // Hijri date one lunar year later
    var status: HawlStatus
    var zakatDueAmount: Decimal?        // 2.5% of zakatable wealth at hawl end
    var zakatPaidAmount: Decimal?
    var zakatPaidDate: Date?
    var wealthAtStart: Decimal          // Snapshot at hawl start
    var wealthAtEnd: Decimal?           // Snapshot at hawl end (nil if still in progress)
    var nisabAtStart: Decimal           // Nisab threshold at start
    var nisabAtEnd: Decimal?            // Nisab threshold at end
    
    init(startDate: Date, wealthAtStart: Decimal, nisabAtStart: Decimal) {
        self.id = UUID()
        self.hawlStartDate = startDate
        self.status = .inProgress
        self.wealthAtStart = wealthAtStart
        self.nisabAtStart = nisabAtStart
        
        // Calculate hawl end date: one lunar year later
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        self.hawlEndDate = hijri.date(byAdding: .year, value: 1, to: startDate) ?? startDate
    }
}

enum HawlStatus: String, Codable {
    case inProgress        // Currently in hawl period
    case zakatDue          // Hawl completed, zakat not yet paid
    case zakatPaid         // Zakat paid for this cycle
    case reset             // Wealth dropped below nisab, hawl restarted
}
```

### ZakatPayment

```swift
@Model
final class ZakatPayment {
    var id: UUID
    var amount: Decimal
    var date: Date
    var recipient: String?              // Optional: who/where you paid
    var notes: String?
    var hawlRecordId: UUID?             // Links to the HawlRecord this payment covers
    
    init(amount: Decimal, date: Date, recipient: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.recipient = recipient
    }
}
```

### AppSettings

```swift
@Model
final class AppSettings {
    var id: UUID
    var simplefinAccessURL: String?     // Stored in Keychain, reference only
    var goldPriceSource: String         // "goldapi" — extensible later
    var lastGoldPriceRefresh: Date?
    var cachedGoldPricePerGram: Decimal?
    var notificationsEnabled: Bool
    var hawlReminderDaysBefore: Int     // Days before hawl end to send reminder
    
    init() {
        self.id = UUID()
        self.goldPriceSource = "goldapi"
        self.notificationsEnabled = true
        self.hawlReminderDaysBefore = 7
    }
}
```

---

## DOMAIN LAYER (Pure Swift — no Apple framework dependencies except Foundation)

### NisabMonitor

Responsible for fetching the current gold price and computing the nisab threshold.

```
struct NisabMonitor {
    static let nisabGoldGrams: Decimal = 85
    
    /// Compute nisab in USD given gold price per gram
    func nisabThreshold(goldPricePerGram: Decimal) -> Decimal {
        return goldPricePerGram * Self.nisabGoldGrams
    }
    
    /// Check if total zakatable wealth meets or exceeds nisab
    func isAboveNisab(totalWealth: Decimal, goldPricePerGram: Decimal) -> Bool {
        return totalWealth >= nisabThreshold(goldPricePerGram: goldPricePerGram)
    }
}
```

### HawlTracker

Manages the lunar year cycle. Uses **continuous tracking with reset**: if total zakatable wealth drops below nisab at any daily check, the hawl resets. A new hawl begins when wealth equals or exceeds nisab again. This means the user must remain at or above nisab for a full uninterrupted lunar year for zakat to become due.

```
struct HawlTracker {
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
    
    /// Calculate the hawl end date (one lunar year from start)
    func hawlEndDate(from startDate: Date) -> Date {
        hijriCalendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
    }
    
    /// Days remaining in the current hawl
    func daysRemaining(from now: Date, hawlEnd: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: now, to: hawlEnd)
        return max(0, components.day ?? 0)
    }
    
    /// Check if hawl has completed
    func isHawlComplete(startDate: Date, currentDate: Date) -> Bool {
        return currentDate >= hawlEndDate(from: startDate)
    }
    
    /// Format current date in Hijri for display
    func hijriDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
```

### ZakatEngine

The core calculation engine. Orchestrates NisabMonitor and HawlTracker.

```
struct ZakatEngine {
    let nisabMonitor = NisabMonitor()
    let hawlTracker = HawlTracker()
    static let zakatRate: Decimal = 0.025  // 2.5%
    
    /// Calculate total zakatable wealth from a list of assets
    func totalZakatableWealth(assets: [Asset]) -> Decimal {
        assets
            .filter { $0.isActive }
            .reduce(Decimal.zero) { $0 + $1.zakatableAmount }
    }
    
    /// Calculate the zakat due amount
    func zakatDue(on totalWealth: Decimal) -> Decimal {
        return totalWealth * Self.zakatRate
    }
    
    /// Evaluate the current hawl status
    /// Continuous tracking: check nisab at every sync. If below, hawl resets.
    func evaluateHawl(
        hawlRecord: HawlRecord,
        currentWealth: Decimal,
        currentGoldPrice: Decimal,
        currentDate: Date
    ) -> HawlEvaluation {
        let currentNisab = nisabMonitor.nisabThreshold(goldPricePerGram: currentGoldPrice)
        
        // FIRST: check if wealth has dropped below nisab (at any point)
        if currentWealth < currentNisab {
            return .hawlReset
        }
        
        // Still above nisab — check if hawl has completed
        let isComplete = hawlTracker.isHawlComplete(
            startDate: hawlRecord.hawlStartDate, 
            currentDate: currentDate
        )
        
        if isComplete {
            // Hawl complete AND still above nisab → zakat is due
            return .zakatDue(amount: zakatDue(on: currentWealth))
        } else {
            let daysLeft = hawlTracker.daysRemaining(
                from: currentDate, 
                hawlEnd: hawlRecord.hawlEndDate
            )
            return .inProgress(daysRemaining: daysLeft)
        }
    }
}

enum HawlEvaluation {
    case inProgress(daysRemaining: Int)
    case zakatDue(amount: Decimal)
    case hawlReset  // Wealth dropped below nisab — hawl must restart
}
```

---

## SERVICE LAYER

### SimpleFINService

Handles authentication and balance fetching from SimpleFIN Bridge.

```swift
protocol FinancialDataService {
    func fetchAccounts() async throws -> [SimpleFINAccount]
}

struct SimpleFINAccount {
    let id: String
    let name: String
    let balance: Decimal
    let currency: String
    let institutionName: String?
    let balanceDate: Date
}

class SimpleFINService: FinancialDataService {
    private let accessURL: String   // Stored in Keychain
    
    init(accessURL: String) {
        self.accessURL = accessURL
    }
    
    func fetchAccounts() async throws -> [SimpleFINAccount] {
        // 1. Parse the access URL (contains basic auth credentials)
        // Format: https://username:password@beta-bridge.simplefin.org/simplefin
        guard let url = URL(string: accessURL + "/accounts") else {
            throw SimpleFINError.invalidURL
        }
        
        // 2. Create request with basic auth from the URL's credentials
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Extract credentials from URL and set Authorization header
        if let user = url.user, let pass = url.password {
            let credentials = "\(user):\(pass)"
            let base64 = Data(credentials.utf8).base64EncodedString()
            request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            
            // Rebuild URL without credentials
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.user = nil
            components.password = nil
            request = URLRequest(url: components.url!)
            request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        }
        
        // 3. Fetch and parse JSON response
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleFINError.invalidResponse
        }
        
        if httpResponse.statusCode == 403 {
            throw SimpleFINError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SimpleFINError.httpError(httpResponse.statusCode)
        }
        
        // 4. Parse the SimpleFIN Account Set response
        let accountSet = try JSONDecoder().decode(SimpleFINAccountSet.self, from: data)
        
        return accountSet.accounts.map { account in
            SimpleFINAccount(
                id: account.id,
                name: account.name,
                balance: Decimal(string: account.balance) ?? 0,
                currency: account.currency,
                institutionName: account.org?.name,
                balanceDate: Date(timeIntervalSince1970: TimeInterval(account.balanceDate))
            )
        }
    }
}

// MARK: - SimpleFIN JSON response models

struct SimpleFINAccountSet: Codable {
    let accounts: [SimpleFINAccountJSON]
    
    enum CodingKeys: String, CodingKey {
        case accounts
    }
}

struct SimpleFINAccountJSON: Codable {
    let id: String
    let name: String
    let balance: String
    let currency: String
    let balanceDate: Int
    let org: SimpleFINOrg?
    
    enum CodingKeys: String, CodingKey {
        case id, name, balance, currency
        case balanceDate = "balance-date"
        case org
    }
}

struct SimpleFINOrg: Codable {
    let name: String?
    let url: String?
}

enum SimpleFINError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid SimpleFIN access URL"
        case .invalidResponse: return "Invalid response from SimpleFIN"
        case .authenticationFailed: return "SimpleFIN authentication failed. Reconfigure your access token."
        case .httpError(let code): return "SimpleFIN returned HTTP \(code)"
        case .decodingError: return "Failed to parse SimpleFIN response"
        }
    }
}
```

### SimpleFIN Setup Flow

The one-time setup flow for connecting SimpleFIN:

```
1. User goes to https://beta-bridge.simplefin.org and signs up ($15/year)
2. User connects their institutions (whichever brokerages/banks they use)
3. User creates a "Setup Token" for the Zakat Tracker app
4. In the app, user pastes the Setup Token
5. App base64-decodes the token to get a claim URL
6. App POSTs to the claim URL to get an Access URL (one-time exchange)
7. App stores the Access URL securely in Keychain
8. From then on, app uses the Access URL to fetch /accounts
```

```swift
class SimpleFINSetup {
    /// Exchange a setup token for a permanent access URL
    static func claimAccessURL(setupToken: String) async throws -> String {
        // 1. Base64 decode the setup token to get the claim URL
        guard let data = Data(base64Encoded: setupToken),
              let claimURLString = String(data: data, encoding: .utf8),
              let claimURL = URL(string: claimURLString) else {
            throw SimpleFINError.invalidURL
        }
        
        // 2. POST to claim URL (empty body)
        var request = URLRequest(url: claimURL)
        request.httpMethod = "POST"
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SimpleFINError.authenticationFailed
        }
        
        // 3. Response body is the access URL
        guard let accessURL = String(data: responseData, encoding: .utf8) else {
            throw SimpleFINError.decodingError
        }
        
        // 4. Store in Keychain (use KeychainService wrapper)
        return accessURL
    }
}
```

### GoldPriceService

Fetches the current gold price for nisab calculation.

```swift
protocol GoldPriceService {
    func fetchGoldPricePerGram() async throws -> Decimal
}

class GoldAPIService: GoldPriceService {
    // Free tier: ~300 requests/month. We need 1/day = ~30/month. Plenty.
    private let apiKey: String  // Store in app config or Keychain
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchGoldPricePerGram() async throws -> Decimal {
        // GoldAPI.io endpoint for gold price in USD
        guard let url = URL(string: "https://www.goldapi.io/api/XAU/USD") else {
            throw GoldPriceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-access-token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoldAPIResponse.self, from: data)
        
        // GoldAPI returns price per troy ounce. Convert to grams.
        // 1 troy ounce = 31.1035 grams
        let pricePerGram = response.price / Decimal(31.1035)
        return pricePerGram
    }
}

struct GoldAPIResponse: Codable {
    let price: Decimal              // Price per troy ounce in USD
    let timestamp: Int
    
    enum CodingKeys: String, CodingKey {
        case price
        case timestamp
    }
}

enum GoldPriceError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
}

/// Fallback: if GoldAPI is down, use cached price with a warning
class CachedGoldPriceService: GoldPriceService {
    private let primaryService: GoldPriceService
    private var cachedPrice: Decimal?
    private var cacheDate: Date?
    
    init(primaryService: GoldPriceService) {
        self.primaryService = primaryService
    }
    
    func fetchGoldPricePerGram() async throws -> Decimal {
        do {
            let price = try await primaryService.fetchGoldPricePerGram()
            cachedPrice = price
            cacheDate = Date()
            return price
        } catch {
            if let cached = cachedPrice {
                return cached  // Use stale price with warning in UI
            }
            throw error
        }
    }
}
```

**Alternative free gold price sources** (if GoldAPI.io becomes unavailable):
- MetalsAPI.com (free tier)
- Scrape Kitco's public page as a last resort
- Hard-code a manual entry fallback in the UI

---

## VIEWMODELS

### DashboardViewModel

```swift
import SwiftUI
import SwiftData

@Observable
class DashboardViewModel {
    // State
    var totalZakatableWealth: Decimal = 0
    var currentNisab: Decimal = 0
    var goldPricePerGram: Decimal = 0
    var isAboveNisab: Bool = false
    var currentHawl: HawlRecord?
    var daysRemainingInHawl: Int = 0
    var zakatDueAmount: Decimal = 0
    var lastSyncDate: Date?
    var isLoading: Bool = false
    var errorMessage: String?
    var goldPriceStale: Bool = false    // True if using cached price
    
    // Hijri date display
    var hijriDateString: String = ""
    
    // Domain
    private let engine = ZakatEngine()
    
    // Dependencies (inject these)
    var financialService: FinancialDataService?
    var goldPriceService: GoldPriceService?
    
    func refresh(assets: [Asset], modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch gold price
            if let goldService = goldPriceService {
                goldPricePerGram = try await goldService.fetchGoldPricePerGram()
                goldPriceStale = false
            }
            
            // 2. Sync SimpleFIN accounts
            if let finService = financialService {
                let accounts = try await finService.fetchAccounts()
                updateAssetBalances(assets: assets, from: accounts, context: modelContext)
                lastSyncDate = Date()
            }
            
            // 3. Recalculate
            totalZakatableWealth = engine.totalZakatableWealth(assets: assets)
            currentNisab = engine.nisabMonitor.nisabThreshold(goldPricePerGram: goldPricePerGram)
            isAboveNisab = totalZakatableWealth >= currentNisab
            
            // 4. Evaluate hawl
            if let hawl = currentHawl {
                let evaluation = engine.evaluateHawl(
                    hawlRecord: hawl,
                    currentWealth: totalZakatableWealth,
                    currentGoldPrice: goldPricePerGram,
                    currentDate: Date()
                )
                
                switch evaluation {
                case .inProgress(let days):
                    daysRemainingInHawl = days
                    zakatDueAmount = 0
                case .zakatDue(let amount):
                    zakatDueAmount = amount
                    daysRemainingInHawl = 0
                    hawl.status = .zakatDue
                    hawl.wealthAtEnd = totalZakatableWealth
                    hawl.nisabAtEnd = currentNisab
                case .hawlReset:
                    hawl.status = .reset
                    currentHawl = nil
                    daysRemainingInHawl = 0
                    zakatDueAmount = 0
                    // Hawl will restart automatically when wealth >= nisab again
                }
            } else if isAboveNisab {
                // No active hawl but above nisab → start new hawl
                let newHawl = HawlRecord(
                    startDate: Date(),
                    wealthAtStart: totalZakatableWealth,
                    nisabAtStart: currentNisab
                )
                modelContext.insert(newHawl)
                currentHawl = newHawl
            }
            
            // 5. Update hijri date
            hijriDateString = engine.hawlTracker.hijriDateString(for: Date())
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateAssetBalances(assets: [Asset], from accounts: [SimpleFINAccount], context: ModelContext) {
        for asset in assets where asset.source == .simplefin {
            if let match = accounts.first(where: { $0.id == asset.simplefinAccountId }) {
                asset.currentBalance = match.balance
                asset.lastSyncedAt = match.balanceDate
            }
        }
        try? context.save()
    }
}
```

### AssetViewModel

```swift
@Observable
class AssetViewModel {
    var assets: [Asset] = []
    var showingAddAsset: Bool = false
    var showingSimpleFINSetup: Bool = false
    
    func addManualAsset(name: String, category: AssetCategory, balance: Decimal, context: ModelContext) {
        let asset = Asset(name: name, category: category, source: .manual, currentBalance: balance)
        context.insert(asset)
        try? context.save()
    }
    
    func updateManualBalance(asset: Asset, newBalance: Decimal, context: ModelContext) {
        guard asset.source == .manual else { return }
        asset.currentBalance = newBalance
        try? context.save()
    }
    
    func deleteAsset(_ asset: Asset, context: ModelContext) {
        context.delete(asset)
        try? context.save()
    }
    
    func linkSimpleFINAccounts(accounts: [SimpleFINAccount], context: ModelContext) {
        for account in accounts {
            let asset = Asset(
                name: account.name,
                category: categorize(account),
                source: .simplefin,
                currentBalance: account.balance
            )
            asset.simplefinAccountId = account.id
            asset.lastSyncedAt = account.balanceDate
            context.insert(asset)
        }
        try? context.save()
    }
    
    private func categorize(_ account: SimpleFINAccount) -> AssetCategory {
        // Simple heuristic — user can recategorize manually
        let name = account.name.lowercased()
        if name.contains("checking") || name.contains("savings") { return .bankAccount }
        if name.contains("brokerage") || name.contains("individual") { return .brokerage }
        if name.contains("ira") || name.contains("401k") || name.contains("roth") { return .retirement }
        return .brokerage  // Default for investment accounts
    }
}
```

### PaymentViewModel

```swift
@Observable
class PaymentViewModel {
    var payments: [ZakatPayment] = []
    
    func recordPayment(amount: Decimal, recipient: String?, hawlRecord: HawlRecord?, context: ModelContext) {
        let payment = ZakatPayment(amount: amount, date: Date(), recipient: recipient)
        payment.hawlRecordId = hawlRecord?.id
        context.insert(payment)
        
        // Update hawl record
        if let hawl = hawlRecord {
            let totalPaid = (hawl.zakatPaidAmount ?? 0) + amount
            hawl.zakatPaidAmount = totalPaid
            if let due = hawl.zakatDueAmount, totalPaid >= due {
                hawl.status = .zakatPaid
                hawl.zakatPaidDate = Date()
            }
        }
        
        try? context.save()
    }
}
```

---

## UI SCREENS

### Screen 1: Dashboard (Main Screen)

The primary view. Shows at a glance whether the user is above nisab, hawl progress, and zakat due.

**Layout:**
```
┌─────────────────────────────────┐
│  Zakat Tracker                  │
│  Today: 14 Dhul Qi'dah 1447    │
├─────────────────────────────────┤
│                                 │
│  Total Zakatable Wealth         │
│  $47,832.00                     │
│                                 │
│  Nisab (85g gold): $6,205.00    │
│  Status: ● ABOVE NISAB          │
│                                 │
├─────────────────────────────────┤
│  ┌─── Hawl Progress ──────────┐ │
│  │  ████████████░░░░  247/354 │ │
│  │  107 days remaining         │ │
│  │  Started: 3 Muharram 1447  │ │
│  │  Ends: 3 Muharram 1448     │ │
│  └────────────────────────────┘ │
├─────────────────────────────────┤
│  Estimated Zakat Due            │
│  $1,195.80  (2.5%)             │
│                                 │
│  Last synced: 2 hours ago  🔄   │
├─────────────────────────────────┤
│  ⚠️ This app assists with Zakat │
│  calculation. Consult a         │
│  qualified scholar for          │
│  specific rulings.              │
└─────────────────────────────────┘
│  🏠 Home  │  💰 Assets  │ ⚙️ Settings │
```

**States:**
- **Above nisab, hawl in progress:** Green status indicator, progress bar, estimated zakat
- **Above nisab, hawl complete:** Gold/amber alert: "Zakat is due!" with prominent "Record Payment" button
- **Below nisab:** Gray status: "Below nisab threshold. No zakat due at this time."
- **No accounts linked:** Prompt to set up SimpleFIN or add manual assets

### Screen 2: Assets List

Shows all linked and manual assets with their current balances.

**Layout:**
```
┌─────────────────────────────────┐
│  My Assets              + Add   │
├─────────────────────────────────┤
│  LINKED ACCOUNTS (SimpleFIN)    │
│  ┌────────────────────────────┐ │
│  │ 🏦 Brokerage A            │ │
│  │    $28,450.00   synced 2h  │ │
│  ├────────────────────────────┤ │
│  │ 🏦 Brokerage B            │ │
│  │    $12,300.00   synced 2h  │ │
│  ├────────────────────────────┤ │
│  │ 🏦 Bank/Credit Union      │ │
│  │    $5,082.00    synced 2h  │ │
│  └────────────────────────────┘ │
│                                 │
│  MANUAL ASSETS                  │
│  ┌────────────────────────────┐ │
│  │ 💵 Cash on Hand            │ │
│  │    $2,000.00    tap to edit│ │
│  └────────────────────────────┘ │
│                                 │
│  TOTAL: $47,832.00              │
└─────────────────────────────────┘
```

- Tapping a SimpleFIN asset shows detail (institution name, account ID, last sync time)
- Tapping a manual asset opens an edit sheet to update the balance
- "+" button shows options: "Add Manual Asset" or "Link via SimpleFIN"

### Screen 3: SimpleFIN Setup

One-time setup flow for connecting SimpleFIN.

```
┌─────────────────────────────────┐
│  Connect Your Accounts          │
├─────────────────────────────────┤
│                                 │
│  1. Visit SimpleFIN Bridge      │
│     beta-bridge.simplefin.org   │
│     [$15/year for up to 25      │
│      institutions]              │
│                                 │
│  2. Connect your banks &        │
│     brokerages there            │
│                                 │
│  3. Create a Setup Token and    │
│     paste it below              │
│                                 │
│  ┌────────────────────────────┐ │
│  │  Paste Setup Token here    │ │
│  └────────────────────────────┘ │
│                                 │
│  [ Connect ]                    │
│                                 │
│  Your credentials are stored    │
│  securely in the iOS Keychain.  │
│  SimpleFIN provides read-only   │
│  access to your balances.       │
└─────────────────────────────────┘
```

### Screen 4: Zakat Payment Recording

When zakat is due, the user can record payments.

```
┌─────────────────────────────────┐
│  Record Zakat Payment           │
├─────────────────────────────────┤
│                                 │
│  Zakat Due: $1,195.80           │
│  Already Paid: $0.00            │
│  Remaining: $1,195.80           │
│                                 │
│  Amount: $[___________]         │
│  Recipient: [___________]       │
│  Notes: [___________]           │
│                                 │
│  [ Pay Full Amount ]            │
│  [ Pay Partial Amount ]         │
│                                 │
│  ── Payment History ──          │
│  (empty)                        │
│                                 │
└─────────────────────────────────┘
```

### Screen 5: Settings

```
┌─────────────────────────────────┐
│  Settings                       │
├─────────────────────────────────┤
│                                 │
│  SIMPLEFIN CONNECTION           │
│  Status: ● Connected            │
│  Accounts: 3 linked             │
│  [ Reconfigure ]                │
│                                 │
│  GOLD PRICE                     │
│  Source: GoldAPI.io              │
│  Current: $73.00/gram           │
│  Last updated: Today 8:00 AM    │
│  [ Refresh Now ]                │
│                                 │
│  NOTIFICATIONS                  │
│  Hawl Reminder: 7 days before   │
│  Daily Sync Alerts: Off         │
│                                 │
│  NISAB                          │
│  Method: 85g of Gold            │
│  Current Threshold: $6,205.00   │
│                                 │
│  DATA                           │
│  [ Export History ]              │
│  [ Reset All Data ]             │
│                                 │
└─────────────────────────────────┘
```

### Screen 6: History

Shows past hawl cycles and payment records.

```
┌─────────────────────────────────┐
│  Zakat History                  │
├─────────────────────────────────┤
│                                 │
│  CURRENT CYCLE                  │
│  Hawl: 3 Muharram 1447 →       │
│        3 Muharram 1448          │
│  Status: In Progress (247/354)  │
│  Wealth at start: $42,100.00    │
│                                 │
│  ── PAST CYCLES ──              │
│  (none yet)                     │
│                                 │
│  ── ALL PAYMENTS ──             │
│  (none yet)                     │
│                                 │
└─────────────────────────────────┘
```

---

## BACKGROUND SYNC

### Daily Refresh Strategy

The app should sync once daily using iOS Background App Refresh:

```swift
// In AppDelegate or App init:
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.yamanshqeirat.zakat-al-mal-app.dailysync",
    using: nil
) { task in
    handleDailySync(task: task as! BGAppRefreshTask)
}

// Schedule:
func scheduleDailySync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.yamanshqeirat.zakat-al-mal-app.dailysync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours
    try? BGTaskScheduler.shared.submit(request)
}
```

Daily sync performs:
1. Fetch gold price → update cached price
2. Fetch SimpleFIN balances → update asset balances
3. Take a NisabSnapshot for historical tracking
4. Check if hawl has completed → trigger local notification if zakat is due
5. Update widget timeline
6. Write shared data to App Group container for widget

---

## WIDGET

### WidgetKit Extension

A simple widget showing nisab status and hawl progress.

**Small widget:**
```
┌───────────────┐
│ Zakat Tracker │
│               │
│ ● Above Nisab │
│ 107 days left │
│               │
│ Est: $1,195   │
└───────────────┘
```

**Medium widget:**
```
┌─────────────────────────────────┐
│ Zakat Tracker                   │
│                                 │
│ Wealth: $47,832  Nisab: $6,205  │
│ ████████████░░░░░  107 days     │
│ Estimated Zakat: $1,195.80      │
└─────────────────────────────────┘
```

**Implementation:**
- Use App Groups to share SwiftData store between main app and widget
- Widget reads from shared container, never makes network calls
- Timeline refreshes every 6 hours or when main app syncs

```swift
// App Group identifier
let appGroupID = "group.com.yamanshqeirat.zakat-al-mal-app"

// In main app: write to shared container after each sync
let sharedDefaults = UserDefaults(suiteName: appGroupID)
sharedDefaults?.set(totalWealth, forKey: "totalZakatableWealth")
sharedDefaults?.set(currentNisab, forKey: "currentNisab")
sharedDefaults?.set(daysRemaining, forKey: "daysRemaining")
sharedDefaults?.set(zakatDue, forKey: "estimatedZakat")
sharedDefaults?.set(isAboveNisab, forKey: "isAboveNisab")
```

---

## NOTIFICATIONS

### Local Notifications

```swift
// Hawl approaching completion (7 days before)
Title: "Hawl Completing Soon"
Body: "Your lunar year cycle completes in 7 days. Current estimated zakat: $1,195.80"

// Hawl completed, zakat due
Title: "Zakat Is Due"
Body: "Your hawl cycle has completed. $1,195.80 in zakat is due on your zakatable wealth of $47,832.00"

// Sync failure (if SimpleFIN fails 3+ days)
Title: "Sync Issue"
Body: "Account balances haven't updated in 3 days. Open the app to check your connection."

// Below nisab — hawl reset
Title: "Hawl Reset"
Body: "Your zakatable wealth has dropped below the nisab threshold. Your hawl has been reset and will restart when your wealth reaches nisab again."
```

---

## KEYCHAIN STORAGE

Store sensitive credentials in the iOS Keychain, not UserDefaults:

```swift
// Simple Keychain wrapper
class KeychainService {
    static func save(key: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)  // Remove old value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

// Usage:
// KeychainService.save(key: "simplefin_access_url", value: accessURL)
// KeychainService.save(key: "goldapi_key", value: apiKey)
```

---

## PROJECT STRUCTURE

```
ZakatTracker/
├── App/
│   ├── ZakatTrackerApp.swift           // @main entry point, SwiftData container
│   └── AppDelegate.swift               // Background task registration
├── Domain/
│   ├── ZakatEngine.swift               // Core calculation logic
│   ├── HawlTracker.swift               // Lunar year cycle management
│   └── NisabMonitor.swift              // Nisab threshold calculation
├── Models/
│   ├── Asset.swift                     // Asset + AssetCategory + AssetSource
│   ├── HawlRecord.swift               // Hawl cycle tracking
│   ├── NisabSnapshot.swift             // Daily snapshots
│   ├── ZakatPayment.swift              // Payment records
│   └── AppSettings.swift              // App configuration
├── Services/
│   ├── SimpleFINService.swift          // SimpleFIN Bridge API client
│   ├── SimpleFINSetup.swift            // One-time token exchange
│   ├── GoldPriceService.swift          // GoldAPI.io client + cache
│   ├── KeychainService.swift           // Secure credential storage
│   └── BackgroundSyncService.swift     // Daily background refresh
├── ViewModels/
│   ├── DashboardViewModel.swift        
│   ├── AssetViewModel.swift            
│   └── PaymentViewModel.swift          
├── Views/
│   ├── DashboardView.swift             // Main screen
│   ├── AssetListView.swift             // All assets
│   ├── AssetDetailView.swift           // Individual asset
│   ├── AddAssetView.swift              // Manual asset entry
│   ├── SimpleFINSetupView.swift        // Token paste flow
│   ├── PaymentView.swift               // Record zakat payment
│   ├── HistoryView.swift               // Past cycles and payments
│   ├── SettingsView.swift              // App settings
│   └── Components/
│       ├── HawlProgressBar.swift       // Circular or linear progress
│       ├── NisabStatusBadge.swift       // Above/below indicator
│       └── CurrencyText.swift          // Formatted currency display
├── Widget/
│   ├── ZakatWidget.swift               // WidgetKit entry point
│   ├── ZakatWidgetProvider.swift       // Timeline provider
│   └── ZakatWidgetView.swift           // Widget UI
└── Resources/
    └── Assets.xcassets                 // App icon, colors
```

---

## BUILD ORDER

Follow this sequence — each step builds on the previous:

1. **Create Xcode project** with SwiftData template, iOS 17+ target
2. **Add Widget Extension** target, configure App Group
3. **Domain layer first**: `NisabMonitor`, `HawlTracker`, `ZakatEngine` — write unit tests
4. **Data models**: All `@Model` classes
5. **KeychainService**: Simple wrapper for secure storage
6. **GoldPriceService**: API client + cache. Test with a real GoldAPI.io free key
7. **SimpleFINService**: API client. Test with SimpleFIN demo token first
8. **SimpleFINSetup**: Token exchange flow
9. **ViewModels**: Wire up domain + services
10. **Views**: Dashboard first, then Assets, then Settings
11. **Background sync**: BGAppRefreshTask registration
12. **Widget**: Read from App Group shared container
13. **Notifications**: Local notification scheduling
14. **Polish**: Error states, loading indicators, empty states

---

## CONFIGURATION NEEDED BEFORE FIRST RUN

1. **SimpleFIN account**: Sign up at beta-bridge.simplefin.org ($15/year)
2. **Connect institutions**: Add your brokerages and bank accounts in SimpleFIN
3. **Create setup token**: Generate in SimpleFIN dashboard
4. **GoldAPI.io key**: Sign up for free tier at goldapi.io
5. **Apple Developer**: Create App ID with App Group capability
6. **App Group**: Create "group.com.yamanshqeirat.zakat-al-mal-app" in developer portal

---

## BEHAVIORAL RULES

1. **Nisab = 85 grams of gold × current gold price per gram.** Always use live price, never a hardcoded dollar amount.
2. **Hawl = one Islamic lunar year (~354 days).** Use `Calendar(identifier: .islamicUmmAlQura)` for all hawl date calculations.
3. **Continuous tracking with reset**: If total zakatable wealth drops below nisab at any daily sync, the hawl resets. A new hawl begins only when wealth equals or exceeds nisab again. The user must remain at or above nisab for a full uninterrupted lunar year for zakat to become due.
4. **Zakat rate = 2.5%** of total zakatable wealth at hawl completion.
5. **Retirement accounts** (future): zakatable amount = value minus early withdrawal penalty.
6. **All brokerage holdings are zakatable**: stocks, ETFs, crypto, cash balances — full value.
7. **Bank account balances are fully zakatable**: checking and savings.
8. **Physical gold/silver**: zakatable at market value. User enters weight; app computes value from live price.
9. **The app is a calculation tool, not a fatwa.** Display disclaimer on dashboard.
10. **SimpleFIN syncs daily.** If sync fails for 3+ consecutive days, alert the user.
