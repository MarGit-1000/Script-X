-- ========================================
-- VENDING MACHINE TOOLS v1.3
-- ========================================

-- Global Variables
local vendingList = {}
local totalVending = 0
local selectedVendings = {}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Scan semua vending machines di world
local function scanVendingMachines()
    vendingList = {}
    totalVending = 0
    
    local tiles = GetTiles()
    if not tiles then
        LogToConsole("`4Error: Cannot get tiles!")
        return false
    end
    
    for _, tile in pairs(tiles) do
        -- Check if tile is vending machine (ID: 2796 atau 9268)
        if tile.fg == 9268 or tile.fg == 2978 then
            local vendData = {
                position = {
                    x = tile.x or 0,
                    y = tile.y or 0
                },
                vendItem = tile.extra.vend_item or 0,
                vendItemName = "Unknown",
                vendPrice = tile.extra.vend_price or 0,
                owner = tile.extra.owner or 0,
                label = tile.extra.label or ""
            }
            
            -- Get item name
            if vendData.vendItem > 0 then
                local itemInfo = getItemInfoByID(vendData.vendItem)
                if itemInfo and itemInfo.name then
                    vendData.vendItemName = itemInfo.name
                end
            end
            
            table.insert(vendingList, vendData)
            totalVending = totalVending + 1
        end
    end
    
    LogToConsole(string.format("`2Found %d vending machines!", totalVending))
    return true
end

-- Tampilkan vending list ke console
local function showVendingList()
    if totalVending == 0 then
        LogToConsole("`4No vending machines found!")
        return
    end
    
    LogToConsole("`9========== VENDING LIST ==========")
    for i, vend in ipairs(vendingList) do
        LogToConsole(string.format("`o%d. `2(%d, %d) `o- `3%s `o- Price: `e%d WL", 
            i, 
            vend.position.x, 
            vend.position.y,
            vend.vendItemName,
            vend.vendPrice
        ))
    end
    LogToConsole("`9==================================")
end

-- Export vending data ke file
local function exportVending()
    if totalVending == 0 then
        LogToConsole("`4No vending to export!")
        return
    end
    
    local output = {}
    table.insert(output, "VENDING SCAN - " .. GetWorldName())
    table.insert(output, "Total: " .. totalVending .. "\n")
    
    for i, vend in ipairs(vendingList) do
        table.insert(output, string.format("#%d - (%d,%d) - %s - %d WL", 
            i, vend.position.x, vend.position.y, vend.vendItemName, vend.vendPrice))
    end
    
    local filename = "vending_" .. GetWorldName() .. ".txt"
    writeToLocal(filename, table.concat(output, "\n"))
    LogToConsole("`2Exported to: " .. filename)
end

-- ========================================
-- DIALOG: MAIN MENU
-- ========================================

