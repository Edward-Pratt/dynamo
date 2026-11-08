--!nonstrict
-- The service: the only entry that reads sensors, settings and the ledger file. Every
-- second it estimates wall power, adds the energy to the ledger and publishes `power`,
-- `energy`, `history` and `settings` (see docs/DESIGN.md). Wiring only.
local cpu = require("./sensor-cpu.luau")
local gpu = require("./sensor-gpu.luau")
local efficiency = require("./efficiency.luau")
local ledger = require("./ledger.luau")
local history = require("./history.luau")
local store = require("./service-store.luau")
local config = require("./service-config.luau")

local TICK_MS = 1000
local MAX_GAP_MS = 10000 -- a longer gap between ticks is sleep: no energy counted for it
local SAVE_MS = 60000
local WARMUP_MS = 5000 -- wait this long for the first CPU and GPU readings

local cfg = config.read()
local data = store.load()
local startedAt = noctalia.nowMs()
local lastTick = nil
local lastSave = startedAt

cpu.init()
gpu.init()

local function publishSettings()
  noctalia.state.set("settings", {
    currency = cfg.currency,
    price = cfg.price,
    warn = cfg.warn,
    high = cfg.high,
  })
end

local function publishHistory()
  noctalia.state.set("history", {
    recent = { values = data.recent.values, step = data.recent.step },
    day = { values = data.day.values, step = data.day.step },
  })
end

local function publishEnergy(wall)
  local t = ledger.totals(data.days, os.time())
  t.perHour = wall / 1000 * cfg.price
  noctalia.state.set("energy", t)
end

local function publishPower(now, cpuW, gpuW, e)
  noctalia.state.set("power", {
    at = now,
    wall = e.wall,
    dc = e.dc,
    loss = e.loss,
    efficiency = e.efficiency,
    load = e.load,
    fixedEfficiency = cfg.psu.rating == "fixed",
    cpu = cpuW,
    gpu = gpuW,
    rest = cfg.rest,
    cpuSource = cpu.source(),
    gpuSource = gpu.source(),
  })
end

publishSettings()
publishHistory()

function onConfigChanged()
  cfg = config.read()
  publishSettings()
end

function onExit()
  store.save(data)
end

noctalia.setUpdateInterval(TICK_MS)
function update()
  local now = noctalia.nowMs()
  if lastTick and now - lastTick > MAX_GAP_MS then
    -- Back from sleep: RAPL's first delta spans the whole gap (or a counter reset), so
    -- drop this tick and let it re-prime. The gap counts no energy and the rings fill
    -- it with zeros on the next push.
    lastTick = now
    cpu.read(now)
    return
  end
  gpu.ensure()
  local cpuW, gpuW = cpu.read(now), gpu.read(now)
  local warming = now - startedAt < WARMUP_MS
  if warming and ((cpu.source() and not cpuW) or (gpu.source() and not gpuW)) then return end

  local e = efficiency.estimate(cpuW, gpuW, cfg.rest, cfg.psu)
  publishPower(now, cpuW, gpuW, e)
  if lastTick and now - lastTick <= MAX_GAP_MS then
    ledger.add(data.days, ledger.dayKey(os.time()), e.wall * (now - lastTick) / 3.6e9, cfg.price)
  end
  lastTick = now
  publishEnergy(e.wall)

  local recentClosed = history.push(data.recent, now, e.wall)
  local dayClosed = history.push(data.day, now, e.wall)
  if recentClosed or dayClosed then publishHistory() end
  if now - lastSave >= SAVE_MS then
    store.save(data)
    lastSave = now
  end
end
