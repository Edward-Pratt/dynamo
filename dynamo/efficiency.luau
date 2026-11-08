-- PSU efficiency: how many wall watts a given DC load costs. Pure (plain Lua, tested by
-- tests/pure.lua).
--
-- Efficiency depends on the load as a share of the PSU's rating, so a 1000 W unit at
-- 80 W (8%) is far less efficient than at 500 W. The 20/50/100% points are the 80 Plus
-- minimums (115 V internal and 230 V EU internal). 80 Plus certifies nothing below 20%
-- (Titanium alone has a 10% point), so the 2/5/10% points are estimates shaped on review
-- measurements of Gold units such as the Corsair RM1000x (about 88% at 10% load and 80%
-- at 5%). Below 2% the 2% value holds; between points the curve is linear.

local M = {}

M.LOADS = { 0.02, 0.05, 0.10, 0.20, 0.50, 1.00 }

M.CURVES = {
  ["230"] = {
    bronze = { 62, 74, 81, 85, 88, 85 },
    silver = { 65, 77, 84, 87, 90, 87 },
    gold = { 70, 81, 87, 90, 92, 89 },
    platinum = { 72, 83, 89, 92, 94, 90 },
    titanium = { 75, 85, 90, 94, 96, 94 },
  },
  ["115"] = {
    bronze = { 60, 71, 78, 82, 85, 82 },
    silver = { 63, 74, 81, 85, 88, 85 },
    gold = { 67, 78, 85, 87, 90, 87 },
    platinum = { 70, 81, 87, 90, 92, 89 },
    titanium = { 73, 84, 90, 92, 94, 90 },
  },
}

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- Efficiency (0..1) at `load` (share of the PSU's rating) on a curve of percentages.
function M.onCurve(curve, load)
  local loads = M.LOADS
  if load <= loads[1] then return curve[1] / 100 end
  for i = 2, #loads do
    if load <= loads[i] then
      local t = (load - loads[i - 1]) / (loads[i] - loads[i - 1])
      return (curve[i - 1] + t * (curve[i] - curve[i - 1])) / 100
    end
  end
  return curve[#curve] / 100
end

-- Efficiency (0..1) for a DC load. psu: { rating, watts, mains, fixedPercent }.
-- rating "fixed" uses fixedPercent everywhere; an unknown rating or mains falls back
-- to Gold at 230 V.
function M.at(dcWatts, psu)
  if psu.rating == "fixed" then return clamp((psu.fixedPercent or 88) / 100, 0.5, 0.99) end
  local curves = M.CURVES[psu.mains] or M.CURVES["230"]
  local curve = curves[psu.rating] or curves.gold
  local watts = (psu.watts and psu.watts > 0) and psu.watts or 850
  return M.onCurve(curve, dcWatts / watts)
end

-- The estimate: component watts plus the fixed allowance for the rest of the PC,
-- divided by PSU efficiency. cpu and gpu may be nil (no sensor); they then count as 0.
function M.estimate(cpu, gpu, rest, psu)
  local dc = (cpu or 0) + (gpu or 0) + (rest or 0)
  local eff = M.at(dc, psu)
  local wall = dc / eff
  local watts = (psu.watts and psu.watts > 0) and psu.watts or 850
  return { dc = dc, wall = wall, loss = wall - dc, efficiency = eff, load = dc / watts }
end

return M
