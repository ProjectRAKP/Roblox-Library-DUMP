local Reader = {}
local U8, U16, U32, F32, F64 = string.byte, nil, nil, nil, nil
local function u8(bc, p)
    return string.byte(bc, p), p + 1
end
local function u32(bc, p)
    local a, b, c, d = string.byte(bc, p, p + 3)
    if not a then error("eof") end
    return (a | (b << 8) | (c << 16) | (d << 24)) & 0xFFFFFFFF, p + 4
end
local function f32(bc, p)
    local ok, v = pcall(string.unpack, "<f", bc:sub(p, p + 3))
    if not ok then error("eof") end
    return v, p + 4
end
local function f64(bc, p)
    local ok, v = pcall(string.unpack, "<d", bc:sub(p, p + 7))
    if not ok then error("eof") end
    return v, p + 8
end
local function leb(bc, p)
    local r, sh = 0, 0
    while true do
        local b = string.byte(bc, p)
        p = p + 1
        if not b then error("leb eof") end
        r = r | ((b & 0x7F) << sh)
        if (b & 0x80) == 0 then break end
        sh = sh + 7
    end
    return r, p
end
local function readStr(bc, p)
    local n
    n, p = leb(bc, p)
    local s = bc:sub(p, p + n - 1)
    return s, p + n
end
local function readList(bc, p, itemFn)
    local n
    n, p = leb(bc, p)
    local list = table.create(n)
    for i = 1, n do
        list[i], p = itemFn(bc, p)
    end
    return list, p
end
local TAG = {
    [0] = "Nil", [1] = "Boolean", [2] = "Number", [3] = "String",
    [4] = "Import", [5] = "Table", [6] = "Closure", [7] = "Vector",
    [8] = "TableC", [9] = "Integer", [10] = "ClassShape", [11] = "VectorD",
}
local function readConst(bc, p)
    local tag
    tag, p = u8(bc, p)
    local c = { tag = tag, kind = TAG[tag] or "Unknown" }
    if tag == 0 then
    elseif tag == 1 then
        local v
        v, p = u8(bc, p)
        c.v = v ~= 0
    elseif tag == 2 then
        c.v, p = f64(bc, p)
    elseif tag == 3 then
        c.idx, p = leb(bc, p)
    elseif tag == 4 then
        local w
        w, p = u32(bc, p)
        c.id1 = w & 0xFFFF
        c.id2 = (w >> 16) & 0xFFFF
    elseif tag == 5 or tag == 8 then
        c.keys, p = readList(bc, p, leb)
    elseif tag == 6 then
        c.fid, p = leb(bc, p)
    elseif tag == 7 or tag == 11 then
        c.x, p = f32(bc, p)
        c.y, p = f32(bc, p)
        c.z, p = f32(bc, p)
        if tag == 11 then c.w, p = f32(bc, p) end
    elseif tag == 9 then
        local v
        v, p = leb(bc, p)
        c.v = (v >> 1) ~ (-(v & 1))
    end
    return c, p
end
local function s16(v) if v >= 32768 then return v - 65536 end return v end
local function s24(v) if v >= 0x800000 then return v - 0x1000000 end return v end
local AUX_OPS = {
    LOP_GETGLOBAL = true, LOP_SETGLOBAL = true, LOP_GETIMPORT = true,
    LOP_GETTABLEKS = true, LOP_SETTABLEKS = true, LOP_NAMECALL = true,
    LOP_JUMPIFEQ = true, LOP_JUMPIFLE = true, LOP_JUMPIFLT = true,
    LOP_JUMPIFNOTEQ = true, LOP_JUMPIFNOTLE = true, LOP_JUMPIFNOTLT = true,
    LOP_NEWTABLE = true, LOP_SETLIST = true, LOP_FORGLOOP = true,
    LOP_LOADKX = true, LOP_FASTCALL2 = true, LOP_FASTCALL2K = true,
    LOP_FASTCALL3 = true, LOP_JUMPXEQKNIL = true, LOP_JUMPXEQKB = true,
    LOP_JUMPXEQKN = true, LOP_JUMPXEQKS = true,
}
local function decodeInsn(word, opNames)
    local op = word & 0xFF
    local a  = (word >> 8)  & 0xFF
    local b  = (word >> 16) & 0xFF
    local c  = (word >> 24) & 0xFF
    local d  = s16((word >> 16) & 0xFFFF)
    local e  = s24((word >> 8)  & 0xFFFFFF)
    return {
        op = op,
        name = opNames[op] or ("OP_" .. op),
        a = a, b = b, c = c, d = d, e = e,
        word = word,
    }
