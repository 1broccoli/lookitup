--- To be added, New Item ID or Spell ID with tool tip to add to the database
--- Add objects database
--- adding items/spells/models manually
--- show model id
--- quest ids

local AddonName, Addon = ...
Addon.db = {}

-- Saved variables
dbSavedVariables = dbSavedVariables or { items = {}, spells = {}, lastCheckbox = "item", debug = false }

-- Load the database from Lookitup\data\db.lua
local dbFilePath = "Interface\\AddOns\\Lookitup\\data\\db.lua"
local dbData, loadError = pcall(dofile, dbFilePath)
if dbData then
    if type(loadError) == "table" then
        dbSavedVariables.items = loadError.items or {}
        dbSavedVariables.spells = loadError.spells or {}
    else
        print("|cffff0000[Lookitup]: Error executing database file:|r", loadError or "Unknown error")
    end
else
    print("|cffff0000[Lookitup]: Failed to load database file:|r", loadError or "Unknown error")
end

-- Ensure the database is loaded
if not dbSavedVariables then
    dbSavedVariables = { items = {}, spells = {}, lastCheckbox = "item", debug = false }
end

-- Check if the db.lua file has defined items and spells
if db and db.items and db.spells then
    dbSavedVariables.items = db.items
    dbSavedVariables.spells = db.spells
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
local function AddIDToDatabase(id, name, isItem)
    local db = isItem and dbSavedVariables.items or dbSavedVariables.spells
    if not db[id] then
        db[id] = name
        DebugPrint("Added ID " .. id .. " (" .. name .. ") to database.")
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
    if (arg1 == "Lookitup") then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
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

    if query == "" then
        results = {}
        resultsCountText:SetText("No results found.")
        pageIndicator:SetText("Page 1 / 1")
        currentPage = 1
        totalPages = 1
        UpdatePaginationButtons()
        UpdateResultsDisplay(isItem)
        return
    end

    -- Perform search in the local database
    results = SearchDatabase(query, isItem)

    -- Update results display
    totalPages = math.ceil(#results / resultsPerPage)
    currentPage = 1
    UpdateResultsDisplay(isItem)
end)

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
    UpdateResultsDisplay(itemCheckbox:GetChecked())
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
    UpdateResultsDisplay(itemCheckbox:GetChecked())
end)

-- Call UpdatePaginationButtons after creating the buttons
UpdatePaginationButtons()

-- Collect Button with Texture
local collectButton = CreateFrame("Button", nil, frame)
collectButton:SetSize(16, 16)
collectButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -10)

collectButton.texture = collectButton:CreateTexture(nil, "ARTWORK")
collectButton.texture:SetAllPoints()
collectButton.texture:SetTexture("Interface\\AddOns\\Lookitup\\textures\\saveit.png")

collectButton:SetScript("OnEnter", function(self)
    self.texture:SetVertexColor(0.5, 0.5, 0) -- Blue color on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Collect Item IDs and Spell IDs", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)

collectButton:SetScript("OnLeave", function(self)
    self.texture:SetVertexColor(1, 1, 1) -- Reset color on leave
    GameTooltip:Hide()
end)

collectButton:SetScript("OnMouseDown", function(self)
    self.texture:SetVertexColor(0, 1, 0) -- Green color on click
end)

collectButton:SetScript("OnMouseUp", function(self)
    self.texture:SetVertexColor(0, 1, 0) -- Green color on release
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
SLASH_Lookitup1 = "/Lookitup"
SlashCmdList["Lookitup"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
