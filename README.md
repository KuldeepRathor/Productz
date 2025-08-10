# ProductZ - Flutter Multi-Source Data Fetching

A Flutter app demonstrating multi-source data fetching with in-memory caching and automatic refresh strategies.

## 🏗️ Architecture

### Repository Pattern

```
UI Layer (Screens) → Repository Layer → Service Layer (API/Cache)
                           ↓
                    State Stream (ProductLoadState)
```

### Core Components

- **ProductRepository**: Orchestrates data fetching from cache → network
- **CacheService**: In-memory cache (non-persistent) with 5-minute staleness
- **ApiService**: Simulates network calls with configurable latency
- **ProductLoadState**: Tracks loading states, data source, and errors

## 🔄 State Management

**Riverpod + Streams** for reactive state updates:

- Automatic UI rebuilds on state changes
- Clean async operation handling
- Resource disposal management

## 📊 Data Flow

1. **Initial Load**: Show cached data (if any) → Fetch from network → Update cache & UI
2. **Staleness**: Auto-refresh when cache > 5 minutes old
3. **Offline**: Gracefully falls back to cached data
4. **Errors**: Shows cached data with error message

## 🎯 Key Features

- ✅ Instant cache display
- ✅ Concurrent network fetching
- ✅ Auto-refresh after 5 minutes
- ✅ Offline mode support
- ✅ Visual state indicators
- ✅ Pull-to-refresh
- ✅ Image caching

## 🚀 Running the App

```bash
# Clone repo
git clone https://github.com/yourusername/productz.git
cd productz

# Install dependencies
flutter pub get

# Run
flutter run
```

## 🧪 Testing Scenarios

1. **Cache Hit**: Navigate between tabs to see instant cache loading
2. **Network Fetch**: Fresh launch always fetches from network
3. **Auto-Refresh**: Wait 5 minutes to see automatic refresh
4. **Offline Mode**: Turn on airplane mode to test offline behavior
5. **Error Handling**: Set `simulateError: true` in ApiService

## 📁 Project Structure

```
lib/
├── models/          # Product data model
├── providers/       # Riverpod providers
├── repository/      # Data fetching logic
├── screens/         # UI screens
└── services/        # API & Cache services
```

## 🎨 Status Indicators

- 🟢 Green: Fresh data
- 🟡 Amber: Stale cache
- 🟠 Orange: Refreshing
- 🔵 Blue: Loading
- 🔴 Red: Error
- ⚫ Grey: Offline

## 💡 Design Decisions

1. **In-Memory Cache**: Non-persistent as per requirements
2. **Stream-Based State**: Real-time reactive updates
3. **Status Bar**: Clear visual feedback for data states
4. **Error Resilience**: Always show cached data when available

---

*  Built for Flutter development assessment*
