# Roblox Library Dump

Complete, Online reference database for **Roblox API** and **Luau Core**

## Files

| File | Description |
|---|---|
| `LuaLib-Dump.lua` | Full Roblox API dump + Luau Core + `Api.*` query functions |
| `BuilderAST.lua` | AST builder — parse Lua/Luau code into an AST (tree) |
| `LICENSE` | MIT License |

## What's Inside

`LuaLib-Dump.lua` contains:

- **937+ Classes** (Instance, Part, Humanoid, Players, ...)
- **12,000+ Methods** with parameters & return types
- **Thousands of Properties** with types & security levels
- **Hundreds of Events** with parameters
- **All Roblox Enums** with values & reverse lookup
- **All Datatypes** (Vector3, CFrame, Color3, ...)
- **Luau Core** (keywords, globals, metamethods, stdlib)

`BuilderAST.lua` provides:

- **Lexer** — text → tokens (handles comments, strings, numbers, operators)
- **Parser** — tokens → AST (full precedence, all statements)
- **Walker** — iterate every node in the tree
- **Code Generator** — AST → text (round-trip safe)
- **Keyword source** — loaded from LuaLib via URL (requires internet, no fallback)

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
