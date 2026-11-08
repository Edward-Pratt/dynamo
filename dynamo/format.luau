-- Display formatting for watts, energy and money. Pure (plain Lua, tested by tests/pure.lua).

local M = {}

function M.watts(w)
  if w == nil then return "n/a" end
  return string.format("%d W", math.floor(w + 0.5))
end

function M.kwh(k)
  if k < 1 then return string.format("%d Wh", math.floor(k * 1000 + 0.5)) end
  if k < 10 then return string.format("%.2f kWh", k) end
  return string.format("%.1f kWh", k)
end

-- Money with the currency symbol in front. Small amounts get a third decimal so a cost
-- per hour like 0.024 does not round to 0.02.
function M.money(v, symbol)
  local s = symbol or ""
  if v ~= 0 and math.abs(v) < 0.1 then return s .. string.format("%.3f", v) end
  return s .. string.format("%.2f", v)
end

-- A typed price per kWh in the currency's main unit, or nil when there is no number.
-- Takes "0.245", "£0.245", "0,245", and "24.5p" / "24.5c" (pence or cents, / 100).
function M.parsePrice(text)
  local s = string.lower(tostring(text or "")):gsub("%s", ""):gsub(",", ".")
  local num, rest = string.match(s, "(%d*%.?%d+)(.*)$")
  local v = tonumber(num)
  if not v then return nil end
  if string.find(rest, "^[pc]") then v = v / 100 end
  return v
end

-- A unit price as set, up to 4 decimals and at least 2: 0.245 -> "£0.245", 0.3 -> "£0.30".
function M.price(v, symbol)
  local s = string.format("%.4f", v):gsub("0+$", "")
  local decimals = #(s:match("%.(%d*)$") or "")
  if decimals < 2 then s = string.format("%.2f", v) end
  return (symbol or "") .. s
end

function M.percent(f)
  return string.format("%d%%", math.floor(f * 100 + 0.5))
end

-- "2026-10-31" -> "31 Oct". Unparsable keys come back unchanged.
function M.day(key)
  local y, m, d = string.match(key or "", "^(%d+)-(%d+)-(%d+)$")
  if not y then return key end
  local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
  return tostring(tonumber(d)) .. " " .. os.date("%b", t)
end

-- The colour role for a wall draw against the warn and high thresholds (0 or nil: off).
function M.loadRole(wall, warn, high)
  if high and high > 0 and wall >= high then return "error" end
  if warn and warn > 0 and wall >= warn then return "tertiary" end
  return "on_surface"
end

return M
