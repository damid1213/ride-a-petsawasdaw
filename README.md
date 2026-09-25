# 🐾 Vanguard — Ride A Pet

> **A modern, modular, high-performance automation suite for Ride A Pet.**  
> Built with Luau, featuring a modular auto-caching loader, dynamic egg ESP, intelligent auto-farming, auto-rebirth routines, and rich Discord webhook integration.

---


## ✨ Key Features

### 🌟 Animated Loading Screen
- Sleek modern loading splash with smooth animated progress bar.
- Animated pulsating spinner dots and elapsed loading timer.
- Clean fade-out transition upon module initialization.

### 🥚 Real-Time Egg ESP
- **Dynamic Distance Tracking**: Real-time 3D billboards displaying egg names and distance (studs).
- **Color-Coded Palette**: Distinct color presets for different egg types.
- **Rare Egg Highlighting**: Automatic golden highlight and custom alerts for rare keywords (`cherub`, `huge`, `exclusive`, `secret`, `titan`, `mythic`, `golden`, `diamond`, `dark`, `rainbow`, `celestial`).

### 🌾 Intelligent Auto-Farm
- **Automated Harvesting**: Locates and navigates to available eggs across the map.
- **Configurable Hold Times**: Fine-tuned interaction durations for smooth egg pickup without getting kicked.
- **Home Deposit Loop**: Automatically returns to your plot and deposits harvested eggs, then resumes farming.
- **Best Egg Hunting**: Optional mode to exclusively target and collect the rarest/best eggs available.

### 🔄 Auto-Rebirth Progression
- **Requirement Tracking**: Automatically inspects missing eggs needed for your next rebirth tier.
- **Targeted Collection**: Prioritizes hunting and collecting specific requirement eggs.
- **Automated Execution**: Automatically teleports home, deposits eggs, and triggers the rebirth action.

### 📨 Discord Webhook Alerts
- **Egg Collection Notifications**: Instant embeds delivered to your Discord channel when eggs are secured.
- **Rare Egg Highlights**: Special gold-themed embeds when rare or high-tier eggs are collected.
- **Session Statistics**: Real-time session runtime tracking and total eggs collected count.
- **Player Information**: Embedded Roblox username, display name, and user ID.
- **Multi-Executor Compatibility**: Supports `syn.request`, `http.request`, `fluxus.request`, `request`, and `http_request` with User-Agent spoofing to prevent Cloudflare/Discord 403 blocks.
- **Smart Rate-Limit Protection**: Automatic spacing prevents dropped notifications during rapid egg harvesting.

### 🛡️ Stability & Safety
- **Anti-AFK Protection**: Built-in Idled event handler keeps your session active 24/7 without disconnects.
- **Anti-Stuck Detection**: Detects navigation stalls and auto-resets player velocity and orientation.
- **Character Respawn Resilience**: Re-hooks connections and resets state seamlessly when your avatar respawns.

### 💻 Dual UI (PC & Mobile)
- **Responsive Layout**: Adapts layout size and padding between PC and Mobile devices.
- **Dark Theme**: Modern glassmorphism dark theme with intuitive sidebar tabs.
- **Live Egg Monitor**: Scrollable list of all currently spawned eggs with distance and collection status.

---

## 📂 Project Architecture

```text
RideAPet/
├── loader.lua              # Modular loader (auto-cache, health check, refresh)
├── version.txt             # Remote version tracker for cache invalidation
├── README.md               # Project documentation
└── src/
    ├── Bootstrap.lua       # Application lifecycle and event binding
    ├── Config.lua          # Centralized configuration and UI color palette
    ├── ESP.lua             # Billboards, highlights, and egg visual rendering
    ├── Farm.lua            # Auto-farm and best egg collection loops
    ├── Interaction.lua     # ProximityPrompt and interaction handlers
    ├── LoadingScreen.lua   # Animated startup GUI and progress indicators
    ├── Movement.lua        # Pathfinding, tweening, and noclip movement engine
    ├── Plot.lua            # Player base/plot detection and home deposit routines
    ├── Rebirth.lua         # Rebirth egg requirement checker and auto-rebirth loop
    ├── Services.lua        # Roblox service cache and UI parent fallback (gethui/CoreGui)
    ├── Stability.lua       # Anti-AFK and character state recovery
    ├── State.lua           # Global reactive state store and history logging
    ├── UI.lua              # Full graphical user interface and control panels
    ├── Utils.lua           # Math, string, vector, and egg validation utilities
    └── Webhook.lua         # Discord Webhook integration with embed formatting
```

---

## ⚙️ Configuration Options

Key parameters can be customized inside [`src/Config.lua`](file:///d:/RideAPet/src/Config.lua):

| Setting | Default | Description |
| :--- | :---: | :--- |
| `MovementSpeed` | `350` | Movement engine travel speed (studs/sec) |
| `TPHeight` | `3` | Height offset above eggs during movement |
| `AutoEggHoldTime` | `2.5s` | Interaction duration for best egg collection |
| `AutoFarmHoldTime` | `2.0s` | Interaction duration for standard auto-farming |
| `HomeDepositWait` | `1.3s` | Wait duration after returning to plot for deposit |
| `EggCooldownSeconds` | `12s` | Cooldown period before re-attempting the same egg |
| `AntiStuckThreshold` | `2.2s` | Timeout before resetting movement if stalled |
| `BestEggName` | `"cherub"` | Keyword identifier for best egg hunting mode |
| `AlertDuration` | `6.5s` | On-screen rare egg alert popup duration |
| `MaxHistoryLogs` | `50` | Maximum farm history records retained in UI |

---

## 🔧 Supported Executors

Tested and compatible across modern Luau executors:
- **Windows**: Synapse X, Wave, Solara, Electron, Celery
- **Android / iOS**: Delta, Fluxus, Codex, Arceus X, Hydrogen, Appleware
- **macOS**: MacSploit

---

## 📜 License & Disclaimer

This project is created for educational and personal automation purposes only. Use responsibly and in accordance with relevant platform guidelines.
