--!nonstrict
-- Bar widget: a bolt and the estimated wall draw, coloured by load. The tooltip breaks
-- it down by component and shows today's energy and cost. Click opens the panel
-- ([widget.actions] in plugin.toml). Renders from state only.
local fmt = require("./format.luau")

local power = noctalia.state.get("power")
local energy = noctalia.state.get("energy")
local settings = noctalia.state.get("settings") or {}

local function tooltip()
  local cur = settings.currency or ""
  local rows = {
    { key = "At the wall (estimate)", value = fmt.watts(power.wall) },
    { key = "CPU", value = fmt.watts(power.cpu) },
    { key = "GPU", value = fmt.watts(power.gpu) },
    { key = "Rest of PC (allowance)", value = fmt.watts(power.rest) },
    { key = "PSU loss", value = `{fmt.watts(power.loss)} ({fmt.percent(power.efficiency)} efficient)` },
  }
  if energy then
    rows[#rows + 1] = { key = "Cost now", value = `{fmt.money(energy.perHour, cur)} per hour` }
    rows[#rows + 1] = { key = "Today", value = `{fmt.kwh(energy.today.kwh)} · {fmt.money(energy.today.cost, cur)}` }
  end
  return rows
end

local function render()
  if not power then
    barWidget.render(ui.glyph({ name = "bolt", size = 16, color = "on_surface_variant" }))
    barWidget.setTooltip("Dynamo: waiting for the first reading")
    return
  end
  local role = fmt.loadRole(power.wall, settings.warn, settings.high)
  local children = { ui.glyph({ name = "bolt", size = 16, color = role }) }
  if not barWidget.isVertical() then
    -- A minimum width keeps the bar from shifting as the number grows and shrinks.
    children[#children + 1] = ui.row({ minWidth = 42, justify = "end" }, {
      ui.label({ text = fmt.watts(power.wall), color = role }),
    })
  end
  barWidget.render(ui.row({ gap = 4, align = "center" }, children))
  barWidget.setTooltip(tooltip())
end

noctalia.state.watch("power", function(v)
  power = v
  render()
end)
noctalia.state.watch("energy", function(v) energy = v end)

-- `noctalia msg plugin edward/dynamo:widget <output> click` opens the panel at this
-- widget; `... pin` opens or closes the pinned panel. For keybinds.
function onIpc(event)
  if event == "click" then noctalia.togglePanel("edward/dynamo:panel") end
  if event == "pin" then noctalia.togglePanel("edward/dynamo:pin") end
end
noctalia.state.watch("settings", function(v)
  settings = v or {}
  render()
end)

render()
