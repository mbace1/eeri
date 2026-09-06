"""Measure every clip's STANDING HEIGHT on a rig, in Blender.

    blender -b --python art-src/tools/clipstance.py -- assets/3d/eeri_v5.glb

Why this exists. The owner reported the kid "gets like 15% bigger" when he
stops running, and it took three goes to answer honestly:

  1. A single-frame measurement said 15%, then 8% after a runtime fix. Both
     numbers were noise -- a run cycle's head height swings 6% within the
     stride, so one frame can say almost anything. THIS is the lesson: sample
     a whole cycle and take the mean.
  2. The cause is not a bug in the game. Every clip was posed by a different
     hand and their standing heights disagree, by a LOT. Measured on
     eeri_v5.glb, head height above the root, mean over each cycle, against
     `run`:

        climboff +70.6%  stomp +28.6%  climb +22.1%  climbon +18.0%
        idle     +16.2%  talk +13.3%   lookaround +9.9%  confused +8.7%
        idle2     +6.4%  hurt +5.7%    teeter +4.9%  jump +4.6%
        walk      +1.3%  run 0.0%      sit -18.0%

     `walk` and `run` agree to a tenth of a percent -- they ship together,
     free, with a Meshy rig, from one author. Everything bought separately
     disagrees.
  3. Bending the knees in Blender to crouch `idle` into `run`'s stance does
     NOT work, and the measurement says why: with the hips keyed, bending the
     knees lifts the FEET (0.049 -> 0.065 at 12 degrees) and leaves the head
     exactly where it was. Matching by geometry needs a ~58 degree squat,
     which is a different pose rather than the same one lower.

So the runtime normalisation in js/kid.js (`holdHeight`) is the right answer
after all, and measured over a full cycle it leaves 0.8% -- not the 8% a
single frame claimed. Keep this script: the next rig, or the next bought
clip, can be checked against the table above before it ships.
"""
import bpy, sys
p = sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=p)
arm = [o for o in bpy.data.objects if o.type=='ARMATURE'][0]
if not arm.animation_data: arm.animation_data_create()
rows=[]
for a in bpy.data.actions:
    arm.animation_data.action = a
    f0,f1 = int(a.frame_range[0]), int(a.frame_range[1])
    hs=[]; fs=[]
    for i in range(13):
        f = f0 + (f1-f0)*i/12
        bpy.context.scene.frame_set(int(f)); bpy.context.view_layer.update()
        hs.append((arm.matrix_world @ arm.pose.bones['Head'].head).z)
        fs.append(min((arm.matrix_world @ arm.pose.bones[n].head).z for n in ['LeftFoot','RightFoot']))
    rows.append((a.name, sum(hs)/len(hs), min(fs)))
base = dict((n,(h,f)) for n,h,f in rows)
run_h = base['run'][0]
print("CLIP        head(mean)   foot(min)   head vs run")
for n,h,f in sorted(rows, key=lambda r:-r[1]):
    print("%-11s %8.4f   %8.4f   %+7.1f%%" % (n, h, f, (h/run_h-1)*100))
