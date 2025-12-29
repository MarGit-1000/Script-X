-- Function untuk punch tile
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
end

-- Function untuk scan semua tile yang ready harvest
local function scanReadyHarvest()
    local tiles = {}
    for _, tile in pairs(GetTiles()) do
        if tile.readyharvest then
            table.insert(tiles, {x = tile.x, y = tile.y})
        end
    end
    return tiles
end

-- Function untuk filter tile berdasarkan pola x dan y
local function filterTilesByPattern(tiles, currentX, yPattern)
    local filtered = {}
    for _, tile in pairs(tiles) do
        -- Cek apakah x sesuai dengan currentX
        if tile.x == currentX then
            -- Cek apakah y sesuai dengan pattern (0, 2, 4, 6, 8, ...)
            for _, y in pairs(yPattern) do
                if tile.y == y then
                    table.insert(filtered, tile)
                    break
                end
            end
        end
    end
    
    -- Sort berdasarkan y (terkecil dulu)
    table.sort(filtered, function(a, b) return a.y < b.y end)
    return filtered
end

-- Function untuk mendapatkan range X dan Y dari tiles yang ready harvest
local function getTileRange(tiles)
    if #tiles == 0 then
        return nil, nil, nil, nil
    end
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    for _, tile in pairs(tiles) do
        minX = math.min(minX, tile.x)
        maxX = math.max(maxX, tile.x)
        minY = math.min(minY, tile.y)
        maxY = math.max(maxY, tile.y)
    end
    
    return minX, maxX, minY, maxY
end

-- Function utama untuk harvest
local function smartHarvest()
    LogToConsole("`2Starting Smart Harvest...")
    
    -- Scan tiles ready harvest pertama kali
    local initialScan = scanReadyHarvest()
    
    if #initialScan == 0 then
        LogToConsole("`4No ready harvest tiles found!")
        return
    end
    
    -- Dapatkan range X dan Y dari tiles yang ready harvest
    local minX, maxX, minY, maxY = getTileRange(initialScan)
    
    LogToConsole("`eDetected range: X(" .. minX .. "-" .. maxX .. ") Y(" .. minY .. "-" .. maxY .. ")")
    
    -- Generate pola y yang genap (0, 2, 4, 6, ...) dari minY sampai maxY
    local yPatterns = {}
    for y = minY, maxY, 2 do
        table.insert(yPatterns, y)
    end
    
    -- Tambahkan y ganjil juga jika ada di data (untuk antisipasi)
    for y = minY + 1, maxY, 2 do
        table.insert(yPatterns, y)
    end
    
    -- Sort pattern Y
    table.sort(yPatterns)
    
    LogToConsole("`9Y Patterns: " .. table.concat(yPatterns, ", "))
    
    -- Loop dari minX sampai maxX
    for x = minX, maxX do
        LogToConsole("`9Processing column X = " .. x)
        
        local breakCount = 0
        
        -- Scan tiles ready harvest
        local readyTiles = scanReadyHarvest()
        
        -- Filter tiles sesuai pola x dan y
        local tilesToBreak = filterTilesByPattern(readyTiles, x, yPatterns)
        
        if #tilesToBreak > 0 then
            LogToConsole("`eFound " .. #tilesToBreak .. " tiles to harvest in X = " .. x)
            
            for _, tile in pairs(tilesToBreak) do
                -- Pindah ke tile
                LogToConsole("`bMoving to (" .. tile.x .. ", " .. tile.y .. ")")
                findPath(tile.x, tile.y)
                sleep(200)
                
                -- Punch tile
                LogToConsole("`cBreaking tile at (" .. tile.x .. ", " .. tile.y .. ")")
                punch(tile.x, tile.y)
                sleep(180)
                
                breakCount = breakCount + 1
                
                -- Setiap 3 tile, scan ulang untuk cek tile yang miss
                if breakCount % 3 == 0 then
                    LogToConsole("`6Rescanning after 3 breaks...")
                    sleep(100)
                    
                    -- Scan ulang semua ready tiles
                    readyTiles = scanReadyHarvest()
                    
                    -- Filter lagi untuk kolom X yang sama
                    local newTilesToBreak = filterTilesByPattern(readyTiles, x, yPatterns)
                    
                    -- Jika masih ada tile yang miss di kolom ini, tambahkan ke list
                    if #newTilesToBreak > 0 then
                        LogToConsole("`eFound " .. #newTilesToBreak .. " tiles (including missed) in X = " .. x)
                        tilesToBreak = newTilesToBreak
                        
                        -- Reset breakCount untuk kolom ini
                        breakCount = 0
                    end
                end
            end
        else
            LogToConsole("`oNo tiles to harvest in X = " .. x)
        end
        
        sleep(100)
    end
    
    LogToConsole("`2Smart Harvest completed!")
end

-- Jalankan script
smartHarvest()
