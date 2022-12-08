
require('chat')
require('logger')
require('tables')
config = require('config')
res = require('resources')
packets = require('packets')

_addon.name = 'autotarget'
_addon.author = 'Fendo'
_addon.version = '0.1'
_addon.commands = {'autotarget', 'atar'}

Start_Engine = true
Is_Casting = false
Is_Busy = 0
Buff_Active = {}
Action_Delay = 1
New_Target = ''
Debug_Mode = false

settings = config.load({
    targets = L{},
    add_to_chat_mode = 11,
    sets = {},
    pull_target = false,
    pull_target_action = '',
    engine_delay = 3,
})

windower.register_event('incoming chunk', function(id, data)
    if id == 0x028 then
        local action_message = packets.parse('incoming', data)
        if action_message["Category"] == 4 then
            Is_Casting = false
        elseif action_message["Category"] == 8 then
            Is_Casting = true
            if action_message["Target 1 Action 1 Message"] == 0 then
                Is_Casting = false
                Is_Busy = Action_Delay
            end
        end
    end
end)

windower.register_event('outgoing chunk', function(id, data)
    if id == 0x015 then
        local action_message = packets.parse('outgoing', data)
        PlayerH = action_message["Rotation"]
    end
end)

-- Run to target.
function Heading_To(X,Y)
    local X = X - windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id).x
    local Y = Y - windower.ffxi.get_mob_by_id(windower.ffxi.get_player().id).y
    local H = math.atan2(X,Y)
    return H - 1.5708
end

-- Turn toward target.
function Turn_To_Target()
    local destX = windower.ffxi.get_mob_by_target('t').x
    local destY = windower.ffxi.get_mob_by_target('t').y
    local direction = math.abs(PlayerH - math.deg(Heading_To(destX,destY)))
    if direction > 10 then
        windower.ffxi.turn(Heading_To(destX,destY))
    end
end

-- Get the nearest target and return mob ID.
function Target_Nearest(target)
    windower.add_to_chat(settings.add_to_chat_mode, 'Finding Targets')
    local player = windower.ffxi.get_player()
    local mobs = windower.ffxi.get_mob_array()
    local closest
    for _, mob in pairs(mobs) do
        if mob.valid_target and mob.hpp > 99 and target:contains(mob.name:lower()) then
            if not closest or mob.distance < closest.distance then
                closest = mob
            end
        end
    end
    if not closest then
        windower.add_to_chat(settings.add_to_chat_mode, 'Cannot find valid target')
        return
    end
    windower.add_to_chat(settings.add_to_chat_mode, 'Targetting '..closest.name..' - '.. closest.id)

    return closest.id
end

-- Packet Inject to target the mob by ID and engage the target. Pull if pull_target is true and there is an action to pull with.
function Engage_Target(target_ID)
    local player = windower.ffxi.get_player()
    packets.inject(packets.new('incoming', 0x058, {
        ['Player'] = player.id,
        ['Target'] = target_ID,
        ['Player Index'] = player.index,
    }))
    if settings.pull_target == true and settings.pull_target_action ~= '' then
        windower.send_command('wait 0.5; input /attack <t>; '..settings.pull_target_action..' <t>; /follow <t>')
    else
        windower.send_command('wait 0.5; input /attack <t>; /follow <t>')
    end
end

-- Check distance from mob then turn toward and run up to target if it's over 3.
function Check_Distance()
    local distance = windower.ffxi.get_mob_by_target('t').distance:sqrt()
    if distance > 3 then
        Turn_To_Target()
        windower.ffxi.run()
    else
        windower.ffxi.run(false)
    end
end

