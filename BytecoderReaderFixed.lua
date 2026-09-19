local BytecodeReader = { VERSION = "1.5" }

local RS = "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/refs/heads/main"

local function fetchMapping()
    local ok, raw = pcall(game.HttpGet, game, RS .. "/BytecodeMapping.json")
    if not ok then return nil end
    local HS = game:GetService("HttpService")
    local ok2, decoded = pcall(function() return HS:JSONDecode(raw) end)
    if not ok2 then return nil end
    local t = {}
    for k, v in pairs(decoded) do t[tonumber(k)] = v end
    return t
end

local OPCODES = fetchMapping()
if not OPCODES then return nil end

local function readLEB128(bc, p)
    local r, sh = 0, 0
    while true do
        local b = bc:byte(p)
        if not b then return nil, p end
        p = p + 1
        r = r + (b % 128) * (2 ^ sh)
        if b < 128 then break end
        sh = sh + 7
    end
    return r, p
end

local function readU32(bc, p)
    local b1, b2, b3, b4 = bc:byte(p), bc:byte(p+1), bc:byte(p+2), bc:byte(p+3)
    if not b4 then return nil end
    return b1 + b2*256 + b3*65536 + b4*16777216
end

local function signExtend16(v)
    if v >= 32768 then return v - 65536 end
    return v
end

local function signExtend24(v)
    if v >= 8388608 then return v - 16777216 end
    return v
end

local function decodeWord(w)
    return {
        op = w % 256,
        A  = math.floor(w / 256) % 256,
        B  = math.floor(w / 65536) % 256,
        C  = math.floor(w / 16777216) % 256,
        D  = signExtend16(math.floor(w / 65536) % 65536),
        E  = signExtend24(math.floor(w / 256) % 16777216),
    }
end

local function readConstant(bc, p, strings)
    local t = bc:byte(p); p = p + 1
    if t == 0 then
        return { type = "nil" }, p
    elseif t == 1 then
        local v = bc:byte(p); p = p + 1
        return { type = "bool", value = v ~= 0 }, p
    elseif t == 2 then
        local s = bc:sub(p, p + 7)
        local num
        if string.unpack then
            local ok, v = pcall(string.unpack, "<d", s)
            if ok then num = v end
        end
        p = p + 8
        return { type = "number", value = num }, p
    elseif t == 3 then
        local lo, hi = readU32(bc, p), readU32(bc, p + 4)
        p = p + 8
        return { type = "integer", lo = lo, hi = hi }, p
    elseif t == 4 then
        p = p + 16
        return { type = "vectorf" }, p
    elseif t == 5 then
        p = p + 32
        return { type = "vectord" }, p
    elseif t == 6 then
        local idx; idx, p = readLEB128(bc, p)
        return { type = "string", value = strings[idx + 1], idx = idx }, p
    elseif t == 7 then
        local raw = readU32(bc, p); p = p + 4
        return { type = "import", raw = raw }, p
    elseif t == 8 then
        local n; n, p = readLEB128(bc, p)
        local keys = {}
        for i = 1, n do
            local k; k, p = readLEB128(bc, p)
            keys[i] = k
        end
        return { type = "table", keys = keys }, p
    elseif t == 9 then
        local idx; idx, p = readLEB128(bc, p)
        return { type = "closure", idx = idx }, p
    elseif t == 10 then
        local idx; idx, p = readLEB128(bc, p)
        return { type = "classshape", idx = idx }, p
    else
        return { type = "unknown", tag = t }, p
    end
end

local function looksLikeProtoStart(bc, q)
    if q > #bc then return false end
    if q == #bc + 1 then return true end
    if q + 5 > #bc then return false end
    local ms = bc:byte(q)
    local np = bc:byte(q + 1)
    local nu = bc:byte(q + 2)
    local va = bc:byte(q + 3)
    local fl = bc:byte(q + 4)
    if not ms or not np or not nu or not va or not fl then return false end
    if ms > 200 then return false end
    if np > 50 then return false end
    if nu > 200 then return false end
    if va ~= 0 and va ~= 1 then return false end
    if fl > 4 then return false end
    return true
end

