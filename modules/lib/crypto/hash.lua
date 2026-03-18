local module = {}

local sha256 = import("lib/crypto/sha256")

for key, func in pairs(sha256) do
    module[key] = func
end

function module.lite(data, seed)
    table.map(data, function(i, x)
        return math.round(x ^ 0.8)
    end)

    return string.format("%x", seed + math.sum(data))
end

function module.hash_mods(packs)
    packs = packs or pack.get_installed()

    local data_line = ""

    for _, pack_path in ipairs(packs) do
        pack_path = pack_path .. ':'
        local files = file.recursive_list(pack_path)

        files = table.filter(files, function(_, path)
            if string.ends_with(path, "png") or
                string.starts_with(path, '.') or
                string.ends_with(path, "vec3") or
                string.ends_with(path, "ogg") or
                string.find(path, ".git")
            then
                return false
            end
            return true
        end)

        for _, abs_file_path in ipairs(files) do
            data_line = data_line .. base64.encode(file.read_bytes(abs_file_path))
        end
    end

    return module.sha256(data_line)
end

function module.equals(str, hash)
    if module.sha256(str) == hash then
        return true
    end

    return false
end

return module
