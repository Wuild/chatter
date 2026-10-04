-- Rendering-only fixtures. Real module activation/cleanup is covered by window.lua.
local addon = ...
addon.Filters:Register("emoji", "FORMAT_MESSAGE_TOKEN", addon.EmojiRenderer.Render)
addon.Filters:Register("emoji", "FORMAT_INPUT_TOKEN", addon.EmojiRenderer.Render)
addon.Filters:Register("emoji", "INPUT_AUTO_SPACE", addon.EmojiRenderer.AutoSpace)
