# Pet Battle Level Up Monitor

A World of Warcraft addon that tracks experience gain and provides detailed progress monitoring during pet battles. Features a customizable UI with progress tracking, time estimation, and cross-character data persistence.

![WoW Version](https://img.shields.io/badge/WoW-Classic%20%7C%20Retail-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 📊 Real-Time Progress Tracking
- **5-Line Display**: Character info, last XP gain, progress percentage, battle statistics, and level 80 estimation
- **Visual Progress Bar**: Real-time XP percentage with color-coded progress indicator
- **Remaining Battles**: Shows exactly how many battles needed to reach next level with time estimation
- **Duration Tracking**: Displays time between battle starts for accurate pacing information

### 🎯 Level 80 Estimation
- **Smart Calculations**: Uses historical data to estimate battles and time needed to reach level 80
- **Clock Time Prediction**: Shows estimated completion time (e.g., "245 battles, 2h 45m (by 14:30)")
- **Cross-Character Data**: Saves XP gain data per level for use across all characters

### 🎨 Customizable Interface
- **Font Scaling**: Adjustable from 0.5x to 4.0x (default 2.0x for better visibility)
- **Persistent Positioning**: Remembers where you drag the frame between sessions
- **Auto Hide/Show**: Appears during pet battles, hides when finished
- **Draggable Frame**: Move the monitor to your preferred screen location

### 💾 Data Persistence
- **SavedVariables**: Cross-character data storage that persists between sessions
- **Auto-Save**: Data automatically saves on logout, zone changes, and other WoW triggers
- **Level Data Recording**: Tracks XP gain per battle for each level to improve future estimates

### 🐛 Debug & Maintenance
- **Debug Mode**: Toggle detailed logging for troubleshooting (`/pblm debug`)
- **Comprehensive Commands**: Full slash command interface for all features
- **Performance Optimized**: Uses frame hide/show instead of recreation for better performance

## Installation

1. Download the latest release or clone this repository
2. Extract the `PetBattleLevelUpMonitor` folder to your WoW addons directory:
   - **Windows**: `World of Warcraft\_retail_\Interface\AddOns\`
   - **Mac**: `Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. Restart World of Warcraft or reload your UI (`/reload`)
4. The addon will automatically load and show a confirmation message

## Usage

### Basic Operation
- The monitor automatically appears when you start a pet battle (for characters under level 80)
- Drag the frame to reposition it - your preferred location will be saved
- The frame automatically hides when the pet battle ends

### Display Information
The monitor shows 5 lines of information:

1. **Character Info**: `PlayerName - Level 45`
2. **Last Battle**: `Last: 1250 XP (45s)` - XP gained and time between battles
3. **Progress**: `67% (8420/12500) - 3 battles (2m 15s) left` - Current progress and remaining battles
4. **Statistics**: `Avg: 42.5s, Battles: 15` - Average time and total battles this session
5. **Level 80 Goal**: `To 80: 245 battles, 2h 45m (by 14:30)` - Estimated time to max level

### Progress Bar
A visual progress bar appears between lines 3 and 4, showing your current XP percentage with a blue fill and dark background.

## Commands

Access all features through the `/pblm` command:

### Basic Commands
- `/pblm` - Show help and available commands
- `/pblm test` - Test addon functionality and show current stats
- `/pblm show` - Manually show the monitor frame
- `/pblm hide` - Manually hide the monitor frame

### Data Management
- `/pblm data` - Display all recorded level data and save status
- `/pblm save` - Mark data for saving (saves on logout/zone change)
- `/pblm reload` - Reload UI to force immediate save
- `/pblm forcesave` - Force save data (same as save + suggests reload)

### Customization
- `/pblm size [0.5-4.0]` - Set custom font size (e.g., `/pblm size 2.5`)
- `/pblm big` - Set font to 3.0x size (extra large)
- `/pblm huge` - Set font to 4.0x size (maximum)

### Debug & Development
- `/pblm debug` - Toggle debug mode for detailed logging

## Data Recording Logic

The addon intelligently records XP data with these rules:

- **Records**: Regular pet battles with XP gain (after the first battle)
- **Skips**: First battle of session, level-up battles, battles with no XP gain
- **Calculates**: Remaining battles using most recent XP gain or saved level data
- **Estimates**: Level 80 completion time using average battle duration and saved data

## Technical Details

### File Structure
```
PetBattleLevelUpMonitor/
├── PetBattleLevelUpMonitor.lua    # Main addon code
├── PetBattleLevelUpMonitor.toc    # Addon manifest
└── README.md                      # This file
```

### SavedVariables Format
```lua
PetBattleLevelUpData = {
    levelData = {
        [45] = { xpGainPerBattle = 1250, totalXpNeeded = 12500 },
        [46] = { xpGainPerBattle = 1300, totalXpNeeded = 13000 },
        -- ... more levels
    },
    fontSize = 2.0,
    framePosition = { x = 0, y = 200 }
}
```

### Performance Features
- **Frame Reuse**: Monitor frame is created once and hidden/shown as needed
- **Efficient Updates**: Only updates display when values change
- **Minimal Memory**: Lightweight data structures and event handling
- **Smart Saving**: Uses WoW's built-in SavedVariables triggers

## Troubleshooting

### Common Issues

**Monitor doesn't appear during pet battles:**
- Check that your character is under level 80
- Try `/pblm show` to test if the frame appears
- Enable debug mode with `/pblm debug` for detailed logging

**Data not saving between sessions:**
- Use `/pblm data` to check save status
- Try `/pblm save` followed by `/reload`
- Check that SavedVariables are enabled in your WoW settings

**Frame positioning issues:**
- The frame position saves automatically when you drag it
- If it appears in the wrong location, drag it to your preferred spot
- Use `/pblm show` to test positioning without starting a pet battle

**Font too small/large:**
- Use `/pblm size 2.0` to reset to default size
- Try `/pblm big` (3.0x) or `/pblm huge` (4.0x) for larger text
- Custom sizes: `/pblm size 1.5` for medium, `/pblm size 0.8` for smaller

### Debug Information
Enable debug mode for detailed logging:
```
/pblm debug
```

This will show:
- Battle start/end events
- XP calculations and level-up detection
- Data recording decisions
- Save operations and timers

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup
1. Clone the repository
2. Make changes to the `.lua` files
3. Test in-game with debug mode enabled
4. Submit a pull request with a clear description

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### Version 2.0.0 (Latest)
- **Major Overhaul**: Complete rewrite with enhanced features
- **Added**: Visual progress bar with XP percentage
- **Added**: Persistent frame positioning across sessions
- **Added**: Font scaling system (0.5x-4.0x, default 2.0x)
- **Added**: Remaining battles calculation with time estimation
- **Added**: Cross-character data persistence
- **Added**: Level 80 time estimation using historical data
- **Added**: Debug mode toggle (off by default)
- **Improved**: Enhanced auto-save following WoW's standard triggers
- **Improved**: Frame hide/show system for better performance
- **Improved**: Timing display shows duration between battle starts
- **Added**: Comprehensive slash command interface

### Version 1.0.0
- **Initial Release**: Basic XP and time tracking during pet battles
- **Features**: Simple 4-line display with XP gain and timing information

## Support

If you encounter any issues or have suggestions:

1. Check the [Issues](https://github.com/songying/petbattlelevelupmonitor/issues) page
2. Enable debug mode (`/pblm debug`) to gather more information
3. Create a new issue with details about your problem and any debug output

---

**Made for World of Warcraft pet battle enthusiasts who want to optimize their leveling experience!**