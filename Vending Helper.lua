-- ========================================
-- VENDING MACHINE TOOLS v1.8 - FRAME DIFFERENTIATION
-- ========================================

-- Global Variables
local vendingList = {}
local totalVending = 0
local selectedVendings = {}
local selectedItems = {}
local isSelectingItems = false
local itemSelectionCount = 0
local maxSelectionCount = 0

function watermark()
local dialog = [[
add_label_with_icon|big|`wX-SCRIPT|left|15110|
add_textbox|`wTerima Kasih Telah Menggunakan Script dari X-SCRIPT, Untuk Update Selanjutnya Silahkan Klik Button Di bawah Ini!|left|
add_url_button|comment|`wOpen Channel X-SCRIPT|color:0,0,0,0|https://whatsapp.com/channel/0029Vb60Vev2phHGjCHMpp3h||0|0|
add_quick_exit||
end_dialog|watermark|CANCEL|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

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
                label = tile.extra.label or "",
                fgID = tile.fg  -- TAMBAHAN: Simpan foreground ID
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

-- Fungsi helper untuk mendapatkan frame berdasarkan fg ID
local function getFrameByFG(fgID)
    if fgID == 2978 then
        return "staticBlueFrame"  -- Vending biasa
    elseif fgID == 9268 then
        return "staticYellowFrame"  -- DigiVending
    else
        return ""  -- Default tanpa frame
    end
end

-- Tampilkan vending list ke console
local function showVendingList()
    if totalVending == 0 then
        LogToConsole("`4No vending machines found!")
        return
    end
    
    LogToConsole("`9========== VENDING LIST ==========")
    for i, vend in ipairs(vendingList) do
        local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
        LogToConsole(string.format("`o%d. %s `2(%d, %d) `o- `3%s `o- Price: `e%d WL", 
            i,
            vendType,
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
        local vendType = vend.fgID == 2978 and "[Vending]" or "[DigiVend]"
        table.insert(output, string.format("#%d %s - (%d,%d) - %s - %d WL", 
            i, vendType, vend.position.x, vend.position.y, vend.vendItemName, vend.vendPrice))
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
add_button|price_vendingss|`wEdit Price Vending|left|
add_button|empty_vending|`wEdit Empty Vending|left|
add_button|disable_vending|`wDisable Vending|left|
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
    if not scanVendingMachines() then
        return
    end
    
    local dialog = [[
add_label_with_icon|big|`9Edit Price Vending|left|9270|
add_textbox|`wSelect Vending|left|
add_spacer|small|
]]
    
    if totalVending == 0 then
        dialog = dialog .. "add_textbox|`4No vending machines found!|left|\n"
    else
        for i, vend in ipairs(vendingList) do
            if vend and vend.vendItem and vend.vendItem > 0 
               and vend.position and vend.position.x and vend.position.y then
                
                local displayText = string.format(
                    "`w%s - %d WL",
                    vend.vendItemName,
                    vend.vendPrice
                )
                
                local frame = getFrameByFG(vend.fgID)
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_%d|%s|%s|%d||0|\n",
                    i,
                    displayText,
                    frame,
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
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                dialog = dialog .. string.format([[
add_textbox|`w%d. %s %s - %d WL at (%d,%d)|left|
add_text_input|price_vending_%d|New Price:||15|
add_checkbox|per_world_%d|`wPer World Lock|0|
add_spacer|small|
]], 
                    idx,
                    vendType,
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
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local totalSelected = #selectedVendings
        local processCount = 0
        local failCount = 0
        
        --LogToConsole("`9========== STARTING PRICE UPDATE ==========")
        
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
                    
                    local packetData = string.format(
                        "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|%d\nchk_peritem|%d\nchk_perlock|%d\n",
                        vend.position.x,
                        vend.position.y,
                        newPrice,
                        perWorldLock and 0 or 1,
                        perWorldLock and 1 or 0
                    )
                    
                    SendPacket(2, packetData)
                    Sleep(500)
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
        
        selectedVendings = {}
    end)
end

-- ========================================
-- FEATURE 2: EDIT EMPTY VENDING
-- ========================================

function show_empty_vending()
    if not scanVendingMachines() then return end
    
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
add_textbox|`wSelect Empty Vending|left|
add_spacer|small|
]]
    
    if #emptyVendings == 0 then
        dialog = dialog .. "add_textbox|`4No empty vending machines found!|left|\n"
    else
        for i, data in ipairs(emptyVendings) do
            local vend = data.vend
            local originalIdx = data.originalIndex
            
            if vend and vend.position and vend.position.x and vend.position.y then
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                local displayText = string.format(
                    "`w%s (%d,%d)",
                    vendType,
                    vend.position.x,
                    vend.position.y
                )
                
                local frame = getFrameByFG(vend.fgID)
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_empty_%d|%s|%s|2||0|\n",
                    originalIdx,
                    displayText,
                    frame
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

function show_item_picker_for_empty()
    local dialog = [[
add_label_with_icon|big|`9Set Item for Empty Vending|left|9270|
add_textbox|`wSelect item for each vending:|left|
add_spacer|small|
]]
    
    if #selectedVendings == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        for idx, vendIdx in ipairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                local selectedItemText = ""
                if selectedItems[vendIdx] then
                    local itemInfo = getItemInfoByID(selectedItems[vendIdx])
                    local itemName = itemInfo and itemInfo.name or "Unknown"
                    selectedItemText = string.format(" `2(Selected: %s)", itemName)
                end
                
                local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
                
                dialog = dialog .. string.format([[
add_textbox|`w%d. %s (%d,%d)%s|left|
add_item_picker|item_%d|`wSelect Item:|%s|
add_spacer|small|
]], 
                    idx,
                    vendType,
                    vend.position.x,
                    vend.position.y,
                    selectedItemText,
                    vendIdx,
                    selectedItems[vendIdx] or "242"
                )
            end
        end
    end
    
    dialog = dialog .. string.format(
        "add_textbox|`oSelection Counter: `e%d/%d `o(Auto-confirm when full)|left|\n",
        itemSelectionCount,
        maxSelectionCount
    )
    
    dialog = dialog .. [[
add_textbox|`oClick OK to continue or keep selecting items.|left|
add_quick_exit||
end_dialog|item_picker_empty|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

function show_confirmation_empty()
    local dialog = [[
add_label_with_icon|big|`9Confirm Items - Empty Vending|left|9270|
add_textbox|`wReview your selection before applying:|left|
add_spacer|small|
]]
    
    local hasAllItems = true
    
    for idx, vendIdx in ipairs(selectedVendings) do
        local vend = vendingList[vendIdx]
        local itemID = selectedItems[vendIdx]
        
        if vend then
            local vendType = vend.fgID == 2978 and "`1[Vending]" or "`e[DigiVend]"
            local itemText = "`4No item selected"
            if itemID and itemID > 0 then
                local itemInfo = getItemInfoByID(itemID)
                local itemName = itemInfo and itemInfo.name or "Unknown"
                itemText = string.format("`2%s `9(ID: `e%d`9)", itemName, itemID)
            else
                hasAllItems = false
            end
            
            dialog = dialog .. string.format(
                "add_textbox|`w%d. %s `9(%d,%d) `w-> %s|left|\n",
                idx,
                vendType,
                vend.position.x,
                vend.position.y,
                itemText
            )
        end
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    
    if not hasAllItems then
        dialog = dialog .. "add_textbox|`4Warning: Some vendings have no item selected!|left|\n"
    end
    
    dialog = dialog .. [[
add_textbox|`oClick Confirm to apply all items to vending machines|left|
add_quick_exit||
end_dialog|confirm_item_empty|Back|Confirm|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

local function applyEmptyVending()
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local totalSelected = #selectedVendings
        local successCount = 0
        local failCount = 0
        
        --LogToConsole("`9========== APPLYING ITEMS TO VENDING ==========")
        LogToConsole(string.format("`9Starting to fill %d vending(s)...", totalSelected))
        
        for _, vendIdx in ipairs(selectedVendings) do
            local itemID = selectedItems[vendIdx]
            
            if itemID and itemID > 0 then
                local vend = vendingList[vendIdx]
                
                if vend and vend.position then
                    successCount = successCount + 1
                    
                    local itemInfo = getItemInfoByID(itemID)
                    local itemName = itemInfo and itemInfo.name or "Unknown"
                    
                    LogToConsole(string.format(
                        "`9[%d/%d] `2Filling vending at (%d,%d) with `3%s `9(ID: `e%d`9)",
                        successCount,
                        totalSelected,
                        vend.position.x,
                        vend.position.y,
                        itemName,
                        itemID
                    ))
                    
                    local packetData = string.format(
                        "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nstockitem|%d\n",
                        vend.position.x,
                        vend.position.y,
                        itemID
                    )
                    
                    SendPacket(2, packetData)
                    Sleep(500)
                else
                    failCount = failCount + 1
                    LogToConsole("`4Invalid vending data at index " .. vendIdx)
                end
            else
                failCount = failCount + 1
                LogToConsole("`4No item selected for vending index " .. vendIdx)
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
     --   LogToConsole("`9===============================================")
        
        selectedVendings = {}
        selectedItems = {}
        itemSelectionCount = 0
        maxSelectionCount = 0
    end)
end

-- ========================================
-- FEATURE 3: DISABLE VENDING
-- ========================================

function show_disable_vending()
    if not scanVendingMachines() then return end
    
    local activeVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendPrice ~= 0 then
            table.insert(activeVendings, {
                originalIndex = i,
                vend = vend
            })
        end
    end
    
    local dialog = [[
add_label_with_icon|big|`9Disable Vending|left|9270|
add_textbox|`wSelect Vending to Disable (Only Active Vending)|left|
add_spacer|small|
]]
    
    if #activeVendings == 0 then
        dialog = dialog .. "add_textbox|`4No active vending machines found!|left|\n"
    else
        for i, data in ipairs(activeVendings) do
            local vend = data.vend
            local originalIdx = data.originalIndex
            
            if vend and vend.position and vend.position.x and vend.position.y then
                local vendType = "`w"
                local displayText = string.format(
                    "`w%s (%d,%d) - %s - `e%d WL",
                    vendType,
                    vend.position.x,
                    vend.position.y,
                    vend.vendItemName,
                    vend.vendPrice
                )
                
                local frame = getFrameByFG(vend.fgID)
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_disable_%d|%s|%s|%d||0|\n",
                    originalIdx,
                    displayText,
                    frame,
                    vend.vendItem > 0 and vend.vendItem or 2
                )
            end
        end
    end
    
    dialog = dialog .. [[
add_quick_exit||
end_dialog|apply_disable|Cancel|OK|
]]
    
    SendVariant({
        v1 = "OnDialogRequest",
        v2 = dialog
    })
end

local function applyDisableVending()
    runThread(function()
        LogToConsole("`eWaiting 5 sec before starting...")
        Sleep(5000)
        
        local totalSelected = #selectedVendings
        local successCount = 0
        local failCount = 0
        
        --LogToConsole("`9========== DISABLING VENDING ==========")
        LogToConsole(string.format("`9Starting to disable %d vending(s)...", totalSelected))
        
        for _, vendIdx in ipairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            
            if vend and vend.position then
                successCount = successCount + 1
                
                LogToConsole(string.format(
                    "`9[%d/%d] `2Disabling vending at (%d,%d)",
                    successCount,
                    totalSelected,
                    vend.position.x,
                    vend.position.y
                ))
                
                local packetData = string.format(
                    "action|dialog_return\ndialog_name|vending\ntilex|%d|\ntiley|%d|\nsetprice|0\nchk_peritem|1\nchk_perlock|0\n",
                    vend.position.x,
                    vend.position.y
                )
                
                SendPacket(2, packetData)
                Sleep(500)
            else
                failCount = failCount + 1
                LogToConsole("`4Invalid vending data at index " .. vendIdx)
            end
        end
        
        LogToConsole(string.format("`9[DONE] `2Success: %d | `4Failed: %d", successCount, failCount))
       -- LogToConsole("`9=======================================")
        
        selectedVendings = {}
    end)
end

-- ========================================
-- PACKET HOOK HANDLER
-- ========================================

addHook(function(packetType, packet)
    if packetType ~= 2 then return false end
    
    if packet:find("/start") then
        show_menu()
        return true
    end
    
    if packet:find("price_vendingss") then
        show_edit_price()
        return true
    end
    
    if packet:find("edit_price") then
        selectedVendings = {}
        
        for i = 1, totalVending do
            if packet:find("vending_" .. i .. "|1") then
                table.insert(selectedVendings, i)
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
    
    if packet:find("empty_vending") then
        show_empty_vending()
        return true
    end
    
    if packet:find("select_empty") then
        selectedVendings = {}
        selectedItems = {}
        itemSelectionCount = 0
        isSelectingItems = true
        
        for i = 1, totalVending do
            if packet:find("vending_empty_" .. i .. "|1") then
                table.insert(selectedVendings, i)
            end
        end
        
        if #selectedVendings > 0 then
            maxSelectionCount = #selectedVendings + 10
            LogToConsole(string.format("`2Selected %d empty vending(s)", #selectedVendings))
            LogToConsole(string.format("`9You have %d selection chances before auto-confirm", maxSelectionCount))
            show_item_picker_for_empty()
        else
            LogToConsole("`4No vending selected!")
            isSelectingItems = false
        end
        return true
    end
    
    if packet:find("item_picker_empty") and isSelectingItems then
        local hasButtonId = packet:find("buttonClicked|")
        
        local hasNewSelection = false
        for _, vendIdx in ipairs(selectedVendings) do
            local itemIDStr = packet:match("item_" .. vendIdx .. "|(%d+)")
            local itemID = tonumber(itemIDStr)
            
            if itemID and itemID > 0 then
                if not selectedItems[vendIdx] or selectedItems[vendIdx] ~= itemID then
                    selectedItems[vendIdx] = itemID
                    hasNewSelection = true
                    
                    local itemInfo = getItemInfoByID(itemID)
                    local itemName = itemInfo and itemInfo.name or "Unknown"
                    LogToConsole(string.format("`2Vending %d: Updated to %s (ID: %d)", vendIdx, itemName, itemID))
                end
            end
        end
        
        itemSelectionCount = itemSelectionCount + 1
        LogToConsole(string.format("`9Selection count: %d/%d", itemSelectionCount, maxSelectionCount))
        
        if itemSelectionCount >= maxSelectionCount or hasButtonId then
            LogToConsole("`2Selection completed! Moving to confirmation...")
            isSelectingItems = false
            itemSelectionCount = 0
            show_confirmation_empty()
        else
            show_item_picker_for_empty()
        end
        
        return true
    end
    
    if packet:find("confirm_item_empty") then
        applyEmptyVending()
        return true
    end
    
    if packet:find("disable_vending") then
        show_disable_vending()
        return true
    end
    
    if packet:find("apply_disable") then
        selectedVendings = {}
        
        for i = 1, totalVending do
            if packet:find("vending_disable_" .. i .. "|1") then
                table.insert(selectedVendings, i)
            end
        end
        
        if #selectedVendings > 0 then
            LogToConsole(string.format("`2Selected %d vending(s) to disable", #selectedVendings))
            applyDisableVending()
        else
            LogToConsole("`4No vending selected!")
        end
        return true
    end
    
    if packet:find("scan_vending") then
        scanVendingMachines()
        showVendingList()
        return true
    end
    
    if packet:find("export_vending") then
        exportVending()
        return true
    end
    
    return false
end, "OnSendPacket")

watermark()
LogToConsole("`2Vending Machine Tools v2.2 [X-SCRIPT]")
LogToConsole("`9Type /start to open menu")
