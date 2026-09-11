local user="kwetzel-projects"
local repo="mining-turtle-scripts"
local base="https://raw.githubusercontent.com/"..user.."/"..repo.."/main/"

local files={
    {"layered.lua","layered"},
    {"not-layered.lua","not-layered"}
}

for _,f in ipairs(files) do
    if fs.exists(f[2]) then fs.delete(f[2]) end
    shell.run("wget",base..f[1],f[2])
end
