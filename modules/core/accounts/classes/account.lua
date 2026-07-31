local metadata = import "lib/data/metadata"
local lib = import "lib/utils/min"
local Account = {}
Account.__index = Account

local accounts_proxy = metadata.proxy("server", "accounts")

function Account.new(identity)
    local self = accounts_proxy[identity]

    if not self then
        self = {
            active = false,
            last_session = nil,
            is_logged = false,
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
