local module = {}

local sha256 = import("lib/crypto/sha256")

function module.hash_directory(path)
    if (file.isdir(path) == false) then
        return ""
    end

    local files = file.recursive_list(path, true)
    if (#files == 0) then
        return ""
    end

    table.sort(files)
    local hash = crypto.hash_new("SHA256")

    for _, abs_file_path in ipairs(files) do
        local size = file.length(abs_file_path)

        if (size > 1000000) then
            local progress = 0
            local io_stream = file.open(abs_file_path, "rb")
            while (progress < size) do
                local read_size = math.min(size - progress, 1000000)
                local bytes = io_stream:read(read_size, false)
                hash:update(Bytearray_as_string(bytes))
                progress = progress + bytes.size
            end
            io_stream:close()
        else
            hash:update(Bytearray_as_string(file.read_bytes(abs_file_path, false)))
        end
    end

    return hash_to_string(hash:final())
end

for key, func in pairs(sha256) do
    module[key] = func
end

function module.lite(data, seed)
    table.map(data, function(i, x)
        return math.round(x ^ 0.8)
    end)

    return string.format("%x", seed + math.sum(data))
end

function module.hash_pack(pack_id)
    local pack_info = pack.get_info(pack_id)
    return module.hash_directory(pack_info.path)
end

function module.equals(str, hash)
    if module.sha256(str) == hash then
        return true
    end

    return false
end

return module
