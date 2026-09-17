local Ast = { VERSION = "1.0", NAME = "LuaAST" }
local URL = "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/main/LuaLib-Dump.lua"
local function fetch(url)
    if game and game.HttpGet then
        local ok, res = pcall(game.HttpGet, game, url)
        if ok and type(res) == "string" and #res > 0 then return res end
    end
    if request then
        local ok, res = pcall(request, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and res.Body then return res.Body end
    end
    if http_request then
        local ok, res = pcall(http_request, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and res.Body then return res.Body end
    end
    return nil
end
local kw = {}
local src = "unknown"
local function loadKw()
    if getgenv and getgenv().__LUA_AST_KW then
        for k in pairs(getgenv().__LUA_AST_KW) do kw[k] = true end
        src = "cache"
        return
    end
    local code = fetch(URL)
    if code then
        local chunk = loadstring(code, "@LuaLib")
        if chunk then
            local ok, lib = pcall(chunk)
            if ok and type(lib) == "table" then
                local core = lib.CORE or (lib.Api and lib.Api.CORE) or getgenv().CORE or rawget(_G, "CORE")
                if core and core.keywords then
                    for k in pairs(core.keywords) do kw[k] = true end
                    src = "LuaLib (URL)"
                    if getgenv then getgenv().__LUA_AST_KW = kw end
                    return
                end
            end
        end
    end
    local fb = {"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","continue","type","export"}
    for _, k in ipairs(fb) do kw[k] = true end
    src = "fallback"
end
loadKw()
local function lex(s)
    local toks = {}
    local i, n, line = 1, #s, 1
    local function add(t, v, r) toks[#toks + 1] = { type = t, val = v, raw = r, line = line } end
    while i <= n do
        local ch = s:sub(i, i)
        if ch == "\n" then
            line = line + 1
            i = i + 1
        elseif ch:match("[ \t\r]") then
            i = i + 1
        elseif ch == "-" and s:sub(i+1, i+1) == "-" then
            if s:sub(i+2, i+3) == "[[" then
                local close = s:find("]]", i+4, true)
                if not close then error("[Lexer] Unclosed block comment") end
                for _ in s:sub(i, close):gmatch("\n") do line = line + 1 end
                i = close + 2
            else
                local nl = s:find("\n", i, true)
                i = nl or (n + 1)
            end
        elseif ch == "[" and s:sub(i+1, i+1) == "[" then
            local close = s:find("]]", i+2, true)
            if not close then error("[Lexer] Unclosed long string") end
            add("String", s:sub(i+2, close-1), s:sub(i, close+1))
            for _ in s:sub(i, close):gmatch("\n") do line = line + 1 end
            i = close + 2
        elseif ch == '"' or ch == "'" then
            local q, j = ch, i + 1
            while j <= n do
                local c = s:sub(j, j)
                if c == "\\" then j = j + 2
                elseif c == q then break
                elseif c == "\n" then error("[Lexer] Unclosed string at line "..line)
                else j = j + 1 end
            end
            if j > n then error("[Lexer] Unclosed string") end
            local raw = s:sub(i, j)
            local val = raw:sub(2, -2):gsub("\\n","\n"):gsub("\\t","\t"):gsub("\\\\","\\"):gsub('\\"','"'):gsub("\\'","'")
            add("String", val, raw)
            i = j + 1
        elseif ch:match("%d") or (ch == "." and s:sub(i+1,i+1):match("%d")) then
            local j = i
            if ch == "0" and s:sub(i+1,i+1):lower() == "x" then
                j = i + 2
                while j <= n and s:sub(j,j):match("[%da-fA-F]") do j = j + 1 end
            else
                while j <= n and s:sub(j,j):match("%d") do j = j + 1 end
                if s:sub(j,j) == "." then
                    j = j + 1
                    while j <= n and s:sub(j,j):match("%d") do j = j + 1 end
                end
                local e = s:sub(j,j):lower()
                if e == "e" then
                    j = j + 1
                    local sign = s:sub(j,j)
                    if sign == "+" or sign == "-" then j = j + 1 end
                    while j <= n and s:sub(j,j):match("%d") do j = j + 1 end
                end
            end
            local raw = s:sub(i, j-1)
            add("Number", tonumber(raw), raw)
            i = j
        elseif ch:match("[%a_]") then
            local j = i
            while j <= n and s:sub(j,j):match("[%w_]") do j = j + 1 end
            local name = s:sub(i, j-1)
            add(kw[name] and "Keyword" or "Name", name, name)
            i = j
        else
            local two = s:sub(i, i+1)
            local three = s:sub(i, i+2)
            local sym
            if three == "..." then sym = three; i = i + 3
            elseif two == "==" or two == "~=" or two == "<=" or two == ">=" or two == ".." or two == "::" or two == "//" then
                sym = two; i = i + 2
            else
                sym = ch; i = i + 1
            end
            add("Symbol", sym, sym)
        end
    end
    add("EOF", nil, nil)
    return toks
end
local function parse(toks)
    local pos = 1
    local function peek(off) return toks[pos + (off or 0)] end
    local function nextTok() local t = toks[pos]; pos = pos + 1; return t end
    local function is(t, v)
        local x = peek()
        return x.type == t and (v == nil or x.val == v)
    end
    local function expect(t, v)
        local x = peek()
        if x.type ~= t or (v and x.val ~= v) then
            error(string.format("[Parser] Line %d: expected %s%s, got %s '%s'", x.line, t, v and (" '"..v.."'") or "", x.type, tostring(x.val)))
        end
        return nextTok()
    end
    local function opt(t, v) if is(t, v) then return nextTok() end end
    local function isSym(v) return is("Symbol", v) end
    local function isKw(v) return is("Keyword", v) end
    local function atEnd()
        local x = peek()
        if x.type == "EOF" then return true end
        if x.type == "Keyword" then
            return x.val == "end" or x.val == "else" or x.val == "elseif" or x.val == "until"
        end
        return false
    end
    local block, stmt, expr
    local primary, suffix, unary
    block = function()
        local list = {}
        while not atEnd() do list[#list + 1] = stmt() end
        return { type = "Block", body = list }
    end
    local function exprList()
        local list = { expr() }
        while isSym(",") do nextTok(); list[#list + 1] = expr() end
        return list
    end
    local function funcBody()
        expect("Symbol", "(")
        local params = {}
        while not isSym(")") do
            if peek().type == "Name" then params[#params + 1] = nextTok().val
            elseif isSym("...") then nextTok(); params[#params + 1] = "..."; break end
            if not isSym(",") then break end
            nextTok()
        end
        expect("Symbol", ")")
        local body = block()
        expect("Keyword", "end")
        return { type = "FunctionExpression", params = params, body = body }
    end
    local function tbl()
        expect("Symbol", "{")
        local fields = {}
        while not isSym("}") do
            if isSym("[") then
                nextTok()
                local k = expr()
                expect("Symbol", "]")
                expect("Symbol", "=")
                fields[#fields + 1] = { key = k, val = expr() }
            elseif peek().type == "Name" and peek(1).type == "Symbol" and peek(1).val == "=" then
                local name = nextTok().val
                nextTok()
                fields[#fields + 1] = { key = { type = "StringLiteral", val = name, raw = name }, val = expr() }
            else
                fields[#fields + 1] = { val = expr() }
            end
            if isSym(",") or isSym(";") then nextTok() end
        end
        expect("Symbol", "}")
        return { type = "TableExpression", fields = fields }
    end
    local function args()
        if isSym("(") then
            nextTok()
            local list = {}
            if not isSym(")") then list = exprList() end
            expect("Symbol", ")")
            return list
        elseif peek().type == "String" then
            local s = nextTok()
            return { { type = "StringLiteral", val = s.val, raw = s.raw } }
        elseif isSym("{") then
            return { tbl() }
        end
        error("[Parser] Line "..peek().line..": expected args")
    end
    suffix = function(base)
        while true do
            if isSym(".") then
                nextTok()
                base = { type = "MemberExpression", obj = base, prop = expect("Name").val, colon = false }
            elseif isSym("[") then
                nextTok()
                local k = expr()
                expect("Symbol", "]")
                base = { type = "IndexExpression", obj = base, key = k }
            elseif isSym(":") then
                nextTok()
                local nm = expect("Name").val
                base = { type = "CallExpression", base = { type = "MemberExpression", obj = base, prop = nm, colon = true }, args = args() }
            elseif isSym("(") or peek().type == "String" or isSym("{") then
                base = { type = "CallExpression", base = base, args = args() }
            else break end
        end
        return base
    end
    primary = function()
        local x = peek()
        if x.type == "Number" then nextTok(); return { type = "NumberLiteral", val = x.val, raw = x.raw } end
        if x.type == "String" then nextTok(); return { type = "StringLiteral", val = x.val, raw = x.raw } end
        if isKw("nil") then nextTok(); return { type = "NilLiteral" } end
        if isKw("true") then nextTok(); return { type = "BooleanLiteral", val = true } end
        if isKw("false") then nextTok(); return { type = "BooleanLiteral", val = false } end
        if isKw("function") then nextTok(); return funcBody() end
        if isSym("...") then nextTok(); return { type = "Vararg" } end
        if x.type == "Name" then nextTok(); return { type = "Identifier", name = x.val } end
        if isSym("(") then
            nextTok()
            local e = expr()
            expect("Symbol", ")")
            return { type = "ParenExpression", expr = e }
        end
        if isSym("{") then return tbl() end
        error("[Parser] Line "..x.line..": unexpected "..tostring(x.val))
    end
    unary = function()
        if isKw("not") or isSym("-") or isSym("#") then
            local op = nextTok().val
            return { type = "UnaryExpression", op = op, arg = unary() }
        end
        return suffix(primary())
    end
    local function binop(nextLevel, ops)
        return function()
            local left = nextLevel()
            while true do
                local hit
                for _, o in ipairs(ops) do
                    if isSym(o) then
                        nextTok()
                        left = { type = "BinaryExpression", op = o, left = left, right = nextLevel() }
                        hit = true
                        break
                    end
                end
                if not hit then break end
            end
            return left
        end
    end
    local power = function()
        local left = unary()
        if isSym("^") then
            nextTok()
            return { type = "BinaryExpression", op = "^", left = left, right = power() }
        end
        return left
    end
    local mul = binop(power, { "*", "/", "%", "//" })
    local add = binop(mul, { "+", "-" })
    local concat = function()
        local left = add()
        while isSym("..") do nextTok(); left = { type = "BinaryExpression", op = "..", left = left, right = add() } end
        return left
    end
    local cmp = binop(concat, { "==", "~=", "<", ">", "<=", ">=" })
    local andOp = function()
        local left = cmp()
        while isKw("and") do nextTok(); left = { type = "BinaryExpression", op = "and", left = left, right = cmp() } end
        return left
    end
    local orOp = function()
        local left = andOp()
        while isKw("or") do nextTok(); left = { type = "BinaryExpression", op = "or", left = left, right = andOp() } end
        return left
    end
    expr = orOp
    stmt = function()
        local x = peek()
        if isKw("local") then
            nextTok()
            if isKw("function") then
                nextTok()
                local name = expect("Name").val
                return { type = "LocalFunction", name = name, body = funcBody() }
            end
            local names = { expect("Name").val }
            while isSym(",") do nextTok(); names[#names + 1] = expect("Name").val end
            local vals = {}
            if opt("Symbol", "=") then vals = exprList() end
            return { type = "LocalStatement", names = names, vals = vals }
        end
        if isKw("return") then
            nextTok()
            local vals = {}
            if not atEnd() and not isSym(";") then vals = exprList() end
            opt("Symbol", ";")
            return { type = "ReturnStatement", vals = vals }
        end
        if isKw("break") then nextTok(); return { type = "BreakStatement" } end
        if isKw("continue") then nextTok(); return { type = "ContinueStatement" } end
        if isKw("if") then
            nextTok()
            local cond = expr()
            expect("Keyword", "then")
            local body = block()
            local elifs, elseBody = {}, nil
            while isKw("elseif") do
                nextTok()
                local c2 = expr()
                expect("Keyword", "then")
                elifs[#elifs + 1] = { cond = c2, body = block() }
            end
            if isKw("else") then nextTok(); elseBody = block() end
            expect("Keyword", "end")
            return { type = "IfStatement", cond = cond, body = body, elifs = elifs, elseBody = elseBody }
        end
        if isKw("while") then
            nextTok()
            local cond = expr()
            expect("Keyword", "do")
            local body = block()
            expect("Keyword", "end")
            return { type = "WhileStatement", cond = cond, body = body }
        end
        if isKw("repeat") then
            nextTok()
            local body = block()
            expect("Keyword", "until")
            return { type = "RepeatStatement", body = body, cond = expr() }
        end
        if isKw("do") then
            nextTok()
            local body = block()
            expect("Keyword", "end")
            return { type = "DoStatement", body = body }
        end
        if isKw("for") then
            nextTok()
            local v = expect("Name").val
            if isSym("=") then
                nextTok()
                local from = expr()
                expect("Symbol", ",")
                local to = expr()
                local step = nil
                if isSym(",") then nextTok(); step = expr() end
                expect("Keyword", "do")
                local body = block()
                expect("Keyword", "end")
                return { type = "ForNumeric", var = v, from = from, to = to, step = step, body = body }
            else
                local vars = { v }
                while isSym(",") do nextTok(); vars[#vars + 1] = expect("Name").val end
                expect("Keyword", "in")
                local iter = exprList()
                expect("Keyword", "do")
                local body = block()
                expect("Keyword", "end")
                return { type = "ForGeneric", vars = vars, iter = iter, body = body }
            end
        end
        if isKw("function") then
            nextTok()
            local name = expect("Name").val
            local target = { type = "Identifier", name = name }
            while isSym(".") do
                nextTok()
                target = { type = "MemberExpression", obj = target, prop = expect("Name").val, colon = false }
            end
            if isSym(":") then
                nextTok()
                target = { type = "MemberExpression", obj = target, prop = expect("Name").val, colon = true }
            end
            return { type = "FunctionDeclaration", target = target, body = funcBody() }
        end
        local e = suffix(primary())
        if isSym(",") or isSym("=") then
            local targets = { e }
            while isSym(",") do nextTok(); targets[#targets + 1] = suffix(primary()) end
            expect("Symbol", "=")
            return { type = "AssignmentStatement", targets = targets, vals = exprList() }
        end
        if e.type == "CallExpression" then
            return { type = "CallStatement", expr = e }
        end
        error("[Parser] Line "..x.line..": unexpected statement")
    end
    local b = block()
    expect("EOF")
    return { type = "Chunk", body = b.body }
end
local function walk(node, fn, parent)
    if type(node) ~= "table" or not node.type then return end
    fn(node, parent)
    for k, v in pairs(node) do
        if k ~= "type" and k ~= "raw" and k ~= "val" then
            if type(v) == "table" then
                if v.type then walk(v, fn, node)
                else for _, x in ipairs(v) do if type(x) == "table" and x.type then walk(x, fn, node) end end end
            end
        end
    end
end
local IND = "    "
local gen
local function genBlock(b, lvl)
    local out = {}
    for _, s in ipairs(b.body) do out[#out + 1] = gen(s, lvl) end
    return table.concat(out, "\n")
end
gen = function(n, lvl)
    lvl = lvl or 0
    local pad = IND:rep(lvl)
    local t = n.type
    if t == "NumberLiteral" then return n.raw or tostring(n.val) end
    if t == "StringLiteral" then
        if n.raw and (n.raw:sub(1,1) == '"' or n.raw:sub(1,1) == "'") then return n.raw end
        return '"'..tostring(n.val):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")..'"'
    end
    if t == "BooleanLiteral" then return tostring(n.val) end
    if t == "NilLiteral" then return "nil" end
    if t == "Vararg" then return "..." end
    if t == "Identifier" then return n.name end
    if t == "ParenExpression" then return "("..gen(n.expr, lvl)..")" end
    if t == "MemberExpression" then return gen(n.obj, lvl)..(n.colon and ":" or ".")..n.prop end
    if t == "IndexExpression" then return gen(n.obj, lvl).."["..gen(n.key, lvl).."]" end
    if t == "CallExpression" then
        local args = {}
        for _, a in ipairs(n.args) do args[#args + 1] = gen(a, lvl) end
        return gen(n.base, lvl).."("..table.concat(args, ", ")..")"
    end
    if t == "BinaryExpression" then return gen(n.left, lvl).." "..n.op.." "..gen(n.right, lvl) end
    if t == "UnaryExpression" then return n.op..((n.op == "not") and " " or "")..gen(n.arg, lvl) end
    if t == "TableExpression" then
        if #n.fields == 0 then return "{}" end
        local parts = {}
        for _, f in ipairs(n.fields) do
            if f.key then parts[#parts + 1] = "["..gen(f.key, lvl).."] = "..gen(f.val, lvl)
            else parts[#parts + 1] = gen(f.val, lvl) end
        end
        return "{"..table.concat(parts, ", ").."}"
    end
    if t == "FunctionExpression" then
        local ps = table.concat(n.params, ", ")
        local body = genBlock(n.body, lvl + 1)
        if body == "" then return "function("..ps..") end" end
        return "function("..ps..")\n"..body.."\n"..pad.."end"
    end
    if t == "LocalStatement" then
        local s = pad.."local "..table.concat(n.names, ", ")
        if #n.vals > 0 then
            local vals = {}
            for _, v in ipairs(n.vals) do vals[#vals + 1] = gen(v, lvl) end
            s = s.." = "..table.concat(vals, ", ")
        end
        return s
    end
    if t == "LocalFunction" then
        local ps = table.concat(n.body.params, ", ")
        local body = genBlock(n.body.body, lvl + 1)
        if body == "" then return pad.."local function "..n.name.."("..ps..") end" end
        return pad.."local function "..n.name.."("..ps..")\n"..body.."\n"..pad.."end"
    end
    if t == "FunctionDeclaration" then
        local ps = table.concat(n.body.params, ", ")
        local body = genBlock(n.body.body, lvl + 1)
        local name = gen(n.target, lvl)
        if body == "" then return pad.."function "..name.."("..ps..") end" end
        return pad.."function "..name.."("..ps..")\n"..body.."\n"..pad.."end"
    end
    if t == "AssignmentStatement" then
        local targets = {}
        for _, x in ipairs(n.targets) do targets[#targets + 1] = gen(x, lvl) end
        local vals = {}
        for _, x in ipairs(n.vals) do vals[#vals + 1] = gen(x, lvl) end
        return pad..table.concat(targets, ", ").." = "..table.concat(vals, ", ")
    end
    if t == "CallStatement" then return pad..gen(n.expr, lvl) end
    if t == "ReturnStatement" then
        if #n.vals == 0 then return pad.."return" end
        local vals = {}
        for _, x in ipairs(n.vals) do vals[#vals + 1] = gen(x, lvl) end
        return pad.."return "..table.concat(vals, ", ")
    end
    if t == "BreakStatement" then return pad.."break" end
    if t == "ContinueStatement" then return pad.."continue" end
    if t == "DoStatement" then return pad.."do\n"..genBlock(n.body, lvl + 1).."\n"..pad.."end" end
    if t == "IfStatement" then
        local s = pad.."if "..gen(n.cond, lvl).." then\n"..genBlock(n.body, lvl + 1)
        for _, e in ipairs(n.elifs) do
            s = s.."\n"..pad.."elseif "..gen(e.cond, lvl).." then\n"..genBlock(e.body, lvl + 1)
        end
        if n.elseBody then s = s.."\n"..pad.."else\n"..genBlock(n.elseBody, lvl + 1) end
        return s.."\n"..pad.."end"
    end
    if t == "WhileStatement" then
        return pad.."while "..gen(n.cond, lvl).." do\n"..genBlock(n.body, lvl + 1).."\n"..pad.."end"
    end
    if t == "RepeatStatement" then
        return pad.."repeat\n"..genBlock(n.body, lvl + 1).."\n"..pad.."until "..gen(n.cond, lvl)
    end
    if t == "ForNumeric" then
        local s = pad.."for "..n.var.." = "..gen(n.from, lvl)..", "..gen(n.to, lvl)
        if n.step then s = s..", "..gen(n.step, lvl) end
        return s.." do\n"..genBlock(n.body, lvl + 1).."\n"..pad.."end"
    end
    if t == "ForGeneric" then
        local iter = {}
        for _, x in ipairs(n.iter) do iter[#iter + 1] = gen(x, lvl) end
        return pad.."for "..table.concat(n.vars, ", ").." in "..table.concat(iter, ", ").." do\n"..genBlock(n.body, lvl + 1).."\n"..pad.."end"
    end
    if t == "Block" then return genBlock(n, lvl) end
    if t == "Chunk" then return genBlock(n, 0) end
    return pad.."-- [unknown: "..t.."]"
end
Ast.build = function(code) return parse(lex(code)) end
Ast.rebuild = function(tree) return gen(tree) end
Ast.lex = lex
Ast.parse = parse
Ast.walk = walk
Ast.generate = gen
Ast.findAll = function(tree, t)
    local out = {}
    walk(tree, function(n) if n.type == t then out[#out + 1] = n end end)
    return out
end
Ast.getKeywordSource = function() return src end
Ast.isKeyword = function(name) return kw[name] == true end
Ast.reload = function()
    if getgenv then getgenv().__LUA_AST_KW = nil end
    kw = {}
    loadKw()
    return src
end
return Ast
