function on_hud_open(pid)
    console.add_command(
        "neutron.open_server port:num",
        "Opens a local server on the port",
        function (args, kwargs)
            hud.set_allow_pause(false)
            local port = args[1]
            require("server:run/local")(port)

            return "Done"
        end
    )
end