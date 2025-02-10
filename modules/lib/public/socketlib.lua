
local socketlib = {}

-- Подключение к TCP-серверу
function socketlib.connect(address, port, on_connect, on_error)
    local socket = network.tcp_connect(address, port, function(s)
        if s:is_connected() then
            if on_connect then
                on_connect(s)
            end
        else
            if on_error then
                on_error("Не удалось подключиться к серверу.")
            end
        end
    end)

    return socket
end

-- Открытие TCP-сервера
function socketlib.create_server(port, on_client_connect)
    local server = network.tcp_open(port, function(client_socket)
        if on_client_connect then
            -- console.log("Пришло новое подключение по сокету ["..client_socket:get_address().."]")
            on_client_connect(client_socket)
        end
    end)

    if not server:is_open() then
        error("Не удалось открыть сервер на порту " .. port)
    end

    return server
end

-- Получение строки через сокет
function socketlib.receive_text(socket, max_length)
    if socket and socket:is_alive() then
        local bytes = socket:recv(max_length, true) -- Читаем как таблицу
        if bytes and #bytes > 0 then
            return utf8.tostring(bytes)
        else
            return nil
        end
    else
        error("Сокет закрыт или не существует.")
    end
end

-- Отправка байт через сокет
function socketlib.send(socket, bytes)
    if socket and socket:is_alive() then
        socket:send(bytes)
    else
        error("Сокет закрыт или не существует.")
    end
end

-- Получение байт через сокет
function socketlib.receive(socket, max_length)
    if socket then
        local bytes = socket:recv(max_length, true) -- Читаем как таблицу
        if bytes and #bytes > 0 then
            return bytes
        else
            return nil
        end
    else
        error("Сокет закрыт или не существует.")
    end
end

-- Закрытие сокета
function socketlib.close_socket(socket)
    if socket and socket:is_alive() then
        socket:close()
    end
end

-- Аналитика сети
function socketlib.get_network_stats()
    return {
        total_upload = network.get_total_upload(),
        total_download = network.get_total_download()
    }
end

-- Пример работы с base64
function socketlib.encode_base64(data)
    return base64.encode(data)
end

function socketlib.decode_base64(data, use_table)
    return base64.decode(data, use_table or false)
end

return socketlib