-- ========================================
-- VENDING MACHINE TOOLS v2.0 - OPTIMIZED
-- ========================================

-- Global Variables
local vendingList = {}
local selectedVendings = {}
local selectedItems = {}
local currentPage = 1
local itemsPerPage = 100
local itemSelectionCount = 0
local maxSelectionCount = 0

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
        table.insert(pageItems, {index = i, data = items[i]})
    end
    
    return pageItems
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
        
        for _, item in ipairs(pageItems) do
            local i = item.index
            local vend = item.data
            
            if vend and vend.position then
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                local displayText = string.format("`w%s (%d,%d) - %s - `e%d WL",
                    vendType, vend.position.x, vend.position.y, 
                    vend.vendItemName, vend.vendPrice)
                
                local frame = getFrameByFG(vend.fgID)
                local isChecked = selectedVendings[i] and 1 or 0
                
                dialog = dialog .. string.format(
                    "add_checkicon|%s_%d|%s|%s|%d||%d|\n",
                    checkPrefix, i, displayText, frame, 
                    vend.vendItem > 0 and vend.vendItem or 2, isChecked)
            end
        end
        
        dialog = dialog .. string.format([[
add_spacer|small|
add_textbox|`9Page %d/%d `o- Total Selected: `2%d|left|
add_spacer|small|
]], currentPage, totalPages, #selectedVendings)
        
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

-- EDIT PRICE
function show_edit_price()
    if not scanVendingMachines() then return end
    currentPage = 1
    show_edit_price_page()
end

function show_edit_price_page()
    SendVariant({v1 = "OnDialogRequest", 
        v2 = buildPaginationDialog("Edit Price Vending", vendingList, currentPage, "vending", 9270)})
end

function show_table_edit_price()
    local dialog = [[
add_label_with_icon|big|`9Edit Price - Selected Items|left|9270|
add_spacer|small|
]]
    
    if #selectedVendings == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        local count = 0
        for vendIdx, _ in pairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                count = count + 1
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                dialog = dialog .. string.format([[
add_textbox|`w%d. %s %s - %d WL at (%d,%d)|left|
add_text_input|price_vending_%d|New Price:||15|
add_checkbox|per_world_%d|`wPer World Lock|0|
add_spacer|small|
]], count, vendType, vend.vendItemName, vend.vendPrice, 
    vend.position.x, vend.position.y, vendIdx, vendIdx)
            end
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
        
        for vendIdx, _ in pairs(selectedVendings) do
            local newPrice = tonumber(packet:match("price_vending_" .. vendIdx .. "|([^|\n]+)"))
            local perWorldLock = packet:find("per_world_" .. vendIdx .. "|1") ~= nil
            
            if newPrice and newPrice > 0 then
                local vend = vendingList[vendIdx]
                if vend and vend.position then
                    processCount = processCount + 1
                    
                    LogToConsole(string.format("`9[%d] `2Updating vending at (%d,%d): %s -> %d %s",
                        processCount, vend.position.x, vend.position.y, vend.vendItemName,
                        newPrice, perWorldLock and "WL" or "Item"))
                    
                    SendPacket(2, string.format(
                        "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|%d\nchk_peritem|%d\nchk_perlock|%d\n",
                        vend.position.x, vend.position.y, newPrice, 
                        perWorldLock and 0 or 1, perWorldLock and 1 or 0))
                    Sleep(500)
                else
                    failCount = failCount + 1
                end
            else
                failCount = failCount + 1
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", processCount, failCount))
        selectedVendings = {}
    end)
end

-- EDIT EMPTY VENDING
function show_empty_vending()
    if not scanVendingMachines() then return end
    currentPage = 1
    show_empty_vending_page()
end

function show_empty_vending_page()
    local emptyVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendItem == 0 then
            table.insert(emptyVendings, {originalIndex = i, vend = vend})
        end
    end
    
    -- Build modified items list with original indices
    local displayItems = {}
    for _, item in ipairs(emptyVendings) do
        local vend = item.vend
        displayItems[#displayItems + 1] = {
            position = vend.position,
            vendItem = 0,
            vendItemName = "Empty",
            vendPrice = 0,
            fgID = vend.fgID,
            originalIndex = item.originalIndex
        }
    end
    
    local dialog = buildPaginationDialog("Edit Empty Vending", displayItems, currentPage, "vending_empty", 9270)
    
    SendVariant({v1 = "OnDialogRequest", v2 = dialog})
end

