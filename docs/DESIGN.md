# Dynamo design

## Goal

Show a desktop PC's total power draw on the noctalia bar, by component, with the energy
used and its cost over time. No hardware meter: everything comes from sensors the
kernel and GPU driver already expose, plus an explicit estimate for the rest.

## Files

```
dynamo/
  plugin.toml
  service.luau          the only entry that reads sensors, settings or the ledger file; wiring only
  service-config.luau   plugin settings as one table, with defaults
  service-store.luau    ledger.json load/save (temp file + rename; unparsable file kept as .bad)
  sensor-cpu.luau       RAPL package energy counters, or zenpower hwmon
  sensor-gpu.luau       nvidia-smi stream, amdgpu hwmon (discrete cards only)
  efficiency.luau       PSU efficiency curves and the estimate (pure)
  ledger.luau           kWh and cost per day, totals (pure)
  history.luau          bucketed ring for the graph (pure)
  format.luau           watts, kWh, money, colours (pure)
  widget.luau           bar widget
  panel.luau            panel shell: state, view state, lifecycle
  panel-graph.luau      history graph with range tabs and hover readout
  panel-sections.luau   header, components, energy and cost
```

Pure modules are plain Lua so `lua tests/pure.lua` runs them without noctalia.

## Sensors

| Data | How | When |
| --- | --- | --- |
| CPU | RAPL `package-*` zones under `/sys/class/powercap`: energy delta over time between reads, wrap handled with `max_energy_range_uj`. Fallback: `zenpower` hwmon `power1_input` | every second |
| NVIDIA GPU | `nvidia-smi --query-gpu=index,power.draw -lms 1000` through `runStream`, one line per card per second; readings older than 5 s are dropped | streamed |
| AMD GPU | hwmon `amdgpu` `power1_average` or `power1_input`, only where `power1_cap` exists | every second |

RAPL and zenpower report the same quantity (zenpower labels it `RAPL_P_Package`), so only
one is used. An integrated Radeon has no `power1_cap`: its reading is inside the CPU
package, or on an APU is the whole package, so counting it would double count.

`runStream` has no close event: the command ends with `echo dynamo-gpu-exited`, and the
service restarts the stream at most every 30 s. Noctalia kills it on hot reload.

For the first 5 s the service waits until every sensor it found has a reading (RAPL needs
two), so the bar never shows a total without the GPU.

## The estimate

`wall = (cpu + gpu + rest) / efficiency(load)`, with `load = dc / psu_watts`. Curves are
in `efficiency.luau`: 80 Plus minimums at 20/50/100% (230 V EU internal and 115 V
internal), and estimated 2/5/10% points shaped on Gold review data (Corsair RM1000x: about
88% at 10%, 80% at 5%). Linear between points, flat outside them.

## State contract

All times are epoch ms (`noctalia.nowMs()`).

| Key | Shape | Published |
| --- | --- | --- |
| `power` | `{ at, wall, dc, loss, efficiency, load, cpu?, gpu?, rest, cpuSource?, gpuSource? }` | every second |
| `energy` | `{ today, week, month, all = { kwh, cost }, since?, perHour }` | every second |
| `history` | `{ recent = { values, step }, day = { values, step } }`, newest last | when a bucket closes (2 s / 2 min) |
| `settings` | `{ currency, price, warn, high }` | at start and on settings change |

`cpu`/`gpu` are nil when there is no sensor; the estimate then counts them as 0 and the
panel says so.

## Persistence

`<data>/ledger.json` holds the days (`{ "YYYY-MM-DD": { kwh, cost } }`, local time) and
both rings including their open bucket, so a reload continues the bucket and the time
the PC was off shows as zeros. Saved every 60 s and on exit; at most a minute of energy
is lost to a crash.

## Decisions

- **Estimate, not just CPU + GPU.** The measured parts alone read 40-80 W under the wall.
  The allowance and PSU curve are visible in the panel, so the estimate is honest.
- **Cost stored per day at the time's price.** A price change applies forward only.
- **Energy counted only while ticks arrive.** A gap over 10 s (suspend) counts nothing.
