local compiler = require "multiplayer/protocol-kernel/compiler"
local module = {
    server = {
        letters = {},
        ids = {}
    },
    client = {
        letters = {},
        ids = {}
    }
}

local PATH_TO_ANNOTATION_SERVER = PACK_ID .. ":resources/protocol/annotation_server.yaml"
local PATH_TO_ANNOTATION_CLIENT = PACK_ID .. ":resources/protocol/annotation_client.yaml"

local compiled = {
    server = {},
    client = {}
}

local function gen_ids(side)
    local packets = compiled[side]
    local name_to_id = {}
    local id_to_name = {}
    local used_ids = {}

    for name, data in pairs(packets) do
        if data.packet_id then
            local id = nil
            if type(data.packet_id) == "number" then
                id = data.packet_id
            else
                id = utf8.codepoint(data.packet_id)
            end

            if id_to_name[id] then
                error(string.format("Duplicate packet_id! ID %d is used by '%s' and '%s'", id, id_to_name[id], name))
            end
            name_to_id[name] = id
            id_to_name[id] = name
            used_ids[id] = true
        end
    end

    local auto_packets = {}
    for name, data in pairs(packets) do
        if not data.packet_id then
            table.insert(auto_packets, name)
        end
    end
    table.sort(auto_packets)

    local current_id = 0
    for _, name in ipairs(auto_packets) do
        while used_ids[current_id] do
            current_id = current_id + 1
        end
        name_to_id[name] = current_id
        id_to_name[current_id] = name
        used_ids[current_id] = true
        current_id = current_id + 1
    end

    module[side].ids = name_to_id

    for id, name in pairs(id_to_name) do
        module[side].ids[id] = name
    end
end

local function get_one(tbl)
    for key, val in pairs(tbl) do
        return key, val
    end
end

local function get_fields(annotation, letter, name)
    local types_compiler_types = {}
    local key2index = {}
    local index2key = {}

    for indx, type in ipairs(letter.fields or {}) do
        local key, val = get_one(type)

        if annotation[val] then
            if val == name then
                error("Stack overflow detected inside the " .. name)
            end

            local _, _, inner_types_compiler_types = get_fields(annotation, annotation[val], val)

            for _, t in ipairs(inner_types_compiler_types) do
                table.insert(types_compiler_types, t)
            end
        else
            table.insert(types_compiler_types, val)
        end

        index2key[indx] = key
        key2index[key] = indx
    end

    return key2index, index2key, types_compiler_types
end

function module.__compilation(side, path)
    local letters = module[side].letters
    local annotation = yaml.parse(file.read(path))

    for name, letter in pairs(annotation) do
        local _, _, types_compiler_types = get_fields(annotation, letter, name)

        local encoder = compiler.load(compiler.compile_encoder(types_compiler_types))
        local decoder = compiler.load(compiler.compile_decoder(types_compiler_types))

        letters[name] = name

        compiled[side][name] = {
            packet_id = letter.packet_id,
            encode = function (buf, data)
                local flat_data = {}
                if data[1] then flat_data = data end

                local function flatten(fields, d)
                    for _, f in ipairs(fields) do
                        local k, t = get_one(f)
                        local v = d[k]
                        if annotation[t] then
                            flatten(annotation[t].fields, v)
                        else
                            table.insert(flat_data, v)
                        end
                    end
                end
                if #flat_data == 0 then flatten(letter.fields or {}, data) end
                encoder(buf, unpack(flat_data))
                buf:flush()
            end,
            decode = function (buf)
                local flat_data = decoder(buf)
                local idx = 1
                local function unflatten(fields)
                    local d = {}
                    for _, f in ipairs(fields) do
                        local k, t = get_one(f)
                        if annotation[t] then
                            d[k] = unflatten(annotation[t].fields)
                        else
                            d[k] = flat_data[idx]
                            idx = idx + 1
                        end
                    end
                    return d
                end
                return unflatten(letter.fields or {})
            end
        }
    end

    gen_ids(side)
end

function module.__init()
    module.__compilation("server", PATH_TO_ANNOTATION_SERVER)
    module.__compilation("client", PATH_TO_ANNOTATION_CLIENT)
end

function module.write(buf, side, letter, data)
    compiled[side][letter].encode(buf, data or {})
end

function module.read(buf, side, letter)
    return compiled[side][letter].decode(buf)
end

return module