# Dynamo

A [noctalia](https://github.com/noctalia-dev) plugin that puts your PC's power draw on
the bar: an estimate of the watts at the wall, a breakdown by component, a history graph,
and the energy used and what it cost over time. The plugin's own
[README](dynamo/README.md) covers what it shows, how the estimate works and its settings.

## Install

Until Dynamo is in the community catalog, install it from this repository as a `path`
source:

```sh
git clone https://github.com/Edward-Pratt/dynamo ~/src/dynamo
noctalia msg plugins source add dynamo path ~/src/dynamo
noctalia msg plugins enable edward/dynamo
```

Then add it to your bar from the Bar Widgets settings with **Add Widget**. Set your
electricity price and your PSU under Dynamo's entry in the Plugins settings.

### Updating

Pull the new version, then turn the plugin off and on so Noctalia rereads its manifest:

```sh
git -C ~/src/dynamo pull
noctalia msg plugins disable edward/dynamo && noctalia msg plugins enable edward/dynamo
```

`main` is the development branch. To stay on releases, check out the latest tag instead
of pulling. [Releases](https://github.com/Edward-Pratt/dynamo/releases) lists them.

## Layout

```
dynamo/      the plugin, in the community-plugins layout (dir name = id suffix)
docs/        DESIGN.md: data sources, the estimate, state contract, persistence
tests/       pure.lua, tests for the pure modules
```

## Development

With the repo added as a `path` source, edits to `.luau` files hot-reload. Changes to
`plugin.toml` need the plugin disabled and enabled again.

For editor type checking, put `noctalia.d.luau` from
[noctalia-dev/official-plugins](https://github.com/noctalia-dev/official-plugins) at the
repo root. It is gitignored.

```sh
lua tests/pure.lua             # efficiency curve, ledger, history ring, formatting
noctalia plugins lint dynamo   # settings against code
```

### Publishing an update

A stable version is a `vX.Y.Z` tag: tag it with
[herald](https://github.com/Edward-Pratt/herald)'s `herald release patch` (or `minor`,
`major`). It sets `version` in `dynamo/plugin.toml` through `.github/bump-version` and
opens a pull request; once that's merged, the same command tags it, and
`.github/workflows/release.yml` publishes the GitHub release.
