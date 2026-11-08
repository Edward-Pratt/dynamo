--!nonstrict
-- Persistence: the energy ledger and both history rings live in <data>/ledger.json, so
-- totals and graphs survive reloads and reboots. Writes go to a temp file first and
-- are renamed over the old one, so a crash mid-write cannot truncate it. A file that
-- does not parse is kept as ledger.json.bad rather than overwritten.

local history = require("./history.luau")

local M = {}

M.RECENT_SIZE, M.RECENT_STEP = 300, 2000 -- 10 minutes at 2 s
M.DAY_SIZE, M.DAY_STEP = 720, 120000 -- 24 hours at 2 min
local VERSION = 1

local function path()
  local dir = noctalia.pluginDataDir()
  return dir and (dir .. "/ledger.json")
end

local function ring(saved, size, step)
  local r = history.new(size, step)
  if type(saved) ~= "table" then return r end
  history.restore(r, saved.values)
  -- The open bucket carries on; time since the save becomes 0-filled gaps on the next push.
  if type(saved.start) == "number" and type(saved.sum) == "number" and type(saved.n) == "number" then
    r.start, r.sum, r.n = saved.start, saved.sum, saved.n
  end
  return r
end

local function fresh()
  return {
    days = {},
    recent = history.new(M.RECENT_SIZE, M.RECENT_STEP),
    day = history.new(M.DAY_SIZE, M.DAY_STEP),
  }
end

local function validDays(days)
  local out = {}
  if type(days) ~= "table" then return out end
  for k, d in pairs(days) do
    if type(k) == "string" and type(d) == "table" and type(d.kwh) == "number" and type(d.cost) == "number" then
      out[k] = { kwh = d.kwh, cost = d.cost }
    end
  end
  return out
end

function M.load()
  local p = path()
  if not p or not noctalia.fileExists(p) then return fresh() end
  local text = noctalia.readFile(p)
  local doc = text and noctalia.json.decode(text)
  if type(doc) ~= "table" then
    noctalia.log("dynamo: ledger.json does not parse; kept as ledger.json.bad, starting fresh")
    noctalia.renameFile(p, p .. ".bad")
    return fresh()
  end
  return {
    days = validDays(doc.days),
    recent = ring(doc.recent, M.RECENT_SIZE, M.RECENT_STEP),
    day = ring(doc.day, M.DAY_SIZE, M.DAY_STEP),
  }
end

local function saveRing(r)
  return { values = r.values, start = r.start, sum = r.sum, n = r.n }
end

function M.save(data)
  local p = path()
  if not p then return false end
  local text = noctalia.json.encode({
    version = VERSION,
    days = data.days,
    recent = saveRing(data.recent),
    day = saveRing(data.day),
  })
  if not text then return false end
  local ok, err = noctalia.writeFile(p .. ".tmp", text)
  if ok then ok, err = noctalia.renameFile(p .. ".tmp", p) end
  if not ok then noctalia.log("dynamo: saving the ledger failed: " .. tostring(err)) end
  return ok
end

return M
