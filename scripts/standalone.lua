local pipe = file.open_named_pipe("neutron-root-client", "r")

while true do
    if pipe:available() then
        local event = reader:read_line()
        file.write("export:test.txt", event)
        print(event)
    end
end
