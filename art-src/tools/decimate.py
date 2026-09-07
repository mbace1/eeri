# EERI — decimate a Meshy machine without changing what it looks like.
#
# WHY THIS EXISTS, and why it is Blender rather than the tool already in the
# toolchain. `assets/3d/` is 33 MB, and the eight big machines are ~2 MB each
# — the largest download cost left in the game by a wide margin. Only ~200 KB
# of each is texture. The rest is 30,000 triangles of geometry on a machine
# that stands maybe a third of a portrait screen tall.
#
# The obvious first move was `gltf-transform simplify`, which is already an
# approved part of this toolchain (CLAUDE.md §2's one dependency exception,
# used by godot/tools/sync-data.mjs) and which is exactly what cut the enemy
# rigs from 30k to 6.8k in v15.6x. On these files it does NOTHING:
#
#     dumptruck_v1.glb   31,779 tris   95,337 verts   0 indexed primitives
#     after `weld`       31,779 tris   95,052 verts   7 indexed primitives
#     after `simplify`   31,751 tris
#
# Ninety-five thousand vertices for thirty-two thousand triangles is 3.0 per
# triangle: **every triangle owns its own three vertices and shares none.**
# Meshy exports flat-shaded triangle soup. `weld` will only merge vertices
# that agree on EVERY attribute, and split normals mean no two ever do — so
# it recovered 285 vertices out of 95,337, meshoptimizer got an index buffer
# with no collapsible edges, and the file came back a fraction LARGER.
#
# Blender can do the thing gltf-transform will not: **merge by distance**,
# which welds on POSITION alone and throws the split normals away, and then
# decimate the surface that results, recomputing the normals afterwards.
#
# The split is a UV-seam artefact, NOT flat shading — these models carry
# AVERAGED normals on their split vertices, and the first version of this
# script assumed the opposite and made every machine faceted. The shading
# note further down records what the picture showed.
#
# This is the rule in the global notes working as intended: *Meshy is for a
# NEW object; Blender is for a WRONG one.* Re-generating these machines would
# cost real credits and would produce DIFFERENT machines. This repairs the
# ones the game already ships.
#
# WHAT IT MUST NOT BREAK — and each of these is asserted, not hoped for:
#
#  · **Node names.** `assets/manifest.json` carries a `paint` map per machine
#    keyed by node name (`house`, `boom`, `beacon`…), and `js/assets.js`
#    resolves it with `getObjectByName` and warns-then-skips on a miss. A
#    renamed node is a machine that silently keeps its Meshy texture instead
#    of its palette colour. Blender's importer will happily rename on
#    collision, so the script checks the set of names round-trips.
#  · **Overall size and pivots.** The seam places these by their own origin.
#  · **The silhouette.** Which a triangle count cannot tell you, so this
#    writes a turntable PNG and the change ends in a picture (per the global
#    Godot note: a gate certifies WORKS and cannot see LOOKS).
#
# WHAT WAS TRIED AND REJECTED, so nobody spends the afternoon again:
#
#  · **Flat shading.** Wrong on both counts — see the shading note below. It
#    faceted every cylinder AND made the file a third bigger.
#  · **Planar dissolve** (`DECIMATE` in DISSOLVE mode, 5°), which is normally
#    the right tool for boxy man-made objects because it merges coplanar
#    faces without moving a single vertex. On these it removed only 4–8% —
#    Meshy meshes have almost no genuinely coplanar faces — and the n-gons it
#    did make **tore the UVs**, so the checkpoint came back with its texture
#    smeared into streaks. Rejected on the picture, not on the number.
#  · **Ratio 0.35.** Cheapest of the credible options and it looked fine in a
#    three-across thumbnail. At full size the checkpoint's post had gone from
#    a cylinder to a creased column and the big flag's cloth had dents in it.
#    0.60 keeps the post round for about 70 KB more per piece, and the pieces
#    are seen at roughly this size on a phone, so it is the honest choice.
#
# Run:
#   B="/c/Users/Mikael/tools/blender/blender-4.5.13-windows-x64/blender.exe"
#   "$B" -b --python art-src/tools/decimate.py -- in.glb out.glb 0.60
#   node "$(npm root -g)/@gltf-transform/cli/bin/cli.js" quantize out.glb final.glb
#
# THE QUANTIZE STEP IS NOT OPTIONAL. Blender writes float32 positions; these
# models arrived 16-bit and the seam already handles that (godot/tools/
# sync-data.mjs dequantizes for Godot, which cannot read
# KHR_mesh_quantization). Skipping it hands back a file about 40% larger.
#
# The ratio is of the WELDED triangle count, not the original.

