local _, addon = ...
local Filters = { handlers = {} }
addon.Filters = Filters
Filters.supported = {
    FORMAT_NAME_TEXT = true,
    FORMAT_KEYWORD_TOKEN = true,
    FORMAT_MESSAGE_TOKEN = true,
    FORMAT_INPUT_TOKEN = true,
    INPUT_AUTO_SPACE = true,
}

function Filters:Register(owner, event, callback)
    self.handlers[event] = self.handlers[event] or {}
    self.handlers[event][owner] = callback
end

function Filters:Remove(owner, event)
    if event then
        if self.handlers[event] then
            self.handlers[event][owner] = nil
        end
    else
        for _, handlers in pairs(self.handlers) do
            handlers[owner] = nil
        end
    end
end

function Filters:Apply(event, value, ...)
    local handlers = self.handlers[event]
    if not handlers then
        return value
    end

    local owners = {}
    for owner in pairs(handlers) do
        owners[#owners + 1] = owner
    end

    table.sort(owners)
    for _, owner in ipairs(owners) do
        local callback = handlers[owner]
        if callback then
            local result = callback(value, ...)
            if result ~= nil then
                value = result
            end
        end
    end

    return value
end
