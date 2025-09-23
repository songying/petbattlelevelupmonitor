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

    -- Create fonts with manual scaling
    local font1 = CreateFont("PetBattleFont1")
    local font2 = CreateFont("PetBattleFont2")
    local font3 = CreateFont("PetBattleFont3")
    local font4 = CreateFont("PetBattleFont4")
    local font5 = CreateFont("PetBattleFont5")

    -- Set font properties with scaling - increased base size to 16px
    local baseFontSize = 16 * fontSize
    font1:SetFont("Fonts\\FRIZQT__.TTF", baseFontSize, "OUTLINE")
    font2:SetFont("Fonts\\FRIZQT__.TTF", baseFontSize, "OUTLINE")
    font3:SetFont("Fonts\\FRIZQT__.TTF", baseFontSize, "OUTLINE")
    font4:SetFont("Fonts\\FRIZQT__.TTF", baseFontSize, "OUTLINE")
    font5:SetFont("Fonts\\FRIZQT__.TTF", baseFontSize, "OUTLINE")

    -- Text displays with scaled fonts and positioning
    monitorFrame.text1 = monitorFrame:CreateFontString(nil, "OVERLAY")
    monitorFrame.text1:SetFontObject(font1)
    monitorFrame.text1:SetPoint("TOPLEFT", margin, -margin)
    monitorFrame.text1:SetTextColor(1, 1, 1, 1)

    monitorFrame.text2 = monitorFrame:CreateFontString(nil, "OVERLAY")
    monitorFrame.text2:SetFontObject(font2)
    monitorFrame.text2:SetPoint("TOPLEFT", monitorFrame.text1, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text2:SetTextColor(1, 1, 0, 1)

    monitorFrame.text3 = monitorFrame:CreateFontString(nil, "OVERLAY")
    monitorFrame.text3:SetFontObject(font3)
    monitorFrame.text3:SetPoint("TOPLEFT", monitorFrame.text2, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text3:SetTextColor(0, 1, 0, 1)

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

    monitorFrame.text4 = monitorFrame:CreateFontString(nil, "OVERLAY")
    monitorFrame.text4:SetFontObject(font4)
    monitorFrame.text4:SetPoint("TOPLEFT", monitorFrame.progressBar, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text4:SetTextColor(0.8, 0.8, 1, 1)

    monitorFrame.text5 = monitorFrame:CreateFontString(nil, "OVERLAY")
    monitorFrame.text5:SetFontObject(font5)
    monitorFrame.text5:SetPoint("TOPLEFT", monitorFrame.text4, "BOTTOMLEFT", 0, spacing)
    monitorFrame.text5:SetTextColor(1, 0.8, 0.4, 1)

    monitorFrame:Hide()
    if debugMode then
        print("Pet Battle Level Up Monitor: Frame created - Size: " .. scaledWidth .. "x" .. scaledHeight .. ", Font size: " .. baseFontSize)
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
    if PetBattleLevelUpData.levelData[currentLevel] and PetBattleLevelUpData.levelData[currentLevel].xpGainPerBattle > 0 then
        local battlesThisLevel = math.ceil(remainingXPThisLevel / PetBattleLevelUpData.levelData[currentLevel].xpGainPerBattle)
        totalBattlesNeeded = totalBattlesNeeded + battlesThisLevel
    end

    -- Calculate battles needed for remaining levels
    for level = currentLevel + 1, 79 do
        if PetBattleLevelUpData.levelData[level] and PetBattleLevelUpData.levelData[level].xpGainPerBattle > 0 then
            local battlesForLevel = math.ceil(PetBattleLevelUpData.levelData[level].totalXpNeeded / PetBattleLevelUpData.levelData[level].xpGainPerBattle)
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
    elseif PetBattleLevelUpData.levelData[playerLevel] and PetBattleLevelUpData.levelData[playerLevel].xpGainPerBattle > 0 then
        remainingBattles = math.ceil(remainingXP / PetBattleLevelUpData.levelData[playerLevel].xpGainPerBattle)
    end

    if remainingBattles > 0 then
        -- Calculate remaining time
        local remainingTime = 0
        local timeText = ""

        if sessionData.averageTime > 0 then
            remainingTime = remainingBattles * sessionData.averageTime
            timeText = string.format(" (%.0fs)", remainingTime)
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

-- Record level data
local function RecordLevelData(level, xpGained)
    if level <= 0 or xpGained <= 0 then
        return
    end

    -- Ensure levelData table exists
    if not PetBattleLevelUpData.levelData then
        PetBattleLevelUpData.levelData = {}
    end

    PetBattleLevelUpData.levelData[level] = {
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
        for level, data in pairs(PetBattleLevelUpData.levelData) do
            print("Level " .. level .. ": " .. data.xpGainPerBattle .. " XP per battle (Total XP: " .. data.totalXpNeeded .. ")")
            count = count + 1
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
    else
        print("Unknown command: " .. msg)
        print("Available commands: test, show, hide, data, save, reload, size, big, huge, debug, forcesave")
    end
end

-- Simple startup message
print("Pet Battle Level Up Monitor loaded. Type /pblm for commands.")

if debugMode then
    print("Pet Battle Level Up Monitor: Slash commands registered!")
    print("Pet Battle Level Up Monitor: Addon loaded successfully!")
    print("Debug mode enabled")
end