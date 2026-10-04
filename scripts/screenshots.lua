local _, addon = ...
local Screenshots = {}
addon.Screenshots = Screenshots

-- Fictional, local-only dialogue. Odd lines are incoming; even lines are replies.
local cast = {
    {
        name = "Aeloria",
        race = "Night Elf",
        class = "Druid",
        classFile = "DRUID",
        area = "Darnassus",
        unread = 0,
        messages = {
            "Hey! Still up for a dungeon tonight? :)",
            "Absolutely. Just finishing a herb run.",
            "Perfect. Bramwick is bringing potions and I found us a tank.",
            "That already sounds more organised than last time.",
            "Last time we called falling off the bridge a shortcut :D",
            "It was a very direct route to the graveyard.",
            "Meet at the inn in ten? I can heal.",
            "On my way! Saving you a seat by the fire.",
        },
    },

    {
        name = "Bramwick",
        race = "Dwarf",
        class = "Hunter",
        classFile = "HUNTER",
        area = "Ironforge",
        unread = 3,
        messages = {
            "Found the pet I was looking for!",
            "The bear, or the suspiciously angry boar?",
            "The bear. His name is Turnip.",
            "A fearsome name. Enemies will tremble.",
            "He has already eaten half my dinner.",
            "That sounds like a successful bonding exercise.",
            "Also, I made those potions for tonight.",
            "I'll leave a stack in the bank before we head out.",
        },
    },

    {
        name = "Seraphine",
        race = "Human",
        class = "Priest",
        classFile = "PRIEST",
        area = "Stormwind",
        unread = 0,
        messages = {
            "Do you still need the robe enchanted?",
            "Yes please! I have all the materials.",
            "Great, meet me near the auction house.",
            "Be there in a minute. Taking the scenic route.",
            "You got lost in the canals again, didn't you?",
            "Only briefly. The fish were very helpful.",
            "There you are. Trade whenever you're ready :)",
            "Thank you! That should last me a good while.",
        },
    },

    {
        name = "Thornak",
        race = "Orc",
        class = "Warrior",
        classFile = "WARRIOR",
        area = "Orgrimmar",
        unread = 2,
        messages = {
            "We have room for one more if you're free.",
            "What are we running?",
            "Something relaxed. A few quests and possibly a terrible decision.",
            "That is my favourite kind of evening.",
            "Bring bandages. I have a plan.",
            "Your last plan involved three extra packs.",
            "This one has fewer stairs.",
            "inv when you're ready :)",
        },
    },

    {
        name = "Lunessa",
        race = "Night Elf",
        class = "Rogue",
        classFile = "ROGUE",
        area = "Ashenvale",
        unread = 0,
        messages = {
            "I found a quiet spot with a view of the whole valley.",
            "Is it reachable without falling off anything?",
            "Mostly.",
            "That is not the reassurance you think it is.",
            "I'll wait by the path. The light is beautiful right now.",
            "Coming! Let me clear some bag space first.",
            "For screenshots?",
            "For the twenty flowers I will inevitably pick on the way.",
        },
    },

    {
        name = "Fizzlebop",
        race = "Gnome",
        class = "Mage",
        classFile = "MAGE",
        area = "Ironforge",
        unread = 1,
        messages = {
            "Small update: the experiment worked.",
            "Why do I feel there is a second part to that sentence?",
            "The results are slightly more sheep-shaped than expected.",
            "How slightly?",
            "Entirely.",
            "Please tell me you can undo it.",
            "Of course. Probably. Bring snacks.",
            "Actually, bring grass.",
        },
    },

    {
        name = "Maelric",
        race = "Undead",
        class = "Warlock",
        classFile = "WARLOCK",
        area = "Undercity",
        unread = 0,
        messages = {
            "Ready for another attempt at that last boss?",
            "Yes. I watched the patrol this time.",
            "And the one behind the patrol?",
            "You make a compelling point.",
            "Let's clear the side room first, then save cooldowns for the final phase.",
            "Agreed. Slow and steady tonight.",
            "Look at us, learning from our mistakes.",
            "Don't tell anyone. We have a reputation.",
        },
    },

    {
        name = "Talura",
        race = "Tauren",
        class = "Shaman",
        classFile = "SHAMAN",
        area = "Thunder Bluff",
        unread = 2,
        messages = {
            "The sunset here is incredible.",
            "Still up on the bluff?",
            "Yes. Just fishing and listening to the wind.",
            "That sounds much better than sorting my bank.",
            "Leave the bank for tomorrow. Bring a fishing pole.",
            "You are a very persuasive person.",
            "I even saved you the lucky spot.",
            "No promises about the fish, though.",
        },
    },

    {
        name = "Roswyn",
        race = "Human",
        class = "Paladin",
        classFile = "PALADIN",
        area = "Westfall",
        unread = 0,
        messages = {
            "Thanks for helping with those quests earlier.",
            "Any time! Did you get the shield?",
            "I did! It matches absolutely nothing I own.",
            "A true adventurer's outfit.",
            "Blue boots, green gloves, enormous red shield.",
            "You will be very easy to find in a crowd.",
            "Exactly. Tactical fashion.",
            "We should finish the next chain tomorrow :)",
        },
    },

    {
        name = "Zinjara",
        race = "Troll",
        class = "Hunter",
        classFile = "HUNTER",
        area = "The Barrens",
        unread = 0,
        messages = {
            "Taking the long road back. Want company?",
            "Sure! I'm just outside the crossroads.",
            "Good. I have a story about today's hunt.",
            "Does it end with you running away?",
            "It ends with a strategic change of direction.",
            "Naturally.",
            "And a surprisingly fast turtle.",
            "All right, I need to hear this one.",
        },
    },
}

function Screenshots:Create()
    if not addon.developmentMode then
        return
    end

    local data = Chatter.db.char
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
                area = person.area,
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
