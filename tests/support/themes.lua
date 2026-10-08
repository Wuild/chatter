local addon = ...
-- Follow the release manifest so new themes are included in every theme harness.
for path in io.lines("Whispr.toc") do
    if path:match("^themes\\") then
        assert(loadfile((path:gsub("\\", "/"))))("Whispr", addon)
    end
end