function show_menu()
    local dialog = [[
add_label_with_icon|big|`9Vending Machine Tools|left|9270|
add_spacer|small|
add_button|price_vendingss|Edit Price Vending|left|
add_button|empty_vending|Edit Empty Vending|left|
add_button|disable_vending|Edit Enable/Disable Vending|left|
add_button|kosongkan_vending|Edit Stock Vending|left|
add_spacer|small|
add_button|scan_vending|Scan All Vending|left|
add_button|export_vending|Export to File|left|
add_quick_exit||
end_dialog|main_menu|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

-- ========================================
-- FEATURE 1: EDIT PRICE VENDING
-- ========================================

function show_edit_price()
    -- Scan vending terlebih dahulu
    if not scanVendingMachines() then
        return
    end
    
    local dialog = [[
add_label_with_icon|big|`9Edit Price Vending|left|9270|
add_textbox|`wSelect Vending (`4MAX 10 SELECT`w)|left|
add_spacer|small|
]]
    
    if totalVending == 0 then
        dialog = dialog .. "add_textbox|`4No vending machines found!|left|\n"
    else
        for i, vend in ipairs(vendingList) do
            -- Validasi data sebelum menampilkan
            if vend and vend.vendItem and vend.vendItem > 0 
               and vend.position and vend.position.x and vend.position.y then
                
                local displayText = string.format(
                    "`w%s - %d WL",
                    vend.vendItemName,
                    vend.vendPrice
                )
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_%d|%s||%d||0|\n",
                    i,
                    displayText,
                    vend.vendItem
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|edit_price|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

function show_table_edit_price()
    local dialog = [[
add_label_with_icon|big|`9Edit Price - Selected Items|left|9270|
add_spacer|small|
]]
    
    if #selectedVendings == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        for idx, vendIdx in ipairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                dialog = dialog .. string.format([[
add_textbox|`w%d. %s - %d WL at (%d,%d)|left|
add_text_input|price_vending_%d|New Price:||15|
add_checkbox|per_world_%d|`wPer World Lock|0|
add_spacer|small|
]], 
                    idx,
                    vend.vendItemName,
                    vend.vendPrice,
                    vend.position.x,
                    vend.position.y,
                    vendIdx,
                    vendIdx
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|apply_price|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

local function applyPriceChanges(packet)
    local totalSelected = #selectedVendings
    local processCount = 0
    local failCount = 0
    
    for _, vendIdx in ipairs(selectedVendings) do
        local pricePattern = "price_vending_" .. vendIdx .. "|([^|\n]+)"
        local newPriceStr = packet:match(pricePattern)
        local newPrice = tonumber(newPriceStr)
        local perWorldLock = packet:find("per_world_" .. vendIdx .. "|1") ~= nil
        
        if newPrice and newPrice > 0 then
            local vend = vendingList[vendIdx]
            
            if vend and vend.position then
                processCount = processCount + 1
                
                local priceLabel = perWorldLock and "Item" or "WL"
                local modeLabel  = perWorldLock and "Per World Lock" or "Per Item"

                LogToConsole(string.format(
                    "`9[%d/%d] `2Updating vending at (%d,%d): %s -> %d %s `o(%s)",
                    processCount,
                    totalSelected,
                    vend.position.x,
                    vend.position.y,
                    vend.vendItemName,
                    newPrice,
                    priceLabel,
                    modeLabel
                ))
                
                -- Kirim packet untuk update vending
                local packetData = string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|%d\nchk_peritem|%d\nchk_perlock|%d\n",
                    vend.position.x,
                    vend.position.y,
                    newPrice,
                    perWorldLock and 0 or 1,
                    perWorldLock and 1 or 0
                )
                
                SendPacket(2, packetData)
                Sleep(100) -- Delay 100ms per proses
            else
                failCount = failCount + 1
                LogToConsole("`4Invalid vending data at index " .. vendIdx)
            end
        else
            failCount = failCount + 1
            LogToConsole(string.format("`4Invalid price for vending %d: %s", vendIdx, newPriceStr or "nil"))
        end
    end
    
    LogToConsole(string.format(
        "`9[DONE] `2Success: %d | `4Failed: %d",
        processCount,
        failCount
    ))
    
    -- Clear selection
    selectedVendings = {}
end

-- ========================================
-- VENDING MACHINE TOOLS v1.3
-- ========================================

-- Global Variables
local vendingList = {}
local totalVending = 0
local selectedVendings = {}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Scan semua vending machines di world
local function scanVendingMachines()
    vendingList = {}
    totalVending = 0
    
    local tiles = GetTiles()
    if not tiles then
        LogToConsole("`4Error: Cannot get tiles!")
        return false
    end
    
    for _, tile in pairs(tiles) do
        -- Check if tile is vending machine (ID: 2796 atau 9268)
        if tile.fg == 9268 or tile.fg == 2978 then
            local vendData = {
                position = {
                    x = tile.x or 0,
                    y = tile.y or 0
                },
                vendItem = tile.extra.vend_item or 0,
                vendItemName = "Unknown",
                vendPrice = tile.extra.vend_price or 0,
                owner = tile.extra.owner or 0,
                label = tile.extra.label or ""
            }
            
            -- Get item name
            if vendData.vendItem > 0 then
                local itemInfo = getItemInfoByID(vendData.vendItem)
                if itemInfo and itemInfo.name then
                    vendData.vendItemName = itemInfo.name
                end
            end
            
            table.insert(vendingList, vendData)
            totalVending = totalVending + 1
        end
    end
    
    LogToConsole(string.format("`2Found %d vending machines!", totalVending))
    return true
end

-- Tampilkan vending list ke console
local function showVendingList()
    if totalVending == 0 then
        LogToConsole("`4No vending machines found!")
        return
    end
    
    LogToConsole("`9========== VENDING LIST ==========")
    for i, vend in ipairs(vendingList) do
        LogToConsole(string.format("`o%d. `2(%d, %d) `o- `3%s `o- Price: `e%d WL", 
            i, 
            vend.position.x, 
            vend.position.y,
            vend.vendItemName,
            vend.vendPrice
        ))
    end
    LogToConsole("`9==================================")
end

-- Export vending data ke file
local function exportVending()
    if totalVending == 0 then
        LogToConsole("`4No vending to export!")
        return
    end
    
    local output = {}
    table.insert(output, "VENDING SCAN - " .. GetWorldName())
    table.insert(output, "Total: " .. totalVending .. "\n")
    
    for i, vend in ipairs(vendingList) do
        table.insert(output, string.format("#%d - (%d,%d) - %s - %d WL", 
            i, vend.position.x, vend.position.y, vend.vendItemName, vend.vendPrice))
    end
    
    local filename = "vending_" .. GetWorldName() .. ".txt"
    writeToLocal(filename, table.concat(output, "\n"))
    LogToConsole("`2Exported to: " .. filename)
end

-- ========================================
-- DIALOG: MAIN MENU
-- ========================================

function show_menu()
    local dialog = [[
add_label_with_icon|big|`9Vending Machine Tools|left|9270|
add_spacer|small|
add_button|price_vendingss|Edit Price Vending|left|
add_button|empty_vending|Edit Empty Vending|left|
add_button|disable_vending|Edit Enable/Disable Vending|left|
add_button|kosongkan_vending|Edit Stock Vending|left|
add_spacer|small|
add_button|scan_vending|Scan All Vending|left|
add_button|export_vending|Export to File|left|
add_quick_exit||
end_dialog|main_menu|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

-- ========================================
-- FEATURE 1: EDIT PRICE VENDING
-- ========================================

function show_edit_price()
    -- Scan vending terlebih dahulu
    if not scanVendingMachines() then
        return
    end
    
    local dialog = [[
add_label_with_icon|big|`9Edit Price Vending|left|9270|
add_textbox|`wSelect Vending (`4MAX 10 SELECT`w)|left|
add_spacer|small|
]]
    
    if totalVending == 0 then
        dialog = dialog .. "add_textbox|`4No vending machines found!|left|\n"
    else
        for i, vend in ipairs(vendingList) do
            -- Validasi data sebelum menampilkan
            if vend and vend.vendItem and vend.vendItem > 0 
               and vend.position and vend.position.x and vend.position.y then
                
                local displayText = string.format(
                    "`w%s - %d WL",
                    vend.vendItemName,
                    vend.vendPrice
                )
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_%d|%s||%d||0|\n",
                    i,
                    displayText,
                    vend.vendItem
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|edit_price|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

function show_table_edit_price()
    local dialog = [[
add_label_with_icon|big|`9Edit Price - Selected Items|left|9270|
add_spacer|small|
]]
    
    if #selectedVendings == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        for idx, vendIdx in ipairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                dialog = dialog .. string.format([[
add_textbox|`w%d. %s - %d WL at (%d,%d)|left|
add_text_input|price_vending_%d|New Price:||15|
add_checkbox|per_world_%d|`wPer World Lock|0|
add_spacer|small|
]], 
                    idx,
                    vend.vendItemName,
                    vend.vendPrice,
                    vend.position.x,
                    vend.position.y,
                    vendIdx,
                    vendIdx
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|apply_price|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

local function applyPriceChanges(packet)
    local totalSelected = #selectedVendings
    local processCount = 0
    local failCount = 0
    
    for _, vendIdx in ipairs(selectedVendings) do
        local pricePattern = "price_vending_" .. vendIdx .. "|([^|\n]+)"
        local newPriceStr = packet:match(pricePattern)
        local newPrice = tonumber(newPriceStr)
        local perWorldLock = packet:find("per_world_" .. vendIdx .. "|1") ~= nil
        
        if newPrice and newPrice > 0 then
            local vend = vendingList[vendIdx]
            
            if vend and vend.position then
                processCount = processCount + 1
                
                local priceLabel = perWorldLock and "Item" or "WL"
                local modeLabel  = perWorldLock and "Per World Lock" or "Per Item"

                LogToConsole(string.format(
                    "`9[%d/%d] `2Updating vending at (%d,%d): %s -> %d %s `o(%s)",
                    processCount,
                    totalSelected,
                    vend.position.x,
                    vend.position.y,
                    vend.vendItemName,
                    newPrice,
                    priceLabel,
                    modeLabel
                ))
                
                -- Kirim packet untuk update vending
                local packetData = string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|%d\nchk_peritem|%d\nchk_perlock|%d\n",
                    vend.position.x,
                    vend.position.y,
                    newPrice,
                    perWorldLock and 0 or 1,
                    perWorldLock and 1 or 0
                )
                
                SendPacket(2, packetData)
                Sleep(100) -- Delay 100ms per proses
            else
                failCount = failCount + 1
                LogToConsole("`4Invalid vending data at index " .. vendIdx)
            end
        else
            failCount = failCount + 1
            LogToConsole(string.format("`4Invalid price for vending %d: %s", vendIdx, newPriceStr or "nil"))
        end
    end
    
    LogToConsole(string.format(
        "`9[DONE] `2Success: %d | `4Failed: %d",
        processCount,
        failCount
    ))
    
    -- Clear selection
    selectedVendings = {}
end

-- ========================================
-- FEATURE 2: EDIT EMPTY VENDING
-- ========================================

function show_empty_vending()
    if not scanVendingMachines() then return end
    
    -- Filter hanya vending yang kosong
    local emptyVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendItem == 0 then
            table.insert(emptyVendings, {
                originalIndex = i,
                vend = vend
            })
        end
    end
    
    local dialog = [[
add_label_with_icon|big|`9Edit Empty Vending|left|9270|
add_textbox|`wSelect Empty Vending (`4MAX 10 SELECT`w)|left|
add_spacer|small|
]]
    
    if #emptyVendings == 0 then
        dialog = dialog .. "add_textbox|`4No empty vending machines found!|left|\n"
    else
        for i, data in ipairs(emptyVendings) do
            local vend = data.vend
            local originalIdx = data.originalIndex
            
            if vend and vend.position and vend.position.x and vend.position.y then
                local displayText = string.format(
                    "`wVending (%d,%d)",
                    vend.position.x,
                    vend.position.y
                )
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_empty_%d|%s||2||0|\n",
                    originalIdx,
                    displayText
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|select_empty|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

function show_item_picker_for_empty(selectedItemID)
    local dialog = [[
add_label_with_icon|big|`9Set Item for Empty Vending|left|9270|
add_spacer|small|
]]
    
    -- Tampilkan list vending terpilih
    if #selectedVendings > 0 then
        dialog = dialog .. "add_textbox|`wSelected Vendings:|left|\n"
        for idx, vendIdx in ipairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                dialog = dialog .. string.format(
                    "add_textbox|`o%d. `wVending (%d,%d)|left|\n",
                    idx,
                    vend.position.x,
                    vend.position.y
                )
            end
        end
        dialog = dialog .. "add_spacer|small|\n"
    end
    
    -- Item picker
    dialog = dialog .. "add_item_picker|item|`wSelect Item:|242|\ndd_spacer|small|\n"
    
    -- Tampilkan info item yang dipilih
    if selectedItemID then
        local itemInfo = getItemInfoByID(selectedItemID)
        local itemName = itemInfo and itemInfo.name or "Unknown"
        dialog = dialog .. string.format(
            "add_textbox|`2Item Selected: `3%s`2, ID: `e%d|left|\n",
            itemName,
            selectedItemID
        )
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|apply_item_empty|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

local function applyItemToEmptyVending(packet)
    local itemID = tonumber(packet:match("item|(%d+)"))
    
    if not itemID then
        LogToConsole("`4No item selected!")
        return
    end
    
    local itemInfo = getItemInfoByID(itemID)
    local itemName = itemInfo and itemInfo.name or "Unknown"
    
    local totalSelected = #selectedVendings
    local successCount = 0
    local failCount = 0
    
    LogToConsole(string.format("`9Starting to fill %d vending(s) with `3%s `9(ID: `e%d`9)", 
        totalSelected, itemName, itemID))
    
    for idx, vendIdx in ipairs(selectedVendings) do
        local vend = vendingList[vendIdx]
        
        if vend and vend.position then
            successCount = successCount + 1
            
            LogToConsole(string.format(
                "`9[%d/%d] `2Filling vending at (%d,%d) with `3%s",
                successCount,
                totalSelected,
                vend.position.x,
                vend.position.y,
                itemName
            ))
            
            -- Kirim packet untuk stock item ke vending
            local packetData = string.format(
                "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nstockitem|%d\n",
                vend.position.x,
                vend.position.y,
                itemID
            )
            
            SendPacket(2, packetData)
            Sleep(150) -- Delay 150ms per proses
        else
            failCount = failCount + 1
            LogToConsole("`4Invalid vending data at index " .. vendIdx)
        end
    end
    
    LogToConsole(string.format(
        "`9[DONE] `2Success: %d | `4Failed: %d",
        successCount,
        failCount
    ))
    
    -- Clear selection
    selectedVendings = {}
end

-- ========================================
-- PACKET HOOK HANDLER (UPDATE)
-- ========================================

addHook(function(packetType, packet)
    if packetType ~= 2 then return false end
    
    -- Main menu trigger
    if packet:find("/start") then
        show_menu()
        return true
    end
    
    -- Feature 1: Edit Price Vending
    if packet:find("price_vendingss") then
        show_edit_price()
        return true
    end
    
    if packet:find("edit_price") then
        selectedVendings = {}
        
        for i = 1, totalVending do
            if packet:find("vending_" .. i .. "|1") then
                table.insert(selectedVendings, i)
                if #selectedVendings >= 10 then
                    LogToConsole("`4Maximum 10 vendings selected!")
                    break
                end
            end
        end
        
        if #selectedVendings > 0 then
            LogToConsole(string.format("`2Selected %d vending(s)", #selectedVendings))
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
    
    -- Feature 2: Edit Empty Vending
    if packet:find("empty_vending") then
        show_empty_vending()
        return true
    end
    
    if packet:find("select_empty") then
        selectedVendings = {}
        
        for i = 1, totalVending do
            if packet:find("vending_empty_" .. i .. "|1") then
                table.insert(selectedVendings, i)
                if #selectedVendings >= 10 then
                    LogToConsole("`4Maximum 10 vendings selected!")
                    break
                end
            end
        end
        
        if #selectedVendings > 0 then
            LogToConsole(string.format("`2Selected %d empty vending(s)", #selectedVendings))
            show_item_picker_for_empty()
        else
            LogToConsole("`4No vending selected!")
        end
        return true
    end
    
    if packet:find("apply_item_empty") then
        local itemID = tonumber(packet:match("item|(%d+)"))
        
        if itemID then
            -- Buka dialog lagi dengan info item terpilih
            show_item_picker_for_empty(itemID)
            -- Tapi juga proses apply-nya
            applyItemToEmptyVending(packet)
        else
            LogToConsole("`4No item selected!")
        end
        
        return true
    end
    
    -- Feature 3: Enable/Disable Vending (TODO)
    if packet:find("disable_vending") then
        LogToConsole("`4Feature not implemented yet!")
        return true
    end
    
    -- Feature 4: Edit Stock Vending (TODO)
    if packet:find("kosongkan_vending") then
        LogToConsole("`4Feature not implemented yet!")
        return true
    end
    
    -- Utility: Scan Vending
    if packet:find("scan_vending") then
        scanVendingMachines()
        showVendingList()
        return true
    end
    
    -- Utility: Export Vending
    if packet:find("export_vending") then
        exportVending()
        return true
    end
    
    return false
end, "OnSendPacket")

LogToConsole("Update 2.0")
