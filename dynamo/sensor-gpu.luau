--!nonstrict
-- Discrete GPU board power. NVIDIA: one long-running `nvidia-smi -lms` stream (one
-- process for the plugin's life, instead of one per sample); Noctalia kills it on hot
-- reload. AMD: hwmon `amdgpu` power1_average or power1_input. Only AMD cards with a
-- power cap (power1_cap) count: integrated Radeons have none, and their reading is
-- already inside the CPU package (or is the whole APU).

local M = {}

local SENTINEL = "dynamo-gpu-exited"
local NVIDIA_CMD = "nvidia-smi --query-gpu=index,power.draw --format=csv,noheader,nounits -lms 1000 </dev/null; echo "
  .. SENTINEL
local RESTART_MS = 30000
local STALE_MS = 5000
local HWMON = "/sys/class/hwmon"

local nvidia = false
local streaming = false
local lastStart = -math.huge
local cards = {} -- NVIDIA index -> { watts, at }
local amdPaths = {}

local function readNumber(path)
  local s = noctalia.readFile(path)
  return s and tonumber(noctalia.string.trim(s))
end

local function findAmd()
  amdPaths = {}
  for _, n in ipairs(noctalia.listDir(HWMON) or {}) do
    local dir = HWMON .. "/" .. n
    local name = noctalia.string.trim(noctalia.readFile(dir .. "/name") or "")
    if name == "amdgpu" and noctalia.fileExists(dir .. "/power1_cap") then
      for _, f in ipairs({ "power1_average", "power1_input" }) do
        if readNumber(dir .. "/" .. f) then
          amdPaths[#amdPaths + 1] = dir .. "/" .. f
          break
        end
      end
    end
  end
end

local function onLine(line)
  if line == SENTINEL then
    streaming = false
    return
  end
  -- "0, 11.81"; a card without a power reading says "[N/A]" and is skipped.
  local index, watts = string.match(line, "^%s*(%d+)%s*,%s*([%d%.]+)")
  if index then cards[index] = { watts = tonumber(watts), at = noctalia.nowMs() } end
end

-- Starts (or restarts, at most every 30 s) the NVIDIA stream when it is not running.
function M.ensure()
  if not nvidia or streaming then return end
  local now = noctalia.nowMs()
  if now - lastStart < RESTART_MS then return end
  lastStart = now
  streaming = noctalia.runStream(NVIDIA_CMD, onLine)
end

function M.init()
  nvidia = noctalia.commandExists("nvidia-smi")
  findAmd()
  M.ensure()
end

-- "nvidia", "amdgpu", both joined with "+", or nil when there is no discrete GPU sensor.
function M.source()
  local parts = {}
  if nvidia then parts[#parts + 1] = "nvidia-smi" end
  if #amdPaths > 0 then parts[#parts + 1] = "amdgpu" end
  return #parts > 0 and table.concat(parts, "+") or nil
end

-- Watts summed over every card, or nil when no card has a fresh reading.
function M.read(nowMs)
  local total, any = 0, false
  for _, c in pairs(cards) do
    if nowMs - c.at <= STALE_MS then
      total, any = total + c.watts, true
    end
  end
  for _, p in ipairs(amdPaths) do
    local uw = readNumber(p)
    if uw then total, any = total + uw / 1e6, true end
  end
  return any and total or nil
end

return M
