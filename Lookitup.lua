--- To be added, New Item ID or Spell ID with tool tip to add to the database
--- Add objects database
--- adding items/spells/models manually
--- show model id
--- quest ids

local AddonName, Addon = ...
Addon.db = {}

-- Saved variables
dbSavedVariables = dbSavedVariables or { items = {}, spells = {}, quests = {}, lastCheckbox = "item", debug = false }

-- Load the database from Lookitup\data\db.lua
local dbFilePath = "Interface\\AddOns\\Lookitup\\data\\db.lua"
local dbData, loadError = pcall(dofile, dbFilePath)
if dbData then
    if type(loadError) == "table" then
        dbSavedVariables.items = loadError.items or {}
        dbSavedVariables.spells = loadError.spells or {}
        dbSavedVariables.quests = loadError.quests or {}
    else
        print("|cffff0000[Lookitup]: Error executing database file:|r", loadError or "Unknown error")
    end
else
    print("|cffff0000[Lookitup]: Failed to load database file:|r", loadError or "Unknown error")
end

-- Ensure the database is loaded
if not dbSavedVariables then
    dbSavedVariables = { items = {}, spells = {}, quests = {}, lastCheckbox = "item", debug = false }
end

-- Check if the db.lua file has defined items, spells, and quests
if db and db.items and db.spells and db.quests then
    dbSavedVariables.items = db.items
    dbSavedVariables.spells = db.spells
    dbSavedVariables.quests = db.quests
else
    print("|cffff0000[Lookitup]: Failed to load database.|r")
end

local QUALITY_COLORS = QUALITY_COLORS or {
    [0] = "|cff9d9d9d", -- Poor (Gray)
    [1] = "|cffffffff", -- Common (White)
    [2] = "|cff1eff00", -- Uncommon (Green)
    [3] = "|cff0070dd", -- Rare (Blue)
    [4] = "|cffa335ee", -- Epic (Purple)
    [5] = "|cffff8000", -- Legendary (Orange)
    [6] = "|cffe6cc80", -- Artifact (Beige-Gold)
}

local QUALITY_OPTIONS = QUALITY_OPTIONS or {
    { value = "ALL", text = "|cffffffffALL|r" },
    { value = 0, text = QUALITY_COLORS[0] .. "Poor|r" },
    { value = 1, text = QUALITY_COLORS[1] .. "Common|r" },
    { value = 2, text = QUALITY_COLORS[2] .. "Uncommon|r" },
    { value = 3, text = QUALITY_COLORS[3] .. "Rare|r" },
    { value = 4, text = QUALITY_COLORS[4] .. "Epic|r" },
    { value = 5, text = QUALITY_COLORS[5] .. "Legendary|r" },
    { value = 6, text = QUALITY_COLORS[6] .. "Artifact|r" },
}

local currentFilter = currentFilter or "ALL"

-- Debug function
local function DebugPrint(message)
    if dbSavedVariables.debug then
        print("|cffff8000[Lookitup Debug]:|r " .. message)
    end
end

-- Helper Functions
local function AddIDToDatabase(id, name, isItem, isQuest)
    local db = isItem and dbSavedVariables.items or (isQuest and dbSavedVariables.quests) or dbSavedVariables.spells
    if not db[id] then
        db[id] = name
        DebugPrint("Added ID " .. id .. " (" .. name .. ") to database.")
    end
end

local function SearchDatabase(query, isItem, isQuest)
    local results = {}
    local db = isItem and dbSavedVariables.items or (isQuest and dbSavedVariables.quests) or dbSavedVariables.spells
    for id, name in pairs(db) do
        if name:lower():find(query:lower()) then
            table.insert(results, { id = id, name = name })
        end
    end

    -- If no results found, request information from World of Warcraft
    if #results == 0 and isQuest then
        local questID = tonumber(query)
        if questID then
            local questLink = "\124cffffff00\124Hquest:" .. questID .. ":60\124h[Quest Name]\124h\124r"
            GameTooltip:SetHyperlink(questLink)
            local questName = GameTooltipTextLeft1:GetText()
            GameTooltip:ClearLines()
            if questName and questName ~= "" and not questName:find("quest:") then
                table.insert(results, { id = questID, name = questName })
                dbSavedVariables.quests[questID] = questName
            end
        end
    end

    return results
