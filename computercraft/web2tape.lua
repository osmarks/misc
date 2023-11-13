local tape = peripheral.find "tape_drive"
local url, opt = ...
if not tape then error "Tape drive required." end
if not url then error "Specify a URL to download. This may need to be in quotes." end

if opt == "range" then
		print "Fetching in range mode"
		-- horrible bodge to fetch content length as CC appears to mess it up
		local test = http.get { url = url, binary = true, headers = { Range = "bytes=0-1" } }
		local headers = test.getResponseHeaders()
		test.close()
		local range = headers["Content-Range"]
		if not range then error "range not supported?" end
		local z = tonumber(range:match "0%-1/(%d+)")
		print("total size is", z / 1e6, "MB")
		local pos = 0
		local chunk_size = 6e6 -- maximum is 12MB
		if z > tape.getSize() then printError "tape too small, will be truncated" end
		while true do
				local was = pos
				pos = pos + chunk_size
				local range = ("bytes=%d-%d"):format(was, pos - 1)
				local h = http.get { url = url, binary = true, headers = { Range = range } }
				tape.write(h.readAll())
				h.close()
				print("fetched up to", pos / 1e6, "MB")
				if pos > z then print "done!" break end
		end
		print "written successfully"
		return
end

print "Downloading..."
local h = http.get(url, nil, true) -- binary mode
local data = h.readAll()
h.close()
print "Downloaded."

if opt ~= "norestart" then
		print "Seeking to start."
		tape.seek(-tape.getPosition())
end

if #data > (tape.getSize() - tape.getPosition()) then printError "WARNING: Data is longer than tape." end

tape.write(data)
print "Data written."