--!nonstrict
-- Panel shell: state, view state (graph range, hovered bucket) and lifecycle. The
-- sections render from ctx; the graph is its own module.
local graph = require("./panel-graph.luau")
local sections = require("./panel-sections.luau")

local KEYS = { "power", "energy", "history", "settings" }

local isOpen = false
local S = {}
for _, k in ipairs(KEYS) do S[k] = noctalia.state.get(k) end
local view = { range = "recent", hover = nil }
local ctx

local function render()
  if not isOpen then return end
  if not S.power then
    panel.render(ui.column({ padding = 8 }, { ui.label({ text = "Waiting for the first reading…" }) }))
    return
  end
  panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 4 }, {
    sections.header(ctx),
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

function onOpen()
  isOpen = true
  render()
end

function onClose()
  isOpen = false
  view.hover = nil
end
