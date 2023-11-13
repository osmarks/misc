local M = peripheral.find"monitor"
assert(M,"no monitor")

os.loadAPI "ethics.lua"

M.setTextScale(0.5)
M.clear()
M.setCursorPos(1,1)
M.setTextColor(colors.red)
M.write("CHAT ETHICS MONITOR")
M.setCursorPos(1,2)
M.write("Version IIan (thanks ubq)")

local Mw,Mh = M.getSize()
local scorewidth=10
local lbw = 4+16+scorewidth
local wLog = window.create(M,1,12,Mw,Mh-11)
 wLog.setBackgroundColor(colors.black)
 wLog.setTextColor(colors.white)
 wLog.clear()
 wLog.setCursorBlink(true)
local wLb = window.create(M,Mw-lbw+1,1,lbw,11)
-- wLb.setBackgroundColor(colors.red)
-- wLb.clear()
-- wLb.write("LB")

-- utils

local function pad_r(s,width)
	return string.rep(" ",width-#tostring(s))..s
end

local function pad_c(s,width)
	local space = width-#tostring(s)
	local hspace = math.floor(space/2)
	return string.rep(" ",hspace)..s
end


local function round(n)
	-- to nearest int
	local f = math.floor(n)
	if n>=f+0.5 then return math.ceil(n) else return f end
end

local function round_dp(n,dp)
	local exp = 10^dp
	return round(n*exp)/exp
end

local function sci(n)
	if n == 0 then return n end
	local x = math.abs(n)
	local b = math.floor(math.log10(x))
	local a = round_dp(x/10^b,2)
	return (n<0 and "-" or "")..a.."e"..b
end

local function maybe_sci(x)
	if #tostring(x) >= scorewidth then return sci(x) else return x end
end

local function isnan(x)
	return x ~= x
end

-- drawing
--  lb

local function draw_lb(W,scores)
	local w,h = W.getSize()
	W.setBackgroundColor(colors.gray)
	W.clear()

	-- header
	W.setTextColor(colors.lime)
	W.setCursorPos(1,1)
	W.write(pad_c("==[[ LEADERBOARD ]]==",lbw))

	-- line numbers
	W.setTextColor(colors.yellow)
	for line=1,10 do
		W.setCursorPos(1,line+1)
		W.write(pad_r(line,2)..".")
	end

	-- actual scores
	local thescores = {}
	for name,score in pairs(scores) do
		table.insert(thescores,{name=name,score=score})
	end
	table.sort(thescores,function(a,b) return a.score > b.score end)
	for i=1,10 do
		if not thescores[i] then break end
		
		local name,score = thescores[i].name, thescores[i].score
		-- name
		W.setTextColor(colors.white)
		W.setCursorPos(5,i+1)
		W.write(name)
		-- score
		W.setTextColor(colors.red)
		W.setCursorPos(w-scorewidth+1,i+1)
		W.write(pad_r(maybe_sci(score),scorewidth))
	end
end

-- logging
local function log_msg(W,user,text,score)
	local w,h = W.getSize()
	W.scroll(1)
	W.setCursorPos(1,h)

	local function st(c) W.setTextColor(c) end
	local function wr(t) W.write(t) end

	st(colors.white) wr"<" st(colors.orange) wr(user) st(colors.white) wr"> ("
	st(colors.cyan) wr(score) st(colors.white) wr(") ") st(colors.lightGray)

	local x,y = W.getCursorPos()
	local remsp = w-x+1
	if remsp >= 3 then 
		if #text > remsp then
			text = text:sub(1,remsp-3).."..."
		end
		wr(text)
	end
end
	
	
	

-- persistence
local function save_scores(scores)
	local file,err = fs.open(".chatscores","w")
	if err then error("fs.open "..err) end
	file.write(textutils.serialize(scores))
	file.flush()
	file.close()
end

local function load_scores()
	local file,err = fs.open(".chatscores","r")
	if err then
		print("fs.open "..err.." - resetting scores")
		return {}
	end
	local c = file.readAll() or ""
	file.close()
	return textutils.unserialize(c) or {}
end

-- scoring

local function score(msg)
	return ethics.ethicize(msg)
end


local userscores = setmetatable(load_scores(),{__index=function()return 0 end})

while true do
	draw_lb(wLb,userscores)
	local _,user,msg = os.pullEvent"chat"
	local s = score(msg)
	userscores[user] = userscores[user] + s
	if isnan(userscores[user]) then userscores[user] = 0 end
	save_scores(userscores)
	log_msg(wLog,user,msg,s)
end
	