-- This is the main loop of the entire AutoTarget system.
-- It will keep running as long as the autotarget on is going (Start_Engine = true).
function Engine()
    -- Get the refreshed buffs list.
    Buffs = windower.ffxi.get_player()["buffs"]
    table.reassign(Buff_Active, Convert_Buff_List(Buffs))

    -- Make sure player can do stuff otherwise otherwise set it as busy.
    if Check_Disable() == true then
        Is_Busy = 1
    end

    -- If it's no longer busy then go into the combat check.
    -- Otherwise tick down the busy for the next loop.
    if Is_Busy < 1 then
        Combat()
    else
        Is_Busy = Is_Busy -1
    end
    -- Engine Loop to keep repeating this function on the set delay.
    if Start_Engine then
        coroutine.schedule(Engine, settings.engine_delay)
    end
end


-- This is the Engaged / Idle check to see if a new target can be snagged.
-- It tries to take in account some lag time and if a target is selected but not engaged.
-- Hopefully it's fixed enough where it will hang onto a target and not keep trying to grab new ones too quickly.
-- If it does you end up with many friends you don't want.
function Combat()
    local status = res.statuses[windower.ffxi.get_player().status].english
    -- Debugging things just to make sure targets don't get swapped on me.
    if Debug_Mode == true then
        windower.add_to_chat(settings.add_to_chat_mode,'Current Target: ' .. New_Target)
        if windower.ffxi.get_mob_by_target("t") ~= nil then
            windower.add_to_chat(settings.add_to_chat_mode,'Current Target HPP: ' .. windower.ffxi.get_mob_by_target("t").hpp)
        end
        windower.add_to_chat(settings.add_to_chat_mode,'Current Engine Delay: ' .. tostring(settings.engine_delay))
    end

    -- If Engaged move up to the mob and attack it. If the mob's health drops below 95% or dies then clear target.
    if status == 'Engaged' then
        -- While enagaged the distance and where you are turning are checked.
        if windower.ffxi.get_mob_by_target('t') ~=nil then
            Turn_To_Target()
            Check_Distance()

            -- Once you do some damage to the mob just clear the new target. Shouldn't lose mob otherwise.
            if windower.ffxi.get_mob_by_target("t").hpp < 95 then
                New_Target = ''
            end
        end
        -- If the mob happens to die before the  loop comes up reset the target also.
        if windower.ffxi.get_mob_by_target('t') ==nil then
            New_Target = ''
        end
    -- If Idle then either grab the mob that is targetting or clear it out and find a new mob.
    elseif status == 'Idle' then
        -- If you happen to be targetting something manually or by a loop prior...
        if windower.ffxi.get_mob_by_target('t') ~=nil then
            if Debug_Mode == true then
                windower.add_to_chat(settings.add_to_chat_mode,'Current Target ID: ' .. windower.ffxi.get_mob_by_target('t').id)
                windower.add_to_chat(settings.add_to_chat_mode,'Claim Current Target ID? : ' .. tostring(Check_Claim(windower.ffxi.get_mob_by_target('t').id)))
            end
            -- Check the Claim on the mob and if you don't claim it do so if it's at 100 HP otherwise go find something else.
            if Check_Claim(windower.ffxi.get_mob_by_target('t').id) == false then
                if windower.ffxi.get_mob_by_target('t').hpp == 100 then
                    Engage_Target(tonumber(New_Target))
                else
                    New_Target = Target_Nearest(settings.targets)
                end
            end
        end
        -- If no new target go get another one and engage it.
        if New_Target == '' then
            -- Otherwise go find a new target.
            New_Target = Target_Nearest(settings.targets)
        else
            Engage_Target(New_Target)
        end
    end
end

-- Do we have claim on this mob? (Probably not).
function Check_Claim(id)
    local id = id or 0
    local player_id = windower.ffxi.get_player().id
    local mob = windower.ffxi.get_mob_by_id(id)
    local party_table = windower.ffxi.get_party()
    local party_ids = T{}

    for _,member in pairs(party_table) do
        if type(member) == 'table' and member.mob then
            party_ids:append(member.mob.id)
        end
    end

    for i,v in pairs(party_ids) do
        local pet_mob = windower.ffxi.get_mob_by_id(v)
        if pet_mob then
            local pet_idx = pet_mob.pet_index or nil
            if pet_idx then
                party_ids:append(windower.ffxi.get_mob_by_index(pet_idx).id)
            end
        end
    end

    if party_ids:contains(mob.claim_id) then
        return true
    end
    return false
