--!nonstrict
-- Plugin settings as one table, with the manifest defaults. Read by the service only;
-- the surfaces get what they show through the `settings` state key.

local M = {}

local function get(key, fallback)
  local v = noctalia.getConfig(key)
  if v == nil then return fallback end
  return v
end

local function num(key, fallback)
  return tonumber(get(key, fallback)) or fallback
end

function M.read()
  return {
    price = math.max(0, num("price_per_kwh", 0.245)),
    currency = tostring(get("currency", "£")),
    rest = math.max(0, num("rest_watts", 40)),
    warn = num("warn_watts", 300),
    high = num("high_watts", 500),
    psu = {
      rating = tostring(get("psu_rating", "gold")),
      watts = num("psu_watts", 850),
      mains = tostring(get("mains", "230")),
      fixedPercent = num("psu_efficiency", 88),
    },
  }
end

return M
