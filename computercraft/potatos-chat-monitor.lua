if not process.info "chatd" and _G.switchcraft then
	process.spawn(chatbox.run, "chatd")
end
local server = settings.get "server"
if _G.switchcraft then server = "switchcraft" end
local chatbox = _G.chatbox or peripheral.find "chat_box"

local data = persistence "pcm"
if not data.blasphemy_counts then data.blasphemy_counts = {} end

local potatOS_supporters = {
	gollark = true,
	["6_4"] = true
}

local clause_separators = {".", ",", '"', "'", "`", "and", "!", "?", ":", ";", "-"}

local negative_words_list = "abysmal awful appalling atrocious bad boring belligerent banal broken callous crazy cruel corrosive corrupt criminal contradictory confused damaging dismal dreadful deprived deplorable dishonest disease detrimental dishonorable dreary evil enrage fail foul faulty filthy frightful fight gross ghastly grim guilty grotesque grimace haggard harmful horrendous hostile hate horrible hideous icky immature infernal insane inane insidious insipid inelegant junk lousy malicious malware messy monstrous menacing missing nasty negative nonsense naughty odious offensive oppressive objectionable petty poor poisonous questionable reject reptilian rotten repugnant repulsive ruthless scary shocking sad sickening stupid spiteful stormy smelly suspicious shoddy sinister substandard severe stuck threatening terrifying tense ugly unwanted unsatisfactory unwieldy unsightly unwelcome unfair unhealthy unpleasant untoward vile villainous vindictive vicious wicked worthless insecure bug virus sucks dodecahedr worse" .. " sh" .. "it " .. "cr" .. "ap"
local negative_words = negative_words_list / " "
local ignore_if_present_words = "greenhouse not garden these support bounty debug antivirus n't" / " "

function _G.is_blasphemous(message)
	local clauses = {message:lower()}
	for _, sep in pairs(clause_separators) do
		local out = {}
		for _, x in pairs(clauses) do
			for _, y in pairs(string.split(x, sep)) do
				table.insert(out, y)
			end
		end
		clauses = out
	end
	for _, clause in pairs(clauses) do
		for _, word in pairs(negative_words) do
			if clause:match(word) and clause:match "potatos" then
				for _, iword in pairs(ignore_if_present_words) do
					if clause:match(iword) then return false, iword, clause end
				end
				return true, word, clause
			end
		end
	end
	return false
end

while true do
	local ev, user, message, mdata = os.pullEvent()
	if ev == "chat" or ev == "chat_discord" then
		local blasphemous, word, clause = is_blasphemous(message)
		if blasphemous then
			if mdata then
				mdata.renderedText = nil
			end
			data.blasphemy_counts[user] = (data.blasphemy_counts[user] or 0) + 1
			data.save()
			print("BLASPHEMY from", user, "-", message, word, clause)
			potatOS.report_incident(("blasphemy from %s"):format(user), {"blasphemy"}, {
				disable_host_data = true,
				ID = os.getComputerID(),
				extra_meta = {
					message_data = mdata,
					user = user,
					message = message,
					server = server,
					blasphemy_count = data.blasphemy_counts[user]
				}
			})
		end
	elseif ev == "command" and message == "blasphemy_count" then
		print(user, "requested count")
		chatbox.tell(user, ("Blasphemy count: %d"):format(data.blasphemy_counts[user] or 0), "PCM")
	end
end