end

-- Check for any disabling buffs so the engine doesn't spam out.
function Check_Disable()
    local player = windower.ffxi.get_player()
    if player.hp == 0 then
        windower.add_to_chat(settings.add_to_chat_mode,'Abort: You are dead.')
        return true
    elseif Buff_Active.terror then
        windower.add_to_chat(settings.add_to_chat_mode,'Abort: You are terrorized.')
        return true
    elseif Buff_Active.petrification then
        windower.add_to_chat(settings.add_to_chat_mode,'Abort: You are petrified.')
        return true
    elseif Buff_Active.sleep or Buff_Active.Lullaby then
        windower.add_to_chat(settings.add_to_chat_mode,'Abort: You are asleep.')
        return true
    elseif Buff_Active.stun then
        windower.add_to_chat(settings.add_to_chat_mode,'Abort: You are stunned.')
        return true
    else
        return false
    end
end

-- Convert buffs.
function Convert_Buff_List(bufflist)
    local buffarr = {}
    for i,v in pairs(bufflist) do
        if res.buffs[v] then -- For some reason we always have buff 255 active, which doesn't have an entry.
            local buff = res.buffs[v].english
            if buffarr[buff] then
                buffarr[buff] = buffarr[buff] +1
            else
                buffarr[buff] = 1
            end

            if buffarr[v] then
                buffarr[v] = buffarr[v] +1
            else
                buffarr[v] = 1
            end
        end
    end
    return buffarr
end


-- All the Addon Commands.
Commands = {}

-- Saves target list as a set.
Commands.save = function(set_name)
    if not set_name then
        windower.add_to_chat(settings.add_to_chat_mode, 'A saved target set needs a name: //autotarget save <set>')
        return
    end

    settings.sets[set_name] = L{settings.targets:unpack()}
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode, set_name .. ' saved')
end

-- Load a target set.
Commands.load = function(set_name)
    if not set_name or not settings.sets[set_name] then
        windower.add_to_chat(settings.add_to_chat_mode, 'Unknown target set: //autotarget load <set>')
        return
    end

    settings.targets = L{settings.sets[set_name]:unpack()}
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode, set_name .. ' target set loaded')
end

-- Add a single target.
Commands.add = function(...)
    local target = T{...}:sconcat()
    if target == 'nil' then return end

    if target == '' then
        local selected_target = windower.ffxi.get_mob_by_target('t')
        if not selected_target then return end
        target = selected_target.name
    end

    target = target:lower()
    if not settings.targets:contains(target) then
        settings.targets:append(target)
        settings.targets:sort()
        settings:save()
    end

    windower.add_to_chat(settings.add_to_chat_mode, target .. ' added')
end
Commands.a = Commands.add

-- Remove a single target.
Commands.remove = function(...)
    local target = T{...}:sconcat()

    if target == '' then
        local selected_target = windower.ffxi.get_mob_by_target('t')
        if not selected_target then return end
        target = selected_target.name
    end

    target = target:lower()
    local new_targets = L{}
    for k, v in ipairs(settings.targets) do
        if v ~= target then
            new_targets:append(v)
        end
    end
    settings.targets = new_targets
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode, target .. ' removed')
end
Commands.r = Commands.remove

-- Remove all targets.
Commands.removeall = function()
    settings.targets = L{}
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode, 'All targets removed')
end
Commands.ra = Commands.removeall

-- List targets.
Commands.list = function()
    if #settings.targets == 0 then
        windower.add_to_chat(settings.add_to_chat_mode, 'There are no targets set')
        return
    end

    windower.add_to_chat(settings.add_to_chat_mode, 'Targets:')
    for _, target in ipairs(settings.targets) do
        windower.add_to_chat(settings.add_to_chat_mode, '  ' .. target)
    end
end
Commands.l = Commands.list

