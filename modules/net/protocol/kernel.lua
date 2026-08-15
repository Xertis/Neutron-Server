local compiler = import "net/protocol/compiler"

local module = {
    server = { letters = {}, ids = {} },
    client = { letters = {}, ids = {} }
}

local PATH_TO_ANNOTATION_SERVER = PACK_ID .. ":resources/protocol/annotation_server.yaml"
local PATH_TO_ANNOTATION_CLIENT = PACK_ID .. ":resources/protocol/annotation_client.yaml"

local compiled = { server = {}, client = {} }

local function get_base_type(typestr)
    if not typestr or type(typestr) ~= "string" then
        return typestr
    end
    local base = typestr
    while true do
        local new_base = base:match("^(.-)%s*%[[^%]]+%]%s*$")
        if not new_base or new_base == base then
            break
        end
        base = new_base
    end
    return base:match("^%s*(.-)%s*$")
end

local function gen_ids(side)
    local packets = compiled[side]
    local name_to_id = {}
    local id_to_name = {}
    local used_ids = {}

    for name, data in pairs(packets) do
        if data.packet_id then
            local id = type(data.packet_id) == "number" and data.packet_id or utf8.codepoint(data.packet_id)
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

local function get_fields(annotation, letter, name, prefix)
    local fields = {}

    for _, type_entry in ipairs(letter.fields or {}) do
        local key, val = get_one(type_entry)
        local full_key = prefix and (prefix .. "." .. key) or key
        local base_type = get_base_type(val)

        if annotation[base_type] then
            if base_type == name then
                error("Stack overflow detected inside the " .. name)
            end
            local nested = get_fields(annotation, annotation[base_type], base_type, full_key)
            for k, t in pairs(nested) do
                fields[k] = t
            end
        else
            fields[full_key] = val
        end
    end

    return fields
end

function module.__compilation(side, path)
    local letters = module[side].letters
    local annotation = yaml.parse(file.read(path))

    for name, letter in pairs(annotation) do
        local fields = get_fields(annotation, letter, name, nil)

        local encoder = compiler.load(compiler.compile_encoder(fields))
        local decoder = compiler.load(compiler.compile_decoder(fields))

        letters[name] = name

        compiled[side][name] = {
            packet_id = letter.packet_id,
            encode = function(buf, data)
                encoder(buf, data or {})
                buf:flush()
            end,
            decode = function(buf)
                return decoder(buf)
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
    if not compiled[side][letter] then
        error("Unknown packet letter: " .. tostring(letter))
    end
    compiled[side][letter].encode(buf, data or {})
end

function module.read(buf, side, letter)
    if not compiled[side][letter] then
        error("Unknown packet letter: " .. tostring(letter))
    end
    return compiled[side][letter].decode(buf)
end

return module