end

-- Helper function to update item quality
local function UpdateItemQuality(line, itemID)
    local qualityColor = QUALITY_COLORS[select(3, GetItemInfo(itemID))] or "|cffffffff"
    if line and line.text then
        line.text:SetText(qualityColor .. line.text:GetText() .. "|r")
    end
end

-- Function to update the pagination buttons
local function UpdatePaginationButtons()
    if not leftButton or not rightButton then
        return -- Exit early if buttons are not created
    end

    -- Ensure currentPage and totalPages are valid
    currentPage = currentPage or 1
    totalPages = totalPages or 1

    if not currentPage or not totalPages then
        return
    end

    -- Enable or disable buttons based on the current page
    leftButton:SetEnabled(currentPage > 1)
    rightButton:SetEnabled(currentPage < totalPages)
end

-- Load AceHook-3.0
local AceHook = LibStub("AceHook-3.0")
local Lookitup = AceHook:Embed({})

-- Main Frame
local frame = CreateFrame("Frame", "LookitupFrame", UIParent, "BackdropTemplate")
frame:SetSize(500, 600)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Adjust the point and offsets as needed
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
})

frame:SetBackdropColor(0, 0, 0, 1) -- Set initial backdrop transparency
frame:SetBackdropBorderColor(0, 0, 0, 1) -- Set border color to black
frame:SetMovable(true) -- Make the frame movable
frame:SetResizable(true) -- Make the frame resizable
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -15)
frame.title:SetText("Look It Up")
frame.title:SetTextColor(1, 0, 0) -- Set text color to red
frame.title:SetShadowColor(0, 0, 0) -- Set shadow color to black
frame.title:SetShadowOffset(1, -1) -- Set shadow offset
frame.title:SetFont("Fonts\\FRIZQT__.TTF", 16)

-- Create a close texture
local closeTexture = frame:CreateTexture(nil, "ARTWORK")
closeTexture:SetSize(22, 22)
closeTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -7)
closeTexture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\close.png")
closeTexture:SetTexCoord(0, 1, 0, 1)

-- Add highlighting and clicking features to the close texture
closeTexture:SetScript("OnEnter", function(self)
    self:SetVertexColor(1, 0, 0)
end)
closeTexture:SetScript("OnLeave", function(self)
    self:SetVertexColor(1, 1, 1)
end)
closeTexture:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        frame:Hide()
    end
end)

-- Checkboxes
local itemCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
itemCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
itemCheckbox.text = itemCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
itemCheckbox.text:SetPoint("LEFT", itemCheckbox, "RIGHT", 5, 0)
itemCheckbox.text:SetText("Item IDs")

itemCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Item IDs\nHold Ctrl to open in Dressing Room", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
itemCheckbox:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

local spellCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
spellCheckbox:SetPoint("LEFT", itemCheckbox, "RIGHT", 200, 0)
spellCheckbox.text = spellCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
spellCheckbox.text:SetPoint("LEFT", spellCheckbox, "RIGHT", 5, 0)
spellCheckbox.text:SetText("Spell IDs")

local questCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
questCheckbox:SetPoint("LEFT", spellCheckbox, "RIGHT", 80, 0)
questCheckbox.text = questCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
questCheckbox.text:SetPoint("LEFT", questCheckbox, "RIGHT", 5, 0)
questCheckbox.text:SetText("Quest IDs")

itemCheckbox:SetScript("OnClick", function()
    if itemCheckbox:GetChecked() then
        spellCheckbox:SetChecked(false)
        questCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "item"
    else
        itemCheckbox:SetChecked(true)
    end
end)

spellCheckbox:SetScript("OnClick", function()
    if spellCheckbox:GetChecked() then
        itemCheckbox:SetChecked(false)
        questCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "spell"
    else
        spellCheckbox:SetChecked(true)
    end
end)

questCheckbox:SetScript("OnClick", function()
    if questCheckbox:GetChecked() then
        itemCheckbox:SetChecked(false)
        spellCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "quest"
    else
        questCheckbox:SetChecked(true)
    end
end)

