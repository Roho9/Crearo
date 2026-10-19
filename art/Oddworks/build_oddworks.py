"""Original Oddworks geometry + UV-painted PBR assets for Crearo.
Verified with Blender 3.6.23 LTS: blender --background --gpu-backend opengl --python build_oddworks.py
No downloaded models, generative model service, or third-party artwork.
"""
import bpy, math, os, random, json, subprocess
from pathlib import Path
from mathutils import Vector, Matrix
from math import sin, cos, pi

BASE = os.path.dirname(os.path.abspath(__file__))
# Works in the committed art/Oddworks folder and the workspace authoring folder.
REPO = next((p for p in [Path(BASE), *Path(BASE).parents]
             if (p/'CrearoApp').is_dir() and (p/'project.yml').exists()), None)
if REPO is None:
    REPO = Path(BASE).parents[1] / 'work/Crearo'
if not (REPO/'CrearoApp').is_dir(): raise RuntimeError('Cannot locate the Crearo repository')
ASSETS = str(REPO/'CrearoApp/Resources/OddworksAssets')
PREVIEW = os.environ.get('ODDWORKS_PREVIEW_DIR', str(Path(BASE)/'renders'))
TEX = os.path.join(BASE, 'textures')
for path in [ASSETS, PREVIEW, TEX]: os.makedirs(path, exist_ok=True)
random.seed(3197)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.materials): bpy.data.materials.remove(block)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'; scene.unit_settings.scale_length = 1.0
scene.render.engine = 'CYCLES'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
try:
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
except TypeError:
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'Medium High Contrast'
scene.world.color = (0.22, 0.22, 0.22)

COLORS = {
    'Cobalt': (0.055, 0.12, 0.88), 'Acid': (0.91, 0.98, 0.10),
    'Coral': (0.99, 0.25, 0.19), 'Chalk': (0.91, 0.87, 0.78),
    'Lavender': (0.62, 0.58, 0.79), 'Ink': (0.028, 0.035, 0.049),
    'PaleBlue': (0.34, 0.58, 0.88), 'White': (0.98, 0.97, 0.89)
}

def texture(name, color, size=256):
    # Authored flecked enamel/chalk texture: tiny pores and slow pigment variation.
    image = bpy.data.images.new(name + '_Pigment', width=size, height=size)
    px = []
    for y in range(size):
        for x in range(size):
            seed = ((x * 73856093) ^ (y * 19349663) ^ 1471) & 0xffffffff
            n = ((seed * 1664525 + 1013904223) & 65535) / 65535
            w = sin(x * .079 + sin(y * .031) * 1.8) * sin(y * .047)
            grain = (n - .5) * .035 + w * .012
            pore = -.075 if n > .997 else 0
            px.extend([max(0.002, min(1.0, c * (1 + grain + pore))) for c in color] + [1.0])
    image.pixels.foreach_set(px)
    image.filepath_raw = os.path.join(TEX, name + '_Pigment.png')
    image.file_format = 'PNG'; image.save()
    image.pack()
    return image

def material(name, roughness=.5, metallic=0):
    m = bpy.data.materials.new(name)
    m.use_nodes=True
    m.diffuse_color = (*COLORS[name], 1)
    n=m.node_tree.nodes
    bsdf=n.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=roughness
    bsdf.inputs['Metallic'].default_value=metallic
    tex=n.new('ShaderNodeTexImage'); tex.image=texture(name, COLORS[name]); tex.interpolation='Linear'
    m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    return m
M={name:material(name, .43 if name in ['Cobalt','Coral','Acid'] else .66, .07 if name=='Ink' else 0) for name in COLORS}

root_collection=scene.collection

def coll(name):
    c=bpy.data.collections.new(name); root_collection.children.link(c); return c
LOOP=coll('Loop_Character'); WORLD=coll('Strange_Atelier'); STUDIO=coll('Render_Only')
active_collection=WORLD

def move_to(obj, collection=None):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    (collection or active_collection).objects.link(obj)
    return obj