import math
import sys
import os

import bpy

# The angle above which an edge stays hard. See the shading note below.
SMOOTH_ANGLE = 60.0


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 3:
        print("usage: decimate.py -- <in.glb> <out.glb> <ratio> [merge_distance]")
        return 2
    src, dst, ratio = argv[0], argv[1], float(argv[2])
    merge = float(argv[3]) if len(argv) > 3 else 0.0005

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)

    before_names = sorted(o.name for o in bpy.data.objects)
    before_tris = 0
    before_verts = 0
    weld_verts = 0
    after_tris = 0

    # SHARED MESH DATA IS DECIMATED ONCE AND RE-SHARED. `flag_v1.glb` is three
    # nodes pointing at one mesh, and Blender refuses point blank to apply a
    # modifier to multi-user data ("Modifiers cannot be applied to multi-user
    # data"). The tempting fix — make every object single-user — would COPY
    # the geometry three times and hand back a bigger file than it was given,
    # which is the opposite of the errand. So each distinct mesh is processed
    # once and every object that shared it is pointed at the result.
    done: dict[str, object] = {}

    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            continue
        key = obj.data.name
        if key in done:
            obj.data = done[key]
            continue
        if obj.data.users > 1:
            obj.data = obj.data.copy()
        me = obj.data
        before_tris += sum(len(p.vertices) - 2 for p in me.polygons)
        before_verts += len(me.vertices)

        bpy.context.view_layer.objects.active = obj
        for o in bpy.context.selected_objects:
            o.select_set(False)
        obj.select_set(True)

        # WELD ON POSITION ALONE. This is the step gltf-transform cannot do:
        # it discards the split normals that made every triangle an island.
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=merge)
        bpy.ops.object.mode_set(mode="OBJECT")
        # VERTICES, not triangles — welding removes duplicate vertices and
        # leaves the triangle count alone, so counting triangles here would
        # report "no change" and hide the only step that made decimation
        # possible at all.
        weld_verts += len(me.vertices)

        # Collapse decimation, which is the one that keeps a silhouette.
        # `use_collapse_triangulate` keeps the result triangles rather than
        # letting it produce degenerate n-gons the exporter would re-split.
        mod = obj.modifiers.new(name="eeri_decimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)

        after_tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)

        # SHADING, and the first version of this script got it backwards.
        #
        # "Every triangle owns its own vertices" reads like flat shading, so
        # this originally forced flat and said in its header that flat "is
        # what it had". IT IS NOT. Meshy splits every vertex and then writes
        # AVERAGED normals onto the copies — the split is how it stores UV
        # seams, not a shading decision. A rendered comparison settled it in
        # one picture: `checkpoint_v1`'s post is a cylinder, flat shading
        # turned it into a faceted square column, and smooth shading kept it
        # round at the same triangle count.
        #
        # It is also SMALLER, which is the part worth remembering. Flat
        # shading forces the exporter to split every vertex again — back to
        # 3.0 per triangle — while smooth normals let it share them. On the
        # checkpoint: 500 KB flat against 366 KB smooth, same 4,151 triangles.
        # So the wrong choice cost a third of the file to look worse.
        #
        # 60° rather than "smooth everything": a genuinely hard edge — the
        # corner of a bucket, the lip of a track frame — stays hard, and
        # nothing this shallow-angled exists in these models by accident.
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SMOOTH_ANGLE))

        done[key] = obj.data

    after_names = sorted(o.name for o in bpy.data.objects)
    if before_names != after_names:
        lost = set(before_names) - set(after_names)
        gained = set(after_names) - set(before_names)
        print(f"FAIL: node names changed. lost={sorted(lost)} gained={sorted(gained)}")
        return 1

    bpy.ops.export_scene.gltf(
        filepath=dst,
        export_format="GLB",
        export_image_format="WEBP",
        export_apply=False,
        export_yup=True,
        use_selection=False,
        export_animations=True,
        export_skins=True,
        export_extras=True,
    )

    print(
        "DECIMATE %s: verts %d -> %d welded (%.1f per tri -> %.1f); "
        "tris %d -> %d (%.0f%%); %d KB -> %d KB; %d nodes preserved"
        % (
            os.path.basename(src), before_verts, weld_verts,
            before_verts / max(1, before_tris), weld_verts / max(1, before_tris),
            before_tris, after_tris, 100.0 * after_tris / max(1, before_tris),
            os.path.getsize(src) // 1024, os.path.getsize(dst) // 1024,
            len(after_names),
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
