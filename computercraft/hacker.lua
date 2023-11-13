local mat = peripheral.wrap "front"
mat.setPaletteColor(colors.black, 0)
mat.setPaletteColor(colors.green, 0x0cff0c)
mat.setPaletteColor(colors.red, 0xff0000)
mat.setTextScale(0.5)
mat.setTextColor(colors.green)
term.redirect(mat)

local jargonWords = {
    acronyms =
       {"TCP", "HTTP", "SDD", "RAM", "GB", "CSS", "SSL", "AGP", "SQL", "FTP", "PCI", "AI", "ADP",
        "RSS", "XML", "EXE", "COM", "HDD", "THX", "SMTP", "SMS", "USB", "PNG", "PHP", "UDP", 
        "TPS", "RX", "ASCII", "CD-ROM", "CGI", "CPU", "DDR", "DHCP", "BIOS", "IDE", "IP", "MAC", 
        "MP3", "AAC", "PPPoE", "SSD", "SDRAM", "VGA", "XHTML", "Y2K", "GUI", "EPS", "SATA", "SAS",
        "VM", "LAN", "DRAM", "L3", "L2", "DNS", "UEFI", "UTF-8", "DDOS", "HDMI", "GPU", "RSA", "AES",
        "L7", "ISO", "HTTPS", "SSH", "SIMD", "GNU", "PDF", "LPDDR5", "ARM", "RISC", "CISC", "802.11",
        "5G", "LTE", "3GPP", "MP4", "2FA", "RCE", "JBIG2", "ISA", "PCIe", "NVMe", "SHA", "QR", "CUDA",
        "IPv4", "IPv6", "ARP", "DES", "IEEE", "NoSQL", "UTF-16", "ADSL", "ABI", "TX", "HEVC", "AVC",
        "AV1", "ASLR", "ECC", "HBA", "HAL", "SMT", "RPC", "JIT", "LCD", "LED", "MIME", "MIMO", "LZW",
        "LGA", "OFDM", "ORM", "PCRE", "POP3", "SMTP", "802.3", "PSU", "RGB", "VLIW", "VPS", "VPN",
        "XMPP", "IRC", "GNSS"}, 
    adjectives =
       {"auxiliary", "primary", "back-end", "digital", "open-source", "virtual", "cross-platform",
        "redundant", "online", "haptic", "multi-byte", "Bluetooth", "wireless", "1080p", "neural",
        "optical", "solid state", "mobile", "unicode", "backup", "high speed", "56k", "analog", 
        "fiber optic", "central", "visual", "ethernet", "Griswold", "binary", "ternary",
        "secondary", "web-scale", "persistent", "Java", "cloud", "hyperscale", "seconday", "cloudscale",
        "software-defined", "hyperconverged", "x86", "Ethernet", "WiFi", "4k", "gigabit", "neuromorphic",
        "sparse", "machine learning", "authentication", "multithreaded", "statistical", "nonlinear",
        "photonic", "streaming", "concurrent", "memory-safe", "C", "electromagnetic", "nanoscale",
        "high-level", "low-level", "distributed", "accelerated", "base64", "purely functional",
        "serial", "parallel", "compute", "graphene", "recursive", "denormalized", "orbital",
        "networked", "autonomous", "applicative", "acausal", "hardened", "category-theoretic",
        "ultrasonic"}, 
    nouns =
       {"driver", "protocol", "bandwidth", "panel", "microchip", "program", "port", "card", 
        "array", "interface", "system", "sensor", "firewall", "hard drive", "pixel", "alarm", 
        "feed", "monitor", "application", "transmitter", "bus", "circuit", "capacitor", "matrix", 
        "address", "form factor", "array", "mainframe", "processor", "antenna", "transistor", 
        "virus", "malware", "spyware", "network", "internet", "field", "acutator", "tetryon",
        "beacon", "resonator", "diode", "oscillator", "vertex", "shader", "cache", "platform",
        "hyperlink", "device", "encryption", "node", "headers", "botnet", "applet", "satellite",
        "Unix", "byte", "Web 3", "metaverse", "microservice", "ultrastructure", "subsystem",
        "call stack", "gate", "filesystem", "file", "database", "bitmap", "Bloom filter", "tensor",
        "hash table", "tree", "optics", "silicon", "hardware", "uplink", "script", "tunnel",
        "server", "barcode", "exploit", "vulnerability", "backdoor", "computer", "page",
        "regex", "socket", "platform", "IP", "compiler", "interpreter", "nanochip", "certificate",
        "API", "bitrate", "acknowledgement", "layout", "satellite", "shell", "MAC", "PHY", "VLAN",
        "SoC", "assembler", "interrupt", "directory", "display", "functor", "bits", "logic",
        "sequence", "procedure", "subnet", "invariant", "monad", "endofunctor", "borrow checker"}, 
    participles =
       {"backing up", "bypassing", "hacking", "overriding", "compressing", "copying", "navigating", 
        "indexing", "connecting", "generating", "quantifying", "calculating", "synthesizing", 
        "inputting", "transmitting", "programming", "rebooting", "parsing", "shutting down", 
        "injecting", "transcoding", "encoding", "attaching", "disconnecting", "networking",
        "triaxilating", "multiplexing", "interplexing", "rewriting", "transducing",
        "acutating", "polarising", "diffracting", "modulating", "demodulating", "vectorizing",
        "compiling", "jailbreaking", "proxying", "Linuxing", "quantizing", "multiplying",
        "scanning", "interpreting", "routing", "rerouting", "tunnelling", "randomizing",
        "underwriting", "accessing", "locating", "rotating", "invoking", "utilizing",
        "normalizing", "hijacking", "integrating", "type-checking", "uploading", "downloading",
        "allocating", "receiving", "decoding"}
}

