--!nonstrict
-- CPU package power. First choice: the powercap RAPL package counters (energy_uj),
-- averaged over the time between two reads. Many kernels make those root-only, so the
-- fallback is a hwmon driver that reports package power directly (zenpower on AMD).
-- Both report the same RAPL quantity, so only one is ever used, never both.
-- An integrated GPU on the CPU die is inside this reading.

local M = {}

local POWERCAP = "/sys/class/powercap"
local HWMON = "/sys/class/hwmon"
local HWMON_DRIVERS = { zenpower = true }

local source = nil -- "rapl" | "hwmon" | nil (no sensor)
local zones = {} -- RAPL: { path, max }
local hwmonPath = nil
local last = nil -- RAPL: { at = ms, energy = { per zone } }

local function readNumber(path)
  local s = noctalia.readFile(path)
  return s and tonumber(noctalia.string.trim(s))
end

local function findRapl()
  local names = noctalia.listDir(POWERCAP) or {}
  for _, n in ipairs(names) do
    -- Top-level zones only (intel-rapl:0, not intel-rapl:0:0); AMD uses the same names.
    if string.match(n, "^intel%-rapl:%d+$") then
      local dir = POWERCAP .. "/" .. n
      local name = noctalia.readFile(dir .. "/name") or ""
      if string.find(name, "^package") and readNumber(dir .. "/energy_uj") then
        zones[#zones + 1] = { path = dir .. "/energy_uj", max = readNumber(dir .. "/max_energy_range_uj") or 2 ^ 32 }
      end
    end
  end
  return #zones > 0
end

local function findHwmon()
  for _, n in ipairs(noctalia.listDir(HWMON) or {}) do
    local dir = HWMON .. "/" .. n
    local name = noctalia.string.trim(noctalia.readFile(dir .. "/name") or "")
    if HWMON_DRIVERS[name] and readNumber(dir .. "/power1_input") then
      hwmonPath = dir .. "/power1_input"
      return true
    end
  end
  return false
end

function M.init()
  zones, hwmonPath, last = {}, nil, nil
  if findRapl() then
    source = "rapl"
  elseif findHwmon() then
    source = "hwmon"
  else
    source = nil
  end
  return source
end

function M.source() return source end

local function readRapl(nowMs)
  local energy = {}
  for i, z in ipairs(zones) do
    local e = readNumber(z.path)
    if not e then return nil end
    energy[i] = e
  end
  local prev = last
  last = { at = nowMs, energy = energy }
  if not prev or nowMs <= prev.at then return nil end
  local joules = 0
  for i, z in ipairs(zones) do
    local d = energy[i] - prev.energy[i]
    if d < 0 then d = d + z.max end -- counter wrapped
    joules = joules + d / 1e6
  end
  return joules / ((nowMs - prev.at) / 1000)
end

-- Watts, or nil when there is no sensor or no reading yet (RAPL needs two reads).
function M.read(nowMs)
  if source == "rapl" then return readRapl(nowMs) end
  if source == "hwmon" then
    local uw = readNumber(hwmonPath)
    return uw and uw / 1e6
  end
  return nil
end

return M
