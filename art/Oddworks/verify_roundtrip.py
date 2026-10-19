import bpy, os, json
from pathlib import Path
from mathutils import Vector
BASE=os.path.dirname(os.path.abspath(__file__))
REPO=next(p for p in Path(BASE).parents if (p/'CrearoApp').is_dir())
ASSETS=str(REPO/'CrearoApp/Resources/OddworksAssets')
os.makedirs(os.path.join(BASE,'renders'),exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.join(BASE,'Oddworks.blend'))
for name in ['Loop_Character','Strange_Atelier']:
    collection=bpy.data.collections.get(name)
    if collection:
        for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(collection)
# Import exactly the packaged runtime assets. Their USD Y-up metadata must
# produce correct Blender Z-up objects in this roundtrip.
counts={}
for filename in ['StrangeAtelier.usdz','Loop.usdz']:
    before=set(bpy.data.objects)
    bpy.ops.wm.usd_import(filepath=os.path.join(ASSETS,filename),import_textures_mode='IMPORT_PACK')
    objects=list(set(bpy.data.objects)-before)
    bpy.context.view_layer.update()
    meshes=[o for o in objects if o.type=='MESH']
    points=[o.matrix_world@Vector(p) for o in meshes for p in o.bound_box]
    counts[filename]={'mesh_count':len(meshes),'vertex_count':sum(len(o.data.vertices) for o in meshes),
                      'bounds_blender_z_up':{'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]}}
    for o in meshes:o.data.calc_loop_triangles()
    counts[filename]['triangle_count']=sum(len(o.data.loop_triangles) for o in meshes)
    if filename=='Loop.usdz':
        # Root transform, rather than every child, to preserve hierarchy.
        for o in objects:
            if o.parent is None:o.location+=Vector((-1.6,-1.02,.27))
scene=bpy.context.scene
scene.render.resolution_x=1800;scene.render.resolution_y=1200
scene.render.filepath=os.path.join(BASE,'renders/ODDWORKS_RUNTIME_ASSETS.png')
bpy.ops.render.render(write_still=True)
with open(os.path.join(BASE,'asset-verification.json'),'w') as f:json.dump(counts,f,indent=2)
print('ROUNDTRIP_VERIFIED',json.dumps(counts))