def finish(obj, name, mat, bevel=0, smooth=True):
    obj.name=name; move_to(obj)
    if mat: obj.data.materials.append(M[mat])
    if bevel:
        mod=obj.modifiers.new('Hand-softened edges','BEVEL'); mod.width=bevel; mod.segments=3
        mod.affect='EDGES'
    if smooth and obj.type=='MESH':
        for p in obj.data.polygons: p.use_smooth=True
        if bevel:
            mod=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=50
    return obj

def cube(name,loc,scale,mat,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,bevel)

def uv_sphere(name,loc,scale,mat,segments=32,rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat)

def cylinder(name,loc,radius,depth,mat,vertices=48,rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot or (0,0,0))
    return finish(bpy.context.object,name,mat,.022)

def curve(name,points,radius,mat,bezier=True,res=12):
    data=bpy.data.curves.new(name,'CURVE'); data.dimensions='3D'; data.resolution_u=res
    data.bevel_depth=radius; data.bevel_resolution=3; data.use_fill_caps=True
    s=data.splines.new('BEZIER' if bezier else 'POLY');
    if bezier:
        s.bezier_points.add(len(points)-1)
        for b,p in zip(s.bezier_points,points): b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'
    else:
        s.points.add(len(points)-1)
        for b,p in zip(s.points,points): b.co=(*p,1)
    o=bpy.data.objects.new(name,data); active_collection.objects.link(o); data.materials.append(M[mat]); return o

