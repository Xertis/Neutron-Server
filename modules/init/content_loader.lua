local hash = import "lib/crypto/hash"

local content_loader = {}

local CONTENT_CACHE = {}
local clients = {}

function content_loader.create_cache()
    logger.log("generating content cache")

    if (file.isdir(PACKS_CACHE_PATH) == false) then
        file.mkdirs(PACKS_CACHE_PATH)
    end

    local packs_list = CONFIG.game.content_packs
    local files = {}

    for _, pack_id in pairs(packs_list) do
        local pack_hash = hash.hash_pack(pack_id)
        local out_file = PACKS_CACHE_PATH .. pack_id .. "#" .. pack_hash .. ".zip"
        if (file.isfile(out_file) == false) then
            file.create_zip(pack.get_info(pack_id).path, out_file)
        end
        table.insert(files, file.name(out_file))

        local cache = {
            path = out_file,
            bytes_size = file.length(out_file),
            io_stream = file.open(out_file, "rb"),
            unpacked_hash = pack_hash
        }

        local progress = 0
        local sha256 = crypto.hash_new("SHA256")
        while (progress < cache.bytes_size) do
            local read_size = math.min(cache.bytes_size - progress, 1000000)
            local bytes = cache.io_stream:read(read_size, false)
            sha256:update(Bytearray_as_string(bytes))
            progress = progress + bytes.size
        end
        cache.zip_hash = hash_to_string(sha256:final())

        CONTENT_CACHE[pack_id] = cache
    end

    if (CONFIG.content_loader.clear_unused_cache == true) then
        for _, path in pairs(file.list(PACKS_CACHE_PATH)) do
            if (file.isfile(path) == true and table.has(files, file.name(path)) == false) then
                file.remove(path)
            end
        end
    end

    CONTENT_CACHE = table.freeze(CONTENT_CACHE)
end

function content_loader.get_pack_info(pack_id)
    return {
        bytes_size = CONTENT_CACHE[pack_id].bytes_size,
        zip_hash = CONTENT_CACHE[pack_id].zip_hash,
        unpacked_hash = CONTENT_CACHE[pack_id].unpacked_hash
    }
end

function content_loader.register_client(client_id, content_list)
    clients[client_id] = {
        content_list = content_list,
        current_pack = {
            index = 1,
            progress = 0
        }
    }
end

function content_loader.get_bytes(client_id)
    local client = clients[client_id]
    if (client == nil) then
        return nil
    end

    local current_pack_id = client.content_list[client.current_pack.index]
    local cache = CONTENT_CACHE[current_pack_id]
    if (cache == nil) then
        return nil
    end

    local read_size = math.max(
        math.min(math.floor(CONFIG.content_loader.max_speed / table.count_pairs(clients) / TPS.tps),
            cache.bytes_size - client.current_pack.progress
        ),
        1
    )
    cache.io_stream:seek("b", client.current_pack.progress)
    local byte_array = cache.io_stream:read(read_size, false)

    client.current_pack.progress = client.current_pack.progress + byte_array.size
    if (client.current_pack.progress >= cache.bytes_size) then
        client.current_pack = {
            index = client.current_pack.index + 1,
            progress = 0
        }
    end

    return byte_array
end

function content_loader.stop(client_id)
    clients[client_id] = nil
end

function content_loader.close_file_descriptors()
    for _, cache in pairs(CONTENT_CACHE) do
        cache.io_stream:close()
    end
    CONTENT_CACHE = {}
end

return content_loader