function show_item_picker_for_empty()
    local dialog = [[
add_label_with_icon|big|`9Set Item for Empty Vending|left|9270|
add_textbox|`wSelect item for each vending:|left|
add_spacer|small|
]]
    
    local count = 0
    for vendIdx, _ in pairs(selectedVendings) do
        local vend = vendingList[vendIdx]
        if vend then
            count = count + 1
            local selectedText = ""
            if selectedItems[vendIdx] then
                local itemInfo = getItemInfoByID(selectedItems[vendIdx])
                selectedText = string.format(" `2(Selected: %s)", itemInfo and itemInfo.name or "Unknown")
            end
            
            local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
            dialog = dialog .. string.format([[
add_textbox|`w%d. %s (%d,%d)%s|left|
add_item_picker|item_%d|`wSelect Item:|%s|
add_spacer|small|
]], count, vendType, vend.position.x, vend.position.y, selectedText, 
    vendIdx, selectedItems[vendIdx] or "242")
        end
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
    
    for vendIdx, _ in pairs(selectedVendings) do
        local vend = vendingList[vendIdx]
        local itemID = selectedItems[vendIdx]
        
        if vend then
            count = count + 1
            local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
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
                count, vendType, vend.position.x, vend.position.y, itemText)
        end
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
        
        for vendIdx, _ in pairs(selectedVendings) do
            local itemID = selectedItems[vendIdx]
            
            if itemID and itemID > 0 then
                local vend = vendingList[vendIdx]
                if vend and vend.position then
                    successCount = successCount + 1
                    local itemInfo = getItemInfoByID(itemID)
                    
                    LogToConsole(string.format("`9[%d] `2Filling vending at (%d,%d) with `3%s",
                        successCount, vend.position.x, vend.position.y, 
                        itemInfo and itemInfo.name or "Unknown"))
                    
                    SendPacket(2, string.format(
                        "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nstockitem|%d\n",
                        vend.position.x, vend.position.y, itemID))
                    Sleep(500)
                else
                    failCount = failCount + 1
                end
            else
                failCount = failCount + 1
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
        selectedVendings = {}
        selectedItems = {}
        itemSelectionCount = 0
        maxSelectionCount = 0
    end)
end

-- DISABLE VENDING
function show_disable_vending()
    if not scanVendingMachines() then return end
    currentPage = 1
    show_disable_vending_page()
end

function show_disable_vending_page()
    local activeVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendPrice ~= 0 then
            table.insert(activeVendings, {originalIndex = i, vend = vend})
        end
    end
    
    local displayItems = {}
    for _, item in ipairs(activeVendings) do
        local vend = item.vend
        displayItems[#displayItems + 1] = {
            position = vend.position,
            vendItem = vend.vendItem,
            vendItemName = vend.vendItemName,
            vendPrice = vend.vendPrice,
            fgID = vend.fgID,
            originalIndex = item.originalIndex
        }
    end
    
    local dialog = buildPaginationDialog("Disable Vending", displayItems, currentPage, "vending_disable", 9270)
    SendVariant({v1 = "OnDialogRequest", v2 = dialog})
end

local function applyDisableVending()
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local successCount = 0
        local failCount = 0
        
        for vendIdx, _ in pairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            
            if vend and vend.position then
                successCount = successCount + 1
                
                LogToConsole(string.format("`9[%d] `2Disabling vending at (%d,%d)",
                    successCount, vend.position.x, vend.position.y))
                
                SendPacket(2, string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|0\nchk_peritem|1\nchk_perlock|0\n",
                    vend.position.x, vend.position.y))
                Sleep(500)
            else
                failCount = failCount + 1
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
        selectedVendings = {}
    end)
end

-- ========================================
-- PACKET HOOK HANDLER
-- ========================================

local function saveCurrentPageSelections(packet, prefix)
    -- Clear selections first untuk items yang tidak di-check
    local pageItems = getPageItems(vendingList, currentPage)
    for _, item in ipairs(pageItems) do
        local i = item.index
        local key = prefix .. "_" .. i
        if packet:find(key .. "|1") then
            selectedVendings[i] = true
        elseif packet:find(key .. "|0") then
            selectedVendings[i] = nil
        end
    end
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
        saveCurrentPageSelections(packet, "vending")
        currentPage = currentPage + 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("prev_page_vending") then
        saveCurrentPageSelections(packet, "vending")
        currentPage = currentPage - 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("dialog_name|vending\n") and packet:find("buttonClicked|") then
        saveCurrentPageSelections(packet, "vending")
        
        local count = 0
        for _ in pairs(selectedVendings) do count = count + 1 end
        
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
        saveCurrentPageSelections(packet, "vending_empty")
        currentPage = currentPage + 1
        show_empty_vending_page()
        return true
    end
    
    if packet:find("prev_page_vending_empty") then
        saveCurrentPageSelections(packet, "vending_empty")
        currentPage = currentPage - 1
        show_empty_vending_page()
        return true
    end
    
    if packet:find("dialog_name|vending_empty\n") and packet:find("buttonClicked|") then
        saveCurrentPageSelections(packet, "vending_empty")
        
        local count = 0
        for _ in pairs(selectedVendings) do count = count + 1 end
        
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
        for vendIdx, _ in pairs(selectedVendings) do
            local itemID = tonumber(packet:match("item_" .. vendIdx .. "|(%d+)"))
            if itemID and itemID > 0 then
                selectedItems[vendIdx] = itemID
            end
        end
        
        itemSelectionCount = 0
        for vendIdx, _ in pairs(selectedVendings) do
            if selectedItems[vendIdx] then
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
        saveCurrentPageSelections(packet, "vending_disable")
        currentPage = currentPage + 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("prev_page_vending_disable") then
        saveCurrentPageSelections(packet, "vending_disable")
        currentPage = currentPage - 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("dialog_name|vending_disable\n") and packet:find("buttonClicked|") then
        saveCurrentPageSelections(packet, "vending_disable")
        
        local count = 0
        for _ in pairs(selectedVendings) do count = count + 1 end
        
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

LogToConsole("`2Vending Machine Tools v2.1 Loaded!")
LogToConsole("`9Type /start to open menu")
watermark()