def ring_arc(name,center,radius,tube,start,end,mat,steps=88,sections=16,taper=False):
    # Elliptically sectioned, gently irregular C form; open ends are capped.
    v=[]; f=[]; uvs=[]
    for i in range(steps+1):
        t=i/steps; a=start+(end-start)*t
        thick=tube*(.55+.45*sin(pi*t)**.28) if taper else tube
        r=radius*(1+.015*sin(a*3))
        for j in range(sections):
            b=2*pi*j/sections
            rr=r+thick*cos(b)
            v.append((center[0]+rr*cos(a),center[1]+thick*.8*sin(b),center[2]+rr*sin(a)))
    for i in range(steps):
        for j in range(sections): f.append((i*sections+j,i*sections+(j+1)%sections,(i+1)*sections+(j+1)%sections,(i+1)*sections+j))
    f.append(tuple(reversed(range(sections)))); f.append(tuple(steps*sections+j for j in range(sections)))
    me=bpy.data.meshes.new(name); me.from_pydata(v,[],f); me.update()
    o=bpy.data.objects.new(name,me); active_collection.objects.link(o); me.materials.append(M[mat])
    uv=me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:
            vi=me.loops[li].vertex_index; uv.data[li].uv=((vi//sections)/steps,(vi%sections)/sections)
    return o

def ribbon(name,points,width,thickness,mat):
    # Broad flat hinge/ribbon, individually bevelled along an authored folded path.
    verts=[]; faces=[]
    for p in points:
        verts.extend([(p[0]-width/2,p[1]-thickness/2,p[2]),(p[0]+width/2,p[1]-thickness/2,p[2]),(p[0]+width/2,p[1]+thickness/2,p[2]),(p[0]-width/2,p[1]+thickness/2,p[2])])
    for i in range(len(points)-1):
        for j in range(4): faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    faces.extend([(3,2,1,0),tuple((len(points)-1)*4+j for j in range(4))])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);active_collection.objects.link(o);finish(o,name,mat,.025)
    # UVs for mesh surfaces, independent of vertex shape.
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.0,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return o

# LOOP: a deliberately asymmetric ring being, rather than a standard humanoid.
active_collection=LOOP
ring_arc('Crescent enamel body',(0,0,.92),.42,.17,math.radians(53),math.radians(349),'Cobalt',taper=True)
# Single large eye sits off centre at the opening; its raised rim is physical geometry.
eye=uv_sphere('Single acid eye',(.25,-.11,1.12),(.245,.115,.245),'Acid')
uv_sphere('Ink iris',(.28,-.215,1.125),(.105,.028,.13),'Ink')
uv_sphere('Eye reflection',(.251,-.244,1.175),(.026,.008,.034),'Chalk',20,12)
# A coral head tab makes the silhouette recognisable from behind.
crest=ring_arc('Coral brow comma',(.04,.025,1.34),.19,.057,math.radians(6),math.radians(139),'Coral',steps=28,sections=12,taper=True)
# Thin offset limbs are folded strips, with visible circular pivots.
ribbon('Left folded ribbon',[(-.43,.015,.93),(-.64,-.025,.76),(-.75,-.055,.92)],.105,.074,'Coral')
ribbon('Right folded ribbon',[(.42,.035,.69),(.65,.025,.65),(.67,-.015,.92)],.105,.074,'Acid')
for name,loc,mat in [('Left hinge',(-.48,-.035,.87),'Acid'),('Right hinge',(.49,-.018,.69),'Ink')]:
    cylinder(name,loc,.064,.036,mat,rot=(pi/2,0,0),vertices=24)
uv_sphere('Left mitten',(-.75,-.055,.94),(.092,.075,.105),'Ink',24,16)
uv_sphere('Right mitten',(.67,-.015,.95),(.092,.075,.105),'Cobalt',24,16)
ribbon('Left articulated leg',[(-.21,.015,.53),(-.27,.03,.29),(-.18,-.02,.14)],.105,.075,'Ink')
ribbon('Right articulated leg',[(.13,.025,.49),(.25,.055,.26),(.29,-.02,.13)],.105,.075,'Ink')
cube('Left cobalt shoe',(-.20,-.07,.08),(.27,.31,.15),'Cobalt',.065)
cube('Right acid shoe',(.31,-.065,.08),(.30,.32,.15),'Acid',.065)
# Three small off-centre calibration ticks embossed into the enamel.
for i in range(3):
    o=cube('Enamel calibration tick %d'%i,(-.30+i*.055,-.149,1.22+i*.034),(.025,.016,.07),'Chalk',.008)
    o.rotation_euler[1]=-.5

# ATELIER: a graphic surreal obstacle landscape with real depth and thick solids.
active_collection=WORLD
cube('Ink floating plinth',(0,0,-.23),(5.8,4.0,.43),'Ink',.24)
cube('Lavender mineral deck',(0,0,-.035),(5.62,3.82,.18),'Lavender',.19)
# The cobalt route is sunk slightly into the chalk/grain top, not a flat backdrop.
cube('Cobalt channel',(0,-.02,.065),(1.03,3.78,.07),'Cobalt',.035)
for i in range(6):
    bar=cube('Channel current %02d'%i,(.015,-1.45+i*.52,.106),(.68,.026,.018),'PaleBlue',.008)
# Foreground vermilion landing with a physical black/white checker lip.
cube('Coral entrance',(-1.70,-1.0,.15),(1.8,1.30,.22),'Coral',.075)
for i in range(8):
    cube('Checker lip %02d'%i,(-2.4+i*.20,-1.66,.277),(.20,.17,.023),'Ink' if i%2==0 else 'Chalk',.009)
# Main impossible arch: flattened outline extruded through Y, with a large void.
def solid_arch(name,cx,cy,bottom,outer_r,inner_r,stem,depth,mat):
    # Front and back use consistent loops: outer path leftbase→arch→rightbase,
    # inner path returns rightbase→innerarch→leftbase, leaving an arch-shaped void.
    seg=48
    outer=[(-outer_r,0)] + [(outer_r*cos(pi-pi*i/seg),stem+outer_r*sin(pi-pi*i/seg)) for i in range(seg+1)] + [(outer_r,0)]
    inner=[(inner_r,0)] + [(inner_r*cos(pi*i/seg),stem+inner_r*sin(pi*i/seg)) for i in range(seg+1)] + [(-inner_r,0)]
    outline=outer+inner; n=len(outline);v=[];f=[]
    for yy in [-depth/2,depth/2]:v.extend([(cx+x,cy+yy,bottom+z) for x,z in outline])
    # Use ngon on each side; Blender tessellates this simple continuous arch strip.
    f.append(tuple(reversed(range(n))));f.append(tuple(n+i for i in range(n)))
    for i in range(n):f.append((i,(i+1)%n,(i+1)%n+n,i+n))
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);active_collection.objects.link(o);finish(o,name,mat,.035)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.0,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return o

