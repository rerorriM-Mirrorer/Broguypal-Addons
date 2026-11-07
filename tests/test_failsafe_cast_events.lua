-- Synthetic, offline Failsafe action-event regression tests (Lua 5.1).
-- Run from the repository root: lua tests/test_failsafe_cast_events.lua
-- No Windower client or live game is required; this is NOT in-game validation.

local now = 0
local original_clock = os.clock
os.clock = function() return now end

local event = {}
local sent = {}
local player = {id = 42, status = 0, vitals = {tp = 1000}}
local settings
local target = {id = 100}

package.loaded.pack = true
package.loaded.resources = {
    spells = {[1] = {id = 1, en = 'Cure'}, [2] = {id = 2, en = 'Poisona'}},
    job_abilities = {},
    action_messages = {},
}
package.loaded.config = {
    load = function(defaults)
        defaults.save = function() end
        settings = defaults
        return defaults
    end,
}
windower = {
    register_event = function(name, handler)
        assert(not event[name], 'Duplicate handler: ' .. name)
        event[name] = handler
    end,
    add_to_chat = function() end,
    send_command = function(command) sent[#sent + 1] = command end,
    ffxi = {
        get_player = function() return player end,
        get_mob_by_target = function() return target end,
        get_spell_recasts = function() return {[1] = 0, [2] = 0} end,
        get_ability_recasts = function() return {} end,
    },
}

local file = debug.getinfo(1, 'S').source:gsub('^@', '')
local root = file:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.'
dofile(root .. '/Failsafe/Failsafe.lua')

local function reset()
    now = 0
    sent = {}
    event['zone change']()
    event['addon command']('mode', 'ready')
    assert(settings.mode == 'ready', 'Ready mode was not restored')
end

local function queued_cure()
    local line = '/ma "Cure" <me>'
    event['outgoing text'](line, line, false)
    event['incoming text']('Unable to cast spells at this time.', nil)
end

local function action(category, param, spell_id)
    event.action({
        actor_id = 42,
        category = category,
        param = param,
        targets = {{actions = {{param = spell_id or 1}}}},
    })
end

local function tick(seconds, expected_count)
    now = seconds
    event.prerender()
    assert(#sent == expected_count,
        string.format('At %.2fs expected %d sends, got %d', seconds, expected_count, #sent))
end

reset()
action(8, 24931)
queued_cure()
tick(0.50, 0) -- The spell is still being cast; readiness must stay blocked.
action(8, 28787, 1) -- Interrupt must clear casting, not clear pending Cure as success.
tick(0.51, 1)
assert(sent[1] == 'input /ma "Cure" <me>')

reset()
queued_cure()
action(8, 12345, 1) -- Unknown category-8 subevent must not clear the queued job.
tick(0.50, 1)

reset()
action(8, 24931)
queued_cure()
tick(0.50, 0)
action(4, 2) -- Another spell completion clears casting, but adds short buffer.
tick(0.65, 0)
tick(0.80, 1)

reset()
event['addon command']('mode', 'fixed')
action(8, 24931)
queued_cure()
tick(0.64, 0)
tick(0.66, 1) -- Fixed mode is not gated by casting state.
assert(settings.max_wait == 4.0 and settings.attack == true and settings.notify == true)

os.clock = original_clock
print('PASS: Failsafe cast start, interrupt, unknown variant, completion, fixed-mode regression')
