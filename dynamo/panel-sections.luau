--!nonstrict
-- The panel's header, component breakdown and energy/cost table.
local fmt = require("./format.luau")

local M = {}

local function small(text, color)
  return ui.label({ text = text, fontSize = 11, color = color or "on_surface_variant" })
end

local function title(text)
  return ui.label({ text = text, fontWeight = "semibold" })
end

-- A right-aligned cell of fixed width (labels ignore width, so a row carries it).
local function cell(text, width, color)
  return ui.row({ width = width, justify = "end" }, { ui.label({ text = text, color = color or "on_surface" }) })
end

local function openSettings()
  noctalia.openSettings()
end

-- `extra` is a button placed before the settings button (pin / unpin).
function M.header(ctx, extra)
  local p, s, e = ctx.S.power, ctx.S.settings or {}, ctx.S.energy
  local role = fmt.loadRole(p.wall, s.warn, s.high)
  local sub = "Estimated draw at the wall"
  if e then sub = `{sub} · {fmt.money(e.perHour, s.currency)} per hour` end
  return ui.row({ align = "center", gap = 10 }, {
    ui.glyph({ name = "bolt", size = 30, color = role }),
    ui.column({ gap = 2, flexGrow = 1 }, {
      ui.label({ text = fmt.watts(p.wall), fontSize = 26, fontWeight = "bold", color = role }),
      small(sub),
    }),
    extra,
    ui.button({ glyph = "settings", variant = "ghost", controlSize = "sm",
      tooltip = "Electricity price, PSU and colours", onClick = openSettings }),
  })
end

local function component(name, note, watts, wall)
  local share = (watts and wall > 0) and math.min(1, watts / wall) or 0
  return ui.column({ gap = 3 }, {
    ui.row({ align = "center" }, {
      ui.column({ gap = 1, flexGrow = 1 }, { ui.label({ text = name }), small(note) }),
      cell(fmt.watts(watts), 70),
    }),
    ui.progress({ progress = share, height = 4, fill = "primary", track = "surface_container_high", radius = 2 }),
  })
end

local CPU_NOTES = { rapl = "Measured: RAPL package", hwmon = "Measured: zenpower (RAPL package)" }

function M.components(ctx)
  local p = ctx.S.power
  local cpuNote = p.cpuSource and CPU_NOTES[p.cpuSource] or "No sensor found, counted as 0"
  local gpuNote = p.gpuSource and `Measured: {p.gpuSource}` or "No discrete GPU sensor, counted as 0"
  local lossNote = p.fixedEfficiency and `{fmt.percent(p.efficiency)} efficient (fixed)`
    or `{fmt.percent(p.efficiency)} efficient at {fmt.percent(p.load)} of the PSU's rating`
  return ui.column({ gap = 8 }, {
    title("By component"),
    component("CPU", cpuNote, p.cpu, p.wall),
    component("GPU", gpuNote, p.gpu, p.wall),
    component("Rest of PC", "Your allowance: board, RAM, drives, fans, USB", p.rest, p.wall),
    component("PSU loss", lossNote, p.loss, p.wall),
  })
end

local function costRow(label, t, currency)
  return ui.row({ align = "center" }, {
    ui.label({ text = label, flexGrow = 1 }),
    cell(fmt.kwh(t.kwh), 90, "on_surface_variant"),
    cell(fmt.money(t.cost, currency), 80),
  })
end

function M.costs(ctx)
  local e, s = ctx.S.energy, ctx.S.settings or {}
  if not e then return ui.column({}, { title("Energy and cost"), small("No energy counted yet.") }) end
  local cur = s.currency or ""
  local since = e.since and `All time (since {fmt.day(e.since)})` or "All time"
  local price = s.price and s.price > 0 and `{fmt.price(s.price, cur)} per kWh` or "No price set: costs show as 0"
  if s.badPrice then price = `Price "{s.badPrice}" has no number: costs show as 0` end
  return ui.column({ gap = 6 }, {
    title("Energy and cost"),
    costRow("Today", e.today, cur),
    costRow("This week", e.week, cur),
    costRow("This month", e.month, cur),
    costRow(since, e.all, cur),
    ui.row({ align = "center", gap = 8 }, {
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = price }),
        small("A new price applies from the moment you set it."),
      }),
      ui.button({ text = "Change price", variant = "outline", controlSize = "sm", onClick = openSettings }),
    }),
  })
end

return M
