-- WoWA Classic Addon: PeggaID

local AddonName, Addon = ...
Addon.db = {}

-- Saved variables
dbSavedVariables = dbSavedVariables or { items = {}, spells = {}, lastCheckbox = "item" }

local QUALITY_COLORS = {
    [0] = "|cff9d9d9d", -- Poor (Gray)
    [1] = "|cffffffff", --h Common (White)
    [2] = "|cff1eff00", -- Uncommon (Green)
    [3] = "|cff0070dd", -- Rare (Blue)
    [4] = "|cffa335ee", --o Epic (Purple)
    [5] = "|cffff8000", -- Legendary (Orange)
    [6] = "|cffe6cc80", -- Artifact (Beige-Gold)
}

local QUALITY_OPTIONS = {
    { value = "ALL", text = "|cffffffffALL|r" },
    { value = 0, text = QUALITY_COLORS[0] .. "Poor|r" },
    { value = 1, text = QUALITY_COLORS[1] .. "Common|r" },
    { value = 2, text = QUALITY_COLORS[2] .. "Uncommon|r" },
    { value = 3, text = QUALITY_COLORS[3] .. "Rare|r" },
    { value = 4, text = QUALITY_COLORS[4] .. "Epic|r" },
    { value = 5, text = QUALITY_COLORS[5] .. "Legendary|r" },
    { value = 6, text = QUALITY_COLORS[6] .. "Artifact|r" },
}

local currentFilter = "ALL"

-- Helper Functions
local function AddIDToDatabase(id, name, isItem)
    local db = isItem and dbSavedVariables.items or dbSavedVariables.spells
    if not db[id] then
        db[id] = name
    end
end

local function SearchDatabase(query, isItem)
    local results = {}
    local db = isItem and dbSavedVariables.items or dbSavedVariables.spells
    for id, name in pairs(db) do
        if name:lower():find(query:lower()) then
            if currentFilter == "ALL" or (isItem and select(3, GetItemInfo(id)) == currentFilter) then
                local isSOD = name:find("Seasoning of Discovery") -- Check for SOD items
                table.insert(results, { id = id, name = name, isSOD = isSOD })
            end
        end
    end

    -- If no results found, request information from World of Warcraft
    if #results == 0 then
        -- Example: Requesting item information from World of Warcraft
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
        else
            -- Example: Requesting spell information from World of Warcraft
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

    return results
end

-- Main Frame
local frame = CreateFrame("Frame", "PeggaIDFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(500, 600)
frame:SetPoint("CENTER")
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Show()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -4)
frame.title:SetText("PeggaID Search")
frame.title:SetFont("Fonts\\FRIZQT__.TTF", 12)

-- Checkboxes
local itemCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
itemCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
itemCheckbox.text = itemCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
itemCheckbox.text:SetPoint("LEFT", itemCheckbox, "RIGHT", 5, 0)
itemCheckbox.text:SetText("Item IDs")

local spellCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
spellCheckbox:SetPoint("LEFT", itemCheckbox, "RIGHT", 200, 0)
spellCheckbox.text = spellCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
spellCheckbox.text:SetPoint("LEFT", spellCheckbox, "RIGHT", 5, 0)
spellCheckbox.text:SetText("Spell IDs")

itemCheckbox:SetScript("OnClick", function()
    if itemCheckbox:GetChecked() then
        spellCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "item"
    else
        itemCheckbox:SetChecked(true)
    end
end)

spellCheckbox:SetScript("OnClick", function()
    if spellCheckbox:GetChecked() then
        itemCheckbox:SetChecked(false)
        dbSavedVariables.lastCheckbox = "spell"
    else
        spellCheckbox:SetChecked(true)
    end
end)

-- Set last checkbox state on frame show
frame:SetScript("OnShow", function()
    local lastCheckbox = dbSavedVariables.lastCheckbox
    if (lastCheckbox == "item") then
        itemCheckbox:SetChecked(true)
        spellCheckbox:SetChecked(false)
    else
        spellCheckbox:SetChecked(true)
        itemCheckbox:SetChecked(false)
    end
end)

-- Ensure the last checkbox state is set when the addon loads
local function OnAddonLoaded()
    local lastCheckbox = dbSavedVariables.lastCheckbox
    if (lastCheckbox == "item") then
        itemCheckbox:SetChecked(true)
        spellCheckbox:SetChecked(false)
    else
        spellCheckbox:SetChecked(true)
        itemCheckbox:SetChecked(false)
    end
end

-- Register the event to set the checkbox state when the addon loads
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if (arg1 == "PeggaID") then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Search Box
local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
searchBox:SetSize(350, 20)
searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -80)
searchBox:SetAutoFocus(false)

-- Search Button
local searchButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
searchButton:SetSize(100, 20)
searchButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -80)
searchButton:SetText("Search")

-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(450, 400)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -120)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(450, 1)
scrollFrame:SetScrollChild(content)