local hcresponses = {
    'Authorizing ',
    'Authorized...',
    'Access Granted..',
    'Going Deeper....',
    'Compression Complete.',
    'Compilation of Data Structures Complete..',
    'Entering Security Console...',
    'Encryption Unsuccesful Attempting Retry...',
    'Waiting for response...',
    '....Searching...',
    'Calculating Space Requirements',
    "nmap 192.168.1.0/24 -p0-65535",
    "Rescanning Databases...",
    "Hacking all IPs simultaneously...",
    "All webs down, activating proxy",
    "rm -rf --no-preserve-root /",
    "Hacking military satellite network...",
    "Guessing password...",
    "Trying 'password123'",
    "Activating Extra Monitors...",
    "Typing Faster...",
    "Checking StackOverflow",
    "Locating crossbows...",
    "Enabling algorithms and coding",
    "Collapsing Subdirectories...",
    "Enabling Ping Wall...",
    "Obtaining sunglasses...",
    "Rehashing hashes.",
    "Randomizing numbers.",
    "Greening text...",
    "Accessing system32",
    "'); DROP DATABASE system;--",
    "...Nesting VPNs...",
    "Opening Wireshark.",
    "Breaking fifth wall....",
    "Flipping arrows and applying yoneda lemma",
    "Rewriting in Rust"
}

local function choose(arr)
    return arr[math.random(1, #arr)]
end

local function capitalize_first(s)
    return s:sub(1, 1):upper() .. s:sub(2)
end

local function jargon()
    local choice = math.random()
    local thing
    if choice > 0.5 then
        thing = choose(jargonWords.adjectives) .. " " .. choose(jargonWords.acronyms)
    elseif choice > 0.1 then
        thing = choose(jargonWords.acronyms) .. " " .. choose(jargonWords.adjectives)
    else
        thing = choose(jargonWords.adjectives) .. " " .. choose(jargonWords.acronyms) .. " " .. choose(jargonWords.nouns)
    end
    thing = thing .. " " .. choose(jargonWords.nouns)
    local out
    if math.random() > 0.3 then
        out = choose(jargonWords.participles) .. " " .. thing
    else
        out = thing .. " " .. choose(jargonWords.participles)
            :gsub("writing", "wrote")
            :gsub("breaking", "broken")
            :gsub("overriding", "overriden")
            :gsub("shutting", "shut")
            :gsub("ying", "ied")
            :gsub("ing", "ed")
    end
    return capitalize_first(out)
end

local function lgen(cs, n)
    local out = {}
    for i = 1, n do
        local r = math.random(1, #cs)
        table.insert(out, cs:sub(r, r))
    end
    return table.concat(out)
end

local function scarynum()
    local r = math.random()
    if r > 0.7 then
        return lgen("0123456789abcdef", 16)
    elseif r > 0.4 then
        return lgen("01", 32)
    else
        return tostring(math.random())
    end
end

while true do
    local r = math.random(1, 3)
    if r == 1 then
        print(jargon())
    elseif r == 2 then
        for i = 1, math.random(1, 3) do write(scarynum() .. " ") end
        print()
    else
        print(choose(hcresponses))
    end
    if math.random() < 0.005 then
        term.setTextColor(colors.red)
        print "Terminated"
        term.setTextColor(colors.green)
    end
    sleep(math.random() * 0.5)
end