-- Manually pull a target with this command.
Commands.target = function()
    New_Target = Target_Nearest(settings.targets)
    Engage_Target(New_Target)
end
Commands.t = Commands.target

-- Turn on Autotarget - starts the engine.
Commands.on = function()
    windower.add_to_chat(settings.add_to_chat_mode,"....Starting Autotargetting....")
    Start_Engine = true
    New_Target = ''
    Engine()
end
Commands.start = Commands.on

-- Turn off Autotarget - stops the engine.
Commands.off = function()
    windower.add_to_chat(settings.add_to_chat_mode,"....Stopping Autotargetting....")
    Start_Engine = false
    New_Target = ''
    Engine()
end
Commands.stop = Commands.off

-- Toggle to pull target with an action to perform when aggroing the mob vs just running up and attacking.
Commands.pulltarget = function()
    if settings.pull_target == true then
        settings.pull_target = false
    else
        settings.pull_target = true
    end
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode,"....Pulling Targets: ".. tostring(settings.pull_target) .. "....")
end
Commands.pt = Commands.pulltarget

-- An action to perform when aggroing the mob vs just running up and attacking.
Commands.pullaction = function(action)
    if not action or action == "" then
        windower.add_to_chat(settings.add_to_chat_mode, 'No target pull action set: //autotarget pullaction <action>')
        return
    end
    settings.pull_target_action = action
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode,"....Pulling Targets with " ..settings.pull_target_action.. "....")
end
Commands.pa = Commands.pullaction

-- The time in seconds to delay out the engine loop.
Commands.enginedelay = function(delay)
    if tonumber(delay) == "nil" then
        windower.add_to_chat(settings.add_to_chat_mode, 'Improper engine delay set: //autotarget enginedelay <number>')
        return
    end
    settings.engine_delay = tonumber(delay)
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode,"....Engine delay set to " ..tostring(delay).. "....")
end
Commands.delay = Commands.enginedelay

-- Choose which chat window the output will go to.
Commands.addtochat = function(num)
    if tonumber(num) == "nil" then
        windower.add_to_chat(settings.add_to_chat_mode, 'Improper chat window set: //autotarget addtochat <number>')
        return
    end
    settings.add_to_chat_mode = tonumber(num)
    settings:save()
    windower.add_to_chat(settings.add_to_chat_mode,"....Chat window set to " ..tostring(num).. "....")
end

-- Debugging Mode Toggle.
Commands.debug = function()
    if Debug_Mode == true then
        Debug_Mode = false
    else
        Debug_Mode = true
    end
    windower.add_to_chat(settings.add_to_chat_mode,"....Debug Mode is : ".. tostring(Debug_Mode) .. " ....")
end

-- Display the help menu.
Commands.help = function()
    windower.add_to_chat(settings.add_to_chat_mode, 'AutoTarget:')
    windower.add_to_chat(settings.add_to_chat_mode, '  Note - Can use //atar in place of //autotarget for any command')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget <on|start> - start autotargetting')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget <off|stop> - stop autotargetting')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget add <target name> - add a target to the list')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget remove <target name> - remove a target from the list')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget removeall - remove all targets from the list')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget target - target the nearest target from the list manually')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget pulltarget <true|false> - turns on pulling with an action - must include action')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget pullaction <action> - Works with pull target and is the declared action to attempt to pull with /<action> (needs shortcuts installed)')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget save <set> - save current targets as a target set')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget load <set> - load a previously saved target set')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget list - list current targets')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget enginedelay <number> - this is the wait on autotargetting between trying to find a new mob (default is 3) Lower may cause multiple target pulls.')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget addtochat <number> - this is the chat window that the chatter is added to. Default is 11')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget debug <true|false> - will give extra info about what is going on with logic.')
    windower.add_to_chat(settings.add_to_chat_mode, '  //autotarget help - display this help')
    windower.add_to_chat(settings.add_to_chat_mode, '(For more detailed information, see the readme)')
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'

    if Commands[command] then
        Commands[command](...)
    else
        Commands.help()
    end
end)
