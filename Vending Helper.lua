-- ========================================
-- VENDING MACHINE TOOLS v1.9 - WITH PAGINATION
-- ========================================

-- Global Variables
local vendingList = {}
local totalVending = 0
local selectedVendings = {}
local selectedItems = {}
local isSelectingItems = false
local itemSelectionCount = 0
local maxSelectionCount = 0

-- Pagination Variables
local currentPage = 1
local itemsPerPage = 100

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
                fgID = tile.fg
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
        return "staticBlueFrame"
    elseif fgID == 9268 then
        return "staticYellowFrame"
    else
        return ""
    end
end

-- Fungsi untuk menghitung total halaman
local function getTotalPages(totalItems)
    return math.ceil(totalItems / itemsPerPage)
end

-- Fungsi untuk mendapatkan item dalam halaman tertentu
local function getPageItems(items, page)
    local startIdx = (page - 1) * itemsPerPage + 1
    local endIdx = math.min(page * itemsPerPage, #items)
    local pageItems = {}
    
    for i = startIdx, endIdx do
        table.insert(pageItems, {
            index = i,
            data = items[i]
        })
    end
    
    return pageItems
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
    
    currentPage = 1  -- Reset ke halaman pertama
    show_edit_price_page()
end

function show_edit_price_page()
    local totalPages = getTotalPages(totalVending)
    
    local dialog = [[
add_label_with_icon|big|`9Edit Price Vending|left|9270|
add_textbox|`wSelect Vending|left|
add_spacer|small|
]]
    
    if totalVending == 0 then
        dialog = dialog .. "add_textbox|`4No vending machines found!|left|\n"
    else
        local pageItems = getPageItems(vendingList, currentPage)
        
        for _, item in ipairs(pageItems) do
            local i = item.index
            local vend = item.data
            
            if vend and vend.vendItem and vend.vendItem > 0 
               and vend.position and vend.position.x and vend.position.y then
                
                local displayText = string.format(
                    "`w%s - %d WL",
                    vend.vendItemName,
                    vend.vendPrice
                )
                
                local frame = getFrameByFG(vend.fgID)
                
                -- Cek apakah vending ini sudah dipilih
                local isChecked = selectedVendings[i] and 1 or 0
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_%d|%s|%s|%d||%d|\n",
                    i,
                    displayText,
                    frame,
                    vend.vendItem,
                    isChecked
                )
            end
        end
        
        -- Pagination info
        dialog = dialog .. string.format(
            "add_spacer|small|\nadd_textbox|`9Page (%d/%d) `o- Total Selected: `2%d|left|\n",
            currentPage,
            totalPages,
            #selectedVendings
        )
        
        -- Navigation buttons
        dialog = dialog .. "add_spacer|small|\n"
        
        if currentPage > 1 then
            dialog = dialog .. "add_button|prev_page_edit|`wPrevious Page|left|\n"
        end
        
        if currentPage < totalPages then
            dialog = dialog .. "add_button|next_page_edit|`wNext Page|left|\n"
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
]], 
                    count,
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
        
        local totalSelected = 0
        for _ in pairs(selectedVendings) do
            totalSelected = totalSelected + 1
        end
        
        local processCount = 0
        local failCount = 0
        
        for vendIdx, _ in pairs(selectedVendings) do
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
    
    currentPage = 1  -- Reset ke halaman pertama
    show_empty_vending_page()
end

