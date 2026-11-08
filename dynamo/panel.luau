--!nonstrict
-- The dropdown panel, attached to the widget. Entry only; the view is panel-view.luau.
local view = require("./panel-view.luau")(false)

function onOpen() view.onOpen() end
function onClose() view.onClose() end
