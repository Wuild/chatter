local name, addon = ...

Chatter = LibStub("AceAddon-3.0"):NewAddon(name, "AceConsole-3.0", "AceEvent-3.0")
-- Developer-only simulations are disabled in normal builds.
addon.developmentMode = false
addon.name = name
addon.defaults = {
    global = {
        themePreset = "default",
        extensions = {},
        maxPeople = 50,
        maxMessages = 200,
        smileys = true,
        timestamps = true,
        outgoingOnRight = true,
        typingIndicators = true,
        showMessagePreviews = true,
        showAllCharacters = false,
        separateWindows = false,
        separateWindowWidth = 550,
        separateWindowHeight = 510,
        autoOpenConversations = true,
        autoSelectIncoming = true,
        suppressWhispers = true,
        hideInCombat = false,
        dontHideWhenTyping = false,
        noOpenInCombat = false,
        minimap = { hide = false, minimapPos = 225 },
        backgroundOpacity = 1,
        windowOpacity = 1,
        fadeWhenIdle = false,
        idleOpacity = 0.35,
        idleFadeDelay = 4,
        animateWindows = true,
        notificationSoundEnabled = true,
        notificationSound = "linux-message",
        chatFont = "Game default",
        chatFontSize = 14,
        chatShadow = false,
        chatShadowColor = { 0, 0, 0, 1 },
    },

    char = { conversations = {}, sequence = 0 },
}
