"""Shared Starlark helpers for HighTide design definitions."""

load("@bazel-orfs//:openroad.bzl", "orfs_flow", "orfs_run")

# PDK label mapping per platform
PDKS = {
    "asap7": "@orfs//flow:asap7",
    "nangate45": "@orfs//flow:nangate45",
    "sky130hd": "@orfs//flow:sky130hd",
}

def _gallery_image(name, src):
    """Render a final-stage screenshot from a routed ODB.

    Produces <name>.png via xvfb-run + OpenROAD GUI.
    """
    orfs_run(
        name = name,
        src = src,
        outs = [name + ".png"],
        arguments = {
            "GALLERY_IMAGE": "$(location :" + name + ".png)",
            "OR_ARGS": "-gui",
        },
        extra_args = "OPENROAD_CMD='xvfb-run -a $(OPENROAD_EXE) -exit $(OPENROAD_ARGS)'",
        script = "//tools/gallery:final_image.tcl",
    )

def hightide_design(name, platform, verilog_files, top = None, arguments = {}, sources = {}, **kwargs):
    """Wraps orfs_flow with HighTide defaults.

    Automatically sets GDS_ALLOW_EMPTY for FakeRAM, maps platform
    names to PDK labels, and emits a <name>_gallery target rendering
    a final-stage screenshot from the routed ODB.

    Args:
        name: Base name for Bazel targets.
        platform: Target platform (asap7, nangate45, sky130hd).
        verilog_files: Verilog source file labels.
        top: Verilog top-level module name. Defaults to name.
        arguments: ORFS flow arguments dict.
        sources: ORFS source file mappings (SDC_FILE, ADDITIONAL_LEFS, etc.).
        **kwargs: Additional arguments passed to orfs_flow.
    """
    merged_arguments = dict(arguments)
    merged_arguments.setdefault("GDS_ALLOW_EMPTY", "fakeram.*")

    flow_kwargs = dict(
        name = name,
        verilog_files = verilog_files,
        arguments = merged_arguments,
        sources = sources,
        pdk = PDKS[platform],
    )
    if top:
        flow_kwargs["top"] = top
    flow_kwargs.update(kwargs)

    orfs_flow(**flow_kwargs)

    _gallery_image(
        name = name + "_gallery",
        src = ":" + name + "_final",
    )
