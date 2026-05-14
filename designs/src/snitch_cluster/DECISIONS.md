# Snitch Cluster

## ⚠ Reduced cluster (not canonical benchmark)

This HighTide build of `snitch_cluster` is **not** the upstream-default 8-core /
128 KB TCDM cluster — it is a half-size variant tuned to close on asap7 within
sane runtime/area on the Nautilus build cluster.

Config: `designs/src/snitch_cluster/dev/cluster_cfg.json` (overrides the
upstream `repo/cfg/default.json` that `setup.sh` would otherwise pick).

| Parameter | Upstream default | HighTide build |
|---|---|---|
| Compute cores | 8 | **4** |
| DMA core | 1 | 1 |
| `NrCores` | 9 | **5** |
| TCDM size | 128 KB | **64 KB** |
| TCDM banks | 32 | **16** |
| ICache (per hive) | 16 KB | 16 KB (unchanged) |
| Zero memory | 64 KB | 64 KB (unchanged) |

### Why

Full-size snitch_cluster on asap7 did not converge in detail-route at
DIE 1500x1500 (>30 h stuck) and was slow even at DIE 2000x2000. Diagnosis
(`/debug-design`) traced this to local-density hot spots around the 70+
`fakeram7_256x256` TCDM macro pin clusters — top-1% routing congestion at 0.98
even with 17% core utilization. The shared/sram-repartition skill flagged this
as a "split or merge memory" candidate, but on asap7 neither direction was a
clean win:

- **Split:** more macros → would worsen the DPL-0036 fix already in place
  (commits `3586c3e5`, `6d1f8fa8`).
- **Merge:** `256x256` already the widest practical bank.

The remaining lever, per the skill's "Last resort: shrink the memory" section,
is reducing the cluster itself. Halving cores + TCDM cuts the macro count by
~half and the routing graph proportionally — enough to bring runtime back to
reasonable territory.

### Implication for results comparison

Numbers from this build (Fmax, area, slack) **must not** be compared against
full-size snitch_cluster numbers from other repos or upstream papers — it is a
different design. The webpage results page should mark this row "reduced" so
consumers don't conflate them.

## asap7

### Flow workarounds (all still apply with the reduced cluster)

- **`DETAIL_PLACEMENT_ARGS = -max_displacement {2000 400}`** — widen diamond
  search for the 3_5 detail-placement step. Default ±500 sites can't legalize
  a few resizer-inserted buffers near TCDM macros (DPL-0036). Commit
  `3586c3e5`. See CLAUDE.md workarounds table.

- **`PRE_CTS_TCL = pre_cts.tcl`** — `cts.tcl` builds its own `dpl_args` and
  ignores `DETAIL_PLACEMENT_ARGS`. The hook wraps `detailed_placement` so the
  CTS-internal call also gets `-max_displacement {2000 400}`, fixing DPL-0036
  on `clkbuf_leaf_*_clk_i`. Commit `6d1f8fa8`.

- **`SKIP_INCREMENTAL_REPAIR = 1`** — post-GRT `repair_timing` does not
  converge on the RTL-bounded paths (WNS stuck, buffers keep being inserted
  without making progress). Same pattern as `litedram`. Commit `4a03d5a0`.

- **`DIE_AREA = 0 0 2000 2000`** (vs `1500x1500`) — at 1500 detail-route never
  finished. Commit `24b02adc`. Reduced cluster may not need the bigger die,
  but keeping it for now to isolate the reduction-vs-die variables.

- **`MACRO_PLACE_HALO = 8 8`** (vs `2 2`) — pushes std cells off macro pin
  clusters to relieve top-1% local routing congestion. Commit `cbd698a4`.

### k8s resources

- `mem_lim=192Gi` — full-size cluster OOMKilled at the default 128 GiB during
  5_1_grt (commit `120b765f`). Reduced cluster may live within 128 GiB; revisit
  after a clean run.
