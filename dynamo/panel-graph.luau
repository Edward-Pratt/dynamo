--!nonstrict
-- The panel's history graph: 10 minutes (2 s buckets) or 24 hours (2 min buckets) of
-- wall draw, scaled to a round ceiling above the peak. Hovering reads out one bucket.
local fmt = require("./format.luau")

local M = {}

local RANGES = {
  { id = "recent", label = "10 min", clock = "%H:%M:%S" },
  { id = "day", label = "24 h", clock = "%H:%M" },
}

-- How far back the graph's left edge is, from what the ring holds so far.
local function ago(ms)
  local minutes = math.floor(ms / 60000 + 0.5)
  if minutes < 1 then return `{math.floor(ms / 1000 + 0.5)} s ago` end
  if minutes < 120 then return `{minutes} min ago` end
  return `{math.floor(minutes / 60 + 0.5)} h ago`
end

local function rangeOf(id)
  for _, r in ipairs(RANGES) do
    if r.id == id then return r end
  end
  return RANGES[1]
end

-- The next multiple of 100 W above the peak, at least 100 W.
local function ceiling(values)
  local peak = 0
  for _, v in ipairs(values) do peak = math.max(peak, v) end
  return math.max(100, math.ceil(peak / 100) * 100), peak
end

local function stats(values, peak)
  local sum = 0
  for _, v in ipairs(values) do sum = sum + v end
  return `Peak {fmt.watts(peak)} · average {fmt.watts(sum / #values)}`
end

-- ui.graph does not draw a series' first two points, so the first value is repeated
-- twice to put every real bucket on screen.
local function scaled(values, top)
  local out = { values[1] / top, values[1] / top }
  for _, v in ipairs(values) do out[#out + 1] = v / top end
  return out
end

local function readout(ctx, values, step, range)
  local i = ctx.view.hover
  if not i or not values[i] then return nil end
  local at = os.time() - math.floor((#values - i) * step / 1000)
  return `{os.date(range.clock, at)} · {fmt.watts(values[i])}`
end

local function tabs(ctx)
  local buttons = {}
  for _, r in ipairs(RANGES) do
    buttons[#buttons + 1] = ui.button({ key = "range-" .. r.id, text = r.label, variant = "ghost", controlSize = "sm",
      selected = ctx.view.range == r.id,
      onClick = function()
        ctx.view.range, ctx.view.hover = r.id, nil
        ctx.render()
      end })
  end
  return ui.row({ gap = 4 }, buttons)
end

local function small(text, color)
  return ui.label({ text = text, fontSize = 11, color = color or "on_surface_variant" })
end

function M.render(ctx)
  local range = rangeOf(ctx.view.range)
  local h = ctx.S.history and ctx.S.history[range.id]
  local values = h and h.values or {}
  local head = ui.row({ align = "center", justify = "space_between" }, {
    ui.label({ text = "History", fontWeight = "semibold" }),
    tabs(ctx),
  })
  if #values < 2 then
    return ui.column({ gap = 8 }, { head, small("Collecting readings. The graph fills in as buckets close.") })
  end
  local top, peak = ceiling(values)
  local graph = ui.graph({ key = "graph-" .. range.id, values = scaled(values, top), height = 110,
    color = "primary", lineWidth = 1.5, fillOpacity = 0.2,
    onPointerMove = function(x)
      ctx.view.hover = math.max(1, math.min(#values, math.floor(tonumber(x) * (#values - 1) + 1.5)))
      ctx.render()
    end,
    onPointerLeave = function()
      ctx.view.hover = nil
      ctx.render()
    end })
  return ui.column({ gap = 6 }, {
    head,
    ui.row({ justify = "space_between" }, {
      small(fmt.watts(top)),
      small(readout(ctx, values, h.step, range) or stats(values, peak), "on_surface"),
    }),
    ui.column({ fill = "surface_container", radius = 8, padding = 6 }, { graph }),
    ui.row({ justify = "space_between" }, { small(ago(#values * h.step)), small("now") }),
  })
end

return M