-- Ensure the last checkbox state is set when the addon loads
local function OnAddonLoaded()
    local lastCheckbox = dbSavedVariables.lastCheckbox
    if lastCheckbox == "item" then
        itemCheckbox:SetChecked(true)
        spellCheckbox:SetChecked(false)
        questCheckbox:SetChecked(false)
    elseif lastCheckbox == "spell" then
        spellCheckbox:SetChecked(true)
        itemCheckbox:SetChecked(false)
        questCheckbox:SetChecked(false)
    elseif lastCheckbox == "quest" then
        questCheckbox:SetChecked(true)
        itemCheckbox:SetChecked(false)
        spellCheckbox:SetChecked(false)
    else
        -- Default to spell checkbox checked
        spellCheckbox:SetChecked(true)
        itemCheckbox:SetChecked(false)
        questCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "spell"
    end

    -- Set dropdown menu to "ALL" by default
    UIDropDownMenu_SetSelectedValue(qualityDropdown, "ALL")
    UIDropDownMenu_SetText(qualityDropdown, "|cffffffffALL|r") -- Explicitly set the text to "ALL"
    currentFilter = "ALL"
end

-- Register the event to set the checkbox state when the addon loads
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if (arg1 == "Lookitup") then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Ensure the OnShow hook is applied only once
local isOnShowHooked = false
frame:SetScript("OnShow", function()
    if not isOnShowHooked then
        Lookitup:HookScript(frame, "OnShow", function()
            local lastCheckbox = dbSavedVariables.lastCheckbox
            if lastCheckbox == "item" then
                itemCheckbox:SetChecked(true)
                spellCheckbox:SetChecked(false)
                questCheckbox:SetChecked(false)
            elseif lastCheckbox == "spell" then
                spellCheckbox:SetChecked(true)
                itemCheckbox:SetChecked(false)
                questCheckbox:SetChecked(false)
            elseif lastCheckbox == "quest" then
                questCheckbox:SetChecked(true)
                itemCheckbox:SetChecked(false)
                spellCheckbox:SetChecked(false)
            end
        end)
        isOnShowHooked = true
    end
end)

local resultsPerPage = resultsPerPage or 100 -- Default to 100 results per page
local currentPage = currentPage or 1
local totalPages = totalPages or 1
local results = results or {}

-- Create the results count text
local resultsCountText = resultsCountText or frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
resultsCountText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 10) -- Adjusted position
resultsCountText:SetText("")

-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(450, 400)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -120)

local content = content or CreateFrame("Frame", nil, scrollFrame)
content:SetSize(450, 1)
scrollFrame:SetScrollChild(content)

-- Page Indicator
local pageIndicator = pageIndicator or frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
pageIndicator:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
pageIndicator:SetText("Page 1 / 1")

