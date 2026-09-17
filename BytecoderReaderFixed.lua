local bit32 = bit32
local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

local Meta = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/BytecodeDataBase.lua"
))()

local Reader = { VERSION = "1.1" }

local function u8(d, p)
    local v = string.byte(d, p)
    if not v then error("eof@"..p) end
    return v, p + 1
end

local function u32(d, p)
    local a, b, c, e = string.byte(d, p, p + 3)
    if not a then error("eof@"..p) end
    return bor(a, lshift(b, 8), lshift(c, 16), lshift(e, 24)), p + 4
end

local function f32(d, p)
    local ok, v = pcall(string.unpack, "<f", d:sub(p, p + 3))
    if not ok then error("eof@"..p) end
    return v, p + 4
end

local function f64(d, p)
    local ok, v = pcall(string.unpack, "<d", d:sub(p, p + 7))
    if not ok then error("eof@"..p) end
    return v, p + 8
end

local function leb(d, p)
    local r, sh = 0, 0
    while true do
        local b = string.byte(d, p)
        if not b then error("leb eof@"..p) end
        p = p + 1
        r = bor(r, lshift(band(b, 0x7F), sh))
        if band(b, 0x80) == 0 then break end
        sh = sh + 7
        if sh > 63 then error("leb overflow") end
    end
    return r, p
end

local function zigzag(u)
    local neg = band(u, 1) == 1
    local v = rshift(u, 1)
    if neg then v = -v - 1 end
    return v
end

local function str(d, p)
    local n
    n, p = leb(d, p)
    local s = d:sub(p, p + n - 1)
    return s, p + n
end

local function list(d, p, fn)
    local n
    n, p = leb(d, p)
    local t = table.create(n)
    for i = 1, n do
        t[i], p = fn(d, p)
    end
    return t, p
end

local CT = Meta.builder.constantType

local function readConst(d, p)
    local tag
    tag, p = u8(d, p)
    local c = { tag = tag }
    if tag == CT.Type_Nil then
        c.kind = "nil"
    elseif tag == CT.Type_Boolean then
        local v
        v, p = u8(d, p)
        c.kind, c.val = "boolean", v ~= 0
    elseif tag == CT.Type_Number then
        c.kind = "number"
        c.val, p = f64(d, p)
    elseif tag == CT.Type_String then
        c.kind = "string"
        c.idx, p = leb(d, p)
    elseif tag == CT.Type_Import then
        c.kind = "import"
        local w
        w, p = u32(d, p)
        c.id1 = band(w, 0xFFFF)
        c.id2 = band(rshift(w, 16), 0xFFFF)
    elseif tag == CT.Type_Table then
        c.kind = "table"
        c.keys, p = list(d, p, leb)
    elseif tag == CT.Type_Closure then
        c.kind = "closure"
        c.fid, p = leb(d, p)
    elseif tag == CT.Type_Vectorf then
        c.kind = "vectorf"
        c.x, p = f32(d, p)
        c.y, p = f32(d, p)
        c.z, p = f32(d, p)
        c.w, p = f32(d, p)
    elseif tag == CT.Type_Vectord then
        c.kind = "vectord"
        c.x, p = f64(d, p)
        c.y, p = f64(d, p)
        c.z, p = f64(d, p)
        c.w, p = f64(d, p)
    elseif tag == CT.Type_Integer then
        c.kind = "integer"
        local v
        v, p = leb(d, p)
        c.val = zigzag(v)
    elseif tag == CT.Type_ClassShape then
        c.kind = "classshape"
        c.data, p = str(d, p)
    else
        c.kind = "unknown"
    end
    return c, p
end

local function s16(v) if v >= 32768 then return v - 65536 end return v end
local function s24(v) if v >= 0x800000 then return v - 0x1000000 end return v end

local function decode(word, opNames)
    local op = band(word, 0xFF)
    local a  = band(rshift(word, 8), 0xFF)
    local b  = band(rshift(word, 16), 0xFF)
    local c  = band(rshift(word, 24), 0xFF)
    return {
        op   = op,
        name = opNames[op] or ("OP_"..op),
        a = a, b = b, c = c,
        d = s16(band(rshift(word, 16), 0xFFFF)),
        e = s24(band(rshift(word, 8), 0xFFFFFF)),
        word = word,
    }
end

