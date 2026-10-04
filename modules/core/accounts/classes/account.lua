local metadata = import "lib/data/metadata"
local lib = import "lib/utils/min"
local Account = {}

local TEMPED_DEFAULTS = {
    last_session = false,
    is_logged = false,
}

local TEMPED_DATA = {}
for key in pairs(TEMPED_DEFAULTS) do
    TEMPED_DATA[key] = setmetatable({}, { __mode = "k" })
end

function Account.__index(self, key)
    local storage = TEMPED_DATA[key]
    if storage then
        local value = storage[self]
        if value == nil then
            local default = TEMPED_DEFAULTS[key]
            if type(default) == "function" then
                value = default()
                storage[self] = value
            else
                value = default
            end
        end
        return value
    end
    return Account[key]
end

local accounts_proxy = metadata.proxy("server", "accounts")

function Account.new(identity)
    local self = accounts_proxy[identity]

    if not self then
        self = {
            active = false,
            role = nil,
            identity = identity,
            password = nil
        }
        accounts_proxy[identity] = self
    end

    self.active = true

    return setmetatable(self, Account)
end

function Account:is_active()
    return self.active
end

function Account:abort()
    self.active = false
end

function Account:set_password(password)
    if type(password) ~= 'string' then
        return CODES.accounts.PasswordUnvalidated
    elseif #password < 8 then
        return CODES.accounts.PasswordUnvalidated
    end

    self.password = lib.hash.sha256(password)
end

function Account:check_password(password)
    if lib.hash.sha256(password) ~= self.password then
        return CODES.accounts.WrongPassword
    end

    self.is_logged = true
    return CODES.accounts.CorrectPassword
end

return Account
