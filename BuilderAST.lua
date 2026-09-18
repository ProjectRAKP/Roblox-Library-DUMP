local M = {}
local RSVD = { "and","break","do","else","elseif","end","false","for","function","goto", "if","in","local","nil","not","or","repeat","return","then","true", "until","while" }
local CTXD = { "continue", "type", "export" }
local LLURL = "https://raw.githubusercontent.com/ProjectRAKP/Roblox-Library-DUMP/refs/heads/main/LuaLib-Dump.lua"
local LLC = { url = nil, chunk = nil, env = nil }
local function norm(t)
  local a = {}
  if type(t) ~= "table" then return a end
  for k, v in pairs(t) do
    if type(k) == "number" and type(v) == "string" then a[#a+1] = v
    elseif type(k) == "string" and v == true then a[#a+1] = k end
  end
  return a
end
local function isTLS(u)
  return type(u) == "string" and u:match("^https://") ~= nil
end
local function hget(u)
  if type(request) == "function" then
    local ok, r = pcall(request, { Url = u, Method = "GET" })
    if ok and type(r) == "table" and r.Body then return r.Body end
    if ok and type(r) == "string" then return r end
  end
  if type(game) == "table" and game.HttpGet then
    local ok, r = pcall(function() return game:HttpGet(u) end)
    if ok and type(r) == "string" then return r end
  end
  if type(http_request) == "function" then
    local ok, r = pcall(http_request, { Url = u, Method = "GET" })
    if ok and type(r) == "table" and r.Body then return r.Body end
  end
  return nil
end
local function lchunk(src, name)
  if type(loadstring) == "function" then return loadstring(src, name) end
  if type(load) == "function" then return load(src, name) end
  return nil
end
function M.fetchLL(url)
  url = url or LLURL
  if not isTLS(url) then return false, "HTTPS required" end
  if LLC.url == url and LLC.env then return true, LLC.env end
  local body = hget(url)
  if not body or #body < 100 then return false, "fetch failed" end
  local ch = lchunk(body, "=LuaLib@" .. url)
  if not ch then return false, "load failed" end
  local ok, res = pcall(ch)
  if not ok then return false, "chunk error" end
  local lib = type(res) == "table" and res or _G.LuaLib or _G.LuaLibraryDump or _G.LuaLibDump
  if type(lib) ~= "table" then return false, "no table" end
  _G.LuaLib = lib
  LLC.url = url
  LLC.chunk = ch
  LLC.env = lib
  return true, lib
end
local function pullLL()
  local L = _G.LuaLib or _G.LuaLibraryDump or _G.LuaLibDump
  if type(L) ~= "table" then
    local ok, lib = M.fetchLL()
    if ok then L = lib end
  end
  if type(L) ~= "table" then return nil end
  if type(L.GetKeywords) == "function" then
    local ok, r = pcall(L.GetKeywords)
    if ok and type(r) == "table" then
      return {
        reserved = norm(r.reserved or r.Reserved or r),
        contextual = norm(r.contextual or r.Contextual or {}),
      }
    end
  end
  local core = L.LuauCore or L.LuauLib or L.Core or L.LuaCore
  if type(core) == "table" then
    local kw = core.Keywords or core.keywords or core.Reserved or core.reserved
    if type(kw) == "table" then
      return {
        reserved = norm(kw),
        contextual = norm(core.Contextual or core.contextual or {}),
      }
    end
  end
  local kw = L.Keywords or L.keywords
  if type(kw) == "table" then
    return { reserved = norm(kw), contextual = {} }
  end
  return nil
end
local function mkKw()
  local p = pullLL()
  local rl = p and p.reserved or RSVD
  local cl = p and p.contextual or CTXD
  local kw, ctx = {}, {}
  for _, w in ipairs(rl) do kw[w] = true end
  for _, w in ipairs(cl) do ctx[w] = true end
  return kw, ctx
end
local KW, CTX = mkKw()
function M.init(o)
  o = o or {}
  if o.lualibUrl then
    if not isTLS(o.lualibUrl) then error("lualibUrl must be HTTPS") end
    LLURL = o.lualibUrl
  end
  if o.fetchLuaLib == true then M.fetchLL(o.lualibUrl) end
  if o.reloadFromLuaLib ~= false then KW, CTX = mkKw() end
  if o.keywords then
    KW = {}
    for _, w in ipairs(o.keywords) do KW[w] = true end
  end
  if o.contextual then
    CTX = {}
    for _, w in ipairs(o.contextual) do CTX[w] = true end
  end
  return M
end
function M.getKeywords() return KW, CTX end
local ESC = {
  n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v",
  ["\\"] = "\\", ['"'] = '"', ["'"] = "'",
}
local function dEsc(s, i)
  local c = s:sub(i + 1, i + 1)
  if c == "" then return "", i + 1 end
  if ESC[c] then return ESC[c], i + 2 end
  if c == "x" then
    local h = s:sub(i + 2, i + 3)
    if h:match("^%x%x$") then return string.char(tonumber(h, 16)), i + 4 end
  end
  if c == "z" then
    local j = i + 2
    while j <= #s and s:sub(j, j):match("%s") do j = j + 1 end
    return "", j
  end
  if c:match("%d") then
    local d = s:sub(i + 1):match("^%d%d?%d?")
    return string.char(tonumber(d, 10) % 256), i + 1 + #d
  end
  return c, i + 2
end
local function dStr(raw)
  local b = raw:sub(2, -2)
  local o, i, n = {}, 1, #b
  while i <= n do
    local c = b:sub(i, i)
    if c == "\\" then
      local d, ni = dEsc(b, i)
      o[#o + 1] = d
      i = ni
    else
      o[#o + 1] = c
      i = i + 1
    end
  end
  return table.concat(o)
end
local S2 = {
  ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true,
  ["::"] = true, ["//"] = true, ["<<"] = true, [">>"] = true,
  ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true,
  ["^="] = true, ["&="] = true, ["|="] = true,
}
local S3 = {
  ["..."] = true, ["..="] = true, ["<<="] = true, [">>="] = true, ["//="] = true,
}
local function lex(src)
  local toks = {}
  local i, n = 1, #src
  local ln, ls = 1, 1
  local function push(t, v, r, l, c)
    toks[#toks + 1] = {
      type = t, val = v, raw = r or tostring(v),
      line = l or ln, col = c or (i - ls + 1),
    }
  end
  local function bump(f, t)
    for _ in src:sub(f, t):gmatch("\n") do
      ln = ln + 1
      local nl = src:find("\n", ls) or ls
      ls = nl + 1
    end
  end
  while i <= n do
    local c = src:sub(i, i)
    if c == "\n" then
      ln = ln + 1; i = i + 1; ls = i
    elseif c:match("%s") then
      i = i + 1
    elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
      i = i + 2
      local eqs = src:match("^%[(=*)%[", i)
      if eqs then
        local cl = "]" .. eqs .. "]"
        local s, e = src:find(cl, i + 2 + #eqs, true)
        if not s then error("unterminated long comment @ " .. ln) end
        bump(i, e); i = e + 1
      else
        while i <= n and src:sub(i, i) ~= "\n" do i = i + 1 end
      end
    elseif c == "[" then
      local eqs = src:match("^%[(=*)%[", i)
      if eqs then
        local ol = 2 + #eqs
        local cl = "]" .. eqs .. "]"
        local s, e = src:find(cl, i + ol, true)
        if not s then error("unterminated long string @ " .. ln) end
        local b = src:sub(i + ol, s - 1)
        local r = src:sub(i, e)
        local l, co = ln, i - ls + 1
        bump(i, e)
        push("String", b, r, l, co)
        i = e + 1
      else
        push("Symbol", "[", "["); i = i + 1
      end
    elseif c == '"' or c == "'" then
      local q = c
      local j = i + 1
      while j <= n do
        local cc = src:sub(j, j)
        if cc == "\\" then j = j + 2
        elseif cc == q then break
        elseif cc == "\n" then error("unterminated string @ " .. ln)
        else j = j + 1 end
      end
      if j > n then error("unterminated string @ " .. ln) end
      local r = src:sub(i, j)
      push("String", dStr(r), r)
      i = j + 1
    elseif c == "`" then
      local j, d = i + 1, 0
      while j <= n do
        local cc = src:sub(j, j)
        if cc == "\\" then j = j + 2
        elseif cc == "{" then d = d + 1; j = j + 1
        elseif cc == "}" and d > 0 then d = d - 1; j = j + 1
        elseif cc == "`" and d == 0 then break
        else j = j + 1 end
      end
      if j > n then error("unterminated interp @ " .. ln) end
      local r = src:sub(i, j)
      push("String", r:sub(2, -2), r)
      i = j + 1
    elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
      local j = i
      local tw = src:sub(i, i + 1):lower()
      if tw == "0x" then
        j = i + 2
        while j <= n and src:sub(j, j):match("[%x_]") do j = j + 1 end
      elseif tw == "0b" then
        j = i + 2
        while j <= n and src:sub(j, j):match("[01_]") do j = j + 1 end
      else
        while j <= n and src:sub(j, j):match("[%d_]") do j = j + 1 end
        if src:sub(j, j) == "." and src:sub(j + 1, j + 1):match("%d") then
          j = j + 1
          while j <= n and src:sub(j, j):match("[%d_]") do j = j + 1 end
        end
        local e = src:sub(j, j):lower()
        if e == "e" then
          local k = j + 1
          if src:sub(k, k) == "+" or src:sub(k, k) == "-" then k = k + 1 end
          if src:sub(k, k):match("%d") then
            j = k
            while j <= n and src:sub(j, j):match("%d") do j = j + 1 end
          end
        end
      end
      local r = src:sub(i, j - 1)
      push("Number", tonumber((r:gsub("_", ""))) or r, r)
      i = j
    elseif c:match("[%a_]") then
      local j = i
      while j <= n and src:sub(j, j):match("[%w_]") do j = j + 1 end
      local w = src:sub(i, j - 1)
      if KW[w] then push("Keyword", w, w)
      else push("Name", w, w) end
      i = j
    else
      local three, two = src:sub(i, i + 2), src:sub(i, i + 1)
      local s
      if S3[three] then s = three
      elseif S2[two] then s = two
      else s = c end
      push("Symbol", s, s)
      i = i + #s
    end
  end
  toks[#toks + 1] = { type = "EOF", val = "<eof>", raw = "", line = ln }
  return toks
end
local P = {}
P.__index = P
local function newP(t) return setmetatable({ t = t, i = 1 }, P) end
function P:peek(k) return self.t[self.i + (k or 0)] or self.t[#self.t] end
function P:next() local t = self.t[self.i]; self.i = self.i + 1; return t end
function P:isSym(v)
  local t = self:peek(); return t.type == "Symbol" and t.val == v
end
function P:isKw(v)
  local t = self:peek(); return t.type == "Keyword" and t.val == v
end
function P:eatSym(v) if self:isSym(v) then return self:next() end end
function P:eatKw(v) if self:isKw(v) then return self:next() end end
function P:expSym(v)
  if not self:isSym(v) then
    local t = self:peek()
    error(("expected '%s' got '%s' @ %d"):format(v, t.val, t.line))
  end
  return self:next()
end
function P:expKw(v)
  if not self:isKw(v) then
    local t = self:peek()
    error(("expected kw '%s' got '%s' @ %d"):format(v, t.val, t.line))
  end
  return self:next()
end
function P:expName()
  local t = self:peek()
  if t.type ~= "Name" then
    error(("expected name got '%s' @ %d"):format(t.val, t.line))
  end
  return self:next()
end
local pExp, pBlk
local BOP = {
  ["or"] = 1, ["and"] = 2,
  ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["=="] = 3,
  ["|"] = 4, ["~"] = 5, ["&"] = 6,
  ["<<"] = 7, [">>"] = 7,
  [".."] = 8,
  ["+"] = 9, ["-"] = 9,
  ["*"] = 10, ["/"] = 10, ["//"] = 10, ["%"] = 10,
  ["^"] = 12,
}
local RASSOC = { ["^"] = true, [".."] = true }
local function pSuf(s)
  local e = s:pPrim()
  while true do
    local t = s:peek()
    if t.type == "Symbol" and t.val == "." then
      s:next()
      local nm = s:expName()
      e = { type = "MemberExpression", object = e, property = nm.val, colon = false, line = t.line }
    elseif t.type == "Symbol" and t.val == "[" then
      s:next()
      local ix = pExp(s)
      s:expSym("]")
      e = { type = "IndexExpression", object = e, index = ix, line = t.line }
    elseif t.type == "Symbol" and t.val == ":" then
      s:next()
      local nm = s:expName()
      local m = { type = "MemberExpression", object = e, property = nm.val, colon = true, line = t.line }
      local a = s:pArgs()
      e = { type = "CallExpression", callee = m, args = a, method = true, line = t.line }
    elseif t.type == "Symbol" and t.val == "(" then
      local a = s:pArgs()
      e = { type = "CallExpression", callee = e, args = a, method = false, line = t.line }
    elseif t.type == "String" then
      local st = s:next()
      e = { type = "CallExpression", callee = e, args = { { type = "StringLiteral", val = st.val, raw = st.raw, line = st.line } }, method = false, line = st.line }
    elseif t.type == "Symbol" and t.val == "{" then
      local tb = s:pTbl()
      e = { type = "CallExpression", callee = e, args = { tb }, method = false, line = t.line }
    else
      break
    end
  end
  return e
end
function P:pArgs()
  self:expSym("(")
  local a = {}
  if not self:isSym(")") then
    repeat
      a[#a + 1] = pExp(self)
    until not self:eatSym(",")
  end
  self:expSym(")")
  return a
end
function P:pTbl()
  local t0 = self:expSym("{")
  local f = {}
  while not self:isSym("}") do
    local x = { line = self:peek().line }
    if self:isSym("[") then
      self:next()
      x.kind = "index"
      x.key = pExp(self)
      self:expSym("]"); self:expSym("=")
      x.value = pExp(self)
    elseif self:peek().type == "Name" and self:peek(1).type == "Symbol" and self:peek(1).val == "=" then
      x.kind = "key"
      x.key = self:next().val
      self:next()
      x.value = pExp(self)
    else
      x.kind = "value"
      x.value = pExp(self)
    end
    f[#f + 1] = x
    if not self:eatSym(",") and not self:eatSym(";") then break end
  end
  self:expSym("}")
  return { type = "TableExpression", fields = f, line = t0.line }
end
function P:pPrim()
  local t = self:peek()
  if t.type == "Number" then
    self:next()
    return { type = "NumberLiteral", val = t.val, raw = t.raw, line = t.line }
  end
  if t.type == "String" then
    self:next()
    return { type = "StringLiteral", val = t.val, raw = t.raw, line = t.line }
  end
  if t.type == "Name" then
    self:next()
    return { type = "Name", val = t.val, line = t.line }
  end
  if t.type == "Keyword" then
    if t.val == "nil" then
      self:next(); return { type = "NilLiteral", line = t.line }
    end
    if t.val == "true" then
      self:next(); return { type = "BooleanLiteral", val = true, line = t.line }
    end
    if t.val == "false" then
      self:next(); return { type = "BooleanLiteral", val = false, line = t.line }
    end
    if t.val == "function" then
      self:next()
      return self:pFnB(t.line)
    end
  end
  if t.type == "Symbol" then
    if t.val == "..." then
      self:next(); return { type = "VarargExpression", line = t.line }
    end
    if t.val == "{" then return self:pTbl() end
    if t.val == "(" then
      self:next()
      local e = pExp(self)
      self:expSym(")")
      return { type = "ParenExpression", expression = e, line = t.line }
    end
  end
  error(("unexpected '%s' @ %d"):format(t.val, t.line))
end
function P:pFnB(ln)
  self:expSym("(")
  local ps, va = {}, false
  if not self:isSym(")") then
    repeat
      if self:isSym("...") then
        self:next(); va = true; break
      end
      local nm = self:expName()
      if self:eatSym(":") then
        while true do
          local tk = self:peek()
          if tk.type == "Symbol" and (tk.val == "," or tk.val == ")" or tk.val == "=") then break end
          self:next()
        end
      end
      if self:eatSym("=") then pExp(self) end
      ps[#ps + 1] = { name = nm.val, line = nm.line }
    until not self:eatSym(",")
  end
  self:expSym(")")
  if self:eatSym(":") then
    while true do
      local tk = self:peek()
      if tk.type == "Keyword" and tk.val == "end" then break end
      if tk.type == "Symbol" then break end
      self:next()
    end
  end
  local b = pBlk(self)
  self:expKw("end")
  return { type = "FunctionExpression", params = ps, vararg = va, body = b, line = ln }
end
function P:pUn()
  local t = self:peek()
  local u = (t.type == "Keyword" and t.val == "not") or (t.type == "Symbol" and (t.val == "-" or t.val == "#" or t.val == "~"))
  if u then
    self:next()
    local a = self:pUn()
    return { type = "UnaryExpression", op = t.val, arg = a, line = t.line }
  end
  return self:pPow()
end
function P:pPow()
  local b = pSuf(self)
  if self:isSym("^") then
    local t = self:next()
    local r = self:pUn()
    return { type = "BinaryExpression", op = "^", left = b, right = r, line = t.line }
  end
  return b
end
function P:pBin(min)
  local l = self:pUn()
  while true do
    local t = self:peek()
    if t.type ~= "Symbol" and t.type ~= "Keyword" then break end
    local p = BOP[t.val]
    if not p or p < min then break end
    self:next()
    local nm = RASSOC[t.val] and p or (p + 1)
    local r = self:pBin(nm)
    l = { type = "BinaryExpression", op = t.val, left = l, right = r, line = t.line }
  end
  return l
end
pExp = function(s) return s:pBin(1) end
local VTGT = { Name = true, MemberExpression = true, IndexExpression = true }
local COPS = {
  ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["//="] = true,
  ["%="] = true, ["^="] = true, ["..="] = true, ["&="] = true, ["|="] = true,
  ["<<="] = true, [">>="] = true,
}
function P:pStmt()
  local t = self:peek()
  if t.type == "Symbol" and t.val == ";" then
    self:next(); return { type = "EmptyStatement", line = t.line }
  end
  if t.type == "Symbol" and t.val == "::" then
    self:next()
    local nm = self:expName()
    self:expSym("::")
    return { type = "LabelStatement", name = nm.val, line = t.line }
  end
  if t.type == "Keyword" then
    if t.val == "break" then
      self:next(); return { type = "BreakStatement", line = t.line }
    end
    if t.val == "goto" then
      self:next()
      local nm = self:expName()
      return { type = "GotoStatement", label = nm.val, line = t.line }
    end
    if t.val == "do" then
      self:next()
      local b = pBlk(self); self:expKw("end")
      return { type = "DoStatement", body = b, line = t.line }
    end
    if t.val == "while" then
      self:next()
      local c = pExp(self); self:expKw("do")
      local b = pBlk(self); self:expKw("end")
      return { type = "WhileStatement", condition = c, body = b, line = t.line }
    end
    if t.val == "repeat" then
      self:next()
      local b = pBlk(self); self:expKw("until")
      local c = pExp(self)
      return { type = "RepeatStatement", body = b, condition = c, line = t.line }
    end
    if t.val == "if" then
      self:next()
      local cl = {}
      local c = pExp(self); self:expKw("then")
      cl[1] = { condition = c, body = pBlk(self) }
      while self:isKw("elseif") do
        self:next()
        local cc = pExp(self); self:expKw("then")
        cl[#cl + 1] = { condition = cc, body = pBlk(self) }
      end
      local eb = nil
      if self:eatKw("else") then eb = pBlk(self) end
      self:expKw("end")
      return { type = "IfStatement", clauses = cl, elseBody = eb, line = t.line }
    end
    if t.val == "for" then
      self:next()
      local f = self:expName()
      if self:eatSym("=") then
        local a = pExp(self); self:expSym(",")
        local b = pExp(self)
        local st = nil
        if self:eatSym(",") then st = pExp(self) end
        self:expKw("do")
        local bd = pBlk(self); self:expKw("end")
        return { type = "NumericForStatement", var = f.val, from = a, to = b, step = st, body = bd, line = t.line }
      else
        local vs = { f.val }
        while self:eatSym(",") do vs[#vs + 1] = self:expName().val end
        self:expKw("in")
        local it = { pExp(self) }
        while self:eatSym(",") do it[#it + 1] = pExp(self) end
        self:expKw("do")
        local bd = pBlk(self); self:expKw("end")
        return { type = "GenericForStatement", vars = vs, iter = it, body = bd, line = t.line }
      end
    end
    if t.val == "function" then
      self:next()
      local tg = { type = "Name", val = self:expName().val, line = t.line }
      while self:isSym(".") do
        self:next()
        local nm = self:expName()
        tg = { type = "MemberExpression", object = tg, property = nm.val, colon = false, line = t.line }
      end
      local me = nil
      if self:isSym(":") then
        self:next()
        local nm = self:expName()
        tg = { type = "MemberExpression", object = tg, property = nm.val, colon = true, line = t.line }
        me = nm.val
      end
      local fn = self:pFnB(t.line)
      if me then table.insert(fn.params, 1, { name = "self", implicit = true }) end
      return { type = "FunctionDeclaration", name = tg, func = fn, isLocal = false, line = t.line }
    end
    if t.val == "local" then
      self:next()
      if self:isKw("function") then
        self:next()
        local nm = self:expName()
        local fn = self:pFnB(t.line)
        return { type = "FunctionDeclaration", name = { type = "Name", val = nm.val, line = t.line }, func = fn, isLocal = true, line = t.line }
      end
      local ns = { { name = self:expName().val, line = t.line } }
      while self:eatSym(",") do
        ns[#ns + 1] = { name = self:expName().val, line = t.line }
      end
      if self:isSym(":") then
        self:next()
        while true do
          local tk = self:peek()
          if tk.type == "Symbol" and (tk.val == "," or tk.val == "=") then break end
          if tk.type == "EOF" then break end
          if tk.type == "Keyword" and (tk.val == "do" or tk.val == "end" or tk.val == "then") then break end
          self:next()
        end
      end
      local v = {}
      if self:eatSym("=") then
        v[#v + 1] = pExp(self)
        while self:eatSym(",") do v[#v + 1] = pExp(self) end
      end
      return { type = "LocalStatement", names = ns, values = v, line = t.line }
    end
    if t.val == "return" then
      self:next()
      local v = {}
      if not self:isSym(";") and not self:isKw("end") and not self:isKw("else") and not self:isKw("elseif") and not self:isKw("until") and self:peek().type ~= "EOF" then
        v[#v + 1] = pExp(self)
        while self:eatSym(",") do v[#v + 1] = pExp(self) end
      end
      self:eatSym(";")
      return { type = "ReturnStatement", values = v, line = t.line }
    end
  end
  if t.type == "Name" and t.val == "continue" then
    local nx = self:peek(1)
    local cx = not (nx.type == "Symbol" and (nx.val == "=" or nx.val == "." or nx.val == ":" or nx.val == "(" or nx.val == "[" or nx.val == "," or COPS[nx.val]))
    if cx then
      self:next()
      return { type = "ContinueStatement", line = t.line }
    end
  end
  local e = pExp(self)
  local nx = self:peek()
  if nx.type == "Symbol" and (nx.val == "=" or COPS[nx.val]) then
    local tg = { e }
    while self:eatSym(",") do tg[#tg + 1] = pExp(self) end
    local op = self:next().val
    for _, x in ipairs(tg) do
      if not VTGT[x.type] then
        error(("bad assign target (%s) @ %d"):format(x.type, x.line))
      end
    end
    local v = { pExp(self) }
    while self:eatSym(",") do v[#v + 1] = pExp(self) end
    return { type = "AssignmentStatement", targets = tg, values = v, op = op, line = t.line }
  end
  return { type = "ExpressionStatement", expression = e, line = t.line }
end
pBlk = function(s)
  local l0 = s:peek().line
  local b = {}
  while true do
    local t = s:peek()
    if t.type == "EOF" then break end
    if t.type == "Keyword" and (t.val == "end" or t.val == "else" or t.val == "elseif" or t.val == "until") then break end
    b[#b + 1] = s:pStmt()
  end
  return { type = "Block", body = b, line = l0 }
end
function P:pChk()
  local b = pBlk(self)
  if self:peek().type ~= "EOF" then
    local t = self:peek()
    error(("unexpected '%s' @ %d"):format(t.val, t.line))
  end
  return { type = "Chunk", body = b.body, line = 1 }
end
local CHLD = {
  Chunk = { "body" },
  Block = { "body" },
  EmptyStatement = {},
  LabelStatement = {},
  BreakStatement = {},
  ContinueStatement = {},
  GotoStatement = {},
  DoStatement = { "body" },
  WhileStatement = { "condition", "body" },
  RepeatStatement = { "body", "condition" },
  IfStatement = { "clauses", "elseBody" },
  NumericForStatement = { "from", "to", "step", "body" },
  GenericForStatement = { "iter", "body" },
  FunctionDeclaration = { "name", "func" },
  LocalStatement = { "values" },
  ReturnStatement = { "values" },
  ExpressionStatement = { "expression" },
  AssignmentStatement = { "targets", "values" },
  FunctionExpression = { "body" },
  TableExpression = { "fields" },
  BinaryExpression = { "left", "right" },
  UnaryExpression = { "arg" },
  ParenExpression = { "expression" },
  MemberExpression = { "object" },
  IndexExpression = { "object", "index" },
  CallExpression = { "callee", "args" },
  Name = {},
  NumberLiteral = {},
  StringLiteral = {},
  BooleanLiteral = {},
  NilLiteral = {},
  VarargExpression = {},
}
local wVal
wVal = function(v, cb, p)
  if type(v) ~= "table" then return end
  if v.type then
    M.walk(v, cb, p)
  else
    for _, it in ipairs(v) do
      if type(it) == "table" then
        if it.type then
          M.walk(it, cb, p)
        else
          if it.condition then M.walk(it.condition, cb, p) end
          if it.body then M.walk(it.body, cb, p) end
        end
      end
    end
  end
end
function M.walk(n, cb, p)
  if not n then return end
  cb(n, p)
  local o = CHLD[n.type]
  if o then
    for _, k in ipairs(o) do
      wVal(n[k], cb, n)
    end
  end
end
function M.findAll(t, ty)
  local out = {}
  M.walk(t, function(n)
    if n.type == ty then out[#out + 1] = n end
  end)
  return out
end
local PRC = {
  ["or"] = 1, ["and"] = 2,
  ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["=="] = 3,
  ["|"] = 4, ["~"] = 5, ["&"] = 6,
  ["<<"] = 7, [">>"] = 7,
  [".."] = 8,
  ["+"] = 9, ["-"] = 9,
  ["*"] = 10, ["/"] = 10, ["//"] = 10, ["%"] = 10,
  ["^"] = 12,
}
local RA = { ["^"] = true, [".."] = true }
local PRU = 11
local PRA = 100
local function nPrec(n)
  if n.type == "BinaryExpression" then return PRC[n.op] or PRA end
  if n.type == "UnaryExpression" then return PRU end
  return PRA
end
local IND = " "
local function ind(n) return string.rep(IND, n) end
local function escS(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  s = s:gsub("%z", "\\0")
  return '"' .. s .. '"'
end
local ge, gs
local function gbLines(b, lv)
  local o = {}
  for _, st in ipairs(b.body or {}) do
    o[#o + 1] = gs(st, lv)
  end
  return o
end
ge = function(n, lv, pp, side, pOp)
  if not n then return "" end
  pp = pp or 0
  local t = n.type
  local pr = nPrec(n)
  local b
  if t == "Name" then
    b = n.val
  elseif t == "NumberLiteral" then
    b = n.raw or tostring(n.val)
  elseif t == "StringLiteral" then
    b = n.raw or escS(tostring(n.val))
  elseif t == "BooleanLiteral" then
    b = n.val and "true" or "false"
  elseif t == "NilLiteral" then
    b = "nil"
  elseif t == "VarargExpression" then
    b = "..."
  elseif t == "BinaryExpression" then
    local L = ge(n.left, lv, pr, "left", n.op)
    local R = ge(n.right, lv, pr, "right", n.op)
    b = L .. " " .. n.op .. " " .. R
  elseif t == "UnaryExpression" then
    local a = n.arg
    local ap = nPrec(a)
    local need = (ap < pr) or (ap == pr)
    if a.type == "UnaryExpression" and n.op == "not" then need = false end
    local as = need and ("(" .. ge(a, lv) .. ")") or ge(a, lv, pr, "arg", n.op)
    b = (n.op == "not") and ("not " .. as) or (n.op .. as)
  elseif t == "ParenExpression" then
    b = "(" .. ge(n.expression, lv) .. ")"
  elseif t == "MemberExpression" then
    b = ge(n.object, lv, PRA, "left") .. (n.colon and ":" or ".") .. n.property
  elseif t == "IndexExpression" then
    b = ge(n.object, lv, PRA, "left") .. "[" .. ge(n.index, lv) .. "]"
  elseif t == "CallExpression" then
    local a = {}
    for _, x in ipairs(n.args) do a[#a + 1] = ge(x, lv) end
    b = ge(n.callee, lv, PRA, "left") .. "(" .. table.concat(a, ", ") .. ")"
  elseif t == "TableExpression" then
    if #n.fields == 0 then
      b = "{}"
    else
      local a = {}
      local v = lv + 1
      for _, f in ipairs(n.fields) do
        if f.kind == "index" then
          a[#a + 1] = "[" .. ge(f.key, v) .. "] = " .. ge(f.value, v)
        elseif f.kind == "key" then
          a[#a + 1] = f.key .. " = " .. ge(f.value, v)
        else
          a[#a + 1] = ge(f.value, v)
        end
      end
      b = "{" .. table.concat(a, ", ") .. "}"
    end
  elseif t == "FunctionExpression" then
    local p = {}
    for _, x in ipairs(n.params) do
      if not x.implicit then p[#p + 1] = x.name end
    end
    if n.vararg then p[#p + 1] = "..." end
    local ls = gbLines(n.body, lv + 1)
    local inr = (#ls > 0) and ("\n" .. table.concat(ls, "\n") .. "\n" .. ind(lv)) or ""
    b = "function(" .. table.concat(p, ", ") .. ")" .. inr .. "end"
  else
    b = "--[[ ? " .. t .. " ]]"
    pr = PRA
  end
  if pp > 0 and pr < PRA then
    local need = false
    if side == "arg" then
      need = pr < pp
    elseif side == "left" then
      need = pr < pp or (pr == pp and not RA[pOp])
    elseif side == "right" then
      need = pr < pp or (pr == pp and RA[pOp])
    end
    if need then b = "(" .. b .. ")" end
  end
  return b
end
gs = function(s, lv)
  local pd = ind(lv)
  local t = s.type
  if t == "EmptyStatement" then
    return pd .. ";"
  elseif t == "BreakStatement" then
    return pd .. "break"
  elseif t == "ContinueStatement" then
    return pd .. "continue"
  elseif t == "GotoStatement" then
    return pd .. "goto " .. s.label
  elseif t == "LabelStatement" then
    return pd .. "::" .. s.name .. "::"
  elseif t == "DoStatement" then
    local l = { pd .. "do" }
    for _, st in ipairs(s.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "WhileStatement" then
    local l = { pd .. "while " .. ge(s.condition, lv) .. " do" }
    for _, st in ipairs(s.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "RepeatStatement" then
    local l = { pd .. "repeat" }
    for _, st in ipairs(s.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "until " .. ge(s.condition, lv)
    return table.concat(l, "\n")
  elseif t == "IfStatement" then
    local l = {}
    for i, cl in ipairs(s.clauses) do
      local kw = (i == 1) and "if" or "elseif"
      l[#l + 1] = pd .. kw .. " " .. ge(cl.condition, lv) .. " then"
      for _, st in ipairs(cl.body.body) do l[#l + 1] = gs(st, lv + 1) end
    end
    if s.elseBody then
      l[#l + 1] = pd .. "else"
      for _, st in ipairs(s.elseBody.body) do l[#l + 1] = gs(st, lv + 1) end
    end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "NumericForStatement" then
    local h = pd .. "for " .. s.var .. " = " .. ge(s.from, lv) .. ", " .. ge(s.to, lv)
    if s.step then h = h .. ", " .. ge(s.step, lv) end
    h = h .. " do"
    local l = { h }
    for _, st in ipairs(s.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "GenericForStatement" then
    local it = {}
    for _, x in ipairs(s.iter) do it[#it + 1] = ge(x, lv) end
    local l = { pd .. "for " .. table.concat(s.vars, ", ") .. " in " .. table.concat(it, ", ") .. " do" }
    for _, st in ipairs(s.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "FunctionDeclaration" then
    local h
    if s.isLocal then
      h = pd .. "local function " .. s.name.val
    else
      h = pd .. "function " .. ge(s.name, lv)
    end
    local p = {}
    for _, x in ipairs(s.func.params) do
      if not x.implicit then p[#p + 1] = x.name end
    end
    if s.func.vararg then p[#p + 1] = "..." end
    h = h .. "(" .. table.concat(p, ", ") .. ")"
    local l = { h }
    for _, st in ipairs(s.func.body.body) do l[#l + 1] = gs(st, lv + 1) end
    l[#l + 1] = pd .. "end"
    return table.concat(l, "\n")
  elseif t == "LocalStatement" then
    local n = {}
    for _, x in ipairs(s.names) do n[#n + 1] = x.name end
    local ln = pd .. "local " .. table.concat(n, ", ")
    if #s.values > 0 then
      local v = {}
      for _, x in ipairs(s.values) do v[#v + 1] = ge(x, lv) end
      ln = ln .. " = " .. table.concat(v, ", ")
    end
    return ln
  elseif t == "ReturnStatement" then
    if #s.values == 0 then return pd .. "return" end
    local v = {}
    for _, x in ipairs(s.values) do v[#v + 1] = ge(x, lv) end
    return pd .. "return " .. table.concat(v, ", ")
  elseif t == "ExpressionStatement" then
    return pd .. ge(s.expression, lv)
  elseif t == "AssignmentStatement" then
    local tg, v = {}, {}
    for _, x in ipairs(s.targets) do tg[#tg + 1] = ge(x, lv) end
    for _, x in ipairs(s.values) do v[#v + 1] = ge(x, lv) end
    return pd .. table.concat(tg, ", ") .. " " .. s.op .. " " .. table.concat(v, ", ")
  else
    return pd .. "--[[ ? stmt " .. t .. " ]]"
  end
end
function M.gen(t)
  if not t then return "" end
  if t.type == "Chunk" or t.type == "Block" then
    local l = {}
    for _, st in ipairs(t.body) do l[#l + 1] = gs(st, 0) end
    return table.concat(l, "\n")
  end
  return ge(t, 0)
end
local _parse = function(src)
  if type(src) ~= "string" then
    error("BuilderAST.parse: expected string, got " .. type(src))
  end
  return newP(lex(src)):pChk()
end
M._ll = nil
local function bindLL()
  local L = _G.LuaLib or _G.LuaLibraryDump or _G.LuaLibDump
  if type(L) ~= "table" then
    local ok, lib = M.fetchLL()
    if ok then L = lib end
  end
  if type(L) == "table" then M._ll = L end
  return L
end
function M.bind(lib)
  if type(lib) == "table" then M._ll = lib end
  return M
end
function M.ll() return M._ll end
local LLX = {}
local PSEUDO = {
  RBXScriptSignal = {
    Connect = true, ConnectParallel = true, Once = true, Wait = true,
  },
  RBXScriptConnection = {
    Disconnect = true,
  },
}
local MCACHE = {}
local function methodSet(L, cls)
  if MCACHE[cls] then return MCACHE[cls] end
  local s = {}
  if type(L.GetMethods) == "function" then
    local ok, list = pcall(L.GetMethods, cls)
    if ok and type(list) == "table" then
      for _, v in ipairs(list) do
        if type(v) == "string" then s[v] = true end
      end
    end
  end
  MCACHE[cls] = s
  return s
end
local function eventSet(L, cls)
  local key = "e:" .. cls
  if MCACHE[key] then return MCACHE[key] end
  local s = {}
  if type(L.GetEvents) == "function" then
    local ok, list = pcall(L.GetEvents, cls)
    if ok and type(list) == "table" then
      for _, v in ipairs(list) do
        if type(v) == "string" then s[v] = true end
      end
    end
  end
  MCACHE[key] = s
  return s
end
function LLX.Class(name)
  local L = M._ll
  if not L or not name then return nil end
  if type(L.GetClassChain) == "function" then
    local ok, chain = pcall(L.GetClassChain, name)
    if ok and type(chain) == "table" and #chain > 0 then
      return { kind = "class", name = name, chain = chain, src = "LuaLib" }
    end
  end
  return nil
end
function LLX.Method(cls, nm)
  local L = M._ll
  if not L or not cls or not nm then return nil end
  if PSEUDO[cls] and PSEUDO[cls][nm] then
    return { kind = "method", class = cls, name = nm, pseudo = true, src = "LuaLib" }
  end
  local set = methodSet(L, cls)
  if set[nm] then
    local sig
    if type(L.GetFullSignature) == "function" then
      local ok, r = pcall(L.GetFullSignature, nm, cls)
      if ok and type(r) == "string" then sig = r end
    end
    if not sig and type(L.GetSignature) == "function" then
      local ok, r = pcall(L.GetSignature, nm, cls)
      if ok and type(r) == "string" then sig = r end
    end
    local yielding = false
    if type(L.IsYielding) == "function" then
      local ok, y = pcall(L.IsYielding, nm, cls)
      if ok then yielding = y == true end
    end
    return { kind = "method", class = cls, name = nm, sig = sig, yielding = yielding, src = "LuaLib" }
  end
  if type(L.HasDatatypeMethod) == "function" then
    local ok, has = pcall(L.HasDatatypeMethod, cls, nm)
    if ok and has then
      return { kind = "method", class = cls, name = nm, datatype = true, src = "LuaLib" }
    end
  end
  return nil
end
function LLX.Prop(cls, nm)
  local L = M._ll
  if not L or not cls or not nm then return nil end
  if type(L.HasProperty) ~= "function" then return nil end
  local ok, has = pcall(L.HasProperty, cls, nm)
  if not ok or has ~= true then return nil end
  local typ
  if type(L.GetPropertyType) == "function" then
    local ok2, t = pcall(L.GetPropertyType, cls, nm)
    if ok2 then typ = t end
  end
  local ro = false
  if type(L.IsPropertyReadOnly) == "function" then
    local ok3, r = pcall(L.IsPropertyReadOnly, cls, nm)
    if ok3 then ro = r == true end
  end
  return { kind = "property", class = cls, name = nm, ptype = typ, readonly = ro, src = "LuaLib" }
end
function LLX.Event(cls, nm)
  local L = M._ll
  if not L or not cls or not nm then return nil end
  local es = eventSet(L, cls)
  if not es[nm] then return nil end
  local sig
  if type(L.GetEventSignature) == "function" then
    local ok, r = pcall(L.GetEventSignature, nm, cls)
    if ok and type(r) == "string" then sig = r end
  end
  return { kind = "event", class = cls, name = nm, sig = sig, retType = "RBXScriptSignal", src = "LuaLib" }
end
function LLX.Enum(path)
  local L = M._ll
  if not L or not path then return nil end
  local enumName, item = path:match("^([^%.]+)%.(.+)$")
  if not enumName or not item then return nil end
  if type(L.HasEnumItem) ~= "function" then return nil end
  local ok, r = pcall(L.HasEnumItem, enumName, item)
  if ok and r == true then
    local val
    if type(L.GetEnumValue) == "function" then
      local ok2, v = pcall(L.GetEnumValue, enumName, item)
      if ok2 then val = v end
    end
    return { kind = "enum", enum = "Enum." .. enumName .. "." .. item, enumName = enumName, item = item, val = val, src = "LuaLib" }
  end
  return nil
end
function LLX.EnumByValue(enumName, val)
  local L = M._ll
  if not L or not enumName or not val then return nil end
  if type(L.ResolveEnumFull) == "function" then
    local ok, r = pcall(L.ResolveEnumFull, enumName, val)
    if ok and type(r) == "string" then
      local eName, item = r:match("^Enum%.([^%.]+)%.(.+)$")
      return { kind = "enum", enum = r, enumName = eName, item = item, val = val, src = "LuaLib" }
    end
  end
  return nil
end
function LLX.FindEnumsByValue(val)
  local L = M._ll
  if not L or not val then return nil end
  if type(L.FindEnumsByValueFull) == "function" then
    local ok, list = pcall(L.FindEnumsByValueFull, val)
    if ok and type(list) == "table" then
      local out = {}
      for i, v in ipairs(list) do
        local eName, item = v:match("^Enum%.([^%.]+)%.(.+)$")
        out[i] = { kind = "enum", enum = v, enumName = eName, item = item, src = "LuaLib" }
      end
      return out
    end
  end
  return nil
end
function LLX.DatatypeMethod(dt, nm)
  local L = M._ll
  if not L or not dt or not nm then return nil end
  if type(L.HasDatatypeMethod) ~= "function" then return nil end
  local ok, has = pcall(L.HasDatatypeMethod, dt, nm)
  if ok and has == true then
    return { kind = "method", class = dt, name = nm, datatype = true, src = "LuaLib" }
  end
  return nil
end
function LLX.IsDatatype(name)
  local L = M._ll
  if not L or not name then return false end
  if type(L.HasDatatype) ~= "function" then return false end
  local ok, has = pcall(L.HasDatatype, name)
  return ok and has == true
end
function LLX.Sig(cls, nm)
  local L = M._ll
  if not L then return nil end
  if type(L.GetFullSignature) == "function" then
    local ok, r = pcall(L.GetFullSignature, nm, cls)
    if ok and type(r) == "string" then return r end
  end
  if type(L.GetSignature) == "function" then
    local ok, r = pcall(L.GetSignature, nm, cls)
    if ok and type(r) == "string" then return r end
  end
  return nil
end
function M.llx() return LLX end
function M.resolve(cls, nm)
  if not M._ll then bindLL() end
  return LLX.Sig(cls, nm)
end
local function inferCls(e)
  if not e then return nil end
  if e.type == "CallExpression" then
    local c = e.callee
    if not c or c.type ~= "MemberExpression" then return nil end
    local a = e.args[1]
    if c.colon and c.object and c.object.type == "Name" and c.object.val == "game" and c.property == "GetService" and a and a.type == "StringLiteral" then
      return a.val, "service"
    end
    if not c.colon and c.object and c.object.type == "Name" and c.object.val == "Instance" and c.property == "new" and a and a.type == "StringLiteral" then
      return a.val, "instance"
    end
    if not c.colon and c.object and c.object.type == "Name" then
      local dtype = c.object.val
      if LLX.IsDatatype(dtype) then
        if type(M._ll.HasDatatypeMethod) == "function" then
          local ok, hasM = pcall(M._ll.HasDatatypeMethod, dtype, c.property)
          if ok and hasM then return dtype, "datatype" end
        end
      end
    end
    if e.lua and e.lua.retType then
      return e.lua.retType, "return"
    end
    return nil
  end
  if e.type == "MemberExpression" and not e.colon then
    if e.lua and e.lua.ptype then
      local t = e.lua.ptype
      if t and not t:match("^Enum%.") then return t, "property" end
    end
  end
  return nil
end
local function resolveType(node, b)
  if not node then return nil end
  local t = node.type
  if t == "Name" then
    local bd = b[node.val]
    if bd and bd.class then return bd.class end
    if node.lua and node.lua.retType then return node.lua.retType end
    if LLX.IsDatatype(node.val) then return node.val end
    return nil
  end
  if t == "CallExpression" then
    local cls = inferCls(node)
    if cls then return cls end
    return nil
  end
  if t == "MemberExpression" then
    if node.colon then return nil end
    if node.lua and node.lua.retType then return node.lua.retType end
    local objType = resolveType(node.object, b)
    if not objType then return nil end
    local p = LLX.Prop(objType, node.property)
    if p and p.ptype then return p.ptype end
    local e = LLX.Event(objType, node.property)
    if e and e.retType then return e.retType end
    return nil
  end
  if t == "IndexExpression" then
    return resolveType(node.object, b)
  end
  if t == "ParenExpression" then
    return resolveType(node.expression, b)
  end
  return nil
end
local function scanBinds(tree)
  local b = {}
  M.walk(tree, function(n)
    if n.type == "LocalStatement" then
      for i, v in ipairs(n.values) do
        local ne = n.names[i]
        if ne and ne.name then
          local cls, via = inferCls(v)
          if cls then b[ne.name] = { class = cls, via = via, line = ne.line } end
        end
      end
    elseif n.type == "AssignmentStatement" then
      for i, v in ipairs(n.values) do
        local t = n.targets[i]
        if t and t.type == "Name" then
          local cls, via = inferCls(v)
          if cls then b[t.val] = { class = cls, via = via, line = t.line } end
        end
      end
    end
  end)
  return b
end
local function inferCallbackParams(tree, b)
  local added = false
  M.walk(tree, function(n)
    if n.type ~= "CallExpression" then return end
    local c = n.callee
    if not c or c.type ~= "MemberExpression" then return end
    if not c.colon then return end
    local pname = c.property
    if pname ~= "Connect" and pname ~= "Once" then return end
    local evt = c.object
    if not evt or evt.type ~= "MemberExpression" then return end
    if not evt.lua or evt.lua.kind ~= "event" then return end
    local arg1 = n.args[1]
    if not arg1 or arg1.type ~= "FunctionExpression" then return end
    local L = M._ll
    if not L or type(L.GetEventParams) ~= "function" then return end
    local ok, params = pcall(L.GetEventParams, evt.lua.name, evt.lua.class)
    if not ok or type(params) ~= "string" then return end
    local paramList = {}
    for part in params:gmatch("([^,]+)") do
      local pn, pt = part:match("^%s*([%w_]+)%s*:%s*([%w_%.:]+)%s*$")
      if pn and pt then paramList[#paramList + 1] = { name = pn, type = pt } end
    end
    for i, fp in ipairs(arg1.params) do
      local ep = paramList[i]
      if ep and not b[fp.name] then
        b[fp.name] = { class = ep.type, via = "event", line = fp.line }
        added = true
      end
    end
  end)
  return added
end
local function enrichEnumExpr(n)
  if n.type ~= "MemberExpression" then return end
  if n.colon then return end
  local mid = n.object
  if not mid or mid.type ~= "MemberExpression" then return end
  if mid.colon then return end
  local base = mid.object
  if not base or base.type ~= "Name" or base.val ~= "Enum" then return end
  local e = LLX.Enum(mid.property .. "." .. n.property)
  if e then n.lua = e end
end
local function enrichNumToEnum(n, b)
  if n.type ~= "AssignmentStatement" then return end
  for i, v in ipairs(n.values) do
    if v.type == "NumberLiteral" and type(v.val) == "number" then
      local tg = n.targets[i]
      if tg and tg.type == "MemberExpression" and not tg.colon then
        local objType = resolveType(tg.object, b)
        if objType then
          local p = LLX.Prop(objType, tg.property)
          if p and p.ptype then
            local enumName = p.ptype:match("^Enum%.([%w_]+)$")
            if enumName then
              local e = LLX.EnumByValue(enumName, v.val)
              if e then v.lua = e end
            end
          end
        end
      end
    end
  end
end
local function enrichMember(n, b)
  if n.type ~= "MemberExpression" then return end
  if not n.colon then
    local mid = n.object
    if mid and mid.type == "MemberExpression" and not mid.colon then
      local base = mid.object
      if base and base.type == "Name" and base.val == "Enum" then return end
    end
  end
  local objType = resolveType(n.object, b)
  if not objType then return end
  local info
  if n.colon then
    info = LLX.Method(objType, n.property) or LLX.Event(objType, n.property)
  else
    info = LLX.Prop(objType, n.property) or LLX.Event(objType, n.property) or LLX.Method(objType, n.property)
  end
  if info then
    n.lua = info
    n.lua.owner = n.object.type == "Name" and n.object.val or nil
  end
end
local function enrichCall(n, b)
  if n.type ~= "CallExpression" then return end
  local c = n.callee
  if not c or c.type ~= "MemberExpression" then return end
  local objType = resolveType(c.object, b)
  if not objType then return end
  local info = c.lua
  if info and info.kind == "event" then return end
  if not info then
    info = LLX.Method(objType, c.property) or LLX.DatatypeMethod(objType, c.property)
    if not info then return end
  end
  n.lua = {
    kind = "call", cls = objType, name = c.property,
    sig = info.sig, args = n.args, src = "LuaLib",
  }
end
local function enrichEnumString(n)
  if n.type ~= "StringLiteral" or not n._pc then return end
  local pc = n._pc.lua
  if not pc or not pc.cls or not pc.name then return end
  local e = LLX.Enum(pc.cls .. "." .. pc.name .. "." .. n.val)
  if e then n.lua = e end
end
function M.enrich(tree, o)
  o = o or {}
  if not M._ll then bindLL() end
  if not M._ll and o.requireLL ~= false then return tree end
  local b = scanBinds(tree)
  for _ = 1, 4 do
    M.walk(tree, function(n)
      enrichMember(n, b)
      enrichCall(n, b)
    end)
    local added = false
    M.walk(tree, function(n)
      if n.type == "LocalStatement" then
        for i, v in ipairs(n.values) do
          local ne = n.names[i]
          if ne and ne.name and not b[ne.name] then
            local cls, via = inferCls(v)
            if cls then
              b[ne.name] = { class = cls, via = via, line = ne.line }
              added = true
            end
          end
        end
      end
    end)
    if inferCallbackParams(tree, b) then added = true end
    if not added then break end
  end
  if o.enum ~= false then
    M.walk(tree, function(n) enrichEnumExpr(n) end)
    M.walk(tree, function(n)
      if n.type == "CallExpression" then
        for _, a in ipairs(n.args) do
          if a.type == "StringLiteral" then a._pc = n end
        end
      end
    end)
    M.walk(tree, function(n) enrichEnumString(n) end)
    M.walk(tree, function(n) enrichNumToEnum(n, b) end)
  end
  tree._binds = b
  return tree
end
function M.inspect(n)
  if not n then return nil end
  return n.lua
end
function M.classOf(tree, v)
  if not tree._binds then return nil end
  local b = tree._binds[v]
  return b and b.class or nil
end
function M.report(tree)
  local o = {
    nodes = 0, tagged = 0,
    classes = {}, methods = {}, props = {}, events = {}, enums = {},
  }
  M.walk(tree, function(n)
    o.nodes = o.nodes + 1
    if n.lua then
      o.tagged = o.tagged + 1
      local k = n.lua.kind
      if k == "method" and n.lua.class then
        o.classes[n.lua.class] = true
        o.methods[#o.methods + 1] = n.lua.class .. ":" .. n.lua.name
      elseif k == "property" and n.lua.class then
        o.classes[n.lua.class] = true
        o.props[#o.props + 1] = n.lua.class .. "." .. n.lua.name
      elseif k == "event" and n.lua.class then
        o.classes[n.lua.class] = true
        o.events[#o.events + 1] = n.lua.class .. "." .. n.lua.name
      elseif k == "call" and n.lua.cls then
        o.classes[n.lua.cls] = true
        o.methods[#o.methods + 1] = n.lua.cls .. ":" .. n.lua.name
      elseif k == "enum" then
        o.enums[#o.enums + 1] = n.lua.enum
      elseif k == "class" then
        if n.lua.all then
          for _, c in ipairs(n.lua.all) do o.classes[c] = true end
        else
          o.classes[n.lua.name] = true
        end
      end
    end
  end)
  local cs = {}
  for c in pairs(o.classes) do cs[#cs + 1] = c end
  table.sort(cs)
  o.classes = cs
  return o
end
function M.parse(src, o)
  local t = _parse(src)
  if o and o.enrich then M.enrich(t, o) end
  return t
end
function M.pretty(src) return M.gen(M.parse(src)) end
function M.genAnnotated(t, o)
  o = o or {}
  local src = M.gen(t)
  if not o.header then return src end
  local h = { "-- === BuilderAST enriched ===" }
  if M._ll then h[#h + 1] = "-- LuaLib: bound" end
  if t._binds then
    local n = 0
    for _ in pairs(t._binds) do n = n + 1 end
    h[#h + 1] = "-- Binds: " .. n
  end
  return table.concat(h, "\n") .. "\n\n" .. src
end
local function fmtTag(l)
  local tag = l.kind or "?"
  local c = l.cls or l.class
  if c then tag = tag .. " " .. c end
  if l.name then tag = tag .. ":" .. l.name end
  if l.enum then tag = tag .. " " .. l.enum end
  if l.ptype then tag = tag .. " (" .. tostring(l.ptype) .. ")" end
  if l.yielding then tag = tag .. " [yield]" end
  if l.readonly then tag = tag .. " [ro]" end
  return tag
end
function M.annotate(tree)
  local res = {}
  local function collectTags(stmt)
    local tags = {}
    M.walk(stmt, function(n)
      if n.lua then
        local tag = fmtTag(n.lua)
        for _, ex in ipairs(tags) do
          if ex == tag then return end
        end
        tags[#tags + 1] = tag
      end
    end)
    return tags
  end
  local function emitStmt(s, lv, pad)
    local tags = collectTags(s)
    if #tags > 0 then
      res[#res + 1] = pad .. "-- [ " .. table.concat(tags, " | ") .. " ]"
    end
    res[#res + 1] = gs(s, lv)
  end
  local function walkBlock(blk, lv)
    if not blk then return end
    local pad = ind(lv)
    for _, s in ipairs(blk.body or {}) do
      emitStmt(s, lv, pad)
      if s.type == "DoStatement" or s.type == "WhileStatement" or s.type == "RepeatStatement" or s.type == "NumericForStatement" or s.type == "GenericForStatement" then
        walkBlock(s.body, lv + 1)
      elseif s.type == "IfStatement" then
        for _, cl in ipairs(s.clauses) do walkBlock(cl.body, lv + 1) end
        if s.elseBody then walkBlock(s.elseBody, lv + 1) end
      elseif s.type == "FunctionDeclaration" then
        walkBlock(s.func.body, lv + 1)
      end
    end
  end
  if tree.type == "Chunk" or tree.type == "Block" then
    walkBlock(tree, 0)
  end
  return table.concat(res, "\n")
end
function M.refreshKw() return M.init({ reloadFromLuaLib = true }) end
bindLL()
return M
