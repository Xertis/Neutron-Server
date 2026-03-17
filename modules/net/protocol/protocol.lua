local bit_buffer = require "server:lib/public/bit_buffer"
local kernel = require "server:multiplayer/protocol-kernel/kernel"
local receiver = require "server:multiplayer/protocol-kernel/receiver"
local http = require "server:lib/private/http/httprequestparser"
local protocol = {}

logger.log("Initializing protocol...")
kernel.__init()
logger.log("Protocol initialized")

function protocol.create_databuffer(bytes)
    local buf = bit_buffer:new(bytes, "BE")

    function buf.ownDb:put_packet(packet)
        self:put_bytes(packet)
    end

    function buf.ownDb:set_be()
        self:set_order("BE")
    end

    function buf.ownDb:set_le()
        self:set_order("LE")
    end

    return buf
end

function protocol.build_packet(client_or_server, packet_type, data)
    local buffer = protocol.create_databuffer()
    buffer:put_byte(packet_type)

    local state, res = pcall(kernel.write, buffer, client_or_server, kernel[client_or_server].ids[packet_type], data)

    if not state then
        logger.log("Packet encoding crash, additional information in server.log", 'E')

        logger.log("Error: " .. res, 'E', true)

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({ client_or_server, packet_type }), 'E', true)

        logger.log("Data:", 'E', true)
        logger.log(json.tostring(data), 'E', true)
        return {}
    end

    buffer:flush()

    return buffer.bytes
end

function protocol.parse_packet(client_or_server, external_buffer)
    local buffer = protocol.create_databuffer()
    buffer.external_buffer = external_buffer
    buffer.recv_func = receiver.get

    local packet_type = buffer:get_byte()

    local state, res = pcall(kernel.read, buffer, client_or_server, kernel[client_or_server].ids[packet_type])

    if not state then
        logger.log("Packet parsing crash, additional information in server.log", 'E')
        logger.log("Error: " .. res, 'E', true)

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)

        logger.log("Packet:", 'E', true)
        logger.log(table.tostring({ client_or_server, packet_type }), 'E', true)
        error()
    end

    local consumed = math.ceil((buffer.pos - 1) / 8)
    receiver.clear(external_buffer, consumed)

    res.packet_type = packet_type

    return res
end

local http_ending = utf8.tobytes("\r\n\r\n", true)
function protocol.parse_query(external_buffer)
    local buffer = protocol.create_databuffer()
    local bytes = {}
    buffer.external_buffer = external_buffer
    buffer.recv_func = receiver.get

    while not table.deep_equals(table.sub(bytes, #bytes - 3), http_ending) do
        local str_byte = buffer:get_byte()

        bytes[#bytes + 1] = str_byte

        if #bytes > 4096 then
            break
        end
    end

    local consumed = math.ceil((buffer.pos - 1) / 8)
    receiver.clear(external_buffer, consumed)

    local state, res = pcall(http.toJsonString, utf8.tostring(bytes))

    if not state then
        logger.log("Http packet parsing crash, additional information in server.log", 'E')
        logger.log("Error: " .. res, 'E', true)

        logger.log("Traceback:", 'E', true)
        logger.log(debug.traceback(), 'E', true)
        error()
    end

    return res
end

protocol.ClientMsg = kernel.client.ids
protocol.ServerMsg = kernel.server.ids
protocol.States = PROTOCOL_STATES

protocol.Version = PROTOCOL_VERSION

do
    logger.log("Server packets:")

    local serverPackets = {}
    for a, b in pairs(protocol.ServerMsg) do
        if type(a) ~= "number" then
            table.insert(serverPackets, { name = a, id = b })
        end
    end

    table.sort(serverPackets, function(x, y) return x.id < y.id end)

    for _, packet in ipairs(serverPackets) do
        print(string.format("%s. %s", packet.id, packet.name))
    end

    logger.log("Client packets:")

    local clientPackets = {}
    for a, b in pairs(protocol.ClientMsg) do
        if type(a) ~= "number" then
            table.insert(clientPackets, { name = a, id = b })
        end
    end

    table.sort(clientPackets, function(x, y) return x.id < y.id end)

    for _, packet in ipairs(clientPackets) do
        print(string.format("%s. %s", packet.id, packet.name))
    end
end

return protocol
