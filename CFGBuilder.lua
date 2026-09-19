local CFGBuilder = { VERSION = "1.1" }

local JUMP_OPS = {
    JUMP=true, JUMPBACK=true, JUMPX=true,
    JUMPIF=true, JUMPIFNOT=true, JUMPIFEQ=true, JUMPIFNOTEQ=true,
    JUMPIFLE=true, JUMPIFLT=true, JUMPIFNOTLE=true, JUMPIFNOTLT=true,
    FORNPREP=true, FORNLOOP=true, FORGLOOP=true,
    FORGPREP=true, FORGPREP_INEXT=true, FORGPREP_NEXT=true,
}

local COND_OPS = {
    JUMPIF=true, JUMPIFNOT=true, JUMPIFEQ=true, JUMPIFNOTEQ=true,
    JUMPIFLE=true, JUMPIFLT=true, JUMPIFNOTLE=true, JUMPIFNOTLT=true,
    FORNPREP=true, FORNLOOP=true, FORGLOOP=true,
}

local UNCOND_OPS = {
    JUMP=true, JUMPBACK=true, JUMPX=true,
}

local END_OPS = {
    RETURN=true, JUMP=true, JUMPBACK=true, JUMPX=true,
}

local function signExtend16(v)
    if v >= 32768 then return v - 65536 end
    return v
end

local function signExtend24(v)
    if v >= 8388608 then return v - 16777216 end
    return v
end

local function readU32(code, p)
    local b1, b2, b3, b4 = code:byte(p), code:byte(p+1), code:byte(p+2), code:byte(p+3)
    if not b4 then return nil end
    return b1 + b2*256 + b3*65536 + b4*16777216
end

local function decodeInstructions(proto, opcodes)
    local code = proto.code
    local insts = {}
    local pc_word = 0
    local byte_p = 1
    while byte_p + 3 <= #code do
        local word = readU32(code, byte_p)
        if not word then break end
        local op = word % 256
        local A = math.floor(word / 256) % 256
        local B = math.floor(word / 65536) % 256
        local C = math.floor(word / 16777216) % 256
        local D = signExtend16(B + C * 256)
        local E = signExtend24(math.floor(word / 256) % 16777216)
        local info = opcodes[op]
        local inst = {
            pc_word = pc_word,
            byte_pc = byte_p - 1,
            op = op, A = A, B = B, C = C, D = D, E = E,
            info = info, aux = nil, has_aux = false, word_size = 1,
        }
        byte_p = byte_p + 4
        if info and info.aux and byte_p + 3 <= #code then
            inst.aux = readU32(code, byte_p)
            inst.has_aux = true
            byte_p = byte_p + 4
            inst.word_size = 2
        end
        insts[#insts + 1] = inst
        pc_word = pc_word + inst.word_size
    end
    return insts
end

local function getJumpTarget(inst)
    if not inst.info then return nil end
    local name = inst.info.name
    if not JUMP_OPS[name] then return nil end
    local offset = (name == "JUMPX") and inst.E or inst.D
    return inst.pc_word + 1 + offset
end

function CFGBuilder.build(proto, opcodes)
    local insts = decodeInstructions(proto, opcodes)
    if #insts == 0 then
        return { blocks = {}, edges = {}, insts = {} }
    end

    local pc_to_idx = {}
    for i, inst in ipairs(insts) do
        pc_to_idx[inst.pc_word] = i
    end

    local max_pc = insts[#insts].pc_word + insts[#insts].word_size

    local is_leader = {}
    is_leader[insts[1].pc_word] = true

    for _, inst in ipairs(insts) do
        if inst.info then
            local name = inst.info.name
            if JUMP_OPS[name] or END_OPS[name] then
                local next_pc = inst.pc_word + inst.word_size
                if next_pc < max_pc then
                    is_leader[next_pc] = true
                end
            end
            if JUMP_OPS[name] then
                local t = getJumpTarget(inst)
                if t and t >= 0 and t < max_pc then
                    is_leader[t] = true
                end
            end
        end
    end

    local leader_list = {}
    for pc in pairs(is_leader) do
        leader_list[#leader_list + 1] = pc
    end
    table.sort(leader_list)

    local blocks = {}
    for i, start_pc in ipairs(leader_list) do
        local end_pc = leader_list[i + 1] or max_pc
        local block = {
            id = i,
            start_pc = start_pc,
            end_pc = end_pc,
            insts = {},
        }
        local j = pc_to_idx[start_pc]
        if j then
            while j <= #insts and insts[j].pc_word < end_pc do
                block.insts[#block.insts + 1] = insts[j]
                j = j + 1
            end
        end
        blocks[i] = block
    end

    local block_by_start = {}
    for _, b in ipairs(blocks) do
        block_by_start[b.start_pc] = b
    end

    local edges = {}

    for _, b in ipairs(blocks) do
        local last = b.insts[#b.insts]
        if last and last.info then
            local name = last.info.name
            local next_pc = last.pc_word + last.word_size

            if name == "RETURN" then
                do end
            elseif UNCOND_OPS[name] then
                local t = getJumpTarget(last)
                local tb = t and block_by_start[t]
                if tb then
                    edges[#edges + 1] = { from = b.id, to = tb.id, kind = "jump" }
                end
            elseif COND_OPS[name] then
                local t = getJumpTarget(last)
                local tb = t and block_by_start[t]
                if tb then
                    edges[#edges + 1] = { from = b.id, to = tb.id, kind = "branch" }
                end
                local fb = block_by_start[next_pc]
                if fb then
                    edges[#edges + 1] = { from = b.id, to = fb.id, kind = "fallthrough" }
                end
            else
                local fb = block_by_start[next_pc]
                if fb then
                    edges[#edges + 1] = { from = b.id, to = fb.id, kind = "fallthrough" }
                end
            end
        end
    end

    return {
        blocks = blocks,
        edges = edges,
        insts = insts,
        block_by_start = block_by_start,
    }
end

function CFGBuilder.format(cfg)
    local out = {}
    out[#out + 1] = ("CFG: %d blocks, %d edges"):format(#cfg.blocks, #cfg.edges)
    out[#out + 1] = ""
    for _, b in ipairs(cfg.blocks) do
        out[#out + 1] = ("Block %d [pc %d-%d] (%d insts)"):format(
            b.id, b.start_pc, b.end_pc - 1, #b.insts)
        for _, inst in ipairs(b.insts) do
            local name = inst.info and inst.info.name or ("UNK_" .. inst.op)
            out[#out + 1] = ("  %4d  %-14s"):format(inst.pc_word, name)
        end
        out[#out + 1] = ""
    end
    out[#out + 1] = "Edges:"
    for _, e in ipairs(cfg.edges) do
        out[#out + 1] = ("  B%d -> B%d  (%s)"):format(e.from, e.to, e.kind)
    end
    return table.concat(out, "\n")
end

local _genv = (type(getgenv) == "function" and getgenv()) or _G
_genv.CFGBuilder = CFGBuilder

return CFGBuilder