-- Dropdown for Quality
local qualityDropdown = CreateFrame("Frame", "QualityDropdown", frame, "UIDropDownMenuTemplate")
qualityDropdown:SetPoint("LEFT", itemCheckbox, "RIGHT", 50, -3)

UIDropDownMenu_SetWidth(qualityDropdown, 100)
UIDropDownMenu_Initialize(qualityDropdown, function(self, level, menuList)
    for _, option in ipairs(QUALITY_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.value = option.value
        info.func = function()
            currentFilter = option.value
            UIDropDownMenu_SetSelectedValue(qualityDropdown, option.value)
        end
        UIDropDownMenu_AddButton(info)
    end
end)

UIDropDownMenu_SetSelectedValue(qualityDropdown, "ALL")

-- Helper function to update item quality
local function UpdateItemQuality(line, itemID)
    local qualityColor = QUALITY_COLORS[select(3, GetItemInfo(itemID))] or "|cffffffff"
    line.text:SetText(qualityColor .. line.text:GetText() .. "|r")
end

-- Collect Button
local collectButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
collectButton:SetSize(100, 20)
collectButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -40)
collectButton:SetText("Collect IDs")

collectButton:SetScript("OnClick", function()
    local isItem = itemCheckbox:GetChecked()
    local apiFunction = isItem and GetItemInfo or GetSpellInfo
    local db = isItem and dbSavedVariables.items or dbSavedVariables.spells
    local consecutiveMisses = 0
    local maxConsecutiveMisses = 1000 -- Stop after 1000 consecutive misses
    local addedCount = 0

    local id = 1
    while consecutiveMisses < maxConsecutiveMisses do
        if not db[id] then
            local name = apiFunction(id)
            if name then
                AddIDToDatabase(id, name, isItem)
                addedCount = addedCount + 1
                consecutiveMisses = 0 -- Reset consecutive misses counter
            else
                consecutiveMisses = consecutiveMisses + 1
            end
        else
            consecutiveMisses = 0 -- Reset consecutive misses counter if ID is already in the database
        end
        id = id + 1
    end

    local totalItems = 0
    for _ in pairs(dbSavedVariables.items) do totalItems = totalItems + 1 end

    local totalSpells = 0
    for _ in pairs(dbSavedVariables.spells) do totalSpells = totalSpells + 1 end

    local typeText = isItem and "items" or "spells"
    print("|cffe6cc80Collection|r |cffffffffComplete!|r |cff00ffffDatabase|r |cff1eff00updated|r. |cffffff00(" .. addedCount .. " " .. typeText .. " added to DB)|r. |cffffffff(Total items: " .. totalItems .. ", Total spells: " .. totalSpells .. ")|r")
end)

local resultsCountText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
resultsCountText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 10) -- Adjusted position
resultsCountText:SetText("")

-- Page Indicator
local pageIndicator = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
pageIndicator:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
pageIndicator:SetText("Page 1 / 1")


local resultsPerPage = 100
local currentPage = 1
local totalPages = 1
local results = {}

local function UpdateResultsDisplay(isItem)
    -- Clear previous results
    if content then
        content:Hide()
    end

    -- Create a new content frame
    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(450, 1)
    scrollFrame:SetScrollChild(content)

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
        if result.isSOD then
            displayName = "|cffffffff(SOD)|r " .. displayName
        end

        if isItem then
            local qualityColor = QUALITY_COLORS[select(3, GetItemInfo(result.id))] or "|cffffffff"
            displayName = qualityColor .. displayName .. "|r"
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
            else
                local spellLink = GetSpellLink(result.id)
                if spellLink then
                    local message = "Spell ID: " .. result.id .. " - |cffffff00#|r " .. spellLink
                    DEFAULT_CHAT_FRAME:AddMessage(message)
                end
            end
        end)

        line:SetScript("OnEnter", function()
            GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
            if isItem then
                GameTooltip:SetHyperlink("item:" .. result.id)
                if IsControlKeyDown() then
                    DressUpItemLink("item:" .. result.id)
                end
            else
                GameTooltip:SetSpellByID(result.id)
                local spellIcon = select(3, GetSpellInfo(result.id))
                if spellIcon then
                    GameTooltip:AddTexture(spellIcon)
                end
            end
            GameTooltip:Show()
        end)

        line:SetScript("OnLeave", function()
            GameTooltip:Hide()
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

        yOffset = yOffset - 25
    end

    resultsCountText:SetText(#results .. " results found.")
    pageIndicator:SetText("Page " .. currentPage .. " / " .. math.max(totalPages, 1))
end
-- Search Button Script
searchButton:SetScript("OnClick", function()
    local query = searchBox:GetText()
    isItem = itemCheckbox:GetChecked()

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
        return
    else
        -- Perform search in the local database
        results = SearchDatabase(query, isItem)
        
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
    UpdateResultsDisplay(isItem)
end)

-- Slash Command
SLASH_PEGGAID1 = "/peggaid"
SlashCmdList["PEGGAID"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
