# Image Generation Reference

Shared reference for generating layout images from OpenROAD ODB files. Used by debug-design and optimize-ppa skills.

## Prerequisites

**Extract the Docker image name:**
```bash
DOCKER_IMAGE=$(grep -oP 'image\s*=\s*"\K[^"]+' MODULE.bazel)
```

**Locate the ODB file** for the stage to visualize (check `bazel-bin/designs/<platform>/<design>/` or `artifacts/<platform>/<design>/`):
- Floorplan: `results/*/base/2_floorplan.odb`
- Placement: `results/*/base/3_place.odb`
- CTS: `results/*/base/4_cts.odb`
- Routing: `results/*/base/5_route.odb`
- Final: `results/*/base/6_final.odb`

## Running image generation

Write a Tcl script to a temp file, then execute inside Docker with Xvfb (virtual framebuffer since Docker has no X11 display):

```bash
cat > /tmp/ht_save_image.tcl << 'TCLEOF'
read_db $::env(ODB_FILE)
# <optional heatmap setup — see variants below>
save_image -width 2048 $::env(OUTPUT_IMAGE)
TCLEOF

cd OpenROAD-flow-scripts
docker run --rm \
  -u $(id -u):$(id -g) \
  -v $(pwd)/flow:/OpenROAD-flow-scripts/flow \
  -v $(pwd)/..:/OpenROAD-flow-scripts/UCSC_ML_suite \
  -v /tmp:/tmp \
  -w /OpenROAD-flow-scripts/UCSC_ML_suite \
  -e ODB_FILE=<path-to-odb-relative-to-workdir> \
  -e OUTPUT_IMAGE=/tmp/design_layout.webp \
  -e DISPLAY=:99 \
  ${DOCKER_IMAGE} \
  bash -c "Xvfb :99 -screen 0 2048x2048x24 &>/dev/null & sleep 1 && openroad -no_splash -gui /tmp/ht_save_image.tcl"
```

## Heatmap Tcl variants

Replace the Tcl script content above with these for specific visualizations.

### Routing congestion
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/Routing" visible true
gui::set_heatmap Routing rebuild 1
gui::set_heatmap Routing ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

### Placement density
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/Placement" visible true
gui::set_heatmap Placement rebuild 1
gui::set_heatmap Placement ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

### RUDY (routing demand estimation)
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/RUDY" visible true
gui::set_heatmap RUDY rebuild 1
gui::set_heatmap RUDY ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

### IR drop
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/IR Drop" visible true
gui::set_heatmap IRDrop rebuild 1
gui::set_heatmap IRDrop ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

After generating images, use the Read tool to display them to the user and analyze what the image shows — hotspots, macro placement issues, pin congestion areas, power routing gaps, etc.
