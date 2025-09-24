# Data Recovery Instructions

This folder contains tools to parse your corrupted `tempdata.lua` and generate a corrected `savedData.lua` file.

## Quick Start

1. **Copy your tempdata.lua file** to this folder (same directory as these scripts)

2. **Run the parser** using one of these methods:

   ### Method 1: PowerShell (Recommended for Windows)
   ```powershell
   # Right-click on parse_data.ps1 and select "Run with PowerShell"
   # OR open PowerShell in this folder and run:
   .\parse_data.ps1
   ```

   ### Method 2: Batch File
   ```cmd
   # Double-click parse_data.bat
   # OR open Command Prompt and run:
   parse_data.bat
   ```

   ### Method 3: Lua (if you have Lua installed)
   ```bash
   lua parse_temp_data.lua
   ```

3. **Enter your current level** when prompted (e.g., 30)

4. **Check the output** - you'll get a `savedData.lua` file with corrected data

## What the Parser Does

### 🔍 **Analysis**
- Reads your `tempdata.lua` file
- Detects array-based data structure (numeric indices)
- Extracts `xpGainPerBattle` and `totalXpNeeded` values

### 🧠 **Intelligent Mapping**
- Sorts all entries by `xpGainPerBattle` (ascending order)
- Maps highest XP → your current level
- Maps second highest → current level - 1
- Continues mapping backward to assign correct levels

### 📝 **Output Generation**
- Creates `savedData.lua` with proper structure:
  ```lua
  PetBattleLevelUpData = {
      levelData = {
          ["28"] = { totalXpNeeded = 33960, xpGainPerBattle = 2500 },
          ["29"] = { totalXpNeeded = 35985, xpGainPerBattle = 2562 },
          ["30"] = { totalXpNeeded = 38075, xpGainPerBattle = 2687 }
      },
      fontSize = 2.0,
      framePosition = { x = 0, y = 200 }
  }
  ```

## Example

If you have corrupted data like:
```lua
levelData = {
    nil, nil, nil, ..., -- 27 empty entries
    { totalXpNeeded = 33960, xpGainPerBattle = 2500 }, -- Index 28
    { totalXpNeeded = 35985, xpGainPerBattle = 2562 }, -- Index 29
    { totalXpNeeded = 38075, xpGainPerBattle = 2687 }  -- Index 30
}
```

And your current level is 30, the parser will:
1. Sort by XP: 2500 < 2562 < 2687
2. Map: 2687 (highest) → Level 30, 2562 → Level 29, 2500 → Level 28
3. Generate corrected data with proper string keys

## After Parsing

1. **Verify the output** in `savedData.lua`
2. **Copy the data structure** to your WoW SavedVariables file
3. **Or use the corrected data** directly in your addon

## Troubleshooting

### "tempdata.lua not found"
- Make sure your tempdata.lua file is in the same folder as these scripts

### "No valid data entries found"
- Check that your tempdata.lua contains the levelData structure
- Ensure entries have both `totalXpNeeded` and `xpGainPerBattle` fields

### "PowerShell execution policy error"
- Run PowerShell as Administrator and execute:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Parser shows wrong level mapping
- Double-check you entered your current level correctly
- The mapping assumes XP increases with level (which it should)

## Files Created

- `savedData.lua` - The corrected data structure (main output)
- Log output shows the mapping process for verification

---

**Need help?** Check the mapping output to verify the levels look correct for your progression.