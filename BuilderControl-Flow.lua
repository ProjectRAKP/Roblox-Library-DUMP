local UCF = {}
local function V(val)
  local t = type(val)
  if t == "nil"     then return { type="NilLiteral", line=1 } end
  if t == "number"  then
    return { type="NumberLiteral", val=val, raw=tostring(val), line=1 }
  end
  if t == "boolean" then
    return { type="BooleanLiteral", val=val, line=1 }
  end
  if t == "string"  then
    local esc = val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')
    return { type="StringLiteral", val=val, raw='"'..esc..'"', line=1 }
  end
  if t == "table" then
    if val.type then return val end
    if val.kind then return UCF.build(val) end
    return UCF.block(val)
  end
  error("UCF: cannot convert value of type " .. t)
end
local function E(spec)
  if spec == nil then return nil end
  if type(spec) ~= "table" then return V(spec) end
  if spec.type then return spec end
  if spec.kind then return UCF.build(spec) end
  if spec.name then return { type="Name", val=spec.name, line=1 } end
  if spec.op then
    if spec.left ~= nil or spec.right ~= nil then
      return { type="BinaryExpression", op=spec.op,
               left=E(spec.left), right=E(spec.right), line=1 }
    end
    return { type="UnaryExpression", op=spec.op, arg=E(spec.arg), line=1 }
  end
  if spec.call then
    local args = {}
    for _, a in ipairs(spec.args or {}) do args[#args+1] = E(a) end
    return { type="CallExpression", callee=E(spec.call), args=args,
             method=spec.method or false, line=1 }
  end
  if spec.member then
    return { type="MemberExpression", object=E(spec.member),
             property=spec.prop, colon=spec.colon or false, line=1 }
  end
  if spec.index then
    return { type="IndexExpression", object=E(spec.index),
             index=E(spec.key), line=1 }
  end
  if spec.enum then
    local path = spec.enum
    local head = { type="Name", val="Enum", line=1 }
    local node = { type="MemberExpression", object=head,
                   property=path:match("^([^%.]+)"), colon=false, line=1 }
    for seg in path:gmatch("%.([^%.]+)") do
      node = { type="MemberExpression", object=node,
               property=seg, colon=false, line=1 }
    end
    return node
  end
  return V(spec)
end
function UCF.block(list)
  local body = {}
  for _, stmt in ipairs(list) do
    local s = UCF.build(stmt)
    if s then body[#body+1] = s end
  end
  return { type="Block", body=body, line=1 }
end
UCF.handlers = {
  assign = function(s)
    local tg, v = {}, {}
    for _, t in ipairs(s.targets or {}) do tg[#tg+1] = E(t) end
    for _, x in ipairs(s.values  or {}) do v[#v+1]  = E(x) end
    return { type="AssignmentStatement", targets=tg, values=v,
             op=s.op or "=", line=1 }
  end,
  local_ = function(s)
    local names, values = {}, {}
    for _, n in ipairs(s.names  or {}) do
      names[#names+1] = { name=n, line=1 }
    end
    for _, x in ipairs(s.values or {}) do values[#values+1] = E(x) end
    return { type="LocalStatement", names=names, values=values, line=1 }
  end,
  call = function(s)
    local args = {}
    for _, a in ipairs(s.args or {}) do args[#args+1] = E(a) end
    return { type="ExpressionStatement",
             expression={ type="CallExpression",
                          callee=E(s.callee or s.call),
                          args=args, method=s.method or false, line=1 },
             line=1 }
  end,
  return_ = function(s)
    local v = {}
    for _, x in ipairs(s.values or {}) do v[#v+1] = E(x) end
    return { type="ReturnStatement", values=v, line=1 }
  end,
  break_    = function() return { type="BreakStatement", line=1 } end,
  continue_ = function() return { type="ContinueStatement", line=1 } end,
  if_ = function(s)
    local clauses = {
      { condition = E(s.cond), body = UCF.block(s.then_ or {}) }
    }
    for _, ei in ipairs(s.elseif_ or {}) do
      clauses[#clauses+1] = {
        condition = E(ei.cond),
        body = UCF.block(ei.then_ or {}),
      }
    end
    local elseBody = s.else_ and UCF.block(s.else_) or nil
    return { type="IfStatement", clauses=clauses,
             elseBody=elseBody, line=1 }
  end,
  while_ = function(s)
    return { type="WhileStatement",
             condition = E(s.cond),
             body = UCF.block(s.body or {}), line=1 }
  end,
  repeat_ = function(s)
    return { type="RepeatStatement",
             body = UCF.block(s.body or {}),
             condition = E(s.until_), line=1 }
  end,
  for_ = function(s)
    return { type="NumericForStatement", var=s.var,
             from=E(s.from), to=E(s.to),
             step=s.step and E(s.step) or nil,
             body=UCF.block(s.body or {}), line=1 }
  end,
  forin = function(s)
    local it = {}
    for _, x in ipairs(s.iter or {}) do it[#it+1] = E(x) end
    return { type="GenericForStatement", vars=s.vars, iter=it,
             body=UCF.block(s.body or {}), line=1 }
  end,
  do_ = function(s)
    return { type="DoStatement",
             body=UCF.block(s.body or {}), line=1 }
  end,
  fn = function(s)
    local params = {}
    for _, p in ipairs(s.params or {}) do
      params[#params+1] = { name=p, line=1 }
    end
    local fn = { type="FunctionExpression", params=params,
                 vararg=s.vararg or false,
                 body=UCF.block(s.body or {}), line=1 }
    if s.name then
      local target
      if s.owner then
        target = { type="MemberExpression",
                   object={ type="Name", val=s.owner, line=1 },
                   property=s.name, colon=true, line=1 }
        table.insert(fn.params, 1, { name="self", implicit=true })
      else
        target = { type="Name", val=s.name, line=1 }
      end
      return { type="FunctionDeclaration", name=target, func=fn,
               isLocal=s.isLocal or false, line=1 }
    end
    return { type="ExpressionStatement", expression=fn, line=1 }
  end,
}
function UCF.build(spec)
  if not spec then return nil end
  if spec.type then return spec end
  local kind = spec.kind
  if not kind then error("UCF.build: spec harus punya .kind atau .type") end
  local h = UCF.handlers[kind]
  if not h then error("UCF.build: unknown kind '"..tostring(kind).."'") end
  return h(spec)
end
function UCF.chunk(specs)
  local body = {}
  for _, s in ipairs(specs) do
    body[#body+1] = UCF.build(s)
  end
  return { type="Chunk", body=body, line=1 }
end
UCF.V = V
UCF.E = E
return UCF
