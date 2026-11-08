-- Energy ledger: kWh and cost per local day. Pure (plain Lua, tested by tests/pure.lua).
--
-- Cost is added at the price in effect when the energy is used, so changing the price
-- later does not rewrite past days. Days are keyed "YYYY-MM-DD" in local time.

local M = {}

function M.dayKey(unixSec)
  return os.date("%Y-%m-%d", unixSec)
end

-- Adds kWh used at `price` per kWh to the day `key`.
function M.add(days, key, kwh, price)
  local d = days[key]
  if not d then
    d = { kwh = 0, cost = 0 }
    days[key] = d
  end
  d.kwh = d.kwh + kwh
  d.cost = d.cost + kwh * (price or 0)
end

-- Keys of this week's days so far, Monday first. Noon steps keep DST changes from
-- skipping or repeating a day.
function M.weekKeys(unixSec)
  local t = os.date("*t", unixSec)
  local sinceMonday = (t.wday + 5) % 7 -- wday: 1 = Sunday
  local keys = {}
  for i = sinceMonday, 0, -1 do
    keys[#keys + 1] = os.date("%Y-%m-%d", os.time({ year = t.year, month = t.month, day = t.day - i, hour = 12 }))
  end
  return keys
end

local function sum(days, keys)
  local out = { kwh = 0, cost = 0 }
  for _, k in ipairs(keys) do
    local d = days[k]
    if d then
      out.kwh = out.kwh + d.kwh
      out.cost = out.cost + d.cost
    end
  end
  return out
end

-- Totals for today, this week (from Monday), this month and all time, plus the first
-- day on record (`since`, nil when empty).
function M.totals(days, unixSec)
  local today = M.dayKey(unixSec)
  local month = os.date("%Y-%m", unixSec)
  local monthKeys, allKeys, since = {}, {}, nil
  for k in pairs(days) do
    allKeys[#allKeys + 1] = k
    if k:sub(1, 7) == month then monthKeys[#monthKeys + 1] = k end
    if not since or k < since then since = k end
  end
  return {
    today = sum(days, { today }),
    week = sum(days, M.weekKeys(unixSec)),
    month = sum(days, monthKeys),
    all = sum(days, allKeys),
    since = since,
  }
end

return M
