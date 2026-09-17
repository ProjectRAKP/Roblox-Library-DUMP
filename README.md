# Roblox Library Dump

A complete, offline reference database for **Roblox API** and **Luau Core** — 
for auto-complete, script analysis, decompiler enrichment, and more.

## What's Inside

| File | Size | Description |
|---|---|---|
| `LuaLib-Dump.lua` | — | Full Roblox API + Luau Core (flat data + `Api` query functions) |
| `AST-Lib-Dump.lua` | 9.73 MB | Pre-indexed AST version of LuaLib — for fast lookup |

## What It Contains

- **937+ Classes** (Instance, Part, Humanoid, Players, ...)
- **12,000+ Methods** with parameters & return types
- **Thousands of Properties** with types & security levels
- **Hundreds of Events** with parameters
- **All Roblox Enums** with values & reverse lookup
- **All Datatypes** (Vector3, CFrame, Color3, ...)
- **Luau Core** (keywords, globals, stdlib)

## How to Use

### LuaLib-Dump.lua — Query API

```lua
local Lib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/LuaLib-Dump.lua"
))()

-- Get method signature
print(Lib.GetSignature("Destroy", "Instance"))
-- → "instance:Destroy() -> null"

-- Reverse enum
print(Lib.ResolveEnumFull("Material", 256))
-- → "Enum.Material.Plastic"

-- Check property
print(Lib.HasProperty("Part", "Anchored"))
-- → true
