local h = http.get "https://raw.githubusercontent.com/MightyPirates/OpenComputers/master-MC1.7.10/src/main/resources/assets/opencomputers/robot.names"
local name_list = h.readAll()
h.close()

local names = {}

local regex = "([^\n]+)" -- technically a pattern and not regex
for line in name_list:gmatch(regex) do
	local comment_pos = line:find "#"
	if comment_pos then line = line:sub(1, comment_pos - 1) end
	local line = line:gsub(" *$", "")
	if #line > 0 then
		table.insert(names, line)
	end
end

local name = names[math.random(1, #names)]
print(name)
os.setComputerLabel(name)
