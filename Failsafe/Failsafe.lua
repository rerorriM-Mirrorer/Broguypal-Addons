--[[
Copyright © 2026 Broguypal

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name    = 'Failsafe'
_addon.author  = 'Broguypal'
_addon.version = '1.1.0-dev'
_addon.commands = {'failsafe'}

require('pack')
local res = require('resources')
local config = require('config')

local max_attempts = 3
local retry_delay  = 0.65
local echo_timeout = 1.00
local settings = config.load({
    notify = true,
    attack = true,
    mode = 'ready', -- 'ready' waits for observable readiness; 'fixed' keeps upstream timing.
    max_wait = 4.0,
})
local casting = false
local casting_since = 0
local next_action_at = 0

local function player()
    return windower.ffxi.get_player()
end

local function current_target_id()
    local target = windower.ffxi.get_mob_by_target('t')
    return target and target.id or nil
end

local function ready_for(job, now)
    local p = player()
    if not p then return false end
    if job.target_id and current_target_id() ~= job.target_id then return false, 'target changed' end
    if job.kind == 'attack' then
        if p.status == 1 then return false, 'already engaged' end
        if not job.target_id then return false, 'no target' end
    end
    -- A missed interruption packet should not strand readiness forever.
    if casting and now - casting_since > 20 then casting = false end
    if casting or now < next_action_at then return false end

    if job.kind == 'spell' and job.id then
        local timers = windower.ffxi.get_spell_recasts()
        if timers and (timers[job.id] or 0) > 0 then return false end
    elseif job.kind == 'ws' then
        if not p.vitals or (p.vitals.tp or 0) < 1000 then return false end
    elseif job.kind == 'ja' and job.id then
        local ability = res.job_abilities[job.id]
        local recast_id = ability and ability.recast_id
        if recast_id then
            local timers = windower.ffxi.get_ability_recasts()
            if timers and (timers[recast_id] or 0) > 0 then return false end
        end
    end
    return true
end

local wait_messages = {[17] = true, [87] = true, [90] = true}

local reject_lines = {
    'Unable to cast spells at this time%.',
    'Unable to use job ability%.',
    'Unable to use weapon skill%.',
    'Unable to use ranged attack%.',
    'Unable to use item%.',
    'You must wait longer to perform that action%.',
}

do
    local messages = res.action_messages
    if messages then
        for id, entry in pairs(messages) do
            if type(id) == 'number' and type(entry) == 'table' then
                local en = entry.en or entry.english
                if type(en) == 'string' then
                    for _, pattern in ipairs(reject_lines) do
                        if en:find(pattern) then
                            wait_messages[id] = true
                            break
                        end
                    end
                end
            end
        end
    end
end

local kind_by_prefix = {
    ['/ma'] = 'spell',  ['/magic'] = 'spell',
    ['/nin'] = 'spell', ['/ninjutsu'] = 'spell',
    ['/so'] = 'spell',  ['/song'] = 'spell',
    ['/ws'] = 'ws',     ['/weaponskill'] = 'ws',
    ['/ja'] = 'ja',     ['/jobability'] = 'ja',  ['/pet'] = 'ja',
    ['/item'] = 'item',
    ['/ra'] = 'ranged', ['/range'] = 'ranged',   ['/rangedattack'] = 'ranged',
    ['/throw'] = 'ranged', ['/shoot'] = 'ranged',
    ['/attack'] = 'attack', ['/a'] = 'attack',
}

local resource_by_kind = {spell = 'spells', ws = 'weapon_skills', ja = 'job_abilities'}

local label_by_kind = {spell = 'Spell', ws = 'Weaponskill', ja = 'Job ability', item = 'Item', ranged = 'Ranged attack', attack = 'Attack'}

local resource_by_category = {
    [4]  = 'spells',        [8]  = 'spells',
    [6]  = 'job_abilities', [13] = 'job_abilities',
    [14] = 'job_abilities', [15] = 'job_abilities',
    [3]  = 'weapon_skills', [7]  = 'weapon_skills',
    [5]  = 'items',         [9]  = 'items',
}
local id_lives_in_target = {[7] = true, [8] = true, [9] = true}
local kind_by_resource = {spells = 'spell', job_abilities = 'ja',
                          weapon_skills = 'ws', items = 'item'}

local job  = nil
local echo = nil

local lookups = {}
local function ability_id(kind, name)
    local resource = resource_by_kind[kind]
    if not resource or not name then return nil end

    if not lookups[resource] then
        local tbl = {}
        for _, entry in pairs(res[resource]) do
            if type(entry) == 'table' and entry.en then tbl[entry.en:lower()] = entry.id end
        end
        lookups[resource] = tbl
    end
    return lookups[resource][name:lower()]
end

local function identify(line)
    local prefix = line:match('^(%S+)')
    if not prefix then return nil end

    local kind = kind_by_prefix[prefix:lower()]
    if not kind then return nil end

    local rest = line:match('^%S+%s+(.+)$')
    if not rest then return kind, nil end

    local name = rest:match('^"([^"]+)"')
    if not name then
        name = rest:gsub('%s*<%S+>%s*$', ''):gsub('%s+%d+%s*$', ''):gsub('%s+$', '')
    end

    return kind, ability_id(kind, name)
end

local function on_refused()
    if not job or job.waiting then return end
    local limit = settings.mode == 'ready' and 2 or max_attempts
    if job.attempts >= limit then
        job = nil
        return
    end

    local now = os.clock()
    job.waiting = true
    job.rejected_at = now
    job.deadline = now + settings.max_wait
    job.fire_at = settings.mode == 'ready' and nil or (now + retry_delay)

    if settings.notify then
        windower.add_to_chat(207, label_by_kind[job.kind] ..
            (settings.mode == 'ready' and ' was refused. Waiting for readiness.' or ' was unsuccessful. Retrying.'))
    end
end

windower.register_event('outgoing text', function(original, modified, blocked)
    local line = type(modified) == 'string' and modified or original
    if type(line) ~= 'string' or line:sub(1, 1) ~= '/' then return end

    local prefix = line:match('^(%S+)')
    if not prefix or not kind_by_prefix[prefix:lower()] then return end

    if echo and line == echo.cmd and os.clock() < echo.deadline then
        echo = nil
        return
    end

    if line:find('<st') then return end

    local kind, id = identify(line)
    if not kind then return end

    -- /attack without an argument toggles on/off. Replay only an idempotent
    -- /attack on, never a toggle or /attack off.
    if kind == 'attack' then
        local rest = (line:match('^%S+%s*(.-)%s*$') or ''):lower()
        if rest:find('^off') then job = nil; return end
        if not settings.attack then return end
        local p = player()
        if p and p.status == 1 then return end
        local tid = current_target_id()
        if not tid then return end
        job = {cmd = '/attack on', kind = 'attack', target_id = tid, attempts = 1}
        return
    end

    local tracked_target = line:find('<t>', 1, true) and current_target_id() or nil
    job = {cmd = line, kind = kind, id = id, target_id = tracked_target, attempts = 1}
end)

windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if id ~= 0x029 or type(original) ~= 'string' or #original < 26 then return end

    local p = windower.ffxi.get_player()
    if not p then return end

    local actor   = original:unpack('I', 0x05)
    local target  = original:unpack('I', 0x09)
    local message = original:unpack('H', 0x19) % 32768
    if actor ~= p.id and target ~= p.id then return end

    if message == 16 then casting = false end -- casting interrupted
    if job and wait_messages[message] then on_refused() end
end)

windower.register_event('incoming text', function(original, modified, mode, modified_mode, blocked)
    if not job then return end

    for _, pattern in ipairs(reject_lines) do
        if (type(original) == 'string' and original:find(pattern))
        or (type(modified) == 'string' and modified:find(pattern)) then
            on_refused()
            return
        end
    end
end)

windower.register_event('action', function(act)
    local p = player()
    if not p or act.actor_id ~= p.id then return end

    -- Only observed action events, not predicted animation timers, can tell
    -- us whether a previous cast has actually started or finished.
    if act.category == 8 then casting = true; casting_since = os.clock() end
    if act.category == 4 then casting = false end
    if act.category == 3 or act.category == 4 or act.category == 5
        or act.category == 6 or act.category == 13 or act.category == 14
        or act.category == 15 then
        next_action_at = os.clock() + 0.25 -- short buffer, never assumed server confirmation
    end
    if not job then return end
    if job.kind == 'attack' and p.status == 1 then job = nil; return end

    if job.kind == 'ranged' and (act.category == 2 or act.category == 12) then
        job = nil
        return
    end

    local resource = resource_by_category[act.category]
    if not resource or kind_by_resource[resource] ~= job.kind then return end

    local id
    if id_lives_in_target[act.category] then
        local t = act.targets and act.targets[1]
        local a = t and t.actions and t.actions[1]
        id = a and a.param
    else
        id = act.param
    end

    if id and job.id and id == job.id then job = nil end
end)

windower.register_event('prerender', function()
    local now = os.clock()

    if echo and now > echo.deadline then echo = nil end

    if not job then return end
    if job.kind == 'attack' then
        local p = player()
        if p and p.status == 1 then job = nil; return end
    end
    if not job.waiting then return end

    if now >= job.deadline then
        if settings.notify then windower.add_to_chat(207, '[Failsafe] Pending action expired without a safe opening.') end
        job = nil
        return
    end
    if now < (job.fire_at or (job.rejected_at + 0.35)) then return end
    local ready, why = ready_for(job, now)
    if why == 'target changed' or why == 'already engaged' or why == 'no target' then
        job = nil
        return
    end
    if settings.mode == 'ready' and not ready then return end
    -- The fixed mode retains its original 0.65s retry interval, but still
    -- refuses to retry a toggled-off /attack or a changed target.
    job.waiting = false
    job.fire_at = nil
    job.attempts = job.attempts + 1
    echo = {cmd = job.cmd, deadline = now + echo_timeout}
    windower.send_command('input ' .. job.cmd)
end)

local function help()
    windower.add_to_chat(207, '[Failsafe] Commands:')
    windower.add_to_chat(207, '  //failsafe mode ready|fixed   - State-aware attempt or original fixed retry')
    windower.add_to_chat(207, '  //failsafe attack on|off     - Track /attack on (never auto-disengage)')
    windower.add_to_chat(207, '  //failsafe maxwait <seconds> - Timeout for pending action (1-15)')
    windower.add_to_chat(207, '  //failsafe notify [on|off]   - Announce rejected actions')
    windower.add_to_chat(207, '  //failsafe status            - Show settings and pending action')
    windower.add_to_chat(207, '  //failsafe help              - Show commands')
    windower.add_to_chat(207, '  //failsafe restart           - Reload this addon')
    windower.add_to_chat(207, '  //failsafe unload            - Unload this addon')
end

local function status()
    windower.add_to_chat(207, string.format('[Failsafe] v%s | Mode: %s | Attack: %s | Notify: %s | Max wait: %.1fs | Pending: %s',
        _addon.version, settings.mode, settings.attack and 'ON' or 'OFF',
        settings.notify and 'ON' or 'OFF', settings.max_wait,
        job and label_by_kind[job.kind] or 'none'))
end

windower.register_event('addon command', function(cmd, arg)
    cmd = cmd and cmd:lower() or ''
    arg = arg and arg:lower() or nil
    if cmd == 'status' then status(); return end
    if cmd == 'help' or cmd == '' then help(); return end
    if cmd == 'restart' or cmd == 'unload' then
        windower.add_to_chat(207, '[Failsafe] '.. (cmd == 'restart' and 'Reloading.' or 'Unloading.'))
        windower.send_command('lua ' .. (cmd == 'restart' and 'reload' or 'unload') .. ' failsafe')
        return
    end
    if cmd == 'mode' then
        if arg ~= 'ready' and arg ~= 'fixed' then help(); return end
        settings.mode = arg
    elseif cmd == 'attack' or cmd == 'notify' then
        if arg ~= 'on' and arg ~= 'off' and arg ~= nil then help(); return end
        settings[cmd] = arg == 'on' or (arg == nil and not settings[cmd])
    elseif cmd == 'maxwait' then
        local n = tonumber(arg)
        if not n or n < 1 or n > 15 then help(); return end
        settings.max_wait = n
    else
        help(); return
    end
    job = nil
    settings:save('all')
    status()
end)

local function reset()
    job = nil
    echo = nil
    casting = false
    next_action_at = 0
    casting_since = 0
end

windower.register_event('zone change', reset)
windower.register_event('logout', reset)