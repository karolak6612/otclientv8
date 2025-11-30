# OTClientV8 - Offline Map Explorer!

> **Note**: This is a specialized fork of [OTClientV8](https://github.com/OTAcademy/otclientv8) designed for offline OTBM map exploration and spawn simulation
#
> **Warning!**: This project is in EXPERIMENTAL phase, so expect bugs, freezes and crashes. Some actions that expect server packets will freeze this program. 

## 🚀 Overview

This project extends the powerful OTClientV8 engine with a suite of offline tools for developers, mappers, and server admins. It allows you to load, explore, and simulate game content directly from your local files without needing a running server.

### ✨ Key Features

*   **Offline Map Explorer**: Load and explore `.otbm` maps directly. No server required.
*   **Spawn Simulator**: Test your spawn configurations (`spawn.xml`) in real-time. Visualize monster density and placement.
*   **Explorer tool!**: Change your server light, change your outfit, speed, scroll, and many to come!
*   **Asset Management**: Seamless loading of multiple client versions (7.40 - 12.20).

---
## 📝 Data/things/[client] directory - preparation

### 📁 Folder structure

*   **Create client folder**:  data/things/800, data/things/1098, etc.
*   **Tibia client**: copy Tibia.dat and Tibia.spr into the client directory
*   **Items**: copy "items.otb" into the client directory (for example from Remere's Map Editor)
*   **OTBM map**: Copy [map.otbm] into the client directory. Multiple files are supported.
*   **Spawns**: Copy [map-spawn.xml] into the client directory. Multiple files are supported.

---

## 🛠️ New Tools & Workflows

### 1. Offline Map Explorer
Explore your map files without need of TFS Server! 

*   **Choose Tibia Version**: In "Enter Game" dialog, change your desired version, (eg. 800)
*   **Open Map**: Click "Offline Map Explorer" on the login screen.
*   **Load Map**: Navigate through dialog to your `.otbm` file from your 'data/things/[client]' directory.
*   **Navigation**:
    *   **Move**: Arrow keys or WASD (if configured)
    *   **Zoom**: Ctrl + Scroll
    *   **Change Floor**: Scroll
    *   **Teleport**: Ctrl + Click on map or minimap

### 2. Spawn Simulator
Visualize and test your spawn XML files!

*   **Load Spawns**: In the Map Explorer, open the "Spawn Simulator" panel.
*   **Select File**: Choose your `spawn.xml` file.
*   **Visualize**: See monsters spawn in real-time based on the configuration.
*   **Heatmap**: (Coming Soon) Visualize spawn density.

### 3. Explorer Tools
Customize your experience!

*   **Light Control**: Adjust ambient light level.
*   **Speed Control**: Change your movement speed.
*   **Outfit Changer**: Change your character's look type, addons, and mount.

### 4. Automatic map refresh!
See your map edits in RME in an INSTANT!

*   **File watcher**: Edit OTBM file in RME directly from your 'data/things/[client]' directory -> save it -> OTclient will automaticly reload the map!

---

## 🤝 Contribution

We believe in the power of community and open source. **Every contribution is welcome!**

Whether you're a seasoned C++ developer, a Lua scripter, or just someone who wants to fix a typo or improve the vibes, we want to hear from you.

*   **Vibe-coded contributions?** YES! If you have an idea that makes the tool feel better, look better, or just be more fun, send it in!
*   **Features?** Absolutely. Missing a tool you need? Build it and share it!
*   **Bugs?** Please report them, or even better, fix them!
*   **Proposals?** Have a crazy idea? Open an issue and let's discuss it.

### How to Contribute

1.  **Fork & Clone**: Fork the repository and clone it to your local machine.
2.  **Branch**: Create a new branch for your feature or fix.
3.  **Code**: Implement your changes.
    *   **Keep it Modular**: Try to keep changes within `modules/client_mapexplorer` if possible.
    *   **Avoid Core Hacks**: Avoid modifying the core engine (`src/`) unless absolutely necessary.
    *   **Follow Patterns**: Look at existing code (especially in `client_mapexplorer`) and follow the style.
4.  **Test**: Run the client and verify your changes work in Offline Mode.
5.  **Pull Request**: Submit a PR with a clear description of what you did.

### Workflows

*   **Code Review**: We use standard PR reviews. Be open to feedback!
*   **Self-Review**: Before submitting, do a quick self-review. Did you leave any debug prints? Is the code clean?
*   **Think**: Take a moment to think about the design before coding. Simple is usually better.

---

## 👨‍💻 For Developers

The core of the offline functionality resides in the `modules/client_mapexplorer` module. This module is designed to be self-contained and modular.

### Module Structure (`modules/client_mapexplorer`)

```
client_mapexplorer/
├── config/                 # Configuration files
│   └── explorer_config.lua # Default settings and config loading
├── events/                 # Event system
│   ├── event_bus.lua       # Central event bus for module communication
│   └── event_definitions.lua # Definitions of event types
├── services/               # Business logic and services
│   ├── lighting_service.lua # Manages ambient light and light updates
│   ├── map_loader_service.lua # Handles OTBM map loading and parsing
│   ├── outfit_service.lua   # Manages player outfits and mounts
│   ├── persistence_service.lua # Saves/loads state (position, camera, etc.)
│   ├── player_service.lua   # Manages the local player entity
│   └── spawn_service.lua    # Handles spawn XML loading and simulation
├── state/                  # State management
│   └── explorer_state.lua   # Centralized state store (reactive-ish)
├── ui/                     # User Interface
│   ├── controllers/        # UI Logic (MVC pattern)
│   │   ├── map_browser_controller.lua
│   │   ├── spawn_simulator_controller.lua
│   │   └── tools_panel_controller.lua
│   ├── views/              # OTUI layout files
│   │   ├── explorer_tools.otui
│   │   ├── mapexplorer.otui
│   │   ├── spawn_simulator.otui
│   │   └── spawn_simulator_dockable.otui
│   ├── widgets/            # Reusable UI widgets
│   │   └── file_browser_widget.lua
│   └── init.lua            # UI initialization
├── utils/                  # Helper functions
│   └── file_browser_utils.lua
├── init.lua                # Module entry point
├── mapexplorer.otmod       # Module definition and dependencies
└── README.md               # Module specific documentation
```

### Key Files & Concerns

| File/Directory | Concern | Description |
| :--- | :--- | :--- |
| `init.lua` | **Entry Point** | Initializes the module, sets up services, and hooks into the game interface. |
| `mapexplorer.otmod` | **Definition** | Defines module metadata, dependencies, and autoload priorities. |
| `services/` | **Logic** | Contains the core business logic. Services are singletons that handle specific domains (Map, Player, Spawns). |
| `ui/controllers/` | **UI Logic** | Bridges the gap between UI views (`.otui`) and Services. Handles user input and updates UI state. |
| `ui/views/` | **Layout** | Defines the visual structure of windows and panels using OTUI syntax. |
| `events/event_bus.lua` | **Communication** | Decouples components. Services publish events, Controllers subscribe to them. |
| `state/explorer_state.lua` | **State** | Holds the runtime state of the explorer (e.g., current map, selected options). |

---

## ⌨️ Hotkeys & Controls

| Action | Hotkey | Context |
| :--- | :--- | :--- |
| **Teleport** | `Ctrl + Left Click` | Map or Minimap |
| **Change Floor** | `Mouse Scroll` | Map View |
| **Zoom** | `Ctrl + Mouse Scroll` | Map View |
| **Move** | `Arrows` | Map View |

---

## 🏗️ Compilation

### Windows (Recommended)

**Prerequisites:**
*   Visual Studio 2022 (with "Desktop development with C++" workload)
*   Git

**Step 1: Install Vcpkg**
```powershell
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg.exe integrate install
```

**Step 2: Build with CMake**
Open the project folder in Visual Studio 2022 (File -> Open -> Folder).
VS will automatically detect `CMakeLists.txt` and configure the project using Vcpkg.

1.  Select **Release** configuration.
2.  Build -> **Build All**.

**Alternative: Command Line**
```powershell
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=[path_to_vcpkg]/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release
```

### Linux (Ubuntu 22.04) - not tested

```bash
sudo apt update
sudo apt install git curl build-essential cmake gcc g++ pkg-config autoconf libtool libglew-dev -y

# Install Vcpkg
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg && ./bootstrap-vcpkg.sh && cd ..

# Build Project
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../vcpkg/scripts/buildsystems/vcpkg.cmake ..
make -j$(nproc)
```

---

## 📜 Original Credits

**OTClientV8** is developed by [OTAcademy](https://github.com/OTAcademy).
*   [Original Repository](https://github.com/OTAcademy/otclientv8)
*   [Discord Community](https://discord.gg/2T9wP8C)

If you add a custom feature, make sure it's optional and can be enabled via `g_game.enableFeature`, otherwise PRs to the main repo may be rejected.
