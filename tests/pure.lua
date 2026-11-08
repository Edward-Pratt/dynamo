-- Tests for the pure modules: `lua tests/pure.lua` from the repo root.
local function load(name) return dofile("dynamo/" .. name .. ".luau") end
local eff = load("efficiency")
local ledger = load("ledger")
local history = load("history")
local fmt = load("format")

local failures = 0
local function eq(got, want, what)
  if got ~= want then
    failures = failures + 1
    print(("FAIL %s: got %s, want %s"):format(what, tostring(got), tostring(want)))
  end
end
local function near(got, want, what)
  if math.abs(got - want) > 1e-6 then
    failures = failures + 1
    print(("FAIL %s: got %.6f, want %.6f"):format(what, got, want))
  end
end

-- Efficiency curve
local gold230 = { rating = "gold", watts = 1000, mains = "230" }
near(eff.at(200, gold230), 0.90, "gold 230V at 20%")
near(eff.at(500, gold230), 0.92, "gold 230V at 50%")
near(eff.at(1000, gold230), 0.89, "gold 230V at 100%")
near(eff.at(10, gold230), 0.70, "below 2% holds the 2% value")
near(eff.at(2000, gold230), 0.89, "above 100% holds the 100% value")
near(eff.at(75, gold230), 0.84, "halfway between 5% and 10%")
near(eff.at(500, { rating = "gold", watts = 1000, mains = "115" }), 0.90, "gold 115V at 50%")
near(eff.at(500, { rating = "fixed", fixedPercent = 85 }), 0.85, "fixed percent")
near(eff.at(500, { rating = "fixed", fixedPercent = 20 }), 0.50, "fixed percent clamped")
near(eff.at(500, { rating = "nonsense", watts = 1000, mains = "nonsense" }), 0.92, "unknown falls back to gold 230V")

local e = eff.estimate(30, 12, 40, gold230)
near(e.dc, 82, "dc sums components")
near(e.load, 0.082, "load share")
near(e.wall, 82 / eff.at(82, gold230), "wall = dc / efficiency")
near(e.loss, e.wall - 82, "loss")
near(eff.estimate(nil, nil, 40, gold230).dc, 40, "missing sensors count as 0")

-- Ledger
local days = {}
ledger.add(days, "2026-11-08", 1.0, 0.25)
ledger.add(days, "2026-11-08", 0.5, 0.30)
near(days["2026-11-08"].kwh, 1.5, "kWh adds up")
near(days["2026-11-08"].cost, 0.40, "cost at the price in effect")
ledger.add(days, "2026-11-03", 2.0, 0.25) -- Monday of the same week
ledger.add(days, "2026-11-02", 1.0, 0.25) -- Sunday before
ledger.add(days, "2026-10-31", 4.0, 0.25) -- last month

-- Sunday 2026-11-08 at noon local time.
local now = os.time({ year = 2026, month = 11, day = 8, hour = 12 })
local wk = ledger.weekKeys(now)
eq(#wk, 7, "week on Sunday has 7 days")
eq(wk[1], "2026-11-02", "week starts Monday")
eq(wk[7], "2026-11-08", "week ends today")
local monday = os.time({ year = 2026, month = 11, day = 2, hour = 9 })
eq(#ledger.weekKeys(monday), 1, "week on Monday has 1 day")

local t = ledger.totals(days, now)
near(t.today.kwh, 1.5, "today kWh")
near(t.week.kwh, 4.5, "week kWh: today + Monday + Tuesday")
near(t.month.kwh, 4.5, "month kWh excludes October")
near(t.all.kwh, 8.5, "all-time kWh")
near(t.all.cost, 0.40 + 7 * 0.25, "all-time cost")
eq(t.since, "2026-10-31", "first day on record")
eq(ledger.totals({}, now).since, nil, "empty ledger has no since")

-- History ring
local r = history.new(3, 1000)
eq(history.push(r, 0, 100), false, "first sample opens a bucket")
eq(history.push(r, 500, 200), false, "same bucket")
eq(history.push(r, 1000, 50), true, "bucket closes")
eq(#r.values, 1, "one bucket")
near(r.values[1], 150, "bucket average")
history.push(r, 4500, 10) -- buckets at 1000 (50), then 2000 and 3000 missed
eq(#r.values, 3, "ring keeps size")
near(r.values[1], 50, "closed bucket")
eq(r.values[2], 0, "missed bucket is 0")
eq(r.values[3], 0, "second missed bucket is 0")
eq(r.start, 4000, "next bucket aligned to the step")
history.push(r, 1e9, 5) -- far future: never more than size zeros, start jumps to now
eq(#r.values, 3, "long gap capped")
eq(r.start, 1e9, "long gap restarts the bucket at now")
local r2 = history.new(2, 1000)
history.restore(r2, { 1, "x", 2, 3 })
eq(#r2.values, 2, "restore keeps size")
eq(r2.values[2], 3, "restore keeps newest")

-- Format
eq(fmt.watts(244.6), "245 W", "watts rounds")
eq(fmt.watts(nil), "n/a", "no sensor")
eq(fmt.kwh(1.234), "1.23 kWh", "kWh")
eq(fmt.kwh(12.34), "12.3 kWh", "kWh large")
eq(fmt.kwh(0.0042), "4 Wh", "under 1 kWh shows Wh")
eq(fmt.kwh(0.9996), "1000 Wh", "Wh rounding")
eq(fmt.money(1.5, "£"), "£1.50", "money")
eq(fmt.money(0.024, "£"), "£0.024", "small money keeps a third decimal")
eq(fmt.money(0, "£"), "£0.00", "zero money")
eq(fmt.percent(0.847), "85%", "percent")
near(fmt.parsePrice("0.245"), 0.245, "parse plain price")
near(fmt.parsePrice(" £0.245 "), 0.245, "parse with symbol and spaces")
near(fmt.parsePrice("0,245"), 0.245, "parse comma decimal")
near(fmt.parsePrice("24.5p"), 0.245, "parse pence")
near(fmt.parsePrice("30c"), 0.30, "parse cents")
near(fmt.parsePrice(".25"), 0.25, "parse leading dot")
near(fmt.parsePrice("1"), 1, "parse whole number")
eq(fmt.parsePrice("abc"), nil, "no number")
eq(fmt.parsePrice(""), nil, "empty")
eq(fmt.price(0.245, "£"), "£0.245", "price keeps its decimals")
eq(fmt.price(0.3, "£"), "£0.30", "price at least 2 decimals")
eq(fmt.price(0.24567, "£"), "£0.2457", "price at most 4 decimals")
eq(fmt.price(2, "$"), "$2.00", "whole price")
eq(fmt.day("2026-10-31"), "31 " .. os.date("%b", os.time({ year = 2026, month = 10, day = 31, hour = 12 })), "day label")
eq(fmt.day("2026-11-08"):sub(1, 2), "8 ", "day label drops the leading zero")
eq(fmt.day("junk"), "junk", "bad key unchanged")
eq(fmt.loadRole(100, 300, 500), "on_surface", "under warn")
eq(fmt.loadRole(300, 300, 500), "tertiary", "warn")
eq(fmt.loadRole(600, 300, 500), "error", "high")
eq(fmt.loadRole(600, 0, 0), "on_surface", "0 turns the thresholds off")
eq(fmt.loadRole(600, 300, 0), "tertiary", "high off, warn on")

if failures > 0 then
  print(failures .. " failure(s)")
  os.exit(1)
end
print("all tests passed")
