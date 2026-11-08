--!nonstrict
-- The pinned panel: persistent and floating, so it stays open (above fullscreen games on
-- noctalia's overlay layer) until unpinned. Entry only; the view is panel-view.luau.
local view = require("./panel-view.luau")(true)

function onOpen() view.onOpen() end
function onClose() view.onClose() end