function show_empty_vending_page()
    local emptyVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendItem == 0 then
            table.insert(emptyVendings, {
                originalIndex = i,
                vend = vend
            })
        end
    end
    
    local totalPages = getTotalPages(#emptyVendings)
    
    local dialog = [[
add_label_with_icon|big|`9Edit Empty Vending|left|9270|
add_textbox|`wSelect Empty Vending|left|
add_spacer|small|
]]
    
    if #emptyVendings == 0 then
        dialog = dialog .. "add_textbox|`4No empty vending machines found!|left|\n"
    else
        local pageItems = getPageItems(emptyVendings, currentPage)
        
        for _, item in ipairs(pageItems) do
            local data = item.data
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
                
                -- Cek apakah vending ini sudah dipilih
                local isChecked = selectedVendings[originalIdx] and 1 or 0
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_empty_%d|%s|%s|2||%d|\n",
                    originalIdx,
                    displayText,
                    frame,
                    isChecked
                )
            end
        end
        
        -- Pagination info
        dialog = dialog .. string.format(
            "add_spacer|small|\nadd_textbox|`9Page (%d/%d) `o- Total Selected: `2%d|left|\n",
            currentPage,
            totalPages,
            #selectedVendings
        )
        
        -- Navigation buttons
        dialog = dialog .. "add_spacer|small|\n"
        
        if currentPage > 1 then
            dialog = dialog .. "add_button|prev_page_empty|`wPrevious Page|left|\n"
        end
        
        if currentPage < totalPages then
            dialog = dialog .. "add_button|next_page_empty|`wNext Page|left|\n"
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
    
    local totalSelected = 0
    for _ in pairs(selectedVendings) do
        totalSelected = totalSelected + 1
    end
    
    if totalSelected == 0 then
        dialog = dialog .. "add_textbox|`4No vending selected!|left|\n"
    else
        local count = 0
        for vendIdx, _ in pairs(selectedVendings) do
            local vend = vendingList[vendIdx]
            if vend then
                count = count + 1
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
                    count,
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
                local itemName = itemInfo and itemInfo.name or "Unknown"
                itemText = string.format("`2%s `9(ID: `e%d`9)", itemName, itemID)
            else
                hasAllItems = false
            end
            
            dialog = dialog .. string.format(
                "add_textbox|`w%d. %s `9(%d,%d) `w-> %s|left|\n",
                count,
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
        
        local totalSelected = 0
        for _ in pairs(selectedVendings) do
            totalSelected = totalSelected + 1
        end
        
        local successCount = 0
        local failCount = 0
        
        LogToConsole(string.format("`9Starting to fill %d vending(s)...", totalSelected))
        
        for vendIdx, _ in pairs(selectedVendings) do
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
    
    currentPage = 1  -- Reset ke halaman pertama
    show_disable_vending_page()
end

function show_disable_vending_page()
    local activeVendings = {}
    for i, vend in ipairs(vendingList) do
        if vend.vendPrice ~= 0 then
            table.insert(activeVendings, {
                originalIndex = i,
                vend = vend
            })
        end
    end
    
    local totalPages = getTotalPages(#activeVendings)
    
    local dialog = [[
add_label_with_icon|big|`9Disable Vending|left|9270|
add_textbox|`wSelect Vending to Disable (Only Active Vending)|left|
add_spacer|small|
]]
    
    if #activeVendings == 0 then
        dialog = dialog .. "add_textbox|`4No active vending machines found!|left|\n"
    else
        local pageItems = getPageItems(activeVendings, currentPage)
        
        for _, item in ipairs(pageItems) do
            local data = item.data
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
                
                -- Cek apakah vending ini sudah dipilih
                local isChecked = selectedVendings[originalIdx] and 1 or 0
                
                dialog = dialog .. string.format(
                    "add_checkicon|vending_disable_%d|%s|%s|%d||%d|\n",
                    originalIdx,
                    displayText,
                    frame,
                    vend.vendItem > 0 and vend.vendItem or 2,
                    isChecked
                )
            end
        end
        
        -- Pagination info
        dialog = dialog .. string.format(
            "add_spacer|small|\nadd_textbox|`9Page (%d/%d) `o- Total Selected: `2%d|left|\n",
            currentPage,
            totalPages,
            #selectedVendings
        )
        
        -- Navigation buttons
        dialog = dialog .. "add_spacer|small|\n"
        
        if currentPage > 1 then
            dialog = dialog .. "add_button|prev_page_disable|`wPrevious Page|left|\n"
        end
        
        if currentPage < totalPages then
            dialog = dialog .. "add_button|next_page_disable|`wNext Page|left|\n"
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
        
        local totalSelected = 0
        for _ in pairs(selectedVendings) do
            totalSelected = totalSelected + 1
        end
        
        local successCount = 0
        local failCount = 0
        
        LogToConsole(string.format("`9Starting to disable %d vending(s)...", totalSelected))
        
        for vendIdx, _ in pairs(selectedVendings) do
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
        
        selectedVendings = {}
    end)
end

-- ========================================
-- PACKET HOOK HANDLER
-- ========================================

-- Helper function to save current page selections before navigating
local function saveCurrentPageSelections(packet, prefix)
    for i = 1, totalVending do
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
    
    if packet:find("/start") then
        show_menu()
        return true
    end
    
    if packet:find("price_vendingss") then
        show_edit_price()
        return true
    end
    
    -- Navigation for Edit Price
    if packet:find("next_page_edit") then
        -- Save current page selections before moving to next page
        saveCurrentPageSelections(packet, "vending")
        currentPage = currentPage + 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("prev_page_edit") then
        -- Save current page selections before moving to previous page
        saveCurrentPageSelections(packet, "vending")
        currentPage = currentPage - 1
        show_edit_price_page()
        return true
    end
    
    if packet:find("edit_price") then
        -- Simpan pilihan user dari halaman saat ini
        -- Using helper function for consistency
        saveCurrentPageSelections(packet, "vending")
        
        -- Konversi ke array untuk tampilan
        local tempArray = {}
        for idx, _ in pairs(selectedVendings) do
            table.insert(tempArray, idx)
        end
        
        if #tempArray > 0 then
            LogToConsole(string.format("`2Selected %d vending(s)", #tempArray))
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
    
    -- Navigation for Empty Vending
    if packet:find("next_page_empty") then
        -- Save current page selections before moving to next page
        saveCurrentPageSelections(packet, "vending_empty")
        currentPage = currentPage + 1
        show_empty_vending_page()
        return true
    end

    if packet:find("prev_page_empty") then
        -- Save current page selections before moving to previous page
        saveCurrentPageSelections(packet, "vending_empty")
        currentPage = currentPage - 1
        show_empty_vending_page()
        return true
    end
    
    if packet:find("select_empty") then
        -- Simpan pilihan user dari halaman saat ini
        -- Using helper function for consistency
        saveCurrentPageSelections(packet, "vending_empty")
        
        -- Hitung jumlah vending yang dipilih
        local count = 0
        for _ in pairs(selectedVendings) do
            count = count + 1
        end
        
        if count > 0 then
            maxSelectionCount = count
            itemSelectionCount = 0
            isSelectingItems = true
            LogToConsole(string.format("`2Selected %d empty vending(s)", count))
            show_item_picker_for_empty()
        else
            LogToConsole("`4No empty vending selected!")
        end
        return true
    end
    
    if packet:find("item_picker_empty") then
        -- Simpan item yang dipilih
        for vendIdx, _ in pairs(selectedVendings) do
            local pattern = "item_" .. vendIdx .. "|(%d+)"
            local itemID = packet:match(pattern)
            if itemID then
                itemID = tonumber(itemID)
                if itemID and itemID > 0 then
                    selectedItems[vendIdx] = itemID
                end
            end
        end
        
        -- Hitung berapa item yang sudah dipilih
        itemSelectionCount = 0
        for vendIdx, _ in pairs(selectedVendings) do
            if selectedItems[vendIdx] then
                itemSelectionCount = itemSelectionCount + 1
            end
        end
        
        -- Jika semua sudah dipilih, langsung ke konfirmasi
        if itemSelectionCount >= maxSelectionCount then
            LogToConsole("`2All items selected! Moving to confirmation...")
            show_confirmation_empty()
        else
            -- Masih ada yang belum dipilih, tampilkan lagi picker
            show_item_picker_for_empty()
        end
        return true
    end
    
    if packet:find("confirm_item_empty") then
        if packet:find("buttonClicked|Confirm") then
            applyEmptyVending()
        else
            -- Back button
            show_item_picker_for_empty()
        end
        return true
    end
    
    if packet:find("disable_vending") then
        show_disable_vending()
        return true
    end
    
    -- Navigation for Disable Vending
    if packet:find("next_page_disable") then
        -- Save current page selections before moving to next page
        saveCurrentPageSelections(packet, "vending_disable")
        currentPage = currentPage + 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("prev_page_disable") then
        -- Save current page selections before moving to previous page
        saveCurrentPageSelections(packet, "vending_disable")
        currentPage = currentPage - 1
        show_disable_vending_page()
        return true
    end
    
    if packet:find("apply_disable") then
        -- Simpan pilihan user dari halaman saat ini
        -- Using helper function for consistency
        saveCurrentPageSelections(packet, "vending_disable")
        
        -- Hitung jumlah vending yang dipilih
        local count = 0
        for _ in pairs(selectedVendings) do
            count = count + 1
        end
        
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

LogToConsole("`2Vending Machine Tools v2.0 Loaded!")
LogToConsole("`9Type /start to open menu")
watermark()
