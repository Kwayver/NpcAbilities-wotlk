local addonName = "NpcAbilities-wotlk"

-- Create a frame to handle events
local npcAbilitiesFrame = CreateFrame("Frame")

-- Table to cache spell data (description and attributes)
local spellDescriptionCache = {}

-- Create a hidden tooltip buffer for reading spell descriptions
local tooltipBuffer = CreateFrame("GameTooltip", "TooltipBuffer", nil, "GameTooltipTemplate")
tooltipBuffer:SetOwner(UIParent, "ANCHOR_NONE")

-- Function to extract spell description and attributes from tooltip buffer
local function getTooltipDescription(spellId)
    tooltipBuffer:ClearLines()
    tooltipBuffer:SetHyperlink("spell:" .. spellId)
    local attributes = {}
    local description = ""
    local numLines = tooltipBuffer:NumLines()
    
    -- Start from TextLeft2 (TextLeft1 is spell name)
    for i = 2, numLines do
        local line = _G["TooltipBufferTextLeft" .. i]
        if line and line:GetText() and line:GetText() ~= "" then
            local text = line:GetText()
            -- Check if the line is an attribute to include
            if text:match("^%d+ yd range$") or
               text:match("^%d+%.%d+ sec cast$") or
               text:match("^%d+ sec cast$") or
               text:match("^Instant$") or
               text:match("^Instant [Cc]ast$") or
               text:match("^Channeled$") or
               text:match("^Melee range$") or
               text:match("^%d+-%d+ yd range$") or
               text:match("^Next melee$") or
               text:match("^%d+ sec cooldown$") or
               text:match("^%d+ milliseconds$") then
                -- Transform specific attributes
                if text:match("^%d+ milliseconds$") then
                    local ms = tonumber(text:match("^%d+"))
                    text = string.format("%.1f sec", ms / 1000)
                elseif text == "0 yards range" then
                    text = "Melee range"
                end
                table.insert(attributes, text)
            -- Skip attributes to omit
            elseif not text:match("^%d+ Mana$") and
                   not text:match("^Requires Melee Weapon$") and
                   not text:match("^Requires Ranged Weapon$") then
                -- Assume this is part of the description
                description = description .. (description ~= "" and " " or "") .. text
            end
        end
    end
    
    return description ~= "" and description or nil, attributes
end

-- Function to print load confirmation to chat
local function PrintLoadConfirmation()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffffNpcAbilities|r: Addon successfully loaded! Displays NPC abilities in tooltips.", 1, 1, 1)
end

-- Retrieve NPC data from npcs.lua
local function GetNpcDataByID(npcId)
    local data = _G["NpcAbilitiesNpcData"]
    if not data then
        return nil
    end

    local convertedId = tonumber(npcId)
    if not convertedId then
        return nil
    end

    local npcData = data[convertedId]
    if not npcData or not npcData.spell_ids then
        return nil
    end

    return npcData
end

-- Retrieve spell data from enUS.lua
local function GetSpellData(spellId)
    local data = _G["NpcAbilitiesAbilityData"]
    if not data then
        return nil
    end

    local enData = data["en"]
    if not enData then
        return nil
    end

    local spellData = enData[spellId]
    if not spellData then
        return nil
    end

    return spellData
end

