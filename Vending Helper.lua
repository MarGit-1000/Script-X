-- ========================================
-- VENDING MACHINE SCANNER + DIALOG
-- ========================================

local vendingList = {}
local totalVending = 0
local selectedVendings = {}

-- ========================================
-- CORE FUNCTIONS
-- ========================================

-- Fungsi untuk scan semua vending machines
local function scanVendingMachines()
    vendingList = {}
    totalVending = 0
    
    local tiles = GetTiles()
    if not tiles then
        LogToConsole("`4Error: Cannot get tiles!")
        return false
    end
    
    for _, tile in pairs(tiles) do
        -- Cek apakah tile adalah vending machine (ID: 2796 atau 9268)
        if tile.fg == 9268 or tile.fg == 2978 then
            local vendData = {
                position = {
                    x = tile.x or 0,
                    y = tile.y or 0
                },
                vendItem = tile.extra.vend_item or 2,
                vendItemName = "Unknown",
                vendPrice = tile.extra.vend_price or 0,
                owner = tile.extra.owner or 0,
                label = tile.extra.label or ""
            }
            
            -- Ambil nama item
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

-- Fungsi untuk tampilkan hasil ke console
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

-- Fungsi untuk export ke file
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

-- Fungsi untuk cari vending berdasarkan item
local function findVendingByItem(itemName)
    local found = {}
    
    for _, vend in ipairs(vendingList) do
        if vend.vendItemName:lower():find(itemName:lower()) then
            table.insert(found, vend)
        end
    end
    
    return found
end

-- Fungsi untuk sort berdasarkan harga
local function sortByPrice(ascending)
    if totalVending == 0 then return end
    
    table.sort(vendingList, function(a, b)
        if ascending then
            return a.vendPrice < b.vendPrice
        else
            return a.vendPrice > b.vendPrice
        end
    end)
    LogToConsole("`2Sorted by price (" .. (ascending and "ascending" or "descending") .. ")")
end

-- ========================================
-- DIALOG FUNCTIONS
-- ========================================

function show_menu()
    local dialog = [[
add_label_with_icon|big|`9Vending Machine Tools|left|9270|
add_spacer|small|
add_button|price_vendingss|Edit Price Vending|left|
add_button|item_vending|Edit Item Vending|left|
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
                    "%s - %d WL at (%d,%d)",
                    vend.vendItemName,
                    vend.vendPrice,
                    vend.position.x,
                    vend.position.y
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
                    vend.vendPrice,
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

-- ========================================
-- PACKET HOOK
-- ========================================

addHook(function(packetType, packet)
    -- Main menu
    if packetType == 2 and packet:find("/start") then
        show_menu()
        return true
    
    -- Scan vending
    elseif packetType == 2 and packet:find("scan_vending") then
        scanVendingMachines()
        showVendingList()
        return true
    
    -- Export vending
    elseif packetType == 2 and packet:find("export_vending") then
        exportVending()
        return true
    
    -- Show edit price dialog
    elseif packetType == 2 and packet:find("price_vendingss") then
        show_edit_price()
        return true
    
    -- Process vending selection
    elseif packetType == 2 and packet:find("edit_price") then
        selectedVendings = {}
        
        -- Parse checkbox selections
        for i = 1, totalVending do
            if packet:find("vending_" .. i .. "|1") then
                table.insert(selectedVendings, i)
                
                -- Limit maksimal 10
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
    
    -- Apply price changes
    elseif packetType == 2 and packet:find("apply_price") then
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
        return true
    end
    
    return false
end, "OnSendPacket")
