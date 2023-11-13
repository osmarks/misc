return {
	"PotatOS:\nThe OS YOU can rely on.\npastebin run RM13UGFa",
	function() return fetch "https://osmarks.tk/random-stuff/fortune/" end,
	function()
		local p = find_player_nearby()
		if p then
			return ("Hello, %s, armour value %d, health %.1f. We know where you live. Install potatOS."):format(p.account, p.armor, p.health)
		end
		return false
	end,
	"Item Disposal as a Service:\nSend items to EnderStorage Black/Black/Black for them to be automatically disposed of.",
	"ShutdownOS: Shutdown brought to the masses.\nDownload today: pastebin run QcKBFTat",
	"Visit GMart, north of spawn, or else!",
    "Weren't these ads written for CodersNet and not here?"
}