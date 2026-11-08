# Dynamo

Your PC's power draw on the bar, and what it costs.

- **Bar widget:** a bolt and the estimated watts at the wall. The number changes colour
  above two thresholds you set. Hover for the breakdown and today's cost.
- **Panel** (click the widget): the estimate, a graph of the last 10 minutes or 24 hours
  (hover it to read a point), each component's share, and the energy and cost for today,
  this week, this month and all time.

## How the estimate works

Software can measure two parts of a PC:

| Part | Source |
| --- | --- |
| CPU package | RAPL (`/sys/class/powercap/intel-rapl:*/energy_uj`), or the `zenpower` hwmon driver where RAPL is root-only |
| Discrete GPU | `nvidia-smi` (one long-running process), or `amdgpu` hwmon |

Nothing reports the motherboard, RAM, drives, fans, RGB, USB devices or the power
supply's own losses. So Dynamo shows an estimate:

```
wall = (CPU + GPU + rest-of-PC allowance) / PSU efficiency
```

PSU efficiency comes from your PSU's rating and wattage: efficiency falls at low load, and
an idle desktop is often under 10% of its PSU's rating. The 20/50/100% load points are the
80 Plus minimums; below 20% the curve is an estimate from review measurements, because 80
Plus does not certify there. The total is an estimate, not a measurement. If you can
borrow a plug-in power meter, tune "Rest of the PC" until the two agree.

Energy is counted every second from the estimate. Time asleep or powered off is not
counted. Costs use the price in effect when the energy was used, so changing the price
does not rewrite past days.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| Electricity price per kWh | 0.245 | In your currency's main unit (0.245 = 24.5p) |
| Currency symbol | £ | Shown in front of costs |
| PSU efficiency rating | Gold | Bronze to Titanium, or a fixed efficiency |
| PSU efficiency (%) | 88 | Only with "Fixed efficiency" |
| PSU wattage (W) | 850 | Your PSU's rated output |
| Mains voltage | 230 V | 115 V for the US, Canada, Japan |
| Rest of the PC (W) | 40 | Allowance for everything without a sensor |
| Warning / high colour from (W) | 300 / 500 | 0 turns a threshold off |

## Data

Nothing leaves your machine. The ledger (kWh and cost per day) and the graph history are
kept in the plugin's data directory, `ledger.json`.

## Keybind

`noctalia msg plugin edward/dynamo:widget <output> click` opens the panel at the widget
on that output.
