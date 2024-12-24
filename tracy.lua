local M = {}

-- You can disable without remove calling code
local Enabled = true
if not Enabled then
  local EmptyFunc = function() return M end
  M.start = EmptyFunc
  M.stop = EmptyFunc
  M.mark_frame = EmptyFunc
  M.begin = EmptyFunc
  M.finish = EmptyFunc
  M.plot = EmptyFunc
  M.plot_incr = EmptyFunc
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

local IsConnected = false
local CtxStack = {}
-- { loc, parent_node, [name] = node }
local LocsTreeNode = { nil, nil }
local Symbols = {} -- { [name] = true }, cache name string, avoid lua GC
local PlotCounters = {}

function M.start()
  Lib.___tracy_startup_profiler()
end

function M.stop()
  Lib.___tracy_shutdown_profiler()
end

function M.mark_frame()
  if IsConnected then
    for k, v in pairs(PlotCounters) do
      Lib.___tracy_emit_plot(k, v)
      PlotCounters[k] = 0
    end
  end

  Lib.___tracy_emit_frame_mark(nil)
  IsConnected = Lib.___tracy_connected() == 1
end

function M.begin(name, top)
  if not IsConnected then return M end
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
  local ctx = Lib.___tracy_emit_zone_begin(loc_node[1], 1) or false
  CtxStack[#CtxStack + 1] = ctx
  LocsTreeNode = loc_node
  return M
end

function M.finish()
  if not IsConnected then return M end
  local ctx = CtxStack[#CtxStack]
  if ctx == nil then
    error("Must call begin before calling finish.")
  end
  CtxStack[#CtxStack] = nil
  LocsTreeNode = LocsTreeNode[2]
  if ctx then
    Lib.___tracy_emit_zone_end(ctx)
  end
  return M
end

-- val: number
function M.plot(name, val)
  if not IsConnected then return M end
  Symbols[name] = true
  Lib.___tracy_emit_plot(name, val)
  return M
end

-- submit on mark_frame and reset to 0 after submit
function M.plot_incr(name, val)
  if not IsConnected then return M end
  PlotCounters[name] = (PlotCounters[name] or 0) + (val or 1)
  return M
end

function M.message(txt)
  if not IsConnected then return M end
  Lib.___tracy_emit_message(txt, #txt, 0)
  return M
end

return M