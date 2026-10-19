# Oddworks original asset source

Oddworks is Crearo's surreal graphic world: cobalt enamel, acid yellow, coral, chalk, lavender, and ink. Loop is an asymmetric crescent with one raised eye, folded hinge limbs, offset shoes, and a coral brow. The atelier uses thick arched portals, suspended stairs, a striped monolith, a checker landing, and a detached orbit sculpture.

![Original Oddworks models rendered in Blender](../../docs/previews/oddworks-world.png)

This image is a Blender Cycles CPU render of the authored models, not an iPhone screenshot or a performance measurement. The exported USDZ files were separately reimported and rendered to verify their geometry, orientation, materials, and packaged textures.

## Files

- `Oddworks.blend`: editable geometry, individually named architectural parts, packed pigment textures, lighting, and hero camera.
- `build_oddworks.py`: reproducible original topology and UV-painted pigment texture generation, static geometry batching, USD export, and CPU preview rendering.
- `verify_roundtrip.py`: reloads the exact runtime USDZ packages, measures their geometry and bounds, and produces a separate verification render.
- `asset-verification.json`: measurements from that packaged-asset roundtrip.
- Runtime assets: `../../CrearoApp/Resources/OddworksAssets/Loop.usdz` and `StrangeAtelier.usdz`.

The meshes and textures were authored for this project. No downloaded character, stock model, HDRI, generated 3D service, or paid asset is included. The existing repository ownership applies to these original assets.

## Coordinate contract

All runtime dimensions are meters. USD stage metadata is **Y-up**, +X is right, and +Z is the foreground/front of Loop's eye. The Blender source uses its normal Z-up convention; the exporter converts the geometry and stage metadata together.

| Asset | Meshes | Triangles | Runtime bounds (minimum → maximum) |
| --- | ---: | ---: | --- |
| Loop | 18 | 10,716 | `(-0.842, 0.005, -0.136)` → `(0.762, 1.5834, 0.252)` |
| StrangeAtelier | 7 | 16,392 | `(-2.9, -0.445, -2)` → `(2.9, 2.5829, 2)` |

Loop's root is at its feet, approximately Y=0. The deck is centered at the origin with its top near Y=0.055. The coral entrance's top is near Y=0.26; the hero composition places Loop at `(-1.6, 0.27, 1.02)`. Runtime code can normalize these dimensions when arranging gameplay. The static architecture is merged into seven material batches; Loop retains named parts for future animation. Actual draw calls depend on the renderer.

The PBR materials use UV-mapped PNG pigment textures with restrained enamel flecks. Their color detail is baked into images, so the runtime does not depend on Blender procedural nodes. Roughness and metalness are explicit constants. Cameras, lights, the studio floor, and animation are excluded from runtime assets.

## Rebuild on macOS

The verified authoring environment was official **Blender 3.6.23 LTS for Apple Silicon**, using its OpenGL background option and **Cycles CPU**. Apple `usdzip` and `usdchecker` must also be available. No Blender MCP server is required to reproduce these files; the same Python authoring can also be run through a connected Blender MCP add-on.

```sh
/path/to/Blender.app/Contents/MacOS/Blender \
  --background --gpu-backend opengl --factory-startup \
  --python art/Oddworks/build_oddworks.py

usdchecker --arkit --strict CrearoApp/Resources/OddworksAssets/Loop.usdz
usdchecker --arkit --strict CrearoApp/Resources/OddworksAssets/StrangeAtelier.usdz

/path/to/Blender.app/Contents/MacOS/Blender \
  --background --gpu-backend opengl --factory-startup \
  --python art/Oddworks/verify_roundtrip.py
```

Run from the repository root. Render outputs default to `art/Oddworks/renders/`; set `ODDWORKS_PREVIEW_DIR` to use another output folder. The `.blend` packs its textures and can be edited without that generated texture folder. The script regenerates the texture files for USD export.

Blender 3.6 emits older USD shader property type aliases. The build script normalizes only those declarations to current schema types before packaging: `varname` becomes a string and diffuse/emissive colors become `color3f`. Both packages pass Apple's `usdchecker --arkit --strict` after this normalization.

## Tool provenance and validation limits

The official Blender 3.6.23 ARM64 DMG SHA-256 matched its official manifest:

```text
ecbeaef4abbeb045de8465e78b3f97aec9b67faf2fc71b20e5eca37bf1caf874
```

Official Blender 4.5.13 LTS was also downloaded and checksum-verified. Its macOS build requires Metal and crashed during GPU detection in this restricted environment before Python ran. The verified 3.6 OpenGL/CPU route produced the committed files without changing global software or Codex configuration.

Completed checks: native Blender generation, Apple USDZ packaging/compliance, strict current USD schema validation, packaged-asset roundtrip import, mesh/bounds inspection, and CPU renders. These establish valid content, not iPhone frame rate, GPU memory use, touch behavior, or RealityKit lighting equivalence. Those require device testing.

Sources: [official Blender 3.6 downloads](https://download.blender.org/release/Blender3.6/), [official command-line documentation](https://docs.blender.org/manual/en/3.6/advanced/command_line/arguments.html), [official USD export API](https://docs.blender.org/api/3.6/bpy.ops.wm.html), [Blender MCP source and Codex setup](https://github.com/ahujasid/mcp-for-blender).
