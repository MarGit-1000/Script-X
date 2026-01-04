-- ========================================
-- VENDING MACHINE TOOLS v2.1 - FIXED
-- ========================================

-- Global Variables
local vendingList = {}
local selectedVendings = {}
local selectedItems = {}
local currentPage = 1
local itemsPerPage = 100
local itemSelectionCount = 0
local maxSelectionCount = 0
local currentMode = "" -- "price", "empty", "disable"

function watermark()
    SendVariant({v1 = "OnDialogRequest", v2 = [[
add_label_with_icon|big|`wX-SCRIPT|left|15110|
add_textbox|`wTerima Kasih Telah Menggunakan Script dari X-SCRIPT!|left|
add_url_button|comment|`wOpen Channel X-SCRIPT|color:0,0,0,0|https://whatsapp.com/channel/0029Vb60Vev2phHGjCHMpp3h||0|0|
add_quick_exit||
end_dialog|watermark|CANCEL|OK|]]})
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

local function resetState()
    selectedVendings = {}
    selectedItems = {}
    itemSelectionCount = 0
    maxSelectionCount = 0
    currentPage = 1
    currentMode = ""
end

local function scanVendingMachines()
    vendingList = {}
    local tiles = GetTiles()
    if not tiles then 
        LogToConsole("`4Error: Cannot get tiles!")
        return false 
    end
    
    for _, tile in pairs(tiles) do
        if tile.fg == 9268 or tile.fg == 2978 then
            local itemInfo = tile.extra.vend_item > 0 and getItemInfoByID(tile.extra.vend_item) or nil
            table.insert(vendingList, {
                position = {x = tile.x or 0, y = tile.y or 0},
                vendItem = tile.extra.vend_item or 0,
                vendItemName = itemInfo and itemInfo.name or "Unknown",
                vendPrice = tile.extra.vend_price or 0,
                owner = tile.extra.owner or 0,
                label = tile.extra.label or "",
                fgID = tile.fg
            })
        end
    end
    
    LogToConsole(string.format("`2Found %d vending machines!", #vendingList))
    return true
end

local function getFrameByFG(fgID)
    return fgID == 2978 and "staticBlueFrame" or "staticYellowFrame"
end

local function getTotalPages(totalItems)
    return math.ceil(totalItems / itemsPerPage)
end

local function getPageItems(items, page)
    local startIdx = (page - 1) * itemsPerPage + 1
    local endIdx = math.min(page * itemsPerPage, #items)
    local pageItems = {}
    
    for i = startIdx, endIdx do
        table.insert(pageItems, items[i])
    end
    
    return pageItems
end

local function countSelected()
    local count = 0
    for _ in pairs(selectedVendings) do
        count = count + 1
    end
    return count
end

-- ========================================
-- DIALOG BUILDER
-- ========================================

local function buildPaginationDialog(title, items, currentPage, checkPrefix, icon)
    local totalPages = getTotalPages(#items)
    local dialog = string.format([[
add_label_with_icon|big|`9%s|left|9270|
add_textbox|`wSelect Vending|left|
add_spacer|small|
]], title)
    
    if #items == 0 then
        dialog = dialog .. "add_textbox|`4No vending machines found!|left|\n"
    else
        local pageItems = getPageItems(items, currentPage)
        
        for _, vend in ipairs(pageItems) do
            if vend and vend.position then
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                local displayText = string.format("`w%s (%d,%d) - %s - `e%d WL",
                    vendType, vend.position.x, vend.position.y, 
                    vend.vendItemName, vend.vendPrice)
                
                local frame = getFrameByFG(vend.fgID)
                local isChecked = selectedVendings[vend.uniqueID] and 1 or 0
                
                dialog = dialog .. string.format(
                    "add_checkicon|%s_%s|%s|%s|%d||%d|\n",
                    checkPrefix, vend.uniqueID, displayText, frame, 
                    vend.vendItem > 0 and vend.vendItem or 2, isChecked)
            end
        end
        
        dialog = dialog .. string.format([[
add_spacer|small|
add_textbox|`9Page %d/%d `o- Total Selected: `2%d|left|
add_spacer|small|
]], currentPage, totalPages, countSelected())
        
        if currentPage > 1 then
            dialog = dialog .. string.format("add_button|prev_page_%s|`wPrevious Page|left|\n", checkPrefix)
        end
        if currentPage < totalPages then
            dialog = dialog .. string.format("add_button|next_page_%s|`wNext Page|left|\n", checkPrefix)
        end
    end
    
    return dialog .. string.format("add_quick_exit||\nend_dialog|%s|Cancel|OK|\n", checkPrefix)
end

-- ========================================
-- FEATURE DIALOGS
-- ========================================

function show_menu()
    SendVariant({v1 = "OnDialogRequest", v2 = [[
add_label_with_icon|big|`9Vending Machine Tools|left|9270|
add_spacer|small|
add_button|price_vendingss|`wEdit Price Vending|left|
add_button|empty_vending|`wEdit Empty Vending|left|
add_button|disable_vending|`wDisable Vending|left|
add_quick_exit||
end_dialog|main_menu|Cancel|OK|]]})
end

-- ========================================
-- EDIT PRICE (Hanya yang ada isinya)
-- ========================================

function show_edit_price()
    if not scanVendingMachines() then return end
    resetState()
    currentMode = "price"
    currentPage = 1
    show_edit_price_page()
end

function show_edit_price_page()
    local filteredVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendItem > 0 then -- Hanya yang ada isinya
            local uniqueID = string.format("%d_%d_%d", vend.position.x, vend.position.y, i)
            table.insert(filteredVendings, {
                position = vend.position,
                vendItem = vend.vendItem,
                vendItemName = vend.vendItemName,
                vendPrice = vend.vendPrice,
                fgID = vend.fgID,
                uniqueID = uniqueID,
                originalIndex = i
            })
        end
    end
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = buildPaginationDialog("Edit Price Vending (Only Filled)", filteredVendings, currentPage, "vending", 9270)})
end

function show_table_edit_price()
    local dialog = [[
add_label_with_icon|big|`9Edit Price - Selected Items|left|9270|
add_spacer|small|
]]
    
    if countSelected() == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        local count = 0
        for uniqueID, vendData in pairs(selectedVendings) do
            count = count + 1
            local vendType = vendData.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
            dialog = dialog .. string.format([[
add_textbox|`w%d. %s %s - %d WL at (%d,%d)|left|
add_text_input|price_vending_%s|New Price:||15|
add_checkbox|per_world_%s|`wPer World Lock|0|
add_spacer|small|
]], count, vendType, vendData.vendItemName, vendData.vendPrice, 
    vendData.position.x, vendData.position.y, uniqueID, uniqueID)
        end
    end
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = dialog .. "add_quick_exit||\nend_dialog|apply_price|Cancel|OK|\n"})
end

local function applyPriceChanges(packet)
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local processCount = 0
        local failCount = 0
        
        for uniqueID, vendData in pairs(selectedVendings) do
            local newPrice = tonumber(packet:match("price_vending_" .. uniqueID .. "|([^|\n]+)"))
            local perWorldLock = packet:find("per_world_" .. uniqueID .. "|1") ~= nil
            
            if newPrice and newPrice > 0 then
                processCount = processCount + 1
                
                LogToConsole(string.format("`9[%d] `2Updating vending at (%d,%d): %s -> %d %s",
                    processCount, vendData.position.x, vendData.position.y, vendData.vendItemName,
                    newPrice, perWorldLock and "WL" or "Item"))
                
                SendPacket(2, string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|%d\nchk_peritem|%d\nchk_perlock|%d\n",
                    vendData.position.x, vendData.position.y, newPrice, 
                    perWorldLock and 0 or 1, perWorldLock and 1 or 0))
                Sleep(500)
            else
                failCount = failCount + 1
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", processCount, failCount))
        resetState()
    end)
end

-- ========================================
-- EDIT EMPTY VENDING (Hanya yang kosong)
-- ========================================

function show_empty_vending()
    if not scanVendingMachines() then return end
    resetState()
    currentMode = "empty"
    currentPage = 1
    show_empty_vending_page()
end

function show_empty_vending_page()
    local filteredVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendItem == 0 then -- Hanya yang kosong
            local uniqueID = string.format("%d_%d_%d", vend.position.x, vend.position.y, i)
            table.insert(filteredVendings, {
                position = vend.position,
                vendItem = 0,
                vendItemName = "Empty",
                vendPrice = vend.vendPrice,
                fgID = vend.fgID,
                uniqueID = uniqueID,
                originalIndex = i
            })
        end
    end
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = buildPaginationDialog("Edit Empty Vending (Only Empty)", filteredVendings, currentPage, "vending_empty", 9270)})
end

function show_item_picker_for_empty()
    local dialog = [[
add_label_with_icon|big|`9Set Item for Empty Vending|left|9270|
add_textbox|`wSelect item for each vending:|left|
add_spacer|small|
]]
    
    local count = 0
    for uniqueID, vendData in pairs(selectedVendings) do
        count = count + 1
        local selectedText = ""
        if selectedItems[uniqueID] then
            local itemInfo = getItemInfoByID(selectedItems[uniqueID])
            selectedText = string.format(" `2(Selected: %s)", itemInfo and itemInfo.name or "Unknown")
        end
        
        local vendType = vendData.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
        dialog = dialog .. string.format([[
add_textbox|`w%d. %s (%d,%d)%s|left|
add_item_picker|item_%s|`wSelect Item:|%s|
add_spacer|small|
]], count, vendType, vendData.position.x, vendData.position.y, selectedText, 
    uniqueID, selectedItems[uniqueID] or "242")
    end
    
    dialog = dialog .. string.format(
        "add_textbox|`oSelection Counter: `e%d/%d|left|\n", 
        itemSelectionCount, maxSelectionCount)
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = dialog .. "add_quick_exit||\nend_dialog|item_picker_empty|Cancel|OK|\n"})
end

function show_confirmation_empty()
    local dialog = [[
add_label_with_icon|big|`9Confirm Items - Empty Vending|left|9270|
add_textbox|`wReview your selection:|left|
add_spacer|small|
]]
    
    local hasAllItems = true
    local count = 0
    
    for uniqueID, vendData in pairs(selectedVendings) do
        local itemID = selectedItems[uniqueID]
        count = count + 1
        local vendType = vendData.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
        local itemText = "`4No item selected"
        
        if itemID and itemID > 0 then
            local itemInfo = getItemInfoByID(itemID)
            itemText = string.format("`2%s `9(ID: `e%d`9)", 
                itemInfo and itemInfo.name or "Unknown", itemID)
        else
            hasAllItems = false
        end
        
        dialog = dialog .. string.format(
            "add_textbox|`w%d. %s `9(%d,%d) `w-> %s|left|\n",
            count, vendType, vendData.position.x, vendData.position.y, itemText)
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    if not hasAllItems then
        dialog = dialog .. "add_textbox|`4Warning: Some vendings have no item selected!|left|\n"
    end
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = dialog .. "add_quick_exit||\nend_dialog|confirm_item_empty|Back|Confirm|\n"})
end

local function applyEmptyVending()
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local successCount = 0
        local failCount = 0
        
        for uniqueID, vendData in pairs(selectedVendings) do
            local itemID = selectedItems[uniqueID]
            
            if itemID and itemID > 0 then
                successCount = successCount + 1
                local itemInfo = getItemInfoByID(itemID)
                
                LogToConsole(string.format("`9[%d] `2Filling vending at (%d,%d) with `3%s",
                    successCount, vendData.position.x, vendData.position.y, 
                    itemInfo and itemInfo.name or "Unknown"))
                
                SendPacket(2, string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nstockitem|%d\n",
                    vendData.position.x, vendData.position.y, itemID))
                Sleep(500)
            else
                failCount = failCount + 1
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
        resetState()
    end)
end

-- ========================================
-- DISABLE VENDING (Hanya yang price ~= 0)
-- ========================================

function show_disable_vending()
    if not scanVendingMachines() then return end
    resetState()
    currentMode = "disable"
    currentPage = 1
    show_disable_vending_page()
end

function show_disable_vending_page()
    local filteredVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendPrice ~= 0 then -- Hanya yang price tidak 0
            local uniqueID = string.format("%d_%d_%d", vend.position.x, vend.position.y, i)
            table.insert(filteredVendings, {
                position = vend.position,
                vendItem = vend.vendItem,
                vendItemName = vend.vendItemName,
                vendPrice = vend.vendPrice,
                fgID = vend.fgID,
                uniqueID = uniqueID,
                originalIndex = i
            })
        end
    end
    
    SendVariant({v1 = "OnDialogRequest", 
        v2 = buildPaginationDialog("Disable Vending (Active Only)", filteredVendings, currentPage, "vending_disable", 9270)})
end

local function applyDisableVending()
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local successCount = 0
        local failCount = 0
        
        for uniqueID, vendData in pairs(selectedVendings) do
            successCount = successCount + 1
            
            LogToConsole(string.format("`9[%d] `2Disabling vending at (%d,%d)",
                successCount, vendData.position.x, vendData.position.y))
            
            SendPacket(2, string.format(
                "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|0\nchk_peritem|1\nchk_perlock|0\n",
                vendData.position.x, vendData.position.y))
            Sleep(500)
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
        resetState()
    end)
end

-- ========================================
-- PACKET HOOK HANDLER
-- ========================================

local function saveCurrentPageSelections(packet, prefix, filteredList)
    for _, vend in ipairs(filteredList) do
        local uniqueID = vend.uniqueID
        local key = prefix .. "_" .. uniqueID
        
        if packet:find(key .. "|1") then
            selectedVendings[uniqueID] = vend
        elseif packet:find(key .. "|0") then
            selectedVendings[uniqueID] = nil
        end
    end
end

local function getFilteredList(mode)
    local filtered = {}
    for i, vend in ipairs(vendingList) do
        local uniqueID = string.format("%d_%d_%d", vend.position.x, vend.position.y, i)
        local shouldInclude = false
        
        if mode == "price" then
            shouldInclude = vend.vendItem > 0
        elseif mode == "empty" then
            shouldInclude = vend.vendItem == 0
        elseif mode == "disable" then
            shouldInclude = vend.vendPrice ~= 0
        end
        
        if shouldInclude then
            table.insert(filtered, {
                position = vend.position,
                vendItem = vend.vendItem,
                vendItemName = vend.vendItemName,
                vendPrice = vend.vendPrice,
                fgID = vend.fgID,
                uniqueID = uniqueID,
                originalIndex = i
            })
        end
    end
    return filtered
end

addHook(function(packetType, packet)
    if packetType ~= 2 then return false end
    
    -- Main Menu
    if packet:find("/start") then
        show_menu()
        return true
    end
    
    -- EDIT PRICE
    if packet:find("price_vendingss") then
        show_edit_price()
        return true
    end
    
    if packet:find("next_page_vending") then
        local filtered = getFilteredList("price")
        saveCurrentPageSelections(packet, "vending", filtered)
        currentPage = currentPage + 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("prev_page_vending") then
        local filtered = getFilteredList("price")
        saveCurrentPageSelections(packet, "vending", filtered)
        currentPage = currentPage - 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("dialog_name|vending\n") and packet:find("buttonClicked|") then
        local filtered = getFilteredList("price")
        saveCurrentPageSelections(packet, "vending", filtered)
        
        local count = countSelected()
        
        if count > 0 then
            LogToConsole(string.format("`2Selected %d vending(s)", count))
            show_table_edit_price()
        else
            LogToConsole("`4No vending selected!")
        end
        return true
    end
    
    if packet:find("apply_price") then
        applyPriceChanges(packet)
        return true
    end
    
    -- EMPTY VENDING
    if packet:find("empty_vending") then
        show_empty_vending()
        return true
    end
    
    if packet:find("next_page_vending_empty") then
        local filtered = getFilteredList("empty")
        saveCurrentPageSelections(packet, "vending_empty", filtered)
        currentPage = currentPage + 1
        show_empty_vending_page()
        return true
    end
    
    if packet:find("prev_page_vending_empty") then
        local filtered = getFilteredList("empty")
        saveCurrentPageSelections(packet, "vending_empty", filtered)
        currentPage = currentPage - 1
        show_empty_vending_page()
        return true
    end
    
    if packet:find("dialog_name|vending_empty\n") and packet:find("buttonClicked|") then
        local filtered = getFilteredList("empty")
        saveCurrentPageSelections(packet, "vending_empty", filtered)
        
        local count = countSelected()
        
        if count > 0 then
            maxSelectionCount = count
            itemSelectionCount = 0
            LogToConsole(string.format("`2Selected %d empty vending(s)", count))
            show_item_picker_for_empty()
        else
            LogToConsole("`4No empty vending selected!")
        end
        return true
    end
    
    if packet:find("item_picker_empty") then
        for uniqueID, _ in pairs(selectedVendings) do
            local itemID = tonumber(packet:match("item_" .. uniqueID .. "|(%d+)"))
            if itemID and itemID > 0 then
                selectedItems[uniqueID] = itemID
            end
        end
        
        itemSelectionCount = 0
        for uniqueID, _ in pairs(selectedVendings) do
            if selectedItems[uniqueID] then
                itemSelectionCount = itemSelectionCount + 1
            end
        end
        
        if itemSelectionCount >= maxSelectionCount then
            LogToConsole("`2All items selected! Moving to confirmation...")
            show_confirmation_empty()
        else
            show_item_picker_for_empty()
        end
        return true
    end
    
    if packet:find("confirm_item_empty") then
        if packet:find("buttonClicked|Confirm") then
            applyEmptyVending()
        else
            show_item_picker_for_empty()
        end
        return true
    end
    
    -- DISABLE VENDING
    if packet:find("disable_vending") then
        show_disable_vending()
        return true
    end
    
    if packet:find("next_page_vending_disable") then
        local filtered = getFilteredList("disable")
        saveCurrentPageSelections(packet, "vending_disable", filtered)
        currentPage = currentPage + 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("prev_page_vending_disable") then
        local filtered = getFilteredList("disable")
        saveCurrentPageSelections(packet, "vending_disable", filtered)
        currentPage = currentPage - 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("dialog_name|vending_disable\n") and packet:find("buttonClicked|") then
        local filtered = getFilteredList("disable")
        saveCurrentPageSelections(packet, "vending_disable", filtered)
        
        local count = countSelected()
        
        if count > 0 then
            LogToConsole(string.format("`2Disabling %d vending(s)", count))
            applyDisableVending()
        else
            LogToConsole("`4No vending selected!")
        end
        return true
    end
    
    return false
end, "OnSendPacket")

-- ========================================
-- STARTUP
-- ========================================

LogToConsole("`2Vending Machine Tools v2.2 Loaded!")
LogToConsole("`9Type /start to open menu")
watermark()