end
local function readInsns(bc, p, count, opNames)
    local words = table.create(count)
    for i = 1, count do
        words[i], p = u32(bc, p)
    end
    local insns = table.create(count)
    local i = 1
    while i <= count do
        local ins = decodeInsn(words[i], opNames)
        if AUX_OPS[ins.name] and i < count then
            ins.aux = words[i + 1]
            insns[#insns + 1] = ins
            insns[#insns + 1] = decodeInsn(0, opNames)
            i = i + 2
        else
            insns[#insns + 1] = ins
            i = i + 1
        end
    end
    return insns, p
end
local function readFunction(bc, p, typesVer, opNames)
    local f = {}
    f.maxstack, p  = u8(bc, p)
    f.numparams, p = u8(bc, p)
    f.nups, p      = u8(bc, p)
    f.isVararg, p  = u8(bc, p)
    f.flags, p     = u8(bc, p)
    f.isVararg = f.isVararg ~= 0
    if typesVer >= 1 then
        f.typeinfo, p = readList(bc, p, u8)
    end
    local cN
    cN, p = leb(bc, p)
    f.code, p = readInsns(bc, p, cN, opNames)
    f.constants, p = readList(bc, p, readConst)
    f.protos, p = readList(bc, p, leb)
    f.line, p = leb(bc, p)
    f.nameIdx, p = leb(bc, p)
    local hasDebug
    hasDebug, p = u8(bc, p)
    if hasDebug ~= 0 then
        f.linegap, p = u8(bc, p)
        f.lineinfo, p = readList(bc, p, u8)
        local m
        m, p = leb(bc, p)
        f.abslineinfo = table.create(m)
        for i = 1, m do
            f.abslineinfo[i] = {}
            f.abslineinfo[i].pc, p = leb(bc, p)
            f.abslineinfo[i].line, p = leb(bc, p)
        end
    end
    local hasLoc
    hasLoc, p = u8(bc, p)
    if hasLoc ~= 0 then
        local n
        n, p = leb(bc, p)
        f.locvars = table.create(n)
        for i = 1, n do
            local ni
            ni, p = leb(bc, p)
            local start
            start, p = leb(bc, p)
            local stop
            stop, p = leb(bc, p)
            local reg
            reg, p = u8(bc, p)
            f.locvars[i] = { nameIdx = ni, start = start, stop = stop, reg = reg }
        end
        f.upvalues, p = readList(bc, p, leb)
    end
    return f, p
end

local function deserialize(bc, opNames, strings)
    local p = 1
    local out = {}
    out.version, p = u8(bc, p)
    if out.version == 0 then error("bytecode error") end
    if out.version < 3 then error("unsupported version " .. out.version) end
    out.typesVersion, p = u8(bc, p)
    if out.typesVersion > 3 then error("types version " .. out.typesVersion) end
    out.strings, p = readList(bc, p, readStr)
    if out.typesVersion == 3 then
        while true do
            local b = bc:byte(p)
            if b == 0 then p = p + 1 break end
            local _, np = leb(bc, p)
            p = np
        end
    end
    out.protos, p = readList(bc, p, function(bb, pp)
        return readFunction(bb, pp, out.typesVersion, opNames)
    end)
    out.main, p = leb(bc, p)
    return out
end
function Reader.new(opNames)
    return {
        deserialize = function(bc) return deserialize(bc, opNames or {}, {}) end,
    }
end
function Reader.deserialize(bc, opNames)
    return deserialize(bc, opNames or {}, {})
end
return Reader