# Portal is asymmetric in its surrounding support and stair routing.
solid_arch('Coral impossible arch',.72,.72,.18,1.12,.73,.92,.48,'Coral')
cube('Arch left chalk footing',(-.38,.72,.22),(.53,.78,.35),'Chalk',.075)
cube('Arch right acid footing',(1.81,.72,.38),(.58,.78,.67),'Acid',.075)
# A detached top cap proves the geometry's surreal construction.
cap=cube('Detached ink keystone',(.72,.69,2.47),(.43,.57,.18),'Ink',.055)
cap.rotation_euler[1]=.15
# A small quarter arch floats across the first one at ninety degrees.
side=solid_arch('Cobalt counter arch',-1.42,.67,.45,.64,.40,.47,.35,'Cobalt')
side.rotation_euler[2]=-.17
# Floating steps terminate in space and break a predictable left-to-right path.
for i in range(6):
    x=-1.83+i*.40; y=-.11+i*.075; z=.40+i*.22
    s=cube('Suspended step %02d'%i,(x,y,z),(.46,.67,.13),'Acid' if i<4 else 'Chalk',.045)
    if i==5:s.rotation_euler[2]=.11
    # Ink tread seam gives the steps a designed scale cue.
    cube('Step seam %02d'%i,(x,y-.22,z+.071),(.30,.021,.009),'Ink',.004)
# Vertical chalk monolith with a drilled looking eye and asymmetric stripes.
monolith=cube('Chalk monolith',(-2.18,1.04,.94),(.50,.70,1.72),'Chalk',.06)
for i in range(4):
    o=cube('Monolith ink band %02d'%i,(-2.18,.678,.47+i*.28),(.40,.018,.095),'Ink',.009)
# An upright sculptural disk with an actual hole.
ring_arc('Floating acid orbit',(2.05,-.77,1.35),.42,.09,0,2*pi,'Acid',steps=64,sections=12)
uv_sphere('Orbit ink moon',(2.05,-.77,1.35),(.15,.15,.15),'Ink',32,20)
cylinder('Orbit coral pedestal',(2.05,-.77,.40),.30,.68,'Coral',vertices=48)
# Teal/cobalt architectural fins on the rear, each independently bevelled.
for i in range(3):
    fin=cube('Rear tilted fin %d'%i,(-.80+i*.25,1.53,.65+i*.12),(.12,.60,1.05+i*.20),'Ink',.035)
    fin.rotation_euler[1]=-.24
# A deliberately bright detached block with rounded corners.
die=cube('Floating coral counterweight',(1.37,-1.23,.54),(.46,.47,.46),'Coral',.07)
die.rotation_euler=(.08,.12,-.18)
for dx in [-.09,.09]:uv_sphere('Counterweight inset', (1.37+dx,-1.48,.59),(.028,.013,.028),'Ink',16,8)
# Architectural rail/bead: a repeated controlled motif instead of scattered clutter.
curve('Chalk handrail',[(.97,-.16,.37),(1.2,-.30,.52),(1.58,-.28,.67)],.035,'Chalk')
for x,y,z in [(1.00,-.18,.24),(1.55,-.28,.37)]:cylinder('Rail support',(x,y,z),.026,.30,'Ink',vertices=16)

# Convert authored tubes to mesh; RealityKit receives triangles, not USD curves.
for obj in list(LOOP.objects) + list(WORLD.objects):
    if obj.type == 'CURVE':
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
        bpy.context.view_layer.objects.active=obj; bpy.ops.object.convert(target='MESH')

