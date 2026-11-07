--[[
BSD 3-Clause License

Copyright (c) 2026 Broguypal
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of Broguypal nor the names of its contributors may be used
   to endorse or promote products derived from this software without specific
   prior written permission.

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

_addon.name    = 'TrueTargetLock'
_addon.author  = 'Broguypal'
_addon.version = '1.3.0'
_addon.commands = {'truetargetlock'}

-- Throttle settings (edit here if desired)
local TURN_INTERVAL = 0.10     -- seconds between turn attempts
local MIN_DELTA     = 0.05     -- radians (~2.9°); must be off by this much to turn

local last_turn_t = 0

local config = require('config')

local defaults = {
    combat = true,
    locked = true,
}

local settings = config.load(defaults)

-- Explicit gaze-control modes are intentionally session-only. A saved 'away'
-- mode could leave the character facing backwards on the next login.
local faceaway = false
local turnaway_until = 0
local turnaway_target = nil
local DEFAULT_TURNAWAY_SECONDS = 3
local MAX_TURNAWAY_SECONDS = 30

local function clear_turnaway()
    turnaway_until = 0
    turnaway_target = nil
end

if settings.mode ~= nil then
    if settings.mode == 'always' then
        settings.locked = false
    end
    settings.mode = nil
    config.save(settings)
end

local function norm_pi(a)
    while a > math.pi do a = a - 2*math.pi end
    while a < -math.pi do a = a + 2*math.pi end
    return a
end

local function desired_facing_direction(self_vector, target)
    local dx = (target.x - self_vector.x)
    local dy = (target.y - self_vector.y)

    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then
        return nil
    end

    local angle_deg = (math.atan2(dy, dx) * 180 / math.pi) * -1
    return angle_deg * (math.pi / 180)
end

local function on_off(v)
    return v and 'ON' or 'OFF'
end

local function parse_toggle(arg, current)
    if arg == 'on' then return true end
    if arg == 'off' then return false end
    if arg == nil or arg == '' or arg == 'toggle' then return not current end
    return nil
end

local function show_status()
    local remain = math.max(0, turnaway_until - os.clock())
    local mode = remain > 0 and string.format('TURN AWAY (%.1fs)', remain)
        or (faceaway and 'FACE AWAY' or 'FACE TARGET')
    windower.add_to_chat(207, '[TrueTargetLock] Combat: '..on_off(settings.combat)
        ..'  |  Locked: '..on_off(settings.locked)..'  |  Facing: '..mode)
end

local function show_help()
    windower.add_to_chat(207, '[TrueTargetLock] Commands:')
    windower.add_to_chat(207, '  //truetargetlock combat on|off  - Require being engaged (default ON)')
    windower.add_to_chat(207, '  //truetargetlock locked on|off  - Require native target lock (default ON)')
    windower.add_to_chat(207, '  //truetargetlock faceaway on|off - Face 180 degrees away until turned off')
    windower.add_to_chat(207, '  //truetargetlock turnaway [seconds] - Face away temporarily (default 3s, max 30s)')
    windower.add_to_chat(207, '  //truetargetlock turnaway off   - Cancel timed turn-away')
    windower.add_to_chat(207, '  //truetargetlock face           - Resume automatic facing')
    windower.add_to_chat(207, '  //truetargetlock status         - Show current settings')
    windower.add_to_chat(207, '  //truetargetlock restart        - Reload this addon')
    windower.add_to_chat(207, '  //truetargetlock unload         - Unload this addon')
end

windower.register_event('addon command', function(cmd, arg)
    cmd = cmd and cmd:lower() or ''
    arg = arg and arg:lower() or nil

    if cmd == 'combat' or cmd == 'locked' then
        local value = parse_toggle(arg, settings[cmd])
        if value == nil then
            windower.add_to_chat(207, '[TrueTargetLock] Usage: //truetargetlock '..cmd..' on|off')
            return
        end

        settings[cmd] = value
        config.save(settings)
        show_status()

        if not settings.combat and not settings.locked then
            windower.add_to_chat(207, '[TrueTargetLock] **You will always face your current target, in or out of combat.**')
        elseif not settings.locked then
            windower.add_to_chat(207, '[TrueTargetLock] **You cannot turn away while engaged.**')
        end
    elseif cmd == 'faceaway' then
        local value = parse_toggle(arg, faceaway)
        if value == nil then
            windower.add_to_chat(207, '[TrueTargetLock] Usage: //truetargetlock faceaway on|off')
            return
        end
        faceaway = value
        clear_turnaway()
        show_status()
    elseif cmd == 'turnaway' or cmd == 'away' then
        if arg == 'off' or arg == 'cancel' then
            clear_turnaway()
            show_status()
            return
        end
        local seconds = arg and tonumber(arg) or DEFAULT_TURNAWAY_SECONDS
        if not seconds or seconds <= 0 or seconds > MAX_TURNAWAY_SECONDS then
            windower.add_to_chat(207, '[TrueTargetLock] Usage: //truetargetlock turnaway [seconds up to 30]|off')
            return
        end
        local p = windower.ffxi.get_player()
        local target = p and p.target_index and windower.ffxi.get_mob_by_index(p.target_index)
        if not target or not target.id or target.id == 0 then
            windower.add_to_chat(207, '[TrueTargetLock] Turn-away needs a current target.')
            return
        end
        -- A timed turn-away takes precedence, then resumes normal targeting.
        faceaway = false
        turnaway_target = target.id
        turnaway_until = os.clock() + seconds
        show_status()
    elseif cmd == 'face' then
        faceaway = false
        clear_turnaway()
        show_status()
    elseif cmd == 'status' then
        show_status()
    elseif cmd == 'restart' then
        windower.add_to_chat(207, '[TrueTargetLock] Reloading.')
        windower.send_command('lua reload truetargetlock')
    elseif cmd == 'unload' then
        windower.add_to_chat(207, '[TrueTargetLock] Unloading.')
        windower.send_command('lua unload truetargetlock')
    else
        show_help()
        show_status()
    end
end)

windower.register_event('prerender', function()
    local t = os.clock()

    if (t - last_turn_t) < TURN_INTERVAL then return end

    local pinfo = windower.ffxi.get_player()
    if not pinfo then return end

    local timed_away = t < turnaway_until
    if not timed_away and turnaway_target then clear_turnaway() end
    local explicit_away = timed_away or faceaway

    -- Explicit facing commands override the automatic combat/lock filters.
    -- Normal face-target behavior still obeys both saved preferences.
    if not explicit_away then
        if settings.combat and pinfo.status ~= 1 then return end
        if settings.locked and not pinfo.target_locked then return end
    end

    if not pinfo.target_index or pinfo.target_index == 0 then return end

    local self_vector = windower.ffxi.get_mob_by_index(pinfo.index or 0)
    if not self_vector then return end

    local target = windower.ffxi.get_mob_by_index(pinfo.target_index)
    if not target or target.id == 0 then return end
    if target.spawn_type == 16 and target.hpp and target.hpp <= 0 then return end

    -- Don't suddenly turn away from a different target when auto-retargeting.
    if timed_away and target.id ~= turnaway_target then
        clear_turnaway()
        return
    end

    local desired = desired_facing_direction(self_vector, target)
    if not desired then return end
    if explicit_away then desired = norm_pi(desired + math.pi) end

    local current = self_vector.facing or self_vector.heading or 0
    local delta = math.abs(norm_pi(desired - current))
    if delta < MIN_DELTA then return end

    windower.ffxi.turn(desired)
    last_turn_t = t
end)
-- No temporary gaze mode survives zones or logouts.
windower.register_event('zone change', function()
    faceaway = false
    clear_turnaway()
end)
windower.register_event('logout', function()
    faceaway = false
    clear_turnaway()
end)
