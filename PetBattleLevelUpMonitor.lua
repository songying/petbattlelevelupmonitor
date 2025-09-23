-- Pet Battle Level Up Monitor Addon
-- Tracks experience gain and level-up progress during pet battles

local addonName = "PetBattleLevelUpMonitor"
local frame = CreateFrame("Frame", addonName .. "Frame", UIParent)

-- Addon variables
local monitorFrame = nil
local sessionData = {
    lastXP = 0,
    lastTime = 0,
    lastRoundXP = 0,
    lastRoundTime = 0,
    battleStartXP = 0,
    battleStartTime = 0,
    totalBattles = 0,
    currentRoundStartXP = 0,     -- Track XP at start of current round
    currentRoundStartTime = 0,   -- Track time at start of current round
    firstRoundStartXP = 0,       -- Track XP at start of first round (doesn't change during battle)
    previousRoundEndXP = 0,      -- Track XP at end of previous round
    previousRoundStartTime = 0,  -- Track time at start of previous round
    lastBattleEndXP = 0,         -- Track XP at end of last battle (for next battle calculation)
    previousBattleStartTime = 0, -- Track start time of previous battle
    totalBattleTime = 0,         -- Track total time spent in battles for average calculation
    averageTime = 0              -- Average time per battle
}
local inPetBattle = false
local debugMode = false

-- Initialize the addon
local function Initialize()
    -- Create the monitor UI frame
    CreateMonitorFrame()

    -- Register events
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PET_BATTLE_OPENING_START")
    frame:RegisterEvent("PET_BATTLE_CLOSE")
    frame:RegisterEvent("PET_BATTLE_FINAL_ROUND")
    frame:RegisterEvent("PET_BATTLE_OVER")
    frame:RegisterEvent("PET_BATTLE_ACTION_SELECTED")
    frame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE")
    frame:RegisterEvent("PLAYER_XP_UPDATE")
    frame:RegisterEvent("PLAYER_LEVEL_UP")

    frame:SetScript("OnEvent", OnEvent)
end

-- Create the monitoring frame UI
function CreateMonitorFrame()
    monitorFrame = CreateFrame("Frame", addonName .. "MonitorFrame", UIParent, "BackdropTemplate")
    monitorFrame:SetSize(400, 100)
    monitorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

    -- Make frame draggable
    monitorFrame:SetMovable(true)
    monitorFrame:EnableMouse(true)
    monitorFrame:RegisterForDrag("LeftButton")
    monitorFrame:SetScript("OnDragStart", monitorFrame.StartMoving)
    monitorFrame:SetScript("OnDragStop", monitorFrame.StopMovingOrSizing)

    -- Set transparent background
    monitorFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    monitorFrame:SetBackdropColor(0, 0, 0, 0) -- Fully transparent

    -- Character name and level (line 1)
    monitorFrame.nameLevel = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.nameLevel:SetPoint("TOPLEFT", monitorFrame, "TOPLEFT", 10, -10)
    monitorFrame.nameLevel:SetTextColor(1, 1, 1, 1)

    -- Last round info (line 2)
    monitorFrame.lastRound = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.lastRound:SetPoint("TOPLEFT", monitorFrame.nameLevel, "BOTTOMLEFT", 0, -5)
    monitorFrame.lastRound:SetTextColor(1, 1, 0, 1)

    -- Average time info (line 3)
    monitorFrame.averageTime = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.averageTime:SetPoint("TOPLEFT", monitorFrame.lastRound, "BOTTOMLEFT", 0, -5)
    monitorFrame.averageTime:SetTextColor(0, 1, 1, 1)

    -- Progress info (line 4)
    monitorFrame.progress = monitorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monitorFrame.progress:SetPoint("TOPLEFT", monitorFrame.averageTime, "BOTTOMLEFT", 0, -5)
    monitorFrame.progress:SetTextColor(0, 1, 0, 1)

    -- Initially hide the frame
    monitorFrame:Hide()
end

-- Event handler
function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            print("Pet Battle Level Up Monitor loaded successfully!")
        end
    elseif event == "PET_BATTLE_OPENING_START" then
        OnPetBattleStart()
    elseif event == "PET_BATTLE_ACTION_SELECTED" then
        OnRoundStart()
    elseif event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" then
        OnRoundEnd()
    elseif event == "PET_BATTLE_CLOSE" or event == "PET_BATTLE_FINAL_ROUND" or event == "PET_BATTLE_OVER" then
        OnPetBattleEnd()
    elseif event == "PLAYER_XP_UPDATE" then
        if inPetBattle then
            OnXPUpdate()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        if inPetBattle then
            OnLevelUp()
        end
    end
end

-- Handle pet battle start
function OnPetBattleStart()
    local playerLevel = UnitLevel("player")

    -- Only show for characters under level 80
    if playerLevel < 80 then
        inPetBattle = true

        -- Store battle start data
        sessionData.battleStartXP = UnitXP("player")
        sessionData.battleStartTime = GetTime()
        sessionData.currentRoundStartXP = UnitXP("player")
        -- Don't reset previousRoundEndXP here - it should carry from previous battle

        if debugMode then
            print("Battle started: battleStartTime = " .. sessionData.battleStartTime .. ", previousBattleStartTime = " .. sessionData.previousBattleStartTime)
        end

        -- Show the monitor frame
        monitorFrame:Show()
        UpdateDisplay()
    end
end

-- Handle round start (action selected)
function OnRoundStart()
    if inPetBattle then
        sessionData.currentRoundStartXP = UnitXP("player")
        sessionData.currentRoundStartTime = GetTime()
        if debugMode then
            print("Action selected: XP = " .. sessionData.currentRoundStartXP .. ", Time = " .. sessionData.currentRoundStartTime)
        end
    end
end

-- Handle round end (playback complete)
function OnRoundEnd()
    if inPetBattle then
        local currentXP = UnitXP("player")

        -- Calculate XP gained this round: current XP - previous round end XP
        local xpGainedThisRound = 0
        if sessionData.previousRoundEndXP > 0 then
            xpGainedThisRound = currentXP - sessionData.previousRoundEndXP

            -- Check if player leveled up (XP gained is negative)
            if xpGainedThisRound < 0 then
                -- Player leveled up: calculate XP from previous round end to max, plus current XP
                local previousMaxXP = UnitXPMax("player") -- This should be the same since we just leveled
                local xpToLevel = previousMaxXP - sessionData.previousRoundEndXP
                xpGainedThisRound = xpToLevel + currentXP
                if debugMode then
                    print("Level up detected! XP to level: " .. xpToLevel .. ", Current XP: " .. currentXP .. ", Total gained: " .. xpGainedThisRound)
                end
            end
        else
            -- First round of first battle, use battle start XP
            xpGainedThisRound = currentXP - sessionData.battleStartXP

            -- Check for level up in first round
            if xpGainedThisRound < 0 then
                local previousMaxXP = UnitXPMax("player")
                local xpToLevel = previousMaxXP - sessionData.battleStartXP
                xpGainedThisRound = xpToLevel + currentXP
                if debugMode then
                    print("Level up detected in first round! XP to level: " .. xpToLevel .. ", Current XP: " .. currentXP .. ", Total gained: " .. xpGainedThisRound)
                end
            end
        end

        -- Calculate round duration: current round start time - previous round start time
        local roundDuration = 0
        if sessionData.previousRoundStartTime > 0 then
            roundDuration = sessionData.currentRoundStartTime - sessionData.previousRoundStartTime
        else
            -- First round, use battle start time to current round start time
            roundDuration = sessionData.currentRoundStartTime - sessionData.battleStartTime
        end

        if debugMode then
            print("Round playback complete: XP gained this round = " .. xpGainedThisRound .. ", Round duration = " .. string.format("%.1f", roundDuration) .. "s")
        end

        -- Update if we gained XP this round (but don't update time during battle)
        if xpGainedThisRound > 0 then
            sessionData.lastRoundXP = xpGainedThisRound
            -- Don't update lastRoundTime here - it should only be set at battle end
            UpdateDisplay()
        end

        -- Store current values as previous for next round
        sessionData.previousRoundEndXP = currentXP
        sessionData.previousRoundStartTime = sessionData.currentRoundStartTime
    end
end

-- Handle pet battle end
function OnPetBattleEnd()
    if inPetBattle then
        local currentXP = UnitXP("player")
        local currentTime = GetTime()

        -- Calculate XP gained: Current XP - Last Battle End XP
        local xpGained = 0
        if sessionData.lastBattleEndXP > 0 then
            xpGained = currentXP - sessionData.lastBattleEndXP

            -- Check for level up
            if xpGained < 0 then
                local previousMaxXP = UnitXPMax("player")
                local xpToLevel = previousMaxXP - sessionData.lastBattleEndXP
                xpGained = xpToLevel + currentXP
                if debugMode then
                    print("Level up detected between battles! Total XP gained: " .. xpGained)
                end
            end
        else
            -- First battle, use battle start XP as reference
            xpGained = currentXP - sessionData.battleStartXP

            -- Check for level up in first battle
            if xpGained < 0 then
                local previousMaxXP = UnitXPMax("player")
                local xpToLevel = previousMaxXP - sessionData.battleStartXP
                xpGained = xpToLevel + currentXP
                if debugMode then
                    print("Level up detected in first battle! Total XP gained: " .. xpGained)
                end
            end
        end

        -- Calculate time between battles (battle start to battle start)
        local timeBetweenBattles = 0
        if sessionData.previousBattleStartTime > 0 then
            timeBetweenBattles = sessionData.battleStartTime - sessionData.previousBattleStartTime
            if debugMode then
                print("Time calculation: current start = " .. sessionData.battleStartTime .. ", previous start = " .. sessionData.previousBattleStartTime .. ", difference = " .. timeBetweenBattles)
            end
        else
            -- First battle, show battle duration instead of 0
            timeBetweenBattles = currentTime - sessionData.battleStartTime
            if debugMode then
                print("First battle: battle duration = " .. timeBetweenBattles)
            end
        end

        -- Update session data if we found XP gain (always update for time tracking)
        if xpGained > 0 or timeBetweenBattles > 0 then
            sessionData.lastRoundXP = xpGained
            sessionData.lastRoundTime = timeBetweenBattles
            sessionData.totalBattles = sessionData.totalBattles + 1

            -- Update average time calculation
            if timeBetweenBattles > 0 then
                sessionData.totalBattleTime = sessionData.totalBattleTime + timeBetweenBattles
                sessionData.averageTime = sessionData.totalBattleTime / sessionData.totalBattles
            end
        end

        -- Update display with new time before hiding
        UpdateDisplay()

        -- Store current values for next battle calculation (do this AFTER using them)
        sessionData.lastBattleEndXP = currentXP
        sessionData.previousBattleStartTime = sessionData.battleStartTime

        inPetBattle = false
        monitorFrame:Hide()

        -- Debug print to help troubleshoot
        if debugMode then
            print("Battle ended: XP gained = " .. xpGained .. ", Time between battles = " .. string.format("%.1f", timeBetweenBattles) .. "s")
            print("Stored values: lastRoundXP = " .. sessionData.lastRoundXP .. ", lastRoundTime = " .. string.format("%.1f", sessionData.lastRoundTime) .. "s")
        end
    end
end

-- Handle XP updates during battle
function OnXPUpdate()
    UpdateDisplay()
end

-- Handle level up
function OnLevelUp()
    -- Reset some tracking since level changed, but keep last round data
    UpdateDisplay()
end

-- Update the display
function UpdateDisplay()
    if not monitorFrame or not monitorFrame:IsShown() then
        return
    end

    local playerName = UnitName("player")
    local playerLevel = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")

    -- Line 1: Character name and level
    monitorFrame.nameLevel:SetText(playerName .. " - Level " .. playerLevel)

    -- Line 2: Last round info
    if sessionData.lastRoundXP > 0 then
        local timeText = FormatTime(sessionData.lastRoundTime)
        monitorFrame.lastRound:SetText("Last round: [" .. sessionData.lastRoundXP .. "XP/" .. timeText .. "]")
    else
        monitorFrame.lastRound:SetText("Last round: [No data]")
    end

    -- Line 3: Average time info
    if sessionData.averageTime > 0 then
        local avgTimeText = FormatTime(sessionData.averageTime)
        monitorFrame.averageTime:SetText("Average time: [" .. avgTimeText .. "]")
    else
        monitorFrame.averageTime:SetText("Average time: [No data]")
    end

    -- Line 4: Progress and estimated time
    local xpPercent = math.floor((currentXP / maxXP) * 100)
    local remainingXP = maxXP - currentXP

    local estimatedTime = "Unknown"
    if sessionData.lastRoundXP > 0 and sessionData.averageTime > 0 then
        local xpPerSecond = sessionData.lastRoundXP / sessionData.averageTime
        local secondsRemaining = remainingXP / xpPerSecond
        estimatedTime = FormatTime(secondsRemaining)
    end

    monitorFrame.progress:SetText(xpPercent .. "%, " .. estimatedTime .. " Remain")

    -- Adjust frame height based on content
    local height = 80 -- Base height for 4 lines + padding
    monitorFrame:SetHeight(height)
end

-- Format time in seconds to "XmYs" format
function FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "0s"
    end

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)

    if minutes > 0 then
        return minutes .. "m" .. remainingSeconds .. "s"
    else
        return remainingSeconds .. "s"
    end
end

-- Slash command for debugging
SLASH_PBLEVELMON1 = "/pblm"
SLASH_PBLEVELMON2 = "/petbattlelevelmon"
SlashCmdList["PBLEVELMON"] = function(msg)
    if msg == "debug" then
        debugMode = not debugMode
        print("Debug mode " .. (debugMode and "enabled" or "disabled"))
    elseif msg == "info" then
        print("=== Pet Battle Level Monitor Debug ===")
        print("Total battles: " .. sessionData.totalBattles)
        print("Last round XP: " .. sessionData.lastRoundXP)
        print("Last round time: " .. string.format("%.1f", sessionData.lastRoundTime) .. "s")
        print("Average time: " .. string.format("%.1f", sessionData.averageTime) .. "s")
        print("Total battle time: " .. string.format("%.1f", sessionData.totalBattleTime) .. "s")
        print("In pet battle: " .. tostring(inPetBattle))
        print("Current XP: " .. UnitXP("player") .. "/" .. UnitXPMax("player"))
        print("Battle start XP: " .. sessionData.battleStartXP)
        print("Current round start XP: " .. sessionData.currentRoundStartXP)
        print("Current round start time: " .. sessionData.currentRoundStartTime)
        print("First round start XP: " .. sessionData.firstRoundStartXP)
        print("Previous round end XP: " .. sessionData.previousRoundEndXP)
        print("Previous round start time: " .. sessionData.previousRoundStartTime)
        print("Last battle end XP: " .. sessionData.lastBattleEndXP)
        print("Previous battle start time: " .. sessionData.previousBattleStartTime)
    elseif msg == "reset" then
        sessionData.lastRoundXP = 0
        sessionData.lastRoundTime = 0
        sessionData.totalBattles = 0
        sessionData.totalBattleTime = 0
        sessionData.averageTime = 0
        print("Session data reset!")
    elseif msg == "show" then
        if monitorFrame then
            monitorFrame:Show()
            UpdateDisplay()
            print("Monitor frame shown manually")
        end
    elseif msg == "hide" then
        if monitorFrame then
            monitorFrame:Hide()
            print("Monitor frame hidden manually")
        end
    else
        print("Pet Battle Level Monitor commands:")
        print("/pblm debug - Toggle debug mode on/off")
        print("/pblm info - Show debug information")
        print("/pblm reset - Reset session data")
        print("/pblm show - Manually show frame")
        print("/pblm hide - Manually hide frame")
    end
end

-- Initialize the addon when loaded
Initialize()