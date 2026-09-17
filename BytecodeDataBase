local M = {}

M.utils = {
    opLength2 = {
        ["LOP_CALLFB"] = true,
        ["LOP_CMPPROTO"] = true,
        ["LOP_FASTCALL2"] = true,
        ["LOP_FASTCALL2K"] = true,
        ["LOP_FASTCALL3"] = true,
        ["LOP_FORGLOOP"] = true,
        ["LOP_GETGLOBAL"] = true,
        ["LOP_GETIMPORT"] = true,
        ["LOP_GETTABLEKS"] = true,
        ["LOP_GETUDATAKS"] = true,
        ["LOP_JUMPIFEQ"] = true,
        ["LOP_JUMPIFLE"] = true,
        ["LOP_JUMPIFLT"] = true,
        ["LOP_JUMPIFNOTEQ"] = true,
        ["LOP_JUMPIFNOTLE"] = true,
        ["LOP_JUMPIFNOTLT"] = true,
        ["LOP_JUMPXEQKB"] = true,
        ["LOP_JUMPXEQKN"] = true,
        ["LOP_JUMPXEQKNIL"] = true,
        ["LOP_JUMPXEQKS"] = true,
        ["LOP_LOADKX"] = true,
        ["LOP_NAMECALL"] = true,
        ["LOP_NAMECALLUDATA"] = true,
        ["LOP_NEWCLASS"] = true,
        ["LOP_NEWCLASSMEMBER"] = true,
        ["LOP_NEWTABLE"] = true,
        ["LOP_SETGLOBAL"] = true,
        ["LOP_SETLIST"] = true,
        ["LOP_SETTABLEKS"] = true,
        ["LOP_SETUDATAKS"] = true,
    },
    fastcall = {
        ["LOP_FASTCALL"] = true,
        ["LOP_FASTCALL1"] = true,
        ["LOP_FASTCALL2"] = true,
        ["LOP_FASTCALL2K"] = true,
        ["LOP_FASTCALL3"] = true,
        ["LOP_FASTPCALL"] = true,
    },
    jumpD = {
        ["LOP_CMPPROTO"] = true,
        ["LOP_FORGLOOP"] = true,
        ["LOP_FORGPREP"] = true,
        ["LOP_FORNLOOP"] = true,
        ["LOP_FORNPREP"] = true,
        ["LOP_JUMP"] = true,
        ["LOP_JUMPBACK"] = true,
        ["LOP_JUMPIF"] = true,
        ["LOP_JUMPIFEQ"] = true,
        ["LOP_JUMPIFLE"] = true,
        ["LOP_JUMPIFLT"] = true,
        ["LOP_JUMPIFNOT"] = true,
        ["LOP_JUMPIFNOTEQ"] = true,
        ["LOP_JUMPIFNOTLE"] = true,
        ["LOP_JUMPIFNOTLT"] = true,
        ["LOP_JUMPXEQKB"] = true,
        ["LOP_JUMPXEQKN"] = true,
        ["LOP_JUMPXEQKNIL"] = true,
        ["LOP_JUMPXEQKS"] = true,
    },
    skipC = {
        ["LOP_LOADB"] = true,
    },
    noFallthrough = {
        ["LOP_JUMP"] = true,
        ["LOP_JUMPBACK"] = true,
        ["LOP_JUMPX"] = true,
        ["LOP_RETURN"] = true,
    },
    loopJump = {
        ["LOP_FORGLOOP"] = true,
        ["LOP_FORNLOOP"] = true,
        ["LOP_JUMPBACK"] = true,
    },
}

M.builder = {
    constants = {
        kMaxJumpDistance = 8388608,
    },
    constantType = {
        Type_Boolean = 1,
        Type_ClassShape = 10,
        Type_Closure = 9,
        Type_Import = 7,
        Type_Integer = 3,
        Type_Nil = 0,
        Type_Number = 2,
        Type_String = 6,
        Type_Table = 8,
        Type_Vectord = 5,
        Type_Vectorf = 4,
    },
    dumpFlags = {
        Dump_Code = 1,
        Dump_Constants = 64,
        Dump_Lines = 2,
        Dump_Locals = 8,
        Dump_Remarks = 16,
        Dump_Source = 4,
        Dump_Types = 32,
    },
}

