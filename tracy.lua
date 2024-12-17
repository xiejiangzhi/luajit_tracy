local M = {}

-- You can disable without remove calling code
local Enabled = true
if not Enabled then
  local EmptyFunc = function() end
  M.start = EmptyFunc
  M.stop = EmptyFunc
  M.mark_frame = EmptyFunc
  M.begin = EmptyFunc
  M.finish = EmptyFunc
  M.finish_begin = EmptyFunc
  M.plot = EmptyFunc
  M.message = EmptyFunc

  return M
end

local ffi = require 'ffi'

-- compile Tracy with TRACY_DELAYED_INIT, TRACY_MANUAL_LIFETIME

ffi.cdef[[
void ___tracy_startup_profiler(void);
void ___tracy_shutdown_profiler(void);

void ___tracy_emit_frame_mark(const char* name);

struct ___tracy_source_location_data {
  const char* name;
  const char* function;
  const char* file;
  uint32_t line;
  uint32_t color;
};
typedef struct ___tracy_source_location_data TracySourceLocation;

struct ___tracy_c_zone_context {
  uint32_t id;
  int active;
};
typedef struct ___tracy_c_zone_context TracyCZoneCtx;

TracyCZoneCtx ___tracy_emit_zone_begin(
  const struct ___tracy_source_location_data* srcloc, int active
);
void ___tracy_emit_zone_end(TracyCZoneCtx ctx);
void ___tracy_emit_plot(const char* name, double val);
void ___tracy_emit_message(const char* txt, size_t size, int callstack);

int ___tracy_connected(void);
]]

local Lib = ffi.load(package.searchpath('TracyClient', package.cpath))

local LocationData = ffi.typeof('TracySourceLocation')

local CtxStack = {}
-- { loc, parent_node, [name] = node }
local LocsTreeNode = { nil, nil }
local Symbols = {} -- { [name] = true }, for cache name string
local IsConnected = false

function M.start()
  Lib.___tracy_startup_profiler()
end

function M.stop()
  Lib.___tracy_shutdown_profiler()
end

function M.mark_frame()
  Lib.___tracy_emit_frame_mark(nil)
  IsConnected = Lib.___tracy_connected() == 1
end

function M.begin(name, top)
  assert(#CtxStack < 32, "APM depth must <= 32. Maybe forgot to call finish?")

  local loc_node = LocsTreeNode[name]
  if not loc_node then
    assert(type(name) == 'string', "name must be a string")
    assert(#name <= 40, "name length must <= 40")
    local info = debug.getinfo(top or 2, 'Sln')
    local loc = LocationData(name, info.name, info.short_src, info.currentline, 0)
    loc_node = { loc, LocsTreeNode, info.name, info.short_src } -- ref string to avoid gc
    LocsTreeNode[name] = loc_node
  end
  local ctx = IsConnected and Lib.___tracy_emit_zone_begin(loc_node[1], 1) or false
  CtxStack[#CtxStack + 1] = ctx
  LocsTreeNode = loc_node
end

function M.finish()
  local ctx = CtxStack[#CtxStack]
  if ctx == nil then
    error("Must call begin before calling finish.")
  end
  CtxStack[#CtxStack] = nil
  LocsTreeNode = LocsTreeNode[2]
  if ctx then
    Lib.___tracy_emit_zone_end(ctx)
  end
end

function M.finish_begin(name)
  M.finish()
  M.begin(name, 3)
end

-- val: number
function M.plot(name, val)
  Symbols[name] = true
  Lib.___tracy_emit_plot(name, val)
end

function M.message(txt)
  Lib.___tracy_emit_message(txt, #txt, 0);
end

return M