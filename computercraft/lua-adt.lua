local function trim(str, chars)
    if chars == nil then
        chars = "%s*"
    end
    return string.match(str, "^"..chars.."(.-)"..chars.."$")
end

local function split(str, delim)
    if delim == nil then
        delim = "\n"
    end
    local t = {}
    for s in string.gmatch(str, "([^"..delim.."]+)") do
        table.insert(t, trim(s))
    end
    return t
end

local function find_multiple(str, patterns, offset)
    local ws = string.len(str)
    local we = we
    local wpattern = nil
    for i, pattern in pairs(patterns) do
        s, e = string.find(str, pattern, offset)
        if s ~= nil then
            if s < ws then
                ws = s
                we = e
                wpattern = pattern
            end
        end
    end
    return ws, we, wpattern
end

local function balanced_end(str, word, offset)
    if offset == nil then
        offset = 1
    end
    local i = offset
    while true do
        local s, e, p
        if word == "then" then
            s, e, p = find_multiple(str, {"%smatch%s", "%sfunction%s", "%sthen%s", "%sdo%s", "%send%s", "%selseif%s"}, i)
        else
            s, e, p = find_multiple(str, {"%smatch%s", "%sfunction%s", "%sthen%s", "%sdo%s", "%send%s"}, i)
        end
        if p == "%send%s" then
            return e
        elseif p == "%selseif%s" then
            return e
        elseif p == nil then
            return "UNBAL"
        end
        i = balanced_end(str, string.sub(p, 3, -3), e)
        if i == "UNBAL" then
            return i
        end
    end
end

local function get_decls(str)
    -- gather data declarations from source & remove
    local datas = {}
    local i = 0
    local strout = ""
    while true do
        local n, a = string.find(str, "%sdata [%w]+", i+1)
        if n == nil then
            strout = strout .. string.sub(str, i+1)
            break
        end
        strout = strout .. string.sub(str, i+1, n)
        local e, d = string.find(str, "end", i+1)
        local cont = string.sub(str, a+1, e-1)
        local data = {}
        for i, case in ipairs(split(cont)) do
            local c = {}
            local b, p = string.find(case, "%(")
            if b == nil then
                c.name = case
                c.args = 0   
            else
                c.name = string.sub(case, 1, p-1)
                c.args = #split(case, ",")
            end
            table.insert(data, c)
        end
        i = d
        table.insert(datas, data)
    end
    return datas, strout
end

local parseexprs, replace_case, replace_match
local function parseexpr(str)
    local n, o, name, body = string.find(str, "(%w+)(%b())")
    if n == nil then
        local b = string.find(str, ",")
        if b == nil then
            return {type="var",name=str}, ""
        else
            return {type="var", name=string.sub(str, 0, b-1)}, string.sub(str,b+1)
        end
    end
    body = string.sub(body, 2, -2)
    local obj = {type="data", name=name, body=parseexprs(body)}
    local rem = string.sub(str, o+1)
    local b = string.find(rem, ",")
    if b == nil then
        return obj, ""
    else
        return obj, string.sub(rem,b+1)
    end
end

parseexprs = function(str)
    local t = {}
    while str ~= "" do
        local obj
        obj, str = parseexpr(str)
        table.insert(t, obj)
    end
    return t
end

local function getCase(datas, data)
    for i, x in ipairs(datas) do
        for i, case in ipairs(x) do
            if case.name == data then
                return i
            end
        end
    end
end

local function comparison(datas, var, pattern)
    if pattern.type == "data" then
        local out = var .. ".case == " .. getCase(datas, pattern.name)
        for i, x in ipairs(pattern.body) do
            if x.type == "data" then
                out = out .. " and " .. comparison(datas, var .. "[" .. i .. "]", x)
            end
        end
        return out
    else
        return "true"
    end
end

local function destructure(datas, var, pattern)
    if pattern.type == "var" then
        return "local " .. pattern.name .. " = " .. var
    else
        local out = ""
        for i, x in ipairs(pattern.body) do
            out = out .. "\n" .. destructure(datas, var .. "[" .. i .. "]", x)
        end
        return out
    end
end

replace_match = function(datas, str)
    while true do
        local m, b, var = string.find(str, "%smatch (%w+)%s")
        if m == nil then
            return str
        end
        local e = balanced_end(str, "match", b)
        local cont = string.sub(str, b, e-4)
        str = string.sub(str, 1, m) .. replace_case(datas, cont, var) .. string.sub(str, e, -1)
    end
end

replace_case = function(datas, out, var)
    local str = out
    local count = 0
    while true do
        local m
        local b
        local p
        m, b, p = string.find(str, "%scase ([^%s]+) do%s")
        if m == nil then
            for i=1,count do
                str = str .. "\nend"
            end
            return str
        end
        count = count + 1
        local e = balanced_end(str, "do", b)
        local cont = string.sub(str, b, e-5)
        local pattern = parseexpr(p)
        local bool = comparison(datas, var, pattern)
        local body = destructure(datas, var, pattern)
        str = string.sub(str, 1, m) .. "\nif " .. bool .. " then\n" .. body .. cont .. "\nelse\n" .. string.sub(str, e, -1)
    end
end

local function printpattern(pattern)
    if pattern.type == "data" then
        io.write(pattern.name)
        io.write("(")
        for i, v in ipairs(pattern.body) do
            printpattern(v)
            io.write(",")
        end
        io.write(")")
    else
        io.write(pattern.name)
    end
end

local function writeheaders(datas)
    local out = ""
    for i, x in ipairs(datas) do
        for i, case in ipairs(x) do
            out = out .. "\nlocal function " .. case.name .. "(...) return {case=" .. i .. ",...} end"
        end
    end
    return out
end

function preprocess(str)
    local decls, str0 = get_decls(str)
    local b = replace_match(decls, str0)
    local h = writeheaders(decls)
    return h .. b
end