M.graph = {
    opKind = {
        Block = 3,
        Imm = 1,
        Inst = 2,
        None = 0,
        Phi = 4,
        Proj = 5,
        VmConst = 7,
        VmProto = 9,
        VmReg = 6,
        VmUpvalue = 8,
    },
    immKind = {
        Boolean = 0,
        Import = 2,
        Int = 1,
    },
    vmConstKind = {
        Boolean = 1,
        ClassShape = 10,
        Closure = 8,
        Import = 6,
        Integer = 9,
        Nil = 0,
        Number = 2,
        String = 5,
        Table = 7,
        Vectord = 4,
        Vectorf = 3,
    },
    blockEdgeKind = {
        Branch = 0,
        Fallthrough = 1,
        Loop = 2,
    },
    blockFlag = {
        Dead = 1,
    },
}

M.ops = {
    BcCall = {
        opcode = "LOP_CALL",
        operands = {
            ParamCount = 0,
            ParamStart = 3,
            ReturnCount = 1,
            Target = 2,
        },
    },
    BcCallFB = {
        opcode = "LOP_CALLFB",
        operands = {
            FbSlot = 2,
            ParamCount = 0,
            ParamStart = 4,
            ReturnCount = 1,
            Target = 3,
        },
    },
    BcCmpProto = {
        opcode = "LOP_CMPPROTO",
        operands = {
            Closure = 0,
            Fallback = 2,
            ProtoId = 1,
        },
    },
    BcGetImport = {
        opcode = "LOP_GETIMPORT",
        operands = {
            Import = 0,
            PathLength = 1,
            PathStart = 2,
        },
    },
    BcGetTableKS = {
        opcode = "LOP_GETTABLEKS",
        operands = {
            Hint = 1,
            Key = 2,
            Source = 0,
        },
    },
    BcGetVarArgs = {
        opcode = "LOP_GETVARARGS",
        operands = {
            StartReg = 0,
            ValuesCount = 1,
        },
    },
    BcJump = {
        opcode = "LOP_JUMP",
        operands = {
            Target = 0,
        },
    },
    BcLoadNil = {
        opcode = "LOP_LOADNIL",
        operands = {},
    },
    BcMove = {
        opcode = "LOP_MOVE",
        operands = {
            Src = 0,
        },
    },
    BcNamecall = {
        opcode = "LOP_NAMECALL",
        operands = {
            Hint = 1,
            Key = 2,
            Table = 0,
        },
    },
    BcReturn = {
        opcode = "LOP_RETURN",
        operands = {
            ReturnCount = 0,
            ValuesStart = 1,
        },
    },
    BcSetList = {
        opcode = "LOP_SETLIST",
        operands = {
            Count = 1,
            ParamStart = 3,
            StartIndex = 0,
            Target = 2,
        },
    },
}

M.inlinerConst = {
    kMaxInlinerCombinedStackSize = 250,
    ksSizeBeforeInline = 0,
}

function M.isOpLength2(op)     return M.utils.opLength2[op] == true end
function M.isFastcall(op)      return M.utils.fastcall[op] == true end
function M.isJumpD(op)         return M.utils.jumpD[op] == true end
function M.isSkipC(op)         return M.utils.skipC[op] == true end
function M.isFallthrough(op)   return M.utils.noFallthrough[op] ~= true end
function M.isLoopJump(op)      return M.utils.loopJump[op] == true end
function M.getOperand(opClass, name) return M.ops[opClass] and M.ops[opClass].operands[name] end
function M.getOpcode(opClass)  return M.ops[opClass] and M.ops[opClass].opcode end

return M
