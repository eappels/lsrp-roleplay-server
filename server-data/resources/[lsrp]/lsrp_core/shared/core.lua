-- LSRP Core - Shared Core Object
--
-- Provides a lightweight registry (LSRP.Core) that other resources can use to
-- share named values within the same resource. Cross-resource sharing should
-- use exports or net events instead.

LSRP = LSRP or {}
LSRP.Core = LSRP.Core or {}

local Core = LSRP.Core

-- basic exports/registry for in-resource helpers
Core._registry = Core._registry or {}

function Core.register(name, value)
    Core._registry[name] = value
end

function Core.get(name)
    return Core._registry[name]
end

function Core.notify(source, msg)
    local text = tostring(msg)
    if type(msg) == 'table' then
        text = table.concat(msg, ' ')
    end

    if source == 0 or source == nil then
        print(('LSRP notify: %s'):format(text))
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^2LSRP', text } })
    end
end

function Core.init()
    print('lsrp_core: Core initialized')
end

-- initialize on load
Core.init()
