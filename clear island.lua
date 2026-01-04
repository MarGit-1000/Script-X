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

-- Konfigurasi prioritas block
local blockPriority = {
    {id = 16, name = "Grass", priority = 1},
    {id = 1004, name = "Hedge", priority = 2},
    {id = 1104, name = "Foliage", priority = 3},
    {id = 7224, name = "Oak Tree", priority = 4},
    {id = 1102, name = "Sequoia Tree", priority = 5},
    {id = 190, name = "Rose", priority = 6},
    {id = 2, name = "Dirt", priority = 7},
    {id = 728, name = "Clouds", priority = 8},
    {id = 3564, name = "Cave Dirt", priority = 9},
    {id = 612, name = "Lattice Background", priority = 10}
}

-- Fungsi untuk punch block
local function punch(x, y)
    local d = {
        x = x * 32,
        y = y * 32,
        px = x,
        py = y,
        type = 3,
        value = 18,
    }
    SendPacketRaw(false, d)
    Sleep(50)
end

-- Fungsi untuk scan world dan mengelompokkan block berdasarkan ID
local function scanWorld()
    local blocks = {}
    
    for _, block in pairs(GetTiles()) do
        if block.fg ~= 0 or block.bg ~= 0 then
            -- Cek foreground block
            if block.fg ~= 0 then
                for _, priority in ipairs(blockPriority) do
                    if priority.id == block.fg then
                        local key = block.fg .. "_fg"
                        if not blocks[key] then
                            blocks[key] = {}
                        end
                        table.insert(blocks[key], {
                            x = block.x,
                            y = block.y,
                            priority = priority.priority,
                            name = priority.name,
                            blockId = block.fg,
                            isBackground = false
                        })
                        break
                    end
                end
            end
            
            -- Cek background block
            if block.bg ~= 0 then
                for _, priority in ipairs(blockPriority) do
                    if priority.id == block.bg then
                        local key = block.bg .. "_bg"
                        if not blocks[key] then
                            blocks[key] = {}
                        end
                        table.insert(blocks[key], {
                            x = block.x,
                            y = block.y,
                            priority = priority.priority,
                            name = priority.name .. " (BG)",
                            blockId = block.bg,
                            isBackground = true
                        })
                        break
                    end
                end
            end
        end
    end
    
    -- Sort setiap grup block berdasarkan x dan y terkecil
    for key, blockList in pairs(blocks) do
        table.sort(blockList, function(a, b)
            if a.x == b.x then
                return a.y < b.y
            end
            return a.x < b.x
        end)
    end
    
    return blocks
end

-- Fungsi untuk cek jarak ke block
local function getDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- Fungsi untuk cek apakah block dalam jangkauan punch
local function isInPunchRange(x, y)
    local botX = math.floor(GetLocal().pos.x / 32)
    local botY = math.floor(GetLocal().pos.y / 32)
    local distance = getDistance(botX, botY, x, y)
    return distance <= 5
end

-- Fungsi untuk mencoba pindah ke dekat block
local function moveNearBlock(x, y)
    if isInPunchRange(x, y) then
        return true
    end
    
    local positions = {
        {x = x, y = y + 1},
        {x = x, y = y - 1},
        {x = x - 1, y = y},
        {x = x + 1, y = y},
        {x = x - 1, y = y + 1},
        {x = x + 1, y = y + 1},
        {x = x - 1, y = y - 1},
        {x = x + 1, y = y - 1},
    }
    
    for _, pos in ipairs(positions) do
        if findPath(pos.x, pos.y) then
            Sleep(50)
            if isInPunchRange(x, y) then
                return true
            end
            Sleep(50)
        end
    end
    
    return false
end

-- Fungsi untuk cek apakah block masih ada
local function isBlockExists(x, y, blockId, isBackground)
    local tile = GetTile(x, y)
    if not tile then return false end
    
    if isBackground then
        return tile.bg == blockId
    else
        return tile.fg == blockId
    end
end

-- Fungsi utama untuk menghancurkan semua block sesuai prioritas
local function destroyAllBlocks()
    LogToConsole("Memulai proses penghancuran block (FG & BG)...")
    
    for _, priority in ipairs(blockPriority) do
        local blockId = priority.id
        local blockName = priority.name
        
        -- Proses FG blocks dulu
        LogToConsole("Memproses: " .. blockName .. " (FG) (ID: " .. blockId .. ")")
        processBlockType(blockId, blockName, false)
        
        -- Kemudian proses BG blocks
        LogToConsole("Memproses: " .. blockName .. " (BG) (ID: " .. blockId .. ")")
        processBlockType(blockId, blockName, true)
    end
    
    LogToConsole("Semua block telah dihancurkan!")
end

-- Fungsi helper untuk memproses satu tipe block (FG atau BG)
function processBlockType(blockId, blockName, isBackground)
    local key = blockId .. (isBackground and "_bg" or "_fg")
    local continueScanning = true
    local failCount = 0
    
    while continueScanning do
        local blocks = scanWorld()
        
        if not blocks[key] or #blocks[key] == 0 then
            LogToConsole(blockName .. (isBackground and " (BG)" or " (FG)") .. " selesai!")
            continueScanning = false
        else
            local targetBlock = blocks[key][1]
            local x = targetBlock.x
            local y = targetBlock.y
            
            if isInPunchRange(x, y) then

                if isBlockExists(x, y, blockId, isBackground) then
                    punch(x, y)
                    Sleep(100)
                    failCount = 0
                end
            else
                local moved = moveNearBlock(x, y)
                
                if moved then
                    if isBlockExists(x, y, blockId, isBackground) then
                        punch(x, y)
                        Sleep(50)
                        failCount = 0
                    else
                        LogToConsole("Block sudah tidak ada, skip...")
                    end
                else

                    
                    if isBlockExists(x, y, blockId, isBackground) then
                        punch(x, y)
                        Sleep(50)
                    end
                    
                    failCount = failCount + 1
                    
                    if failCount >= 5 then
     
                        Sleep(50)
                        failCount = 0
                        table.remove(blocks[key], 1)
                    end
                end
            end
            
            Sleep(50)
        end
    end
end

-- Jalankan fungsi utama
LogToConsole("versi 1")
watermark()
destroyAllBlocks()
