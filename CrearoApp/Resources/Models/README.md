# 3D models (USDZ)

Drop `.usdz` files here. They're bundled into the app automatically on `xcodegen generate`
and load by **filename without extension** in RealityKit:

```swift
let blob = try await Entity(named: "blob")   // loads blob.usdz from this folder
```

Put the clay character here as **`blob.usdz`**. After adding it, run `xcodegen generate`
(so the new file is included in the Xcode project), then build.
