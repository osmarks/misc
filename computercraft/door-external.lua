local channel = 22907
local modem = peripheral.find "modem"

modem.open(channel)

while true do
	term.clear()
	term.setCursorPos(1, 1)
	print "GTech RDS-V2 Door Lock System Terminal"
	write "Passcode: "
	local input = read "*"
	modem.transmit(channel, channel, input)
	parallel.waitForAny(
		function()
			local _, _, channel, reply_channel, message, distance = os.pullEvent "modem_message"
			if distance < 10 then
				print(message)
				sleep(5)
			end
		end,
		function()
			sleep(5)
			printError "Connection timed out. Press the Any key to continue."
			os.pullEvent "char"
		end)
end