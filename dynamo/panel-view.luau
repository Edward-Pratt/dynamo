--!nonstrict
-- The panel view shared by both panels: state, view state (graph range, hovered bucket)
-- and lifecycle. `pinned` is the persistent floating copy that stays open while other
-- windows have focus; the attached dropdown has a pin button that opens it.
local graph = require("./panel-graph.luau")
local sections = require("./panel-sections.luau")

local KEYS = { "power", "energy", "history", "settings" }
local PIN_PANEL = "edward/dynamo:pin"

return function(pinned)
  local isOpen = false
  local S = {}
  for _, k in ipairs(KEYS) do S[k] = noctalia.state.get(k) end
  local view = { range = "recent", hover = nil }
  local ctx

  local function pinButton()
    if pinned then
      return ui.button({ glyph = "pinned-off", variant = "ghost", controlSize = "sm", tooltip = "Unpin and close",
        onClick = function() panel.close() end })
    end
    return ui.button({ glyph = "pin", variant = "ghost", controlSize = "sm",
      tooltip = "Pin: keep open while you use other windows",
      onClick = function()
        noctalia.togglePanel(PIN_PANEL)
        panel.close()
      end })
  end

  local function render()
    if not isOpen then return end
    if not S.power then
      panel.render(ui.column({ padding = 8 }, { ui.label({ text = "Waiting for the first reading…" }) }))
      return
    end
    panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 4 }, {
      sections.header(ctx, pinButton()),
      graph.render(ctx),
      sections.components(ctx),
      sections.costs(ctx),
    }))
  end

  ctx = { S = S, view = view, render = render }

  for _, k in ipairs(KEYS) do
    noctalia.state.watch(k, function(v)
      S[k] = v
      render()
    end)
  end

  return {
    onOpen = function()
      isOpen = true
      render()
    end,
    onClose = function()
      isOpen = false
      view.hover = nil
    end,
  }
end
