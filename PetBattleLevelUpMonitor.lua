-- Pet Battle Level Up Monitor - Complete Version

-- Global variables
PetBattleLevelUpData = PetBattleLevelUpData or {
    levelData = {},
    fontSize = 2.0,  -- Default to 2x size
    framePosition = { x = 0, y = 200 }  -- Remember frame position
}

local frame = CreateFrame("Frame")
local monitorFrame = nil
local debugMode = false
local inPetBattle = false

-- Session data
local sessionData = {
    lastRoundXP = 0,
    lastRoundTime = 0,
    totalBattles = 0,
    isFirstBattle = true,
    currentLevel = 0,
    battleStartXP = 0,
    battleStartTime = 0,
    lastBattleEndXP = 0,
    previousBattleStartTime = 0,
    averageTime = 0,
    totalBattleTime = 0,
    lastXPTime = 0,  -- Track when XP was last gained
    lastBattleDuration = 0,  -- Track duration between battle starts
    needsSave = false  -- Flag to track if data needs saving
}

-- Force save the data (moved early so it's available for drag handler)
local function ForceSaveData()
    -- Mark the SavedVariables as changed so WoW will save it
    if PetBattleLevelUpData then
        -- Force WoW to recognize changes by modifying multiple fields
        PetBattleLevelUpData._lastSave = GetTime()
        PetBattleLevelUpData._saveCounter = (PetBattleLevelUpData._saveCounter or 0) + 1
        PetBattleLevelUpData._forceWrite = math.random(1000000)  -- Random number to force change detection

        -- Create nested changes to ensure SavedVariables detects modification
        if not PetBattleLevelUpData._saveMetadata then
            PetBattleLevelUpData._saveMetadata = {}
        end
        PetBattleLevelUpData._saveMetadata.lastUpdate = GetTime()
        PetBattleLevelUpData._saveMetadata.session = (PetBattleLevelUpData._saveMetadata.session or 0) + 1

        if debugMode then
            print("Data marked for saving (will save on logout/reload) - Count: " .. PetBattleLevelUpData._saveCounter)
        end
    end
end

-- Progress bar frame creation (only create once)
local function CreateProgressFrame()
    if monitorFrame then
        return  -- Frame already exists, don't recreate
    end

    local fontSize = PetBattleLevelUpData.fontSize or 2.0
    local scaledWidth = 500 * fontSize
    local scaledHeight = 200 * fontSize  -- Increased height for progress bar
    local spacing = -8 * fontSize
    local margin = 15 * fontSize

    monitorFrame = CreateFrame("Frame", "PetBattleMonitorFrame", UIParent, "BackdropTemplate")
    monitorFrame:SetSize(scaledWidth, scaledHeight)

    -- Use saved position or default
    local savedPos = PetBattleLevelUpData.framePosition or { x = 0, y = 200 }
    monitorFrame:SetPoint("CENTER", UIParent, "CENTER", savedPos.x, savedPos.y)

    monitorFrame:SetMovable(true)
    monitorFrame:EnableMouse(true)
    monitorFrame:RegisterForDrag("LeftButton")
    monitorFrame:SetScript("OnDragStart", monitorFrame.StartMoving)
    monitorFrame:SetScript("OnDragStop", function(self)
        monitorFrame.StopMovingOrSizing(self)
        -- Save position when dragging stops
        local point, relativeTo, relativePoint, xOfs, yOfs = monitorFrame:GetPoint()
        PetBattleLevelUpData.framePosition = { x = xOfs, y = yOfs }
        ForceSaveData()
    end)

    monitorFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    monitorFrame:SetBackdropColor(0, 0, 0, 0.9)

    -- Text displays with smart font setting
    local baseFontSize = 16 * fontSize
    local locale = GetLocale()

    -- Function to set appropriate font for locale
    local function SetSmartFont(fontString, size)
        if not fontString then
            print("ERROR: SetSmartFont called with nil fontString")
            return false
        end

        local success = false

        -- Try Chinese font first for Chinese locales
        if locale == "zhCN" or locale == "zhTW" then
            success = fontString:SetFont("Fonts\\ARHei.ttf", size, "OUTLINE")
            if success and debugMode then
                print("Using Chinese font ARHei.ttf")
            end
        end

        -- Fallback to English font
        if not success then
            success = fontString:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            if success and debugMode then
                print("Using English font FRIZQT__.TTF")
            end
        end

        -- Final fallback - just use the inherited font from GameFontNormal
        if not success then
            -- Don't set font, use the default from GameFontNormal template
            if debugMode then
                print("Using default font inheritance for locale: " .. locale)
            end
            return false
        end

        return success
    end

    monitorFrame.text1 = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.text1:SetPoint("TOPLEFT", margin, -margin)
    monitorFrame.text1:SetTextColor(1, 1, 1, 1)
    SetSmartFont(monitorFrame.text1, baseFontSize)

    monitorFrame.text2 = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.text2:SetPoint("TOPLEFT", monitorFrame.text1, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text2:SetTextColor(1, 1, 0, 1)
    SetSmartFont(monitorFrame.text2, baseFontSize)

    monitorFrame.text3 = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.text3:SetPoint("TOPLEFT", monitorFrame.text2, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text3:SetTextColor(0, 1, 0, 1)
    SetSmartFont(monitorFrame.text3, baseFontSize)

    -- Progress bar
    local progressBarWidth = scaledWidth - (margin * 2)
    local progressBarHeight = 20 * fontSize

    monitorFrame.progressBar = CreateFrame("StatusBar", nil, monitorFrame)
    monitorFrame.progressBar:SetSize(progressBarWidth, progressBarHeight)
    monitorFrame.progressBar:SetPoint("TOPLEFT", monitorFrame.text3, "BOTTOMLEFT", 0, spacing)
    monitorFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    monitorFrame.progressBar:SetStatusBarColor(0, 0.4, 0.8, 1)
    monitorFrame.progressBar:SetMinMaxValues(0, 100)

    -- Progress bar background
    local bg = monitorFrame.progressBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(monitorFrame.progressBar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

    monitorFrame.text4 = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.text4:SetPoint("TOPLEFT", monitorFrame.progressBar, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text4:SetTextColor(0.8, 0.8, 1, 1)
    SetSmartFont(monitorFrame.text4, baseFontSize)

    monitorFrame.text5 = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.text5:SetPoint("TOPLEFT", monitorFrame.text4, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text5:SetTextColor(1, 0.8, 0.4, 1)
    SetSmartFont(monitorFrame.text5, baseFontSize)

    monitorFrame:Hide()

    -- Verify all text objects were created successfully
    local creationSuccess = true
    if not monitorFrame.text1 then
        print("ERROR: text1 creation failed")
        creationSuccess = false
    end
    if not monitorFrame.text2 then
        print("ERROR: text2 creation failed")
        creationSuccess = false
    end
    if not monitorFrame.text3 then
        print("ERROR: text3 creation failed")
        creationSuccess = false
    end
    if not monitorFrame.text4 then
        print("ERROR: text4 creation failed")
        creationSuccess = false
    end
    if not monitorFrame.text5 then
        print("ERROR: text5 creation failed")
        creationSuccess = false
    end

    if debugMode or not creationSuccess then
        print("Pet Battle Level Up Monitor: Frame created - Size: " .. scaledWidth .. "x" .. scaledHeight .. ", Font size: " .. baseFontSize)
        print("Text objects created: " .. (creationSuccess and "✅ All successful" or "❌ Some failed"))
    end
end

-- Calculate time to level 80
local function CalculateTimeToLevel80()
    local currentLevel = UnitLevel("player")
    if currentLevel >= 80 then
        return "Max level reached!"
    end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local remainingXPThisLevel = maxXP - currentXP

    local totalBattlesNeeded = 0
    local totalTimeNeeded = 0

    -- Calculate battles needed for current level
    local currentLevelData = PetBattleLevelUpData.levelData[tostring(currentLevel)]
    if currentLevelData and currentLevelData.xpGainPerBattle > 0 then
        local battlesThisLevel = math.ceil(remainingXPThisLevel / currentLevelData.xpGainPerBattle)
        totalBattlesNeeded = totalBattlesNeeded + battlesThisLevel
    end

    -- Calculate battles needed for remaining levels
    for level = currentLevel + 1, 79 do
        local levelData = PetBattleLevelUpData.levelData[tostring(level)]
        if levelData and levelData.xpGainPerBattle > 0 then
            local battlesForLevel = math.ceil(levelData.totalXpNeeded / levelData.xpGainPerBattle)
            totalBattlesNeeded = totalBattlesNeeded + battlesForLevel
        else
            return "Need more data for level " .. level
        end
    end

    -- Calculate total time using average battle time
    if sessionData.averageTime > 0 then
        totalTimeNeeded = totalBattlesNeeded * sessionData.averageTime

        -- Convert to hours and minutes
        local hours = math.floor(totalTimeNeeded / 3600)
        local minutes = math.floor((totalTimeNeeded % 3600) / 60)

        -- Calculate estimated completion time
        local currentTime = time()
        local completionTime = currentTime + totalTimeNeeded
        local completionTimeStr = date("%H:%M", completionTime)

        return string.format("%d battles, %dh %dm (by %s)", totalBattlesNeeded, hours, minutes, completionTimeStr)
    else
        return string.format("%d battles (no time data)", totalBattlesNeeded)
    end
end

-- Update display
local function UpdateDisplay()
    if not monitorFrame or not monitorFrame:IsShown() then
        return
    end

    -- Check if text objects exist, recreate frame if needed
    if not monitorFrame.text1 or not monitorFrame.text2 or not monitorFrame.text3 or not monitorFrame.text4 or not monitorFrame.text5 then
        if debugMode then
            print("Text objects missing, recreating frame...")
        end
        monitorFrame:Hide()
        monitorFrame = nil
        CreateProgressFrame()
        if not monitorFrame.text1 then
            print("ERROR: Failed to create text objects - frame creation failed")
            return
        end
    end

    local playerName = UnitName("player")
    local playerLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local xpPercent = math.floor((currentXP / maxXP) * 100)

    monitorFrame.text1:SetText(playerName .. " - Level " .. playerLevel)

    if sessionData.lastRoundXP > 0 then
        -- Show duration between battle starts
        if sessionData.lastBattleDuration > 0 then
            monitorFrame.text2:SetText(string.format("Last: %d XP (%.0fs)", sessionData.lastRoundXP, sessionData.lastBattleDuration))
        else
            monitorFrame.text2:SetText(string.format("Last: %d XP", sessionData.lastRoundXP))
        end
    else
        monitorFrame.text2:SetText("Last: No data")
    end

    -- Calculate remaining battles for this level
    local remainingXP = maxXP - currentXP
    local remainingBattles = 0
    if sessionData.lastRoundXP > 0 then
        remainingBattles = math.ceil(remainingXP / sessionData.lastRoundXP)
    else
        local playerLevelData = PetBattleLevelUpData.levelData[tostring(playerLevel)]
        if playerLevelData and playerLevelData.xpGainPerBattle > 0 then
            remainingBattles = math.ceil(remainingXP / playerLevelData.xpGainPerBattle)
        end
    end

    if remainingBattles > 0 then
        -- Calculate remaining time
        local remainingTime = 0
        local timeText = ""

        if sessionData.averageTime > 0 then
            remainingTime = remainingBattles * sessionData.averageTime

            -- Format time as minutes and seconds if >= 60 seconds
            if remainingTime >= 60 then
                local minutes = math.floor(remainingTime / 60)
                local seconds = math.floor(remainingTime % 60)
                timeText = string.format(" (%dm%ds)", minutes, seconds)
            else
                timeText = string.format(" (%.0fs)", remainingTime)
            end
        end

        monitorFrame.text3:SetText(string.format("%d%% (%d/%d) - %d battles%s left", xpPercent, currentXP, maxXP, remainingBattles, timeText))
    else
        monitorFrame.text3:SetText(xpPercent .. "% (" .. currentXP .. "/" .. maxXP .. ")")
    end

    -- Update progress bar
    monitorFrame.progressBar:SetValue(xpPercent)

    -- Average time and battle info
    if sessionData.averageTime > 0 then
        monitorFrame.text4:SetText(string.format("Avg: %.1fs, Battles: %d", sessionData.averageTime, sessionData.totalBattles))
    else
        monitorFrame.text4:SetText("Battles: " .. sessionData.totalBattles)
    end

    -- Level 80 estimation
    local level80Text = CalculateTimeToLevel80()
    monitorFrame.text5:SetText("To 80: " .. level80Text)
end

-- Force save function already defined above

-- Load default data from savedData.lua (simulated - in WoW we'd include it as a separate addon file)
local function LoadDefaultData()
    -- Default data structure based on savedData.lua
    local defaultData = {
        ["28"] = { totalXpNeeded = 33960, xpGainPerBattle = 2500 },
        ["29"] = { totalXpNeeded = 35985, xpGainPerBattle = 2562 },
        ["30"] = { totalXpNeeded = 38075, xpGainPerBattle = 2687 },
        ["31"] = { totalXpNeeded = 38430, xpGainPerBattle = 2750 },
        ["32"] = { totalXpNeeded = 38725, xpGainPerBattle = 2812 },
        ["33"] = { totalXpNeeded = 38970, xpGainPerBattle = 2937 },
        ["34"] = { totalXpNeeded = 39155, xpGainPerBattle = 3000 },
        ["35"] = { totalXpNeeded = 39280, xpGainPerBattle = 3062 },
        ["36"] = { totalXpNeeded = 39355, xpGainPerBattle = 3187 },
        ["37"] = { totalXpNeeded = 39370, xpGainPerBattle = 3250 },
        ["38"] = { totalXpNeeded = 39325, xpGainPerBattle = 3312 },
        ["39"] = { totalXpNeeded = 39225, xpGainPerBattle = 3437 },
        ["40"] = { totalXpNeeded = 39070, xpGainPerBattle = 3500 },
        ["41"] = { totalXpNeeded = 38860, xpGainPerBattle = 3562 },
        ["42"] = { totalXpNeeded = 38590, xpGainPerBattle = 3687 },
        ["43"] = { totalXpNeeded = 38265, xpGainPerBattle = 3750 },
        ["44"] = { totalXpNeeded = 37880, xpGainPerBattle = 3812 },
        ["45"] = { totalXpNeeded = 37440, xpGainPerBattle = 3937 },
        ["46"] = { totalXpNeeded = 36945, xpGainPerBattle = 4000 },
        ["47"] = { totalXpNeeded = 36395, xpGainPerBattle = 4125 },
        ["48"] = { totalXpNeeded = 35785, xpGainPerBattle = 4187 },
        ["49"] = { totalXpNeeded = 35115, xpGainPerBattle = 4250 },
        ["50"] = { totalXpNeeded = 34395, xpGainPerBattle = 4375 },
        ["51"] = { totalXpNeeded = 36305, xpGainPerBattle = 4437 },
        ["52"] = { totalXpNeeded = 38265, xpGainPerBattle = 4500 },
        ["53"] = { totalXpNeeded = 40275, xpGainPerBattle = 4625 },
        ["54"] = { totalXpNeeded = 42330, xpGainPerBattle = 4687 },
        ["55"] = { totalXpNeeded = 44430, xpGainPerBattle = 4750 },
        ["56"] = { totalXpNeeded = 46580, xpGainPerBattle = 4875 },
        ["57"] = { totalXpNeeded = 48780, xpGainPerBattle = 4937 },
        ["58"] = { totalXpNeeded = 51030, xpGainPerBattle = 5000 },
        ["59"] = { totalXpNeeded = 53320, xpGainPerBattle = 5125 },
        ["60"] = { totalXpNeeded = 55665, xpGainPerBattle = 5187 },
        ["61"] = { totalXpNeeded = 58055, xpGainPerBattle = 5250 },
        ["62"] = { totalXpNeeded = 60490, xpGainPerBattle = 5375 },
        ["63"] = { totalXpNeeded = 62980, xpGainPerBattle = 5437 },
        ["64"] = { totalXpNeeded = 65510, xpGainPerBattle = 5500 },
        ["65"] = { totalXpNeeded = 68095, xpGainPerBattle = 5625 },
        ["66"] = { totalXpNeeded = 70720, xpGainPerBattle = 5687 },
        ["67"] = { totalXpNeeded = 73400, xpGainPerBattle = 5812 },
        ["68"] = { totalXpNeeded = 76125, xpGainPerBattle = 5875 },
        ["69"] = { totalXpNeeded = 78895, xpGainPerBattle = 6500 },
        ["70"] = { totalXpNeeded = 225105, xpGainPerBattle = 6625 },
        ["71"] = { totalXpNeeded = 247375, xpGainPerBattle = 6687 },
        ["72"] = { totalXpNeeded = 270190, xpGainPerBattle = 6812 },
        ["73"] = { totalXpNeeded = 293540, xpGainPerBattle = 6875 },
        ["74"] = { totalXpNeeded = 317430, xpGainPerBattle = 7000 },
        ["75"] = { totalXpNeeded = 341865, xpGainPerBattle = 7062 },
        ["76"] = { totalXpNeeded = 366835, xpGainPerBattle = 7187 },
        ["77"] = { totalXpNeeded = 392350, xpGainPerBattle = 7250 },
        ["78"] = { totalXpNeeded = 418405, xpGainPerBattle = 7375 },
        ["79"] = { totalXpNeeded = 445000, xpGainPerBattle = 7625 }
    }

    if debugMode then
        print("Loaded default data for levels 28-79")
    end

    return defaultData
end

-- Fill missing level data with defaults
local function FillMissingLevelData()
    local defaultData = LoadDefaultData()
    local addedCount = 0

    for level, data in pairs(defaultData) do
        if not PetBattleLevelUpData.levelData[level] then
            PetBattleLevelUpData.levelData[level] = {
                totalXpNeeded = data.totalXpNeeded,
                xpGainPerBattle = data.xpGainPerBattle
            }
            addedCount = addedCount + 1

            if debugMode then
                print("Added default data for level " .. level .. " (XP: " .. data.xpGainPerBattle .. ")")
            end
        end
    end

    if addedCount > 0 then
        print("LOADED: Added " .. addedCount .. " missing levels from default data")
        ForceSaveData()
    elseif debugMode then
        print("No missing level data - all levels already present")
    end

    return addedCount
end

-- Parse array-based level data using XP value sorting
local function ParseLevelDataByXP()
    if not PetBattleLevelUpData.levelData then
        return {}
    end

    local arrayData = {}
    local hasArrayData = false

    -- Collect array-based data entries
    for i = 1, 80 do
        if PetBattleLevelUpData.levelData[i] and type(PetBattleLevelUpData.levelData[i]) == "table" then
            local entry = PetBattleLevelUpData.levelData[i]
            if entry.xpGainPerBattle and entry.totalXpNeeded then
                table.insert(arrayData, {
                    index = i,
                    xpGainPerBattle = entry.xpGainPerBattle,
                    totalXpNeeded = entry.totalXpNeeded
                })
                hasArrayData = true
            end
        end
    end

    if not hasArrayData or #arrayData == 0 then
        return {}
    end

    -- Sort by xpGainPerBattle in ascending order
    table.sort(arrayData, function(a, b)
        return a.xpGainPerBattle < b.xpGainPerBattle
    end)

    -- Map to correct levels: highest XP = current level, descending from there
    local currentLevel = UnitLevel("player")
    local fixedData = {}

    -- Start from the highest XP entry and work backwards
    for i = #arrayData, 1, -1 do
        local entry = arrayData[i]
        local assignedLevel = currentLevel - (#arrayData - i)

        if assignedLevel > 0 and assignedLevel <= 80 then
            fixedData[tostring(assignedLevel)] = {
                totalXpNeeded = entry.totalXpNeeded,
                xpGainPerBattle = entry.xpGainPerBattle
            }

            if debugMode then
                print("Mapped: Index " .. entry.index .. " (XP:" .. entry.xpGainPerBattle .. ") -> Level " .. assignedLevel)
            end
        end
    end

    print("PARSED: Recovered " .. #arrayData .. " levels using XP-based mapping")
    print("Mapped to levels " .. (currentLevel - #arrayData + 1) .. " through " .. currentLevel)

    return fixedData
end

-- Fix corrupted level data with intelligent parsing
local function FixLevelData()
    if not PetBattleLevelUpData.levelData then
        PetBattleLevelUpData.levelData = {}
    end

    -- Check if we have proper key-value data already
    local hasProperKeys = false
    local hasArrayData = false

    for key, value in pairs(PetBattleLevelUpData.levelData) do
        if type(key) == "string" and tonumber(key) and type(value) == "table" then
            hasProperKeys = true
            break
        elseif type(key) == "number" and type(value) == "table" then
            hasArrayData = true
        end
    end

    -- If we already have proper string keys, no need to fix
    if hasProperKeys and not hasArrayData then
        if debugMode then
            print("Level data structure is already correct")
        end
        return
    end

    -- Parse array data using XP-based intelligent mapping
    local fixedData = ParseLevelDataByXP()

    if next(fixedData) then
        PetBattleLevelUpData.levelData = fixedData
        ForceSaveData()

        -- Save to tempdata for backup
        if debugMode then
            print("Level data structure fixed and saved")
        end
    else
        if debugMode then
            print("No array data found to parse")
        end
    end
end

-- Record level data
local function RecordLevelData(level, xpGained)
    if level <= 0 or xpGained <= 0 then
        return
    end

    -- Ensure levelData table exists
    if not PetBattleLevelUpData.levelData then
        PetBattleLevelUpData.levelData = {}
    end

    -- Store data using level number as key (not array index)
    PetBattleLevelUpData.levelData[tostring(level)] = {
        xpGainPerBattle = xpGained,
        totalXpNeeded = UnitXPMax("player")
    }

    -- Multiple save attempts to ensure data persistence
    PetBattleLevelUpData._lastRecorded = GetTime()
    PetBattleLevelUpData._recordCount = (PetBattleLevelUpData._recordCount or 0) + 1
    sessionData.needsSave = true
    ForceSaveData()

    -- Data recorded - show messages based on debug mode
    if debugMode then
        print("RECORDED: Level " .. level .. " gains " .. xpGained .. " XP per battle")
        print("Data will save automatically on logout, zone change, or /reload")
        print("Level data marked for save - Record count: " .. PetBattleLevelUpData._recordCount)
    end
end

-- Pet battle start
local function OnPetBattleStart()
    local playerLevel = UnitLevel("player")
    if playerLevel >= 80 then
        return
    end

    inPetBattle = true
    sessionData.battleStartXP = UnitXP("player")
    sessionData.battleStartTime = GetTime()

    -- Calculate time between battles for average and last battle duration
    if sessionData.previousBattleStartTime > 0 then
        local timeBetweenBattles = sessionData.battleStartTime - sessionData.previousBattleStartTime
        sessionData.lastBattleDuration = timeBetweenBattles  -- Store individual battle duration
        sessionData.totalBattleTime = sessionData.totalBattleTime + timeBetweenBattles
        sessionData.averageTime = sessionData.totalBattleTime / sessionData.totalBattles

        if debugMode then
            print(string.format("Time between battles: %.1fs, Average: %.1fs", timeBetweenBattles, sessionData.averageTime))
        end
    end

    if sessionData.currentLevel == 0 then
        sessionData.currentLevel = playerLevel
    end

    -- Create frame only if it doesn't exist, then show it
    CreateProgressFrame()
    if monitorFrame then
        monitorFrame:Show()
        UpdateDisplay()
    end

    if debugMode then
        print("Pet Battle started - showing monitor")
    end
end

-- Pet battle end
local function OnPetBattleEnd()
    if not inPetBattle then
        return
    end

    local currentXP = UnitXP("player")
    local currentLevel = UnitLevel("player")
    local leveledUp = currentLevel > sessionData.currentLevel

    -- Calculate XP gained
    local xpGained = 0
    if sessionData.lastBattleEndXP > 0 then
        xpGained = currentXP - sessionData.lastBattleEndXP
    else
        xpGained = currentXP - sessionData.battleStartXP
    end

    -- Handle level up
    if leveledUp then
        sessionData.currentLevel = currentLevel
        if debugMode then
            print("Level up detected - skipping data recording")
        end
    end

    -- Record data if appropriate
    if xpGained > 0 and not sessionData.isFirstBattle and not leveledUp then
        if debugMode then
            print("Recording data: Level " .. sessionData.currentLevel .. ", XP: " .. xpGained)
        end
        RecordLevelData(sessionData.currentLevel, xpGained)
    elseif sessionData.isFirstBattle then
        if debugMode then
            print("First battle - skipping data recording")
        end
        sessionData.isFirstBattle = false
    elseif leveledUp then
        if debugMode then
            print("Level up battle - skipping data recording")
        end
    elseif xpGained <= 0 then
        if debugMode then
            print("No XP gained - skipping data recording")
        end
    end

    -- Update session data BEFORE updating display
    sessionData.lastRoundXP = xpGained
    sessionData.lastBattleEndXP = currentXP
    sessionData.totalBattles = sessionData.totalBattles + 1
    sessionData.previousBattleStartTime = sessionData.battleStartTime
    if xpGained > 0 then
        sessionData.lastXPTime = GetTime()  -- Record when XP was gained
    end

    -- Auto-save after every battle to ensure data persistence
    ForceSaveData()

    -- Update display after updating session data
    UpdateDisplay()

    inPetBattle = false
    if monitorFrame then
        monitorFrame:Hide()
    end

    if debugMode then
        print("Battle ended: " .. xpGained .. " XP gained")
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "PetBattleLevelUpMonitor" then
            if debugMode then
                print("Pet Battle Level Up Monitor: ADDON_LOADED event received!")
            end

            -- Fix any corrupted level data on load
            FixLevelData()

            -- Fill missing level data with defaults from savedData.lua
            FillMissingLevelData()

            -- Load existing data if available
            if PetBattleLevelUpData and PetBattleLevelUpData.levelData then
                local count = 0
                for _ in pairs(PetBattleLevelUpData.levelData) do
                    count = count + 1
                end
                if count > 0 and debugMode then
                    print("Pet Battle Level Up Monitor: Loaded " .. count .. " saved levels")
                end
            end
        end
    elseif event == "PET_BATTLE_OPENING_START" then
        OnPetBattleStart()
    elseif event == "PET_BATTLE_CLOSE" or event == "PET_BATTLE_OVER" then
        OnPetBattleEnd()
    elseif event == "PLAYER_LOGOUT" then
        if debugMode then
            print("Pet Battle Level Up Monitor: Saving data on logout...")
        end
        ForceSaveData()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Auto-save on entering world to ensure data persistence
        ForceSaveData()
        if debugMode then
            print("Pet Battle Level Up Monitor: Player entering world - data saved")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Auto-save when leaving combat (additional safety)
        ForceSaveData()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        -- Auto-save on zone changes (triggers SavedVariables write)
        ForceSaveData()
        if debugMode then
            print("Pet Battle Level Up Monitor: Zone changed - data saved")
        end
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PET_BATTLE_OPENING_START")
frame:RegisterEvent("PET_BATTLE_CLOSE")
frame:RegisterEvent("PET_BATTLE_OVER")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Additional save trigger
frame:RegisterEvent("ZONE_CHANGED")  -- Save on zone change
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")  -- Save on area change
frame:SetScript("OnEvent", OnEvent)

-- Register slash commands IMMEDIATELY
if debugMode then
    print("Pet Battle Level Up Monitor: Registering slash commands...")
end

SLASH_PETBATTLEMON1 = "/pblm"
SLASH_PETBATTLEMON2 = "/petbattle"
SlashCmdList["PETBATTLEMON"] = function(msg)
    msg = msg or ""

    if msg == "" then
        print("Pet Battle Level Monitor Commands:")
        print("/pblm test - Test addon")
        print("/pblm show - Show frame")
        print("/pblm hide - Hide frame")
        print("/pblm data - Show recorded data")
        print("/pblm save - Force save data")
        print("/pblm reload - Reload UI (saves data)")
        print("/pblm size [number] - Set font size (0.5-4.0)")
        print("/pblm big - Set to 3.0x size")
        print("/pblm huge - Set to 4.0x size")
        print("/pblm debug - Toggle debug mode")
        print("/pblm forcesave - Force save data immediately (reloads UI)")
        print("/pblm fixdata - Fix corrupted level data structure")
        print("/pblm parsedata - Parse array data using XP-based intelligent mapping")
        print("/pblm exportdata - Export current data structure for backup")
        print("/pblm loaddefaults - Load missing levels from default data")
        print("/pblm validatedata - Validate data format consistency")
        print("/pblm fonttest - Test font display for Chinese/localized characters")
    elseif msg == "test" then
        print("Pet Battle Level Up Monitor is working!")
        print("Player: " .. UnitName("player") .. " Level: " .. UnitLevel("player"))
        print("XP: " .. UnitXP("player") .. "/" .. UnitXPMax("player"))
    elseif msg == "show" then
        CreateProgressFrame()
        if monitorFrame then
            monitorFrame:Show()
            UpdateDisplay()
            if debugMode then
                print("Monitor frame shown")
            end
        end
    elseif msg == "hide" then
        if monitorFrame then
            monitorFrame:Hide()
            if debugMode then
                print("Monitor frame hidden")
            end
        end
    elseif msg == "debug" then
        debugMode = not debugMode
        print("Debug mode: " .. (debugMode and "ON" or "OFF"))
    elseif msg == "data" then
        print("=== Recorded Level Data ===")
        local count = 0
        local levels = {}

        -- Collect and sort level numbers for better display
        for level, data in pairs(PetBattleLevelUpData.levelData) do
            if type(data) == "table" and data.xpGainPerBattle then
                table.insert(levels, tonumber(level))
                count = count + 1
            end
        end

        table.sort(levels)

        for _, level in ipairs(levels) do
            local data = PetBattleLevelUpData.levelData[tostring(level)]
            print("Level " .. level .. ": " .. data.xpGainPerBattle .. " XP per battle (Total XP: " .. data.totalXpNeeded .. ")")
        end

        if count == 0 then
            print("No data recorded yet")
        else
            print("Total levels recorded: " .. count)
        end
        print("=== Save Status ===")
        if PetBattleLevelUpData._lastSave then
            print("Last save marked at: " .. date("%H:%M:%S", PetBattleLevelUpData._lastSave))
        end
        if PetBattleLevelUpData._recordCount then
            print("Record count: " .. PetBattleLevelUpData._recordCount)
        end
        if PetBattleLevelUpData._saveCounter then
            print("Save counter: " .. PetBattleLevelUpData._saveCounter)
        end
        if sessionData.needsSave then
            print("WARNING: Data needs saving! Will save on logout, zone change, or /reload")
        else
            print("Data is saved")
        end
    elseif msg == "save" then
        ForceSaveData()
        sessionData.needsSave = false
        print("Data marked for saving - will persist on logout, zone change, or /reload")
    elseif msg == "reload" then
        print("Reloading UI to save data...")
        ReloadUI()
    elseif string.sub(msg, 1, 4) == "size" then
        local sizeStr = string.match(msg, "size%s+(.+)")
        if sizeStr then
            local newSize = tonumber(sizeStr)
            if newSize and newSize >= 0.5 and newSize <= 4.0 then
                PetBattleLevelUpData.fontSize = newSize
                print("Font size set to " .. newSize .. "x - recreating frame...")

                -- Recreate the frame with new size (font size changes require recreation)
                if monitorFrame then
                    local wasShown = monitorFrame:IsShown()
                    monitorFrame:Hide()
                    monitorFrame = nil  -- Force recreation for font size changes
                    CreateProgressFrame()
                    if wasShown and monitorFrame then
                        monitorFrame:Show()
                        UpdateDisplay()
                    end
                end
                ForceSaveData()
            else
                print("Font size must be between 0.5 and 4.0")
            end
        else
            local currentSize = PetBattleLevelUpData.fontSize or 2.0
            print("Current font size: " .. currentSize .. "x (range: 0.5 to 4.0)")
            print("Usage: /pblm size <number> (e.g., /pblm size 3.0)")
        end
    elseif msg == "big" then
        PetBattleLevelUpData.fontSize = 3.0
        print("Setting font size to 3.0x (extra large)")
        if monitorFrame then
            local wasShown = monitorFrame:IsShown()
            monitorFrame:Hide()
            monitorFrame = nil  -- Force recreation for font size changes
            CreateProgressFrame()
            if wasShown and monitorFrame then
                monitorFrame:Show()
                UpdateDisplay()
            end
        end
        ForceSaveData()
    elseif msg == "huge" then
        PetBattleLevelUpData.fontSize = 4.0
        print("Setting font size to 4.0x (huge)")
        if monitorFrame then
            local wasShown = monitorFrame:IsShown()
            monitorFrame:Hide()
            monitorFrame = nil  -- Force recreation for font size changes
            CreateProgressFrame()
            if wasShown and monitorFrame then
                monitorFrame:Show()
                UpdateDisplay()
            end
        end
        ForceSaveData()
    elseif msg == "forcesave" then
        print("Force saving data...")
        ForceSaveData()
        sessionData.needsSave = false
        print("Data marked for saving - use /reload to save immediately")
    elseif msg == "fixdata" then
        print("Attempting to fix level data structure...")
        FixLevelData()
        print("Level data fix completed - use /pblm data to verify")
    elseif msg == "parsedata" then
        print("Parsing array data using XP-based intelligent mapping...")
        local currentLevel = UnitLevel("player")
        print("Current player level: " .. currentLevel)

        local fixedData = ParseLevelDataByXP()
        if next(fixedData) then
            PetBattleLevelUpData.levelData = fixedData
            ForceSaveData()
            print("Data parsed and applied successfully!")
            print("Use /pblm data to see the corrected level mapping")
        else
            print("No array data found to parse")
        end
    elseif msg == "exportdata" then
        print("=== Current Data Structure Export ===")
        print("-- Copy this to tempdata.lua for backup --")
        print("PetBattleLevelUpData = {")
        print('    levelData = {')

        local hasData = false
        for key, value in pairs(PetBattleLevelUpData.levelData) do
            if type(value) == "table" and value.xpGainPerBattle and value.totalXpNeeded then
                print('        ["' .. tostring(key) .. '"] = {')
                print('            totalXpNeeded = ' .. value.totalXpNeeded .. ',')
                print('            xpGainPerBattle = ' .. value.xpGainPerBattle)
                print('        },')
                hasData = true
            end
        end

        if not hasData then
            print('        -- No valid data found')
        end

        print('    },')
        print('    fontSize = ' .. (PetBattleLevelUpData.fontSize or 2.0) .. ',')
        print('    framePosition = { x = ' .. (PetBattleLevelUpData.framePosition and PetBattleLevelUpData.framePosition.x or 0) .. ', y = ' .. (PetBattleLevelUpData.framePosition and PetBattleLevelUpData.framePosition.y or 200) .. ' }')
        print('}')
        print("=== End Export ===")
    elseif msg == "loaddefaults" then
        print("Loading missing level data from defaults...")
        local addedCount = FillMissingLevelData()
        if addedCount > 0 then
            print("Successfully added " .. addedCount .. " missing levels")
        else
            print("No missing levels found - all data present")
        end
    elseif msg == "validatedata" then
        print("=== Data Format Validation ===")
        local validCount = 0
        local invalidCount = 0
        local issues = {}

        for level, data in pairs(PetBattleLevelUpData.levelData) do
            if type(level) ~= "string" then
                table.insert(issues, "Level key " .. tostring(level) .. " is not a string")
                invalidCount = invalidCount + 1
            elseif not tonumber(level) then
                table.insert(issues, "Level key '" .. level .. "' is not a valid number string")
                invalidCount = invalidCount + 1
            elseif type(data) ~= "table" then
                table.insert(issues, "Level " .. level .. " data is not a table")
                invalidCount = invalidCount + 1
            elseif not data.totalXpNeeded or not data.xpGainPerBattle then
                table.insert(issues, "Level " .. level .. " missing required fields")
                invalidCount = invalidCount + 1
            else
                validCount = validCount + 1
            end
        end

        print("Valid entries: " .. validCount)
        print("Invalid entries: " .. invalidCount)

        if #issues > 0 then
            print("Issues found:")
            for _, issue in ipairs(issues) do
                print("  - " .. issue)
            end
        else
            print("✅ All data entries are properly formatted!")
        end

        -- Check data format matches savedData.lua style
        print("Data format: " .. (invalidCount == 0 and "✅ Compatible with savedData.lua" or "❌ Needs fixing"))
    elseif msg == "fonttest" then
        print("=== Font Display Test ===")
        local locale = GetLocale()
        print("Current locale: " .. locale)
        print("Player name: " .. UnitName("player"))

        -- Force recreate frame with GameFont (supports all locales)
        if monitorFrame then
            monitorFrame:Hide()
            monitorFrame = nil
        end
        CreateProgressFrame()
        monitorFrame:Show()
        print("Frame recreated with GameFont (supports Chinese characters)")
        print("Check if your character name displays correctly now")
    else
        print("Unknown command: " .. msg)
        print("Available commands: test, show, hide, data, save, reload, size, big, huge, debug, forcesave, fixdata, parsedata, exportdata, loaddefaults, validatedata, fonttest")
    end
end

-- Simple startup message
print("Pet Battle Level Up Monitor loaded. Type /pblm for commands.")

if debugMode then
    print("Pet Battle Level Up Monitor: Slash commands registered!")
    print("Pet Battle Level Up Monitor: Addon loaded successfully!")
    print("Debug mode enabled")
end