# Roblox Library Dump

Complete, online reference database for **Roblox API**, **Luau Core**, and **Luau Bytecode** metadata.

## Files

| File | Type | Description |
|---|---|---|
| `LuaLib-Dump.lua` | Lua | Full Roblox API dump + Luau Core + `Api.*` query functions |
| `BuilderAST.lua` | Lua | AST builder — parse Lua/Luau code into an AST (tree) |
| `BytecodeV11.json` | JSON | Luau opcode, bytecode tag, builtin function, type data (v11) |
| `Bytecoder-Reader-V11.lua` | Lua | Opcode metadata — utils, builder, graph, ops, inliner |
| `LICENSE` | — | MIT License |

## What's Inside

### `LuaLib-Dump.lua`

- **937+ Classes** (Instance, Part, Humanoid, Players, ...)
- **12,000+ Methods** with parameters & return types
- **Thousands of Properties** with types & security levels
- **Hundreds of Events** with parameters
- **All Roblox Enums** with values & reverse lookup
- **All Datatypes** (Vector3, CFrame, Color3, ...)
- **Luau Core** (keywords, globals, metamethods, stdlib)

### `BuilderAST.lua`

- **Lexer** — text → tokens (handles comments, strings, numbers, operators)
- **Parser** — tokens → AST (full precedence, all statements)
- **Walker** — iterate every node in the tree
- **Code Generator** — AST → text (round-trip safe)
- **Keyword source** — loaded from LuaLib via URL

### `BytecodeV11.json`

Parsed from Luau's `Bytecode.h`:

- `LuauOpcode` — all opcodes with values
- `LuauBytecodeTag` — constant type tags
- `LuauBytecodeType` — type info tags
- `LuauBuiltinFunction` — builtin function IDs (~130)
- `LuauCaptureType` — closure capture modes
- `LuauProtoFlag` — proto flags
- `versionHistory` — bytecode version log

### `Bytecoder-Reader-V11.lua`

Parsed from Luau's bytecode headers (`BytecodeUtils.h`, `BytecodeBuilder.h`, `BytecodeGraph.h`, `BytecodeOps.h`, `BytecodeCallInliner.h`):

- `utils` — opcode categories (`opLength2`, `fastcall`, `jumpD`, `skipC`, `noFallthrough`, `loopJump`)
- `builder` — constants, constant type, dump flags
- `graph` — IR op kinds, immediate kinds, VM const kinds, block edges, block flags
- `ops` — operand layout per opcode (`BcCall`, `BcReturn`, `BcGetImport`, ...)
- `inlinerConst` — inliner constants
- Helper functions: `isOpLength2`, `isFastcall`, `isJumpD`, `isSkipC`, `isFallthrough`, `isLoopJump`, `getOperand`, `getOpcode`

## Usage

### LuaLib-Dump.lua — Query Roblox API

```lua
local Lib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/LuaLib-Dump.lua"
))()

-- Get method signature
print(Lib.GetSignature("Destroy", "Instance"))
--> "instance:Destroy()"

-- Full signature (with return type)
print(Lib.GetFullSignature("GetAsync", "HttpService"))
--> "httpservice:GetAsync(url:Variant,nocache:bool,headers:Variant) -> string"

-- Check if method exists
print(Lib.HasMethod("Instance", "Destroy"))
--> true

-- Check if yielding
print(Lib.IsYielding("HttpService", "GetAsync"))
--> true

-- Get property type
print(Lib.GetPropertyType("Part", "Anchored"))
--> "bool"

-- Check event
print(Lib.HasEvent("BasePart", "Touched"))
--> true

-- Inheritance chain
print(Lib.GetClassChain("Part"))
--> {"Part","FormFactorPart","BasePart","PVInstance","Instance","Object"}

-- IsA check
print(Lib.IsA("Part", "BasePart"))
--> true

-- Reverse enum (value → name)
print(Lib.ResolveEnumFull("Material", 256))
--> "Enum.Material.Plastic"

-- Find all enum candidates for a value
print(Lib.FindEnumsByValueFull(256))
--> {"Enum.Material.Plastic", ...}

-- List all methods of a class
for _, m in ipairs(Lib.GetMethods("Humanoid")) do
    print(m)
end

-- Stats
print(Lib.Stats())
--> {classes=937, methods=12847, ...}
```

