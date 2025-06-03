function protocol.create_databuffer(bytes)
    local buf = data_buffer:new(bytes, protocol.data.order)
    ---Записать LEB128
    ---@param number number
    function buf:put_leb128(number)
        local bytes = protocol.leb128_encode(number)
        self:put_bytes(bytes)
    end
    ---Прочитать LEB128
    ---@return number
    function buf:get_leb128()
        local n, bytesRead = protocol.leb128_decode(self.bytes, self.pos)
        self.pos = self.pos + bytesRead
        return n
    end
    ---Записать пакет
    ---@param packet table Таблица байт
    function buf:put_packet(packet)
        -- local packet = protocol.build_packet(client_or_server, packet_type, ...)
        self:put_uint16(#packet) -- длина пакета, фиксировано 2 байта
        self:put_bytes(packet)
    end
    ---Прочитать пакет
    ---@return table table Таблица байт (пакет)
    ---@return number length Длина пакета
    function buf:get_packet()
        local length = self:get_uint16()
        local sliced = protocol.slice_table(self.bytes, self.pos, self.pos + length - 1)
        self:set_position(self.pos + length)
        -- local parsed = protocol.parse_packet(client_or_server, sliced)
        return sliced, length
    end

    ---Записать строку
    ---@param str string строка
    function buf:pack_string(str)
        DATA_ENCODE.string(self, str)
    end
    ---Прочитать строку
    ---@return string string строка
    function buf:unpack_string()
        return DATA_DECODE.string(self)
    end

    ---Установить порядок байт на Big-Endian (применяется только для последующих операций)
    function buf:set_be()
        self:set_order("BE")
    end
    ---Установить порядок байт на Little-Endian (применяется только для последующих операций)
    function buf:set_le()
        self:set_order("LE")
    end

    return buf
end