-- Add ability details to tooltip
local function AddAbilityLinesToGameTooltip(spellId, addedAbilityLine)
    local name, rank, icon = GetSpellInfo(spellId) -- Only use name, rank, icon from GetSpellInfo
    local spellData = GetSpellData(spellId) -- From enUS.lua

    -- Use NpcAbilitiesAbilityData name as fallback if GetSpellInfo fails
    if not name and spellData and spellData.name then
        name = spellData.name
        icon = icon or 0
    end

    if not name then
        if not addedAbilityLine then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Abilities:", 1, 0.85, 0)
            addedAbilityLine = true
        else
            GameTooltip:AddLine(" ")
        end
        local iconTexture = "|TInterface\\Icons\\INV_Misc_QuestionMark:12|t"
        GameTooltip:AddLine(iconTexture .. " Unknown Spell - " .. spellId, 1, 0, 0)
        return addedAbilityLine
    end

    if not addedAbilityLine then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Abilities:", 1, 0.85, 0)
        addedAbilityLine = true
    else
        GameTooltip:AddLine(" ")
    end

    local iconTexture = icon and "|T" .. icon .. ":12:12:0:0:64:64:4:60:4:60|t" or "|TInterface\\Icons\\INV_Misc_QuestionMark:12|t"
    local displayName = name .. " - " .. spellId
    -- Use light blue color for spell name (0.4, 0.7, 1.0)
    GameTooltip:AddLine(iconTexture .. " " .. displayName, 0.4, 0.7, 1.0)

    -- Check for cached description and attributes
    local description, attributes = nil, {}
    if spellDescriptionCache[spellId] then
        description = spellDescriptionCache[spellId].description
        attributes = spellDescriptionCache[spellId].attributes
    else
        -- Try getTooltipDescription
        description, attributes = getTooltipDescription(spellId)
        if description then
            spellDescriptionCache[spellId] = { description = description, attributes = attributes }
        else
            -- Fallback to enUS.lua or default
            if spellData and spellData.description and spellData.description ~= "" then
                description = spellData.description
                spellDescriptionCache[spellId] = { description = description, attributes = attributes }
            else
                description = "No description available."
                spellDescriptionCache[spellId] = { description = description, attributes = attributes }
            end
        end
    end

    -- Add attributes from tooltip (excluding range and cast time, which come from enUS.lua)
    for _, attr in ipairs(attributes) do
        -- Skip range and cast time attributes, as we'll use enUS.lua
        if not attr:match("^%d+ yd range$") and
           not attr:match("^%d+%.%d+ sec cast$") and
           not attr:match("^%d+ sec cast$") and
           not attr:match("^Instant$") and
           not attr:match("^Instant [Cc]ast$") and
           not attr:match("^Channeled$") and
           not attr:match("^%d+-%d+ yd range$") then
            GameTooltip:AddLine(attr, 1, 1, 1, true)
        end
    end

    -- Add range and cast_time from enUS.lua if available
    if spellData then
        if spellData.range and spellData.range ~= "" then
            local rangeText = string.gsub(spellData.range, "%s+$", "") -- Trim trailing spaces
            if rangeText == "0 yards" then
                rangeText = "Melee range"
            end
            GameTooltip:AddLine("Range: " .. rangeText, 1, 1, 1, true)
        end

        if spellData.cast_time and spellData.cast_time ~= "" then
            local castTimeText = string.gsub(spellData.cast_time, "%s+$", "") -- Trim trailing spaces
            if castTimeText:match("^%d+ milliseconds$") then
                local ms = tonumber(castTimeText:match("^%d+"))
                castTimeText = string.format("%.1f sec", ms / 1000)
            end
            GameTooltip:AddLine("Cast: " .. castTimeText, 1, 1, 1, true)
        end
    end

    -- Add description
    GameTooltip:AddLine("|cFFFFD700" .. description .. "|r", nil, nil, nil, true)

    return addedAbilityLine
end

-- Modify tooltip for NPCs
local function ModifyTooltip()
    local _, unitId = GameTooltip:GetUnit()
    if not unitId or not UnitExists(unitId) then
        return
    end

    local unitGUID = UnitGUID(unitId)
    if not unitGUID then
        return
    end

    local unitType, npcId
    if unitGUID:find("-") then
        unitType, _, _, _, _, npcId = strsplit("-", unitGUID)
    else
        if unitGUID:match("^0xF13") then
            unitType = "Creature"
            npcId = tonumber(unitGUID:sub(7, 12), 16)
        end
    end

    if unitType ~= "Creature" or not npcId then
        return
    end

    local npcData = GetNpcDataByID(npcId)
    if not npcData then
        return
    end

    local addedAbilityLine = false
    for _, spellId in ipairs(npcData.spell_ids) do
        local success, result = pcall(AddAbilityLinesToGameTooltip, spellId, addedAbilityLine)
        if success then
            addedAbilityLine = result
        end
    end

    if addedAbilityLine then
        GameTooltip:Show()
    end
end

-- Hook the tooltip's OnTooltipSetUnit event
GameTooltip:HookScript("OnTooltipSetUnit", function()
    local success, err = pcall(ModifyTooltip)
end)

-- Event handler for addon loading
npcAbilitiesFrame:RegisterEvent("ADDON_LOADED")
npcAbilitiesFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        PrintLoadConfirmation()
    end
end)

-- Slash command to test spell IDs
SLASH_NPCABILITIES1 = "/npcabilities"
SlashCmdList["NPCABILITIES"] = function(msg)
    local spellId = tonumber(msg)
    if spellId then
        local name, _, icon = GetSpellInfo(spellId)
        local spellData = GetSpellData(spellId)
        if name then
            DEFAULT_CHAT_FRAME:AddMessage("Spell ID: " .. spellId .. ", Name: " .. name .. ", Icon: " .. tostring(icon))
        elseif spellData and spellData.name then
            DEFAULT_CHAT_FRAME:AddMessage("Spell ID: " .. spellId .. ", Name (from NpcAbilitiesAbilityData): " .. spellData.name)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Invalid spell ID: " .. spellId .. " (GetSpellInfo and NpcAbilitiesAbilityData returned nil)")
        end
        local description, attributes = nil, {}
        if spellDescriptionCache[spellId] then
            description = spellDescriptionCache[spellId].description
            attributes = spellDescriptionCache[spellId].attributes
            DEFAULT_CHAT_FRAME:AddMessage("Description (cached): " .. description)
        else
            description, attributes = getTooltipDescription(spellId)
            if description then
                spellDescriptionCache[spellId] = { description = description, attributes = attributes }
                DEFAULT_CHAT_FRAME:AddMessage("Description (tooltip): " .. description)
            else
                if spellData and spellData.description then
                    description = spellData.description
                    spellDescriptionCache[spellId] = { description = description, attributes = attributes }
                    DEFAULT_CHAT_FRAME:AddMessage("Description (enUS.lua): " .. description)
                else
                    description = "No description available."
                    spellDescriptionCache[spellId] = { description = description, attributes = attributes }
                    DEFAULT_CHAT_FRAME:AddMessage("Description: " .. description)
                end
            end
        end
        for _, attr in ipairs(attributes) do
            if not attr:match("^%d+ yd range$") and
               not attr:match("^%d+%.%d+ sec cast$") and
               not attr:match("^%d+ sec cast$") and
               not attr:match("^Instant$") and
               not attr:match("^Instant [Cc]ast$") and
               not attr:match("^Channeled$") and
               not attr:match("^%d+-%d+ yd range$") then
                DEFAULT_CHAT_FRAME:AddMessage("Attribute: " .. attr)
            end
        end
        if spellData then
            if spellData.range and spellData.range ~= "" then
                local rangeText = string.gsub(spellData.range, "%s+$", "")
                if rangeText == "0 yards" then
                    rangeText = "Melee range"
                end
                DEFAULT_CHAT_FRAME:AddMessage("Range: " .. rangeText)
            end
            if spellData.cast_time and spellData.cast_time ~= "" then
                local castTimeText = string.gsub(spellData.cast_time, "%s+$", "")
                if castTimeText:match("^%d+ milliseconds$") then
                    local ms = tonumber(castTimeText:match("^%d+"))
                    castTimeText = string.format("%.1f sec", ms / 1000)
                end
                DEFAULT_CHAT_FRAME:AddMessage("Cast: " .. castTimeText)
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /npcabilities <spellId>")
    end
end