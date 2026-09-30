# My Wallet - Offline-First Personal Finance App

An Android-first personal finance application built in **Flutter** & **Dart**. Designed for one person, with local financial storage and no account registration or server dependency.

## Current implementation

- Flutter 3.44.8 / Dart 3.12.2; run `flutter pub get`, `flutter test`, then `flutter run`.
- Loans given and taken, people, partial and full repayments, overdue status, and receivable/payable summaries are stored in Hive.
- Loan movements appear in transaction history. They are excluded from income and expense reports.
- Optional loan proof images are copied into app-private document storage with `image_picker` and `path_provider`.
- Account balances are rebuilt from opening balances and all saved movements on startup to repair interrupted writes.
- Android biometric support uses `FlutterFragmentActivity` and `USE_BIOMETRIC`; iOS Face ID has an Info.plist usage description.
- Inter and Poppins are bundled under their OFL licenses in `assets/fonts`; Google Fonts runtime downloads are disabled.
- Tests cover basic transactions, auth, reports, loan accounting, repayment, deletion, and balance recovery.
- Transaction history and Settings offer a customizable CSV ledger export. On Android, the system document picker lets you save it to Downloads or another chosen folder. The ledger includes loans and repayments as separate movement types, with opening and running cash balances.

Device testing is still required for biometric prompts, gallery selection, and a complete restart flow. Full data backup/import and scheduled reminders remain future extensions.

---

## Key Features

- ** App Security & Lock Screen**:
  - Default app password: `123456`.
  - Enforced lock screen on **every app launch**.
  - Dual unlock options: App password or native device biometrics (Fingerprint / Face ID / PIN / Pattern via `local_auth`).
  - Smooth shake animation on incorrect password entry.
  - Secure credential storage using `flutter_secure_storage`.
  - Dedicated Change Password module in Settings.

- ** Financial Accounts & Wallets**:
  - Unlimited account creation (Bank Accounts, Mobile Wallets like JazzCash/Easypaisa, Cash in Hand, Other).
  - Accurate balance tracking stored in integer minor units (zero floating-point errors).
  - Safe account deletion with linked transaction checks.

- ** Transactions & Balance Adjustment**:
  - Record Income & Expense transactions.
  - Automatic account balance updates upon creation, edit, or deletion.
  - Reversal and recalculation logic for edited and deleted transactions.
  - Configurable "Allow Negative Balance" toggle in Settings (disabled by default).

- ** Dashboard**:
  - Total available balance across all wallets.
  - Period summary (Income, Expenses, Net Savings).
  - Month-to-date quick metrics.
  - Recent transactions list.
  - Interactive Income vs Expense chart (`fl_chart`).
  - Quick action buttons (Add Income, Add Expense, Add Account, View Transactions).
  - Date range selector (Today, This Week, This Month, Last 6 Months, This Year, Last 3 Years, Custom Range).

- ** Transaction History & Filtering**:
  - Chronological, date-grouped transaction list.
  - Real-time search by note, category, account, or amount.
  - Multi-dimensional filters (Type, Date range, Category, Account).
  - Flexible sorting (Newest, Oldest, Highest amount, Lowest amount).
  - CSV ledger export with date, account, category, movement type, and search filters.

- ** Analytics & Reports**:
  - Financial trends (Line chart for monthly/daily trajectory).
  - Category breakdown with visual progress bars.
  - Account balance distribution.
  - Daily & monthly averages calculator.

- ** Settings & Customization**:
  - Custom category creator (icon and color picker).
  - Biometrics toggle.
  - Currency symbol selector (Default: PKR `₨`).
  - Negative balance control.
  - Irreversible Clear All Data feature with safety confirmation.

---

## Technical Architecture

- **Architecture**: Clean, scalable, feature-based architecture.
- **State Management**: Riverpod (`flutter_riverpod`).
- **Database**: Hive (`hive`, `hive_flutter`) with custom `TypeAdapter`s.
- **Secure Storage**: `flutter_secure_storage` for password & security preferences.
- **UI/UX**: Custom Light Theme with Google Fonts Inter & Poppins, Emerald/Teal color palette, responsive cards, micro-animations (`flutter_animate`), and `fl_chart`.

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.5.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^11.2.0
  local_auth: ^3.0.2
  google_fonts: ^8.2.1
  uuid: ^4.6.0
  fl_chart: ^1.2.0
  intl: ^0.20.3
  flutter_animate: ^4.5.2
```

---

## Setup & Running Instructions

### Prerequisites
- Flutter SDK (`>= 3.12.0` / Stable channel)
- Android Studio / VS Code with Flutter extension
- Android Emulator or physical test device

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Run Unit Tests
```bash
flutter test
```

### Step 3: Launch the App
```bash
flutter run
```

---

## Unit Test Suite Overview

The project includes unit tests covering all primary finance and security contracts:
1. Income increases account balance.
2. Expense deducts account balance.
3. Editing transaction recalculates balance correctly.
4. Deleting transaction restores balance correctly.
5. Password validation and password change logic.
6. Biometric setting behavior.
7. Biometric failure fallback to password.
8. Date-range report calculations.

Run unit tests via:
```bash
flutter test
```
