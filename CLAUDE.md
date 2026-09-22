# UtangMate — CLAUDE.md

## Project Overview

**UtangMate** is a Flutter mobile application for small store owners (sari-sari stores, mini groceries) to track customer debts, record payments, and monitor outstanding balances. Think of it as a digital *utang notebook* with customer management, reports, and reminders.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart 3.x) |
| State Management | Provider (`ChangeNotifier`) |
| Local Database | SQLite via `sqflite` |
| PDF Generation | `pdf` + `printing` |
| File Sharing | `share_plus` |
| CSV Export | `csv` |
| Charts | `fl_chart` |
| Image Picker | `image_picker` |
| Preferences | `shared_preferences` |
| Fonts | `google_fonts` (Inter) |
| URL Launching | `url_launcher` |
| Swipe Actions | `flutter_slidable` |

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, MultiProvider, routing
├── core/
│   └── theme.dart                   # Light/dark themes, AppTheme color constants
├── data/
│   ├── database/
│   │   └── database_helper.dart     # SQLite schema, all CRUD, SQL queries
│   └── models/
│       ├── store_model.dart
│       ├── customer_model.dart
│       ├── transaction_model.dart   # DebtTransaction + TransactionItem
│       ├── payment_model.dart
│       └── audit_log_model.dart
├── providers/
│   ├── store_provider.dart          # PIN auth, dark mode, store settings
│   ├── customer_provider.dart       # Customer list, search, filters
│   ├── transaction_provider.dart    # Transactions, overdue refresh
│   ├── payment_provider.dart        # Payments
│   └── dashboard_provider.dart      # Aggregated dashboard stats
├── screens/
│   ├── splash_screen.dart
│   ├── auth/
│   │   ├── pin_login_screen.dart    # PIN login + PinSetupScreen (both here)
│   │   └── pin_setup_screen.dart    # Re-export only
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── customers/
│   │   ├── customer_list_screen.dart
│   │   ├── add_edit_customer_screen.dart
│   │   └── customer_detail_screen.dart
│   ├── transactions/
│   │   └── add_debt_screen.dart
│   ├── payments/
│   │   └── record_payment_screen.dart
│   ├── reports/
│   │   └── reports_screen.dart
│   ├── settings/
│   │   └── settings_screen.dart
│   └── reminders/
│       └── reminders_screen.dart
├── utils/
│   ├── constants.dart               # AppRoutes, AppStrings, AppDurations
│   ├── formatters.dart              # AppFormatter (currency, date, timeAgo)
│   ├── validators.dart              # AppValidators (phone, email, amount, PIN)
│   └── receipt_generator.dart       # PDF receipt generation + share
└── widgets/
    ├── status_badge.dart
    ├── amount_display.dart
    ├── customer_avatar.dart
    ├── empty_state.dart
    ├── loading_overlay.dart
    ├── confirm_dialog.dart
    ├── app_search_bar.dart
    └── info_card.dart               # InfoCard + CountCard
```

---

## Database Schema

### Tables

**`stores`** — Store profile (name, address, phone, currency, logo)  
**`customers`** — Customer records with status (active/archived)  
**`transactions`** — Debt transactions with running balance fields  
**`transaction_items`** — Line items per transaction  
**`payments`** — Payment records linked to transactions  
**`audit_logs`** — Immutable log of all create/update/delete actions  
**`sequences`** — Auto-incrementing counters for human-readable IDs  

### Human-Readable IDs

| Entity | Format | Example |
|---|---|---|
| Customer | `CUST-XXXX` | `CUST-0001` |
| Transaction | `TX-XXXXX` | `TX-00001` |
| Payment | `PAY-XXXXX` | `PAY-00001` |

### Financial Logic

**Balances are never manually entered.** They are always computed:

```
remaining_balance = total_amount - amount_paid
```

When a payment is recorded, the database transaction:
1. Validates the payment amount ≤ remaining balance (overpayment prevented)
2. Updates `amount_paid` and `remaining_balance` on the transaction row
3. Recalculates `status` → `unpaid | partiallyPaid | paid | overdue`
4. Writes an audit log entry

Outstanding balance per customer is computed via SQL aggregation, never stored.

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release

# Build release AAB (Play Store)
flutter build appbundle --release
```

---

## Key Flows

### First Launch
`SplashScreen` → `StoreProvider.init()` → no PIN set → `PinSetupScreen` → `Dashboard`

### Returning User (PIN set)
`SplashScreen` → `PinLoginScreen` (shake on wrong PIN) → `Dashboard`

### Add Debt
`Customer Detail` or `Dashboard quick action` → `AddDebtScreen`  
→ Select customer → Set dates → Add items (name/qty/unit/price) → Credit limit check → Save  
→ Transaction created, balance updated atomically

### Record Payment
`Customer Detail` → expand transaction → `Record Payment`  
→ Amount (Full Payment shortcut) → Method (Cash/GCash/Bank/Other) → Save  
→ Balance recalculated, status updated atomically

### Reminders
`RemindersScreen` → Overdue / Due Soon tabs  
→ Copy reminder message to clipboard, or open SMS/WhatsApp  
→ Direct Pay button records payment inline

---

## Authentication

- 4-digit PIN stored in `SharedPreferences` (key: `app_pin`)
- No PIN = app opens directly (first launch flow)
- Wrong PIN → shake animation, counter reset
- `StoreProvider.lockApp()` can be called to re-require PIN

> For production, consider hashing the PIN with `crypto` package before storing.

---

## Currency

Default currency is **Philippine Peso (₱ / PHP)**. Configurable per store in Settings → Store Information. The `currencySymbol` from `StoreProvider` is passed down to all formatting calls.

---

## Adding a New Screen

1. Create `lib/screens/<section>/<name>_screen.dart`
2. Add route constant to `AppRoutes` in `lib/utils/constants.dart`
3. Add case to `_onGenerateRoute` in `lib/main.dart`
4. Navigate with `Navigator.of(context).pushNamed(AppRoutes.yourRoute, arguments: ...)`

---

## Adding a New DB Query

1. Add the method to `DatabaseHelper` in `lib/data/database/database_helper.dart`
2. Expose it through the relevant Provider
3. Call from the screen via `context.read<XProvider>().yourMethod()`

---

## Receipts

`ReceiptGenerator` in `lib/utils/receipt_generator.dart` generates A6 PDF receipts using the `pdf` package and shares via `share_plus`. Two receipt types:

- `ReceiptGenerator.shareTransactionReceipt(store, transaction)` — debt slip
- `ReceiptGenerator.sharePaymentReceipt(store, payment, remainingBalance)` — payment proof

---

## Known Limitations / Future Work

- [ ] Biometric lock (use `local_auth` package)
- [ ] Cloud backup / sync (Firebase Firestore)
- [ ] Import customers from CSV
- [ ] Push notifications for overdue debts (via `flutter_local_notifications`)
- [ ] Multi-store support (add `store_id` FK to customers/transactions)
- [ ] Staff accounts with role-based access
- [ ] Product inventory tracking
- [ ] Offline-first sync when internet available
- [ ] Audit log screen (model + DB query already exist, screen is a placeholder)