local function SetupTooltip(line, isItem, isQuest, result)
    Lookitup:HookScript(line, "OnEnter", function()
        GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
        if isItem then
            GameTooltip:SetHyperlink("item:" .. result.id)
            if IsControlKeyDown() then
                DressUpItemLink("item:" .. result.id)
            end
        elseif isQuest then
            local questLink = "\124cffffff00\124Hquest:" .. result.id .. ":60\124h[" .. result.name .. "]\124h\124r"
            GameTooltip:SetHyperlink(questLink)
        else
            GameTooltip:SetSpellByID(result.id)
            local spellIcon = select(3, GetSpellInfo(result.id))
            if spellIcon then
                GameTooltip:AddTexture(spellIcon)
            end
        end
        GameTooltip:Show()
    end)

    Lookitup:HookScript(line, "OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function UpdateResultsDisplay(isItem, isQuest)
    -- Clear previous results
    if content then
        content:Hide()
    end

    -- Create a new content frame
    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(450, 1)
    scrollFrame:SetScrollChild(content)

    -- Calculate the range of results to display
    local startIndex = (currentPage - 1) * resultsPerPage + 1
    local endIndex = math.min(currentPage * resultsPerPage, #results)
    local yOffset = 0

    for i = startIndex, endIndex do
        local result = results[i]
        local line = CreateFrame("Button", nil, content)
        line:SetSize(430, 20)
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)

        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line.text:SetPoint("LEFT", line, "LEFT")

        local displayName = result.name
        if isItem then
            local itemID = result.id
            local _, _, itemQuality = GetItemInfo(itemID)
            if currentFilter ~= "ALL" and itemQuality ~= currentFilter then
                -- Skip items that don't match the quality filter
                do
                    yOffset = yOffset - 25
                    break
                end
            else
                local qualityColor = QUALITY_COLORS[itemQuality] or "|cffffffff"
                displayName = qualityColor .. displayName .. "|r"
            end
        elseif isQuest then
            displayName = "|cffffff00" .. displayName .. "|r" -- Yellow color for quest IDs
        else
            displayName = "|cffffff00" .. displayName .. "|r" -- Yellow color for spell IDs
        end

        line.text:SetText(displayName)

        line:SetScript("OnClick", function()
            if isItem then
                local itemName, itemLink = GetItemInfo(result.id)
                if itemLink then
                    local message = "Item ID: " .. result.id .. " - |cffffff00#|r " .. itemLink
                    DEFAULT_CHAT_FRAME:AddMessage(message)
                end
            elseif isQuest then
                local questLink = "\124cffffff00\124Hquest:" .. result.id .. ":60\124h[" .. result.name .. "]\124h\124r"
                DEFAULT_CHAT_FRAME:AddMessage("Quest ID: " .. result.id .. " - " .. questLink)
            else
                local spellLink = GetSpellLink(result.id)
                if spellLink then
                    local message = "Spell ID: " .. result.id .. " - |cffffff00#|r " .. spellLink
                    DEFAULT_CHAT_FRAME:AddMessage(message)
                end
            end
        end)

        if isItem then
            local itemID = result.id
            if not GetItemInfo(itemID) then
                -- Register for the GET_ITEM_INFO_RECEIVED event
                local frame = CreateFrame("Frame")
                frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                frame:SetScript("OnEvent", function(self, event, arg1)
                    if event == "GET_ITEM_INFO_RECEIVED" and arg1 == itemID then
                        UpdateItemQuality(line, itemID)
                        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
                        self:SetScript("OnEvent", nil)
                    end
                end)
            end
        end

        SetupTooltip(line, isItem, isQuest, result)

        yOffset = yOffset - 25
    end

    resultsCountText:SetText(#results .. " results found.")
    pageIndicator:SetText("Page " .. (currentPage or 1) .. " / " .. math.max(totalPages, 1))
    UpdatePaginationButtons()
end

-- Search Box
local searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
searchBox:SetSize(350, 20)
searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -80) -- Adjusted position
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("GameFontHighlight")
searchBox:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 15,
    edgeSize = 15,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }, -- Fill to the insets
})
searchBox:SetBackdropColor(0, 0, 0, 1)
searchBox:SetBackdropBorderColor(0, 0, 0, 1)

-- Unfocus the search box when ESC is pressed
searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

searchBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end -- Ignore programmatic changes
    local query = self:GetText()
    local isItem = itemCheckbox:GetChecked()
    local isQuest = questCheckbox:GetChecked()

    if query == "" then
        results = {}
        resultsCountText:SetText("No results found.")
        pageIndicator:SetText("Page 1 / 1")
        currentPage = 1
        totalPages = 1
        UpdatePaginationButtons()
        UpdateResultsDisplay(isItem, isQuest)
        return
    end

    -- Perform search in the local database
    results = SearchDatabase(query, isItem, isQuest)

    -- Update results display
    totalPages = math.ceil(#results / resultsPerPage)
    currentPage = 1
    UpdateResultsDisplay(isItem, isQuest)
end)

-- Dropdown for Quality
local qualityDropdown = CreateFrame("Frame", "QualityDropdown", frame, "UIDropDownMenuTemplate")
qualityDropdown:SetPoint("LEFT", itemCheckbox, "RIGHT", 50, -3)

