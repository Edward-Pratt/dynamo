-- History ring: averages samples into fixed time buckets and keeps the newest `size`.
-- Pure (plain Lua, tested by tests/pure.lua). Missed buckets (the PC asleep or off) are
-- filled with 0, so the graph shows the gap where it happened.

local M = {}

function M.new(size, stepMs)
  return { size = size, step = stepMs, values = {}, start = nil, sum = 0, n = 0 }
end

local function append(ring, v)
  local values = ring.values
  values[#values + 1] = v
  while #values > ring.size do table.remove(values, 1) end
end

-- Adds a sample taken at nowMs. Returns true when a bucket closed (values changed).
function M.push(ring, nowMs, value)
  if not ring.start then
    ring.start, ring.sum, ring.n = nowMs, value, 1
    return false
  end
  local elapsed = nowMs - ring.start
  if elapsed < ring.step then
    ring.sum, ring.n = ring.sum + value, ring.n + 1
    return false
  end
  append(ring, ring.n > 0 and ring.sum / ring.n or 0)
  local buckets = math.floor(elapsed / ring.step)
  local missed = buckets - 1
  if missed >= ring.size then
    missed, ring.start = ring.size, nowMs
  else
    ring.start = ring.start + buckets * ring.step
  end
  for _ = 1, missed do append(ring, 0) end
  ring.sum, ring.n = value, 1
  return true
end

-- Restores values saved by a previous run (newest last), keeping at most `size`.
function M.restore(ring, values)
  if type(values) ~= "table" then return end
  for _, v in ipairs(values) do
    if type(v) == "number" then append(ring, v) end
  end
end

return M
