-- Konfigurasi prioritas block
local blockPriority = {
    {id = 16, name = "Grass", priority = 1},
    {id = 1004, name = "Hedge", priority = 2},
    {id = 1104, name = "Foliage", priority = 3},
    {id = 7224, name = "Oak Tree", priority = 4},
    {id = 190, name = "Rose", priority = 5},
    {id = 2, name = "Dirt", priority = 6},
    {id = 728, name = "Clouds", priority = 7},
    {id = 3564, name = "Cave Dirt", priority = 8},
    {id = 612, name = "Lattice Background", priority = 9}
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
    sleep(50) -- Delay kecil setelah punch
end

-- Fungsi untuk scan world dan mengelompokkan block berdasarkan ID
local function scanWorld()
    local maxX = 99
    local maxY = 113
    local blocks = {}
    
    for _, block in pairs(GetTiles()) do
        if block.fg ~= 0 then -- Hanya ambil block yang ada (tidak kosong)
            local blockId = block.fg
            
            -- Cek apakah block ini ada di priority list
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

-- Fungsi untuk mencoba pindah ke dekat block
local function moveNearBlock(x, y)
    -- Coba y-1 (bawah)
    if findPath(x, y - 1) then
        Sleep(50)
        return true
    end
    
    -- Coba y+1 (atas)
    if findPath(x, y + 1) then
        Sleep(50)
        return true
    end
    
    -- Coba x-1 (kiri)
    if findPath(x - 1, y) then
        Sleep(50)
        return true
    end
    
    -- Coba x+1 (kanan)
    if findPath(x + 1, y) then
        Sleep(50)
        return true
    end
    
    return false -- Gagal pindah
end

-- Fungsi utama untuk menghancurkan semua block sesuai prioritas
local function destroyAllBlocks()
    print("Memulai proses penghancuran block...")
    
    -- Loop sampai semua block selesai
    for _, priority in ipairs(blockPriority) do
        local blockId = priority.id
        local blockName = priority.name
        
        print("Memproses: " .. blockName .. " (ID: " .. blockId .. ")")
        
        local continueScanning = true
        
        while continueScanning do
            -- Scan ulang world
            local blocks = scanWorld()
            
            -- Cek apakah masih ada block dengan ID ini
            if not blocks[blockId] or #blocks[blockId] == 0 then
                print(blockName .. " selesai!")
                continueScanning = false
            else
                -- Ambil block pertama dari list (x dan y terkecil)
                local targetBlock = blocks[blockId][1]
                local x = targetBlock.x
                local y = targetBlock.y
                
                print("Menghancurkan " .. blockName .. " di (" .. x .. ", " .. y .. ")")
                
                -- Coba pindah ke dekat block
                local moved = moveNearBlock(x, y)
                
                -- Punch block
                punch(x, y)
                sleep(200) -- Delay setelah punch untuk memastikan block hancur
            end
        end
    end
    
    print("Semua block telah dihancurkan!")
end

-- Jalankan fungsi utama
destroyAllBlocks()
LogToConsole("versi 1.0")