BuilderAST.lua — Real AST Builder

```lua
local AST = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/BuilderAST.lua"
))()

-- Parse code → AST (tree)
local tree = AST.build([[
    local part = Instance.new("Part")
    part.Material = 256
    if part.Material == 256 then
        print("plastic")
    end
]])

-- Inspect structure
print(tree.type)                    --> "Chunk"
print(#tree.body)                   --> 3
print(tree.body[1].type)            --> "LocalStatement"
print(tree.body[2].type)            --> "AssignmentStatement"
print(tree.body[3].type)            --> "IfStatement"

-- Walk all nodes
AST.walk(tree, function(node)
    if node.type == "NumberLiteral" then
        print("Number:", node.val)
    end
end)
--> Number: 256
--> Number: 256

-- Rewrite AST (enum resolution)
AST.walk(tree, function(node)
    if node.type == "AssignmentStatement"
       and node.targets[1].prop == "Material"
       and node.vals[1].type == "NumberLiteral" then
        node.vals[1] = { type = "Identifier", name = "Enum.Material.Plastic" }
    end
end)

print(AST.rebuild(tree))
--> local part = Instance.new("Part")
--> part.Material = Enum.Material.Plastic
--> if part.Material == Enum.Material.Plastic then
-->     print("plastic")
--> end
```

BytecodeV11.json — Bytecode Metadata

```lua
local data = game:GetService("HttpService"):JSONDecode(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/BytecodeV11.json"
))

-- Opcode lookup
print(data.LuauOpcode["LOP_GETGLOBAL"])    --> 7
print(data.LuauOpcode["LOP_CALL"])         --> 21
print(data.LuauOpcode["LOP_CALLFB"])       --> 87

-- Builtin IDs
print(data.LuauBuiltinFunction["LBF_MATH_FLOOR"])   --> 12
print(data.LuauBuiltinFunction["LBF_ASSERT"])       --> 1

-- Constant tags
print(data.LuauBytecodeTag["LBC_CONSTANT_STRING"])  --> 3
print(data.LuauBytecodeTag["LBC_CONSTANT_NUMBER"])  --> 2

-- Version
print(data.LuauBytecodeTag["LBC_VERSION_MAX"])      --> 14
```

Bytecoder-Reader-V11.lua — Opcode Analysis

```lua
local M = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/Bytecoder-Reader-V11.lua"
))()

-- Opcode categories
print(M.isOpLength2("LOP_GETGLOBAL"))   --> true
print(M.isJumpD("LOP_JUMPIF"))          --> true
print(M.isLoopJump("LOP_JUMPBACK"))     --> true
print(M.isFallthrough("LOP_RETURN"))    --> false

-- Operand layout
print(M.ops.BcCall.opcode)              --> "LOP_CALL"
print(M.ops.BcCall.operands.Target)     --> 2
print(M.ops.BcCall.operands.ParamStart) --> 3

-- Builder constants
print(M.builder.constants.kMaxJumpDistance)  --> 8388608

-- Graph IR kinds
print(M.graph.opKind.Inst)              --> 2
print(M.graph.vmConstKind.Closure)      --> 8
```

 Use Cases

· Auto-complete for Roblox code editors
· Decompiler — bytecode metadata for disassembly
· Deobfuscation — reverse lookup numbers → enums
· Script analysis — audit for dangerous APIs
· AST manipulation — transform / analyze code structure
· AI code generation — ground truth for API

 License
MIT License — see LICENSE file.
Author:ProjectRAKP