local function readInsns(d, p, count, opNames)
    local words = table.create(count)
    for i = 1, count do
        words[i], p = u32(d, p)
    end
    local out = {}
    local i = 1
    while i <= count do
        local ins = decode(words[i], opNames)
        if Meta.isOpLength2(ins.name) and i < count then
            ins.aux = words[i + 1]
            out[#out + 1] = ins
            out[#out + 1] = decode(0, opNames)
            i = i + 2
        else
            out[#out + 1] = ins
            i = i + 1
        end
    end
    return out, p
end

local function readFunction(d, p, typesVer, opNames)
    local f = {}
    f.maxstack,  p = u8(d, p)
    f.numparams, p = u8(d, p)
    f.nups,      p = u8(d, p)
    local va
    va, p = u8(d, p)
    f.isVararg = va ~= 0
    f.flags, p = u8(d, p)

    if typesVer >= 1 then
        local sz
        sz, p = leb(d, p)
        f.typeinfo = sz > 0 and d:sub(p, p + sz - 1) or nil
        p = p + sz
    end

    local codeN
    codeN, p = leb(d, p)
    f.code, p = readInsns(d, p, codeN, opNames)

    f.constants, p = list(d, p, readConst)
    f.protos,    p = list(d, p, leb)

    f.line, p = leb(d, p)
    f.nameIdx, p = leb(d, p)

    local hasDbg
    hasDbg, p = u8(d, p)
    if hasDbg ~= 0 then
        f.linegap, p = u8(d, p)
        f.lineinfo, p = list(d, p, u8)
        local m
        m, p = leb(d, p)
        f.abslineinfo = table.create(m)
        for i = 1, m do
            local pc, ln
            pc, p = leb(d, p)
            ln, p = leb(d, p)
            f.abslineinfo[i] = { pc = pc, line = ln }
        end
    end

    local hasLoc
    hasLoc, p = u8(d, p)
    if hasLoc ~= 0 then
        local n
        n, p = leb(d, p)
        f.locvars = table.create(n)
        for i = 1, n do
            local ni, sp, ep, rg
            ni, p = leb(d, p)
            sp, p = leb(d, p)
            ep, p = leb(d, p)
            rg, p = u8(d, p)
            f.locvars[i] = { nameIdx = ni, start = sp, stop = ep, reg = rg }
        end
        f.upvalues, p = list(d, p, leb)
    end

    return f, p
end

local function readChunk(d, p, version, opNames)
    local typesVer = 0
    if version >= 4 then
        typesVer, p = u8(d, p)
        if typesVer > 3 then error("types version "..typesVer) end
    end

    local strings
    strings, p = list(d, p, str)

    if typesVer == 3 then
        local n
        n, p = leb(d, p)
        for i = 1, n do
            local _, np = str(d, p)
            p = np
        end
    end

    local protos
    protos, p = list(d, p, function(dd, pp)
        return readFunction(dd, pp, typesVer, opNames)
    end)

    local main
    main, p = leb(d, p)

    return {
        version = version,
        typesVersion = typesVer,
        strings = strings,
        protos = protos,
        main = main,
    }, p
end

function Reader.deserialize(bc, opNames)
    if type(bc) ~= "string" or #bc == 0 then
        error("empty bytecode")
    end
    opNames = opNames or {}
    local p = 1
    local version
    version, p = u8(bc, p)
    if version == 0 then error("bytecode error marker") end
    if version < 3 or version > 14 then
        error("unsupported bytecode version "..version)
    end
    local chunk, _ = readChunk(bc, p, version, opNames)
    return chunk
end

function Reader.dump(bc, opcodeMap)
    local names = {}
    for name, num in pairs(opcodeMap or {}) do
        names[num] = name
    end
    local data = Reader.deserialize(bc, names)
    local out = {}
    out[#out + 1] = "version: " .. data.version
    out[#out + 1] = "typesVersion: " .. data.typesVersion
    out[#out + 1] = "strings: " .. #data.strings
    out[#out + 1] = "protos: " .. #data.protos
    out[#out + 1] = "main: " .. data.main
    for i, pr in ipairs(data.protos) do
        out[#out + 1] = ""
        out[#out + 1] = ("proto[%d] name=%s params=%d stack=%d nups=%d vararg=%s"):format(
            i, data.strings[pr.nameIdx + 1] or "?",
            pr.numparams, pr.maxstack, pr.nups, tostring(pr.isVararg))
        for j, ins in ipairs(pr.code) do
            local aux = ins.aux and (" aux="..ins.aux) or ""
            out[#out + 1] = ("  [%d] %s a=%d b=%d c=%d d=%d%s"):format(
                j, ins.name, ins.a, ins.b, ins.c, ins.d, aux)
        end
    end
    return table.concat(out, "\n")
end

return Reader
