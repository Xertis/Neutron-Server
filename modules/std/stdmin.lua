server = {}

function server.log(text)
    print("\n") --временный костыль, пока не найдём способ заменить lua-debug на другой текст
    print(debug.getinfo(2).source)
    debug.log(text, PACK_ID)
    print("\n")
end