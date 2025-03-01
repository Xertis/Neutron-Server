local module = {}

local protect = require "lib/private/protect"

local function rightRotate(value, amount)
    return bit.bor(bit.rshift(value, amount), bit.lshift(value, 32 - amount))
end

local function unpackInt32(data, offset)
    local byte1 = data:byte(offset)
    local byte2 = data:byte(offset + 1)
    local byte3 = data:byte(offset + 2)
    local byte4 = data:byte(offset + 3)

    return (byte1 * 256^3) + (byte2 * 256^2) + (byte3 * 256) + byte4
end

function module.sha256(input)
    if not input then
        return
    end

    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c48, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa11, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }

    local h = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }

    local originalByteLen = #input
    input = input .. string.char(0x80)
    while (#input % 64) ~= 56 do
        input = input .. string.char(0)
    end

    local originalBitLen = originalByteLen * 8
    for i = 7, 0, -1 do
        input = input .. string.char(bit.band(bit.rshift(originalBitLen, i * 8), 255))
    end

    for chunkStart = 1, #input, 64 do
        local chunk = input:sub(chunkStart, chunkStart + 63)

        local w = {}
        for i = 1, 64 do
            if i <= 16 then
                w[i] = unpackInt32(chunk, (i - 1) * 4 + 1)
            else
                local s0 = bit.bxor(rightRotate(w[i - 15], 7), rightRotate(w[i - 15], 18), bit.rshift(w[i - 15], 3))
                local s1 = bit.bxor(rightRotate(w[i - 2], 17), rightRotate(w[i - 2], 19), bit.rshift(w[i - 2], 10))           
                w[i] = (bit.band(w[i - 16], 4294967295) + s0 + bit.band(w[i - 7], 4294967295) + s1) % (2^32)
            end
        end

        local a, b, c, d, e, f, g, h1 = unpack(h)

        for i = 1, 64 do
            local S1 = bit.bxor(rightRotate(e, 6), rightRotate(e, 11), rightRotate(e, 25))
            local ch = bit.bxor(bit.band(e, f), bit.band(bit.bnot(e), g))
            local temp1 = (h1 + S1 + ch + k[i] + w[i]) % (2^32)
            local S0 = bit.bxor(rightRotate(a, 2), rightRotate(a, 13), rightRotate(a, 22))
            local maj = bit.bxor(bit.band(a, b), bit.band(a, c), bit.band(b, c))
            local temp2 = (S0 + maj) % (2^32)

            h1 = g
            g = f
            f = e
            e = (d + temp1) % (2^32)
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % (2^32)
        end

        h[1] = (h[1] + a) % (2^32)
        h[2] = (h[2] + b) % (2^32)
        h[3] = (h[3] + c) % (2^32)
        h[4] = (h[4] + d) % (2^32)
        h[5] = (h[5] + e) % (2^32)
        h[6] = (h[6] + f) % (2^32)
        h[7] = (h[7] + g) % (2^32)
        h[8] = (h[8] + h1) % (2^32)
    end

    local hash = ""
    for i = 1, #h do
        hash = hash .. string.format("%08x", h[i])
    end

    return hash
end

function module.lite(str, seed)
    local hash = seed or 5381
    local len = #str

    for i = 1, len do
        local char = string.byte(str, i)
        hash = bit.bxor(bit.lshift(hash, 5) + hash, char)
    end

    local hex_hash = string.format("%08x", bit.band(hash, 0xFFFFFFFF))
    return hex_hash
end

function module.hash_mods(packs)
    packs = packs or pack.get_installed()

    local hash_data = "00000000"

    for _, pack_path in ipairs(packs) do
        local files = file.recursive_list(pack_path)

        table.filter(files, function (_, path)
            if string.ends_with(path, "png") or string.starts_with(path, '.') then
                return false
            end
            return true
        end)

        for _, abs_file_path in ipairs(files) do
            local file_data = file.read_bytes(abs_file_path)
            local str_data = ""

            for _, byte in ipairs(file_data) do
                str_data = str_data .. string.char(byte)
            end

            hash_data = module.lite(str_data, tonumber(hash_data, 16))
        end
    end

    return hash_data
end

function module.equals(str, hash)
    if module.sha256(str) == hash then
        return true
    end

    return false
end

return protect.protect_return(module)