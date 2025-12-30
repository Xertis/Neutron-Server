local interceptors_v2 = start_require "api/v2/interceptors"

local module = table.deep_copy(interceptors_v2)

function module.receive.add_middleware(packet_type, middleware)
    interceptors_v2.receive.add_interceptor(packet_type, function (client, packet)
        return middleware(packet, client)
    end)
end

function module.receive.add_general_middleware(middleware)
    interceptors_v2.receive.add_generic_interceptor(function (client, packet)
        return middleware(packet, client)
    end)
end

return module