local function readProto(bc, p, version, typesVersion, strings)
    local maxstack  = bc:byte(p); p = p + 1
    local numparams = bc:byte(p); p = p + 1
    local nups      = bc:byte(p); p = p + 1
    local isvararg  = bc:byte(p); p = p + 1
    if version >= 4 then p = p + 1 end

    if typesVersion and typesVersion >= 2 then
        local ts; ts, p = readLEB128(bc, p)
        p = p + ts
    end

    local sizecode; sizecode, p = readLEB128(bc, p)
    if not sizecode then return nil, p end
    local code = bc:sub(p, p + sizecode * 4 - 1)
    p = p + sizecode * 4

    local sizek; sizek, p = readLEB128(bc, p)
    local constants = {}
    for i = 1, sizek do
        constants[i], p = readConstant(bc, p, strings)
    end

    local sizep; sizep, p = readLEB128(bc, p)
    local subprotos = {}
    for i = 1, sizep do
        subprotos[i], p = readLEB128(bc, p)
    end

    local linedefined; linedefined, p = readLEB128(bc, p)

    local namelen; namelen, p = readLEB128(bc, p)
    local name = bc:sub(p, p + namelen - 1)
    p = p + namelen

    local debugStart = p
    local bestP = nil

    for tryOff = 3, math.min(80, #bc - debugStart + 2) do
        local tryP = debugStart + tryOff
        if looksLikeProtoStart(bc, tryP) then
            if tryP == #bc + 1 then
                bestP = tryP
                break
            end
            local saveP = tryP
            local probeOk = true
            if saveP + 5 <= #bc then
                bestP = tryP
                break
            end
        end
    end

    p = bestP or (#bc + 1)

    return {
        maxstack    = maxstack,
        numparams   = numparams,
        nups        = nups,
        isvararg    = isvararg,
        sizecode    = sizecode,
        code        = code,
        constants   = constants,
        subprotos   = subprotos,
        linedefined = linedefined,
        name        = name,
    }, p
end

function BytecodeReader.parseChunk(bc)
    if type(bc) ~= "string" or #bc < 4 then
        return nil, "invalid bytecode"
    end

    local p = 1
    local version = bc:byte(p); p = p + 1
    local typesVersion = nil
    if version >= 4 then
        typesVersion = bc:byte(p); p = p + 1
    end

    local strCount; strCount, p = readLEB128(bc, p)
    local strings = {}
    for i = 1, strCount do
        local len; len, p = readLEB128(bc, p)
        strings[i] = bc:sub(p, p + len - 1)
        p = p + len
    end

    if version >= 3 then
        local udCount; udCount, p = readLEB128(bc, p)
        for i = 1, udCount do
            local len; len, p = readLEB128(bc, p)
            p = p + len
        end
    end

    local protoCount; protoCount, p = readLEB128(bc, p)
    if not protoCount then return nil, "invalid protoCount" end

    local protos = {}
    for i = 1, protoCount do
        local proto, newp = readProto(bc, p, version, typesVersion, strings)
        if not proto then break end
        if not newp or newp <= p or newp > #bc + 1 then break end
        protos[i] = proto
        p = newp
    end

    return {
        version      = version,
        typesVersion = typesVersion,
        strings      = strings,
        protos       = protos,
    }
end

local function formatOperand(inst, info)
    if info.enc == "ABC" then
        return string.format("%d %d %d", inst.A, inst.B, inst.C)
    elseif info.enc == "AD" then
        return string.format("%d %d", inst.A, inst.D)
    elseif info.enc == "E" then
        return tostring(inst.E)
    end
    return ""
end

function BytecodeReader.disassemble(proto)
    local code = proto.code
    local out = {}
    local idx = 0
    local p = 1

    while p + 3 <= #code do
        local w = readU32(code, p)
        if not w then break end
        local inst = decodeWord(w)
        local info = OPCODES[inst.op]

        local line
        if not info then
            line = string.format("%04d  UNKNOWN_0x%02X  raw=0x%08X", idx, inst.op, w)
        else
            local args = formatOperand(inst, info)
            line = string.format("%04d  %-14s %s", idx, info.name, args)
        end

        p = p + 4
        if info and info.aux and p + 3 <= #code then
            local aux = readU32(code, p)
            line = line .. string.format("  AUX=0x%08X", aux)
            p = p + 4
        end

        idx = idx + 1
        out[#out + 1] = line
    end

    return table.concat(out, "\n")
end

local function protoHeader(idx, proto)
    return string.format("─── Proto %d [%s] stack=%d params=%d ups=%d vararg=%d code=%d ───",
        idx, proto.name ~= "" and proto.name or "?",
        proto.maxstack, proto.numparams, proto.nups, proto.isvararg, proto.sizecode)
end

function BytecodeReader.dump(bc)
    local chunk, err = BytecodeReader.parseChunk(bc)
    if not chunk then return "-- parse error: " .. tostring(err) end

    local out = {}
    out[#out + 1] = string.format("v%d types v%s | %d strings | %d protos",
        chunk.version, tostring(chunk.typesVersion),
        #chunk.strings, #chunk.protos)
    out[#out + 1] = ""

    for i, proto in ipairs(chunk.protos) do
        out[#out + 1] = protoHeader(i, proto)
        out[#out + 1] = BytecodeReader.disassemble(proto)
        out[#out + 1] = ""
    end

    return table.concat(out, "\n")
end

function BytecodeReader.dumpScript(script)
    local ok, bc = pcall(getscriptbytecode, script)
    if not ok or type(bc) ~= "string" then
        return "-- getscriptbytecode failed: " .. tostring(bc)
    end
    return BytecodeReader.dump(bc)
end

function BytecodeReader.dumpSource(src)
    local fn = loadstring(src)
    if not fn then return "-- compile failed" end
    local ok, bc = pcall(getfunctionbytecode, fn)
    if not ok or type(bc) ~= "string" then return "-- bytecode failed" end
    return BytecodeReader.dump(bc)
end

function BytecodeReader.getOpcodeTable()
    return OPCODES
end

local _genv = (type(getgenv) == "function" and getgenv()) or _G
_genv.BytecodeReader = BytecodeReader

return BytecodeReader
