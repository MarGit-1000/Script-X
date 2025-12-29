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
    Sleep(10)
end

-- Fungsi untuk scan world dan mengelompokkan block berdasarkan ID
local function scanWorld()
    local blocks = {}
    
    for _, block in pairs(GetTiles()) do
        if block.fg ~= 0 then
            local blockId = block.fg
            
            for _, priority in ipairs(blockPriority) do
                if priority.id == blockId then
                    if not blocks[blockId] then
                        blocks[blockId] = {}
                    end
                    table.insert(blocks[blockId], {
                        x = block.x,
                        y = block.y,
                        priority = priority.priority,
                        name = priority.name
                    })
                    break
                end
            end
        end
    end
    
    -- Sort setiap grup block berdasarkan x dan y terkecil
    for blockId, blockList in pairs(blocks) do
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
    return distance <= 5 -- Jangkauan punch biasanya 5 tile
end

-- Fungsi untuk mencoba pindah ke dekat block (DIPERBAIKI)
local function moveNearBlock(x, y)
    -- Cek apakah sudah dalam jangkauan
    if isInPunchRange(x, y) then
        LogToConsole("Sudah dalam jangkauan, tidak perlu pindah")
        return true
    end
    
    local positions = {
        {x = x, y = y + 1},     -- Atas
        {x = x, y = y - 1},     -- Bawah
        {x = x - 1, y = y},     -- Kiri
        {x = x + 1, y = y},     -- Kanan
        {x = x - 1, y = y + 1}, -- Kiri atas
        {x = x + 1, y = y + 1}, -- Kanan atas
        {x = x - 1, y = y - 1}, -- Kiri bawah
        {x = x + 1, y = y - 1}, -- Kanan bawah
    }
    
    -- Coba setiap posisi
    for _, pos in ipairs(positions) do
        if findPath(pos.x, pos.y) then
            Sleep(10) -- Beri waktu bot untuk sampai
            
            -- Verifikasi posisi bot sudah dalam jangkauan
            if isInPunchRange(x, y) then
                return true
            end
            
            Sleep(10)
        end
    end
    
    return false
end

-- Fungsi untuk cek apakah block masih ada
local function isBlockExists(x, y, blockId)
    local tile = GetTile(x, y)
    if not tile then return false end
    return tile.fg == blockId
end

-- Fungsi utama untuk menghancurkan semua block sesuai prioritas
local function destroyAllBlocks()
    LogToConsole("Memulai proses penghancuran block...")
    
    for _, priority in ipairs(blockPriority) do
        local blockId = priority.id
        local blockName = priority.name
        
        LogToConsole("Memproses: " .. blockName .. " (ID: " .. blockId .. ")")
        
        local continueScanning = true
        local failCount = 0
        
        while continueScanning do
            -- Scan ulang world
            local blocks = scanWorld()
            
            -- Cek apakah masih ada block dengan ID ini
            if not blocks[blockId] or #blocks[blockId] == 0 then
                LogToConsole(blockName .. " selesai!")
                continueScanning = false
            else
                -- Ambil block pertama dari list
                local targetBlock = blocks[blockId][1]
                local x = targetBlock.x
                local y = targetBlock.y
                
                -- Cek apakah sudah dalam jangkauan tanpa perlu pindah
                if isInPunchRange(x, y) then
                    LogToConsole("Block sudah dalam jangkauan!")
                    if isBlockExists(x, y, blockId) then
                        punch(x, y)
                        (100)
                        failCount = 0
                    end
                else
                    -- Coba pindah ke dekat block
                    local moved = moveNearBlock(x, y)
                    
                    if moved then
                        -- Berhasil pindah, verifikasi block masih ada
                        if isBlockExists(x, y, blockId) then
                            punch(x, y)
                            Sleep(10)
                            failCount = 0
                        else
                            LogToConsole("Block sudah tidak ada, skip...")
                        end
                    else
                        -- GAGAL PINDAH - Tetap coba punch dari posisi sekarang
                        LogToConsole("Gagal pindah, coba punch dari posisi sekarang...")
                        
                        if isBlockExists(x, y, blockId) then
                            punch(x, y)
                            Sleep(10) -- Delay lebih lama karena mungkin diluar jangkauan optimal
                        end
                        
                        failCount = failCount + 1
                        
                        -- Jika gagal 5x berturut-turut, skip block ini
                        if failCount >= 5 then
                            LogToConsole("Skip block setelah 5x gagal punch dari posisi jauh")
                            Sleep(10)
                            failCount = 0
                            -- Hapus block dari list agar tidak stuck
                            table.remove(blocks[blockId], 1)
                        end
                    end
                end
                
                Sleep(10) -- Delay antar iterasi
            end
        end
    end
    
    LogToConsole("Semua block telah dihancurkan!")
end

-- Jalankan fungsi utama
LogToConsole("versi 1.0.9 - Auto punch even if move fails")
destroyAllBlocks()
