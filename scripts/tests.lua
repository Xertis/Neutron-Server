local pid = 0
local world_name = "player_flight_test"

app.reconfig_packs({"base"}, {})
app.new_world(
    world_name,
    "111111111111",
    "core:default",
    pid
)

player.create("test", pid)
player.set_flight(pid, true)
player.set_pos(pid, 0, 100, 0)

app.close_world(true)

local function process()
    app.open_world(world_name)

    for i=1, 100 do
        local x, y, z = player.get_pos(pid)
        print("Player Y is " .. tostring(y))
        print(player.is_flight(pid))
        app.tick()
    end

    app.close_world(true)
end

process()
process()
process()

app.open_world(world_name)
local x, y, z = player.get_pos(pid)
print("Player Y is " .. tostring(y))

app.close_world(true)
app.delete_world(world_name)

assert(100 - y < 1)