# Runtime assets have clean names and exactly the authored scene geometry.
def export_collection(collection,filename):
    original_collection=collection
    # Static architecture is batched by material after modifier evaluation.
    # The editable .blend retains the separate authored pieces.
    if collection == WORLD:
        collection=coll('Runtime_Static_Batches')
        groups={}
        for obj in original_collection.objects:
            clone=obj.copy();clone.data=obj.data.copy();collection.objects.link(clone)
            bpy.ops.object.select_all(action='DESELECT');clone.select_set(True)
            bpy.context.view_layer.objects.active=clone
            for mod in list(clone.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
            key=clone.data.materials[0].name if clone.data.materials else 'Default'
            groups.setdefault(key,[]).append(clone)
        for key,objects in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects:obj.select_set(True)
            bpy.context.view_layer.objects.active=objects[0]
            bpy.ops.object.join();objects[0].name='Architecture_'+key
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.objects:obj.select_set(True)
    props=bpy.ops.wm.usd_export.get_rna_type().properties.keys()
    output=os.path.join(BASE,'usd-source',filename.split('.')[0])
    os.makedirs(output,exist_ok=True)
    usda=os.path.join(output,filename.replace('.usdz','.usda'))
    # Blender 3.6 retains Z-up on export; rotate the selected authored geometry
    # into the same Y-up coordinate system natively supported by later exporters.
    matrices={o:o.matrix_world.copy() for o in collection.objects}
    if 'convert_orientation' not in props:
        rotation=Matrix.Rotation(-pi/2,4,'X')
        for o in collection.objects:o.matrix_world=rotation@o.matrix_world
        bpy.context.view_layer.update()
    opts=dict(filepath=usda, selected_objects_only=True, visible_objects_only=False,
              export_materials=True, export_uvmaps=True, export_normals=True,
              generate_preview_surface=True, export_textures=True, overwrite_textures=True,
              relative_paths=True, convert_orientation=True,
              export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
              convert_world_material=False, export_cameras=False, export_lights=False,
              export_animation=False, use_instancing=False, root_prim_path='/'+filename.split('.')[0])
    opts={k:v for k,v in opts.items() if k in props}
    bpy.ops.wm.usd_export(**opts)
    for o,m in matrices.items():o.matrix_world=m
    bpy.context.view_layer.update()
    text=open(usda).read()
    if 'convert_orientation' not in props:text=text.replace('upAxis = "Z"','upAxis = "Y"')
    # Blender 3.6 authored these old aliases; current USD shade validators require
    # their declared schema types, without changing material values or networks.
    text=text.replace('token inputs:varname', 'string inputs:varname')
    text=text.replace('float3 inputs:diffuseColor', 'color3f inputs:diffuseColor')
    text=text.replace('float3 inputs:emissiveColor', 'color3f inputs:emissiveColor')
    open(usda,'w').write(text)
    target=os.path.join(ASSETS,filename)
    if os.path.exists(target):os.unlink(target)
    subprocess.run(['/usr/bin/usdzip','--arkitAsset',usda,'--checkCompliance',target],check=True)
    bpy.ops.object.select_all(action='DESELECT')
    if collection != original_collection:
        for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(collection)

export_collection(LOOP,'Loop.usdz')
export_collection(WORLD,'StrangeAtelier.usdz')

# Layout for real Blender renders: same assets, no paintover or concept substitute.
# Move the character collection to its authored entrance for diorama preview.
for o in LOOP.objects:o.location.x-=1.6;o.location.y-=1.02;o.location.z+=.27
active_collection=STUDIO
floor=cube('Studio floor',(0,0,-.52),(200,200,.1),'Lavender',0)
# Use an independent flat background to keep the architectural shadows legible.
floor.data.materials.clear()
flat=bpy.data.materials.new('Studio lavender');flat.diffuse_color=(.24,.20,.38,1);flat.use_nodes=True
flat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.24,.20,.38,1)
flat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
floor.data.materials.append(flat)

def light(name,loc,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);STUDIO.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler();return o
light('Large warm key',(-3.5,-4.5,8),1250,(1.0,.91,.80),4.0)
light('Cool soft fill',(5,-1,5),500,(.66,.78,1),4.5)
light('Rear coral rim',(0,5,6),900,(1,.68,.55),3)
# Ambient world uses a controlled neutral, not a downloaded HDRI.
world=bpy.data.worlds.new('Oddworks studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.32,.32,.38,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35;scene.world=world

def camera(name,loc,target,ortho):
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=ortho
    o=bpy.data.objects.new(name,d);STUDIO.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();scene.camera=o;return o
cam=camera('Atelier hero camera',(7,-10,7.8),(0,0,.85),7.5)
scene.render.resolution_x=1800;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.filepath=os.path.join(PREVIEW,'ODDWORKS_ATELIER_WIDE.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE,'Oddworks.blend'))
bpy.ops.render.render(write_still=True)
# Portrait retains the actual diorama rather than cropping a wide image.
cam.location=(6.8,-10.8,8.8);cam.rotation_euler=(Vector((0,0,.92))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=7.8
scene.render.resolution_x=1280;scene.render.resolution_y=1600
scene.render.filepath=os.path.join(PREVIEW,'ODDWORKS_ATELIER_PORTRAIT.png')
bpy.ops.render.render(write_still=True)
# Character turntable-style proof, same model at its asset origin.
for o in WORLD.objects:o.hide_render=True
for o in LOOP.objects:o.location.x+=1.6;o.location.y+=1.02;o.location.z-=.27
floor.location.z=-.09
cam.location=(3.2,-7,2.8);cam.rotation_euler=(Vector((0,0,.79))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.25
scene.render.resolution_x=1280;scene.render.resolution_y=1600
scene.render.filepath=os.path.join(PREVIEW,'ODDWORKS_LOOP_PORTRAIT.png')
bpy.ops.render.render(write_still=True)
# Restore final editable source with the world visible and hero composition.
for o in WORLD.objects:o.hide_render=False
for o in LOOP.objects:o.location.x-=1.6;o.location.y-=1.02;o.location.z+=.27
floor.location.z=-.52
cam.location=(7,-10,7.8);cam.rotation_euler=(Vector((0,0,.85))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=7.5
scene.render.resolution_x=1800;scene.render.resolution_y=1200
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE,'Oddworks.blend'))
def stats(collection, batched=False):
    dep=bpy.context.evaluated_depsgraph_get(); points=[]; vertices=0;triangles=0
    for obj in collection.objects:
        evaluated=obj.evaluated_get(dep); mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        vertices+=len(mesh.vertices);triangles+=len(mesh.loop_triangles)
        points.extend([obj.matrix_world@Vector(p) for p in evaluated.bound_box])
        evaluated.to_mesh_clear()
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    return {'meshes':len({o.data.materials[0].name for o in collection.objects}) if batched else len(collection.objects),
            'vertices':vertices, 'triangles':triangles,
            'bounds_m':{'minimum':[low[0],low[2],-high[1]],'maximum':[high[0],high[2],-low[1]]}}
# The source model is restored to its hero pose above; remove the diorama offset
# while measuring the separately exported character, then put the source back.
for o in LOOP.objects:o.location.x+=1.6;o.location.y+=1.02;o.location.z-=.27
bpy.context.view_layer.update()
loop_stats=stats(LOOP);world_stats=stats(WORLD,True)
for o in LOOP.objects:o.location.x-=1.6;o.location.y-=1.02;o.location.z+=.27
manifest={'style':'Original surreal graphic sculpture; cobalt, acid, coral, chalk, lavender and ink',
          'authoring':'Blender Python / Crearo, original geometry and deterministic authored pigment textures',
          'ownership':'Original project assets; no third-party model or texture downloads',
          'units':'meters; runtime X-right, Y-up, Z-front (Blender authoring Z-up is converted on export)',
          'Loop.usdz':dict(loop_stats,origin='feet on Y=0; +Z is the front of the eye',purpose='single-eye crescent companion'),
          'StrangeAtelier.usdz':dict(world_stats,origin='deck centre at (0,0,0); deck top Y~0.055; +Z is foreground',purpose='surreal arched traversal diorama'),
          'materials':'UV-mapped PNG pigment textures, constant PBR roughness/metalness; tiny enamel flecks are baked into base color',
          'runtime':'No camera, light, studio floor or animation exported. Root prim names Loop and StrangeAtelier.',
          'validation':{'packaging':'Apple usdzip --arkitAsset --checkCompliance; run usdchecker --arkit --strict after rebuilding',
                        'device_rendering':'RealityKit/iPhone performance is not established by offline exports'}}
with open(os.path.join(ASSETS,'ART_METADATA.json'),'w') as f:json.dump(manifest,f,indent=2)
print('ODDWORKS_ASSETS_DONE')