UIDropDownMenu_SetWidth(qualityDropdown, 100)
UIDropDownMenu_Initialize(qualityDropdown, function(self, level, menuList)
    if not level then return end
    for _, option in ipairs(QUALITY_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.value = option.value
        info.func = function()
            currentFilter = option.value
            UIDropDownMenu_SetSelectedValue(qualityDropdown, option.value)
            UIDropDownMenu_SetText(qualityDropdown, option.text) -- Ensure dropdown text updates
            DebugPrint("Quality filter set to: " .. tostring(option.value))
            -- Refresh results display with the updated filter
            UpdateResultsDisplay(itemCheckbox:GetChecked(), questCheckbox:GetChecked())
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_SetSelectedValue(qualityDropdown, "ALL")

-- Ensure the dropdown reflects the current filter when the frame is shown
frame:SetScript("OnShow", function()
    UIDropDownMenu_SetSelectedValue(qualityDropdown, currentFilter)
end)

-- Create pagination buttons
local leftButton = leftButton or CreateFrame("Button", nil, frame)
leftButton:SetSize(32, 32)
leftButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
leftButton.texture = leftButton:CreateTexture(nil, "ARTWORK")
leftButton.texture:SetAllPoints()
leftButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\left.png") -- Ensure the texture path is correct
leftButton.texture:SetVertexColor(0.5, 0.5, 0.5) -- Initially gray out the button
leftButton:SetScript("OnClick", function()
    if currentPage and currentPage > 1 then
        currentPage = currentPage - 1
    else
        currentPage = totalPages
    end
    UpdateResultsDisplay(itemCheckbox:GetChecked(), questCheckbox:GetChecked())
end)

local rightButton = rightButton or CreateFrame("Button", nil, frame)
rightButton:SetSize(32, 32)
rightButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
rightButton.texture = rightButton:CreateTexture(nil, "ARTWORK")
rightButton.texture:SetAllPoints()
rightButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\right.png") -- Ensure the texture path is correct
rightButton.texture:SetVertexColor(0.5, 0.5, 0.5) -- Initially gray out the button
rightButton:SetScript("OnClick", function()
    if currentPage and currentPage < totalPages then
        currentPage = currentPage + 1
    else
        currentPage = 1
    end
    UpdateResultsDisplay(itemCheckbox:GetChecked(), questCheckbox:GetChecked())
end)

-- Call UpdatePaginationButtons after creating the buttons
UpdatePaginationButtons()

-- Collect Items Button
local collectItemsButton = CreateFrame("Button", nil, frame)
collectItemsButton:SetSize(16, 16)
collectItemsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -10)
collectItemsButton.texture = collectItemsButton:CreateTexture(nil, "ARTWORK")
collectItemsButton.texture:SetAllPoints()
collectItemsButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\saveit.png")
collectItemsButton.texture:SetVertexColor(0, 1, 0) -- Green for items

collectItemsButton:SetScript("OnEnter", function(self)
    self.texture:SetVertexColor(0.5, 1, 0.5) -- Highlight green on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Collect Item IDs", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)

collectItemsButton:SetScript("OnLeave", function(self)
    self.texture:SetVertexColor(0, 1, 0) -- Reset color
    GameTooltip:Hide()
end)

collectItemsButton:SetScript("OnMouseUp", function(self)
    local db = dbSavedVariables.items
    local consecutiveMisses, addedCount = 0, 0
    local id = 1
    while consecutiveMisses < 20000 do
        if not db[id] then
            local name = GetItemInfo(id)
            if name then
                AddIDToDatabase(id, name, true)
                addedCount = addedCount + 1
                consecutiveMisses = 0
            else
                consecutiveMisses = consecutiveMisses + 1
            end
        end
        id = id + 1
    end
    print("|cffe6cc80Collection|r |cffffffffComplete!|r |cff00ffffDatabase|r updated. |cffffff00(" .. addedCount .. " items added)|r.")
end)

-- Collect Spells Button
local collectSpellsButton = CreateFrame("Button", nil, frame)
collectSpellsButton:SetSize(16, 16)
collectSpellsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -60, -10)
collectSpellsButton.texture = collectSpellsButton:CreateTexture(nil, "ARTWORK")
collectSpellsButton.texture:SetAllPoints()
collectSpellsButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\saveit.png")
collectSpellsButton.texture:SetVertexColor(0, 1, 1) -- Teal for spells

collectSpellsButton:SetScript("OnEnter", function(self)
    self.texture:SetVertexColor(0.5, 1, 1) -- Highlight teal on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Collect Spell IDs", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)

collectSpellsButton:SetScript("OnLeave", function(self)
    self.texture:SetVertexColor(0, 1, 1) -- Reset color
    GameTooltip:Hide()
end)

collectSpellsButton:SetScript("OnMouseUp", function(self)
    local db = dbSavedVariables.spells
    local consecutiveMisses, addedCount = 0, 0
    local id = 1
    while consecutiveMisses < 50000 do
        if not db[id] then
            local name = GetSpellInfo(id)
            if name then
                AddIDToDatabase(id, name, false)
                addedCount = addedCount + 1
                consecutiveMisses = 0
            else
                consecutiveMisses = consecutiveMisses + 1
            end
        end
        id = id + 1
    end
    print("|cffe6cc80Collection|r |cffffffffComplete!|r |cff00ffffDatabase|r updated. |cffffff00(" .. addedCount .. " spells added)|r.")
end)

-- Collect Quests Button
local collectQuestsButton = CreateFrame("Button", nil, frame)
collectQuestsButton:SetSize(16, 16)
collectQuestsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -80, -10)
collectQuestsButton.texture = collectQuestsButton:CreateTexture(nil, "ARTWORK")
collectQuestsButton.texture:SetAllPoints()
collectQuestsButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\saveit.png")
collectQuestsButton.texture:SetVertexColor(1, 1, 0) -- Yellow for quests

collectQuestsButton:SetScript("OnEnter", function(self)
    self.texture:SetVertexColor(1, 1, 0.5) -- Highlight yellow on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Collect Quest IDs", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)

collectQuestsButton:SetScript("OnLeave", function(self)
    self.texture:SetVertexColor(1, 1, 0) -- Reset color
    GameTooltip:Hide()
end)

local function CollectQuestsCoroutine()
    local db = dbSavedVariables.quests
    local addedQuests = 0
    for questID = 1, 10000 do
        if not db[questID] then
            local questLink = "\124cffffff00\124Hquest:" .. questID .. ":60\124h[Quest Name]\124h\124r"
            GameTooltip:SetHyperlink(questLink)
            local questName = GameTooltipTextLeft1:GetText()
            GameTooltip:ClearLines()
            if questName and questName ~= "" and not questName:find("quest:") then
                db[questID] = questName
                addedQuests = addedQuests + 1
            end
        end
        if questID % 100 == 0 then
            coroutine.yield() -- Yield every 100 iterations to prevent freezing
        end
    end
    print("|cffe6cc80Collection|r |cffffffffComplete!|r |cff00ffffDatabase|r updated. |cffffff00(" .. addedQuests .. " quests added)|r.")
end

local questCollectorCoroutine

collectQuestsButton:SetScript("OnMouseUp", function(self)
    if not questCollectorCoroutine or coroutine.status(questCollectorCoroutine) == "dead" then
        questCollectorCoroutine = coroutine.create(CollectQuestsCoroutine)
    end

    local function OnUpdateHandler()
        if questCollectorCoroutine and coroutine.status(questCollectorCoroutine) == "suspended" then
            coroutine.resume(questCollectorCoroutine)
        else
            collectQuestsButton:SetScript("OnUpdate", nil) -- Stop the OnUpdate handler when done
        end
    end

    collectQuestsButton:SetScript("OnUpdate", OnUpdateHandler)
end)

-- Search Button with Texture
local searchButton = CreateFrame("Button", nil, frame)
searchButton:SetSize(20, 20)
searchButton:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

searchButton.texture = searchButton:CreateTexture(nil, "ARTWORK")
searchButton.texture:SetAllPoints()
searchButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\search.png")

searchButton:SetScript("OnEnter", function(self)
    self.texture:SetVertexColor(0.8, 0.8, 0.8) -- Slightly darken on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click to search", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)

searchButton:SetScript("OnLeave", function(self)
    self.texture:SetVertexColor(1, 1, 1) -- Reset color on leave
    GameTooltip:Hide()
end)

searchButton:SetScript("OnMouseDown", function(self)
    self.texture:SetVertexColor(0.6, 0.6, 0.6) -- Darken on click
end)

searchButton:SetScript("OnMouseUp", function(self)
    self.texture:SetVertexColor(0.8, 0.8, 0.8) -- Slightly darken on release
    local query = searchBox:GetText()
    local isItem = itemCheckbox:GetChecked()
    local isQuest = questCheckbox:GetChecked()

    if query == "" and (currentFilter == 5 or currentFilter == 6) then
        -- If the query is blank and the filter is set to Legendary or Artifact, return all results of that quality
        results = {}
        local db = isItem and dbSavedVariables.items or dbSavedVariables.spells
        for id, name in pairs(db) do
            if isItem and select(3, GetItemInfo(id)) == currentFilter then
                table.insert(results, { id = id, name = name })
            end
        end
    elseif query == "" then
        resultsCountText:SetText("No results found.")
        pageIndicator:SetText("Page 1 / 1")
        currentPage = 1
        totalPages = 1
        UpdatePaginationButtons()
        return
    else
        -- Perform search in the local database
        results = SearchDatabase(query, isItem, isQuest)
        
        -- If no results found in the local database, request information from the server
        if #results == 0 then
            if isItem then
                local itemID = tonumber(query)
                if itemID then
                    local itemName, _, itemQuality = GetItemInfo(itemID)
                    if itemName and (currentFilter == "ALL" or itemQuality == currentFilter) then
                        local isSOD = itemName:find("Seasoning of Discovery") -- Check for SOD items
                        table.insert(results, { id = itemID, name = itemName, isSOD = isSOD })
                        -- Add the result to the database
                        AddIDToDatabase(itemID, itemName, isItem)
                    end
                end
            elseif isQuest then
                local questID = tonumber(query)
                if questID then
                    local questLink = "\124cffffff00\124Hquest:" .. questID .. ":60\124h[Quest Name]\124h\124r"
                    GameTooltip:SetHyperlink(questLink)
                    local questName = GameTooltipTextLeft1:GetText()
                    GameTooltip:ClearLines()
                    if questName and questName ~= "" and not questName:find("quest:") then
                        table.insert(results, { id = questID, name = questName })
                        dbSavedVariables.quests[questID] = questName
                    end
                end
            else
                local spellID = tonumber(query)
                if spellID then
                    local spellName = GetSpellInfo(spellID)
                    if spellName then
                        table.insert(results, { id = spellID, name = spellName, isSOD = false })
                        -- Add the result to the database
                        AddIDToDatabase(spellID, spellName, isItem)
                    end
                end
            end
        end
    end

    totalPages = math.ceil(#results / resultsPerPage)
    currentPage = 1
    UpdateResultsDisplay(isItem, isQuest)
end)

-- Slash Command
SLASH_Lookitup1 = "/Lookitup"
SlashCmdList["Lookitup"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Load LibDBIcon-1.0
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("Lookitup", {
    type = "launcher",
    icon = "Interface\\AddOns\\Lookitup\\textures\\mmb.jpeg",  -- Path to the minimap icon
    OnClick = function(_, button)
        if button == "LeftButton" then
            -- Toggle the Lookitup frame
            if LookitupFrame:IsShown() then
                LookitupFrame:Hide()
            else
                LookitupFrame:Show()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cffe6cc80Lookitup|r")
        tooltip:AddLine("|cff9d9d9dOpen Lookitup,|r")
    end,
})

local icon = LibStub("LibDBIcon-1.0")
local minimapButtonDB = {}

-- Register the minimap button
icon:Register("Lookitup", LDB, minimapButtonDB)

-- Save minimap button position on logout
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        -- Save the minimap button position
        LookitupSavedVariables = LookitupSavedVariables or {}
        LookitupSavedVariables.minimapButtonDB = minimapButtonDB
        Lookitup:UnhookAll()
    end
end)

-- Load saved minimap button position on addon load
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "Lookitup" then
        LookitupSavedVariables = LookitupSavedVariables or {}
        minimapButtonDB = LookitupSavedVariables.minimapButtonDB or {}
        icon:Refresh("Lookitup", minimapButtonDB)
    end
end)
