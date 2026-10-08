local _, addon = ...
local L = addon.L
local Screenshots = {}
addon.Screenshots = Screenshots

-- Fictional, local-only dialogue. Odd lines are incoming; even lines are replies.
local cast
addon.Locale:OnReady(function()
    cast = {
        {
            name = "Aeloria",
            race = L["Night Elf"],
            class = L["Druid"],
            classFile = "DRUID",
            unread = 0,
            messages = {
                L["Hey! Still up for a dungeon tonight? :)"],
                L["Absolutely. Just finishing a herb run."],
                L["Perfect. Bramwick is bringing potions and I found us a tank."],
                L["That already sounds more organised than last time."],
                L["Last time we called falling off the bridge a shortcut :D"],
                L["It was a very direct route to the graveyard."],
                L["Meet at the inn in ten? I can heal."],
                L["On my way! Saving you a seat by the fire."],
            },
        },

        {
            name = "Bramwick",
            race = L["Dwarf"],
            class = L["Hunter"],
            classFile = "HUNTER",
            unread = 3,
            messages = {
                L["Found the pet I was looking for!"],
                L["The bear, or the suspiciously angry boar?"],
                L["The bear. His name is Turnip."],
                L["A fearsome name. Enemies will tremble."],
                L["He has already eaten half my dinner."],
                L["That sounds like a successful bonding exercise."],
                L["Also, I made those potions for tonight."],
                L["I'll leave a stack in the bank before we head out."],
            },
        },

        {
            name = "Seraphine",
            race = L["Human"],
            class = L["Priest"],
            classFile = "PRIEST",
            unread = 0,
            messages = {
                L["Do you still need the robe enchanted?"],
                L["Yes please! I have all the materials."],
                L["Great, meet me near the auction house."],
                L["Be there in a minute. Taking the scenic route."],
                L["You got lost in the canals again, didn't you?"],
                L["Only briefly. The fish were very helpful."],
                L["There you are. Trade whenever you're ready :)"],
                L["Thank you! That should last me a good while."],
            },
        },

        {
            name = "Thornak",
            race = L["Orc"],
            class = L["Warrior"],
            classFile = "WARRIOR",
            unread = 2,
            messages = {
                L["We have room for one more if you're free."],
                L["What are we running?"],
                L["Something relaxed. A few quests and possibly a terrible decision."],
                L["That is my favourite kind of evening."],
                L["Bring bandages. I have a plan."],
                L["Your last plan involved three extra packs."],
                L["This one has fewer stairs."],
                L["inv when you're ready :)"],
            },
        },

        {
            name = "Lunessa",
            race = L["Night Elf"],
            class = L["Rogue"],
            classFile = "ROGUE",
            unread = 0,
            messages = {
                L["I found a quiet spot with a view of the whole valley."],
                L["Is it reachable without falling off anything?"],
                L["Mostly."],
                L["That is not the reassurance you think it is."],
                L["I'll wait by the path. The light is beautiful right now."],
                L["Coming! Let me clear some bag space first."],
                L["For screenshots?"],
                L["For the twenty flowers I will inevitably pick on the way."],
            },
        },

        {
            name = "Fizzlebop",
            race = L["Gnome"],
            class = L["Mage"],
            classFile = "MAGE",
            unread = 1,
            messages = {
                L["Small update: the experiment worked."],
                L["Why do I feel there is a second part to that sentence?"],
                L["The results are slightly more sheep-shaped than expected."],
                L["How slightly?"],
                L["Entirely."],
                L["Please tell me you can undo it."],
                L["Of course. Probably. Bring snacks."],
                L["Actually, bring grass."],
            },
        },

        {
            name = "Maelric",
            race = L["Undead"],
            class = L["Warlock"],
            classFile = "WARLOCK",
            unread = 0,
            messages = {
                L["Ready for another attempt at that last boss?"],
                L["Yes. I watched the patrol this time."],
                L["And the one behind the patrol?"],
                L["You make a compelling point."],
                L["Let's clear the side room first, then save cooldowns for the final phase."],
                L["Agreed. Slow and steady tonight."],
                L["Look at us, learning from our mistakes."],
                L["Don't tell anyone. We have a reputation."],
            },
        },

        {
            name = "Talura",
            race = L["Tauren"],
            class = L["Shaman"],
            classFile = "SHAMAN",
            unread = 2,
            messages = {
                L["The sunset here is incredible."],
                L["Still up on the bluff?"],
                L["Yes. Just fishing and listening to the wind."],
                L["That sounds much better than sorting my bank."],
                L["Leave the bank for tomorrow. Bring a fishing pole."],
                L["You are a very persuasive person."],
                L["I even saved you the lucky spot."],
                L["No promises about the fish, though."],
            },
        },

        {
            name = "Roswyn",
            race = L["Human"],
            class = L["Paladin"],
            classFile = "PALADIN",
            unread = 0,
            messages = {
                L["Thanks for helping with those quests earlier."],
                L["Any time! Did you get the shield?"],
                L["I did! It matches absolutely nothing I own."],
                L["A true adventurer's outfit."],
                L["Blue boots, green gloves, enormous red shield."],
                L["You will be very easy to find in a crowd."],
                L["Exactly. Tactical fashion."],
                L["We should finish the next chain tomorrow :)"],
            },
        },

        {
            name = "Zinjara",
            race = L["Troll"],
            class = L["Hunter"],
            classFile = "HUNTER",
            unread = 0,
            messages = {
                L["Taking the long road back. Want company?"],
                L["Sure! I'm just outside the crossroads."],
                L["Good. I have a story about today's hunt."],
                L["Does it end with you running away?"],
                L["It ends with a strategic change of direction."],
                L["Naturally."],
                L["And a surprisingly fast turtle."],
                L["All right, I need to hear this one."],
            },
        },
    }
end)

function Screenshots:Create()
    if not addon.developmentMode then
        return
    end

    local data = Whispr.db.char
    local now = time()
    -- Seed directly: screenshot samples must never evict real history, even
    -- when the user's retention limits are smaller than this set.
    for index = #cast, 1, -1 do
        local person = cast[index]
        local key = "demo:screenshot:" .. person.name:lower()
        local previous = data.conversations[key]
        local conversation = {
            key = key,
            name = person.name,
            demo = true,
            unread = person.unread,
            messages = {},
            character = {
                race = person.race,
                class = person.class,
                classFile = person.classFile,
                guild = "The Wandering Lanterns",
                level = 60,
            },
        }

        -- Preserve detached-window routing when refreshing the same samples.
        if previous then
            for _, field in ipairs({ "window", "undocked", "undockedOpen", "undockedStandalone" }) do
                conversation[field] = previous[field]
            end
        end

        for messageIndex, text in ipairs(person.messages) do
            data.sequence = (data.sequence or 0) + 1
            conversation.messages[messageIndex] = {
                id = data.sequence,
                text = text,
                outgoing = messageIndex % 2 == 0 and messageIndex <= #person.messages - person.unread,
                time = now - (index - 1) * 900 - (#person.messages - messageIndex) * 75,
            }
        end

        conversation.updated = data.sequence
        data.conversations[key] = conversation
    end

    addon.History.Invalidate()
    addon.Window:Open("demo:screenshot:" .. cast[1].name:lower())
    addon.Window:RefreshList()
end
