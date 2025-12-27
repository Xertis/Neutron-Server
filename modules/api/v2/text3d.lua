local text3d_manager = start_require("server:lib/private/gfx/text3d_manager")

local defaultFunctions = {
    "get_text", "set_text",
    "get_pos", "set_pos",
    "get_axis_x", "get_axis_y",
    "set_axis_x", "set_axis_y",
    "set_rotation", "update_settings"
}

local module = {}

local Text = {}
Text.__index = Text

function Text.new(id)
    local self = setmetatable({}, Text)

    self.id = id

    return self
end

function Text:hide()
    text3d_manager.hide(self.id)
    self.id = nil
end

function Text:get_text()
    return text3d_manager.get_text(self.id)
end

function Text:set_text(text)
    text3d_manager.set_text(self.id, text)
end

function Text:get_pos()
    return text3d_manager.get_pos(self.id)
end

function Text:set_pos(position)
    text3d_manager.set_pos(self.id, position)
end

function Text:get_axis_x()
    return text3d_manager.get_axis_x(self.id)
end

function Text:get_axis_y()
    return text3d_manager.get_axis_y(self.id)
end

function Text:set_axis_x(axis)
    text3d_manager.set_axis_x(self.id, axis)
end

function Text:set_axis_y(axis)
    text3d_manager.set_axis_y(self.id, axis)
end

function Text:set_rotation(rotation)
    text3d_manager.set_rotation(self.id, rotation)
end

function Text:update_settings(preset)
    text3d_manager.update_settings(self.id, preset)
end

for _, key in ipairs(defaultFunctions) do
    module[key] = text3d_manager[key]
end

function module.show(...)
    local id = text3d_manager.show(...)

    return id, Text.new(id)
end

return module