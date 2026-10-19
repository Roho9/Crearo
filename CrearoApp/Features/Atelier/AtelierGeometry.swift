import UIKit
import RealityKit
import simd

/// Small, original mesh vocabulary for the working mechanisms. These are real curved
/// surfaces with UVs, rather than silhouettes painted over the game scene.
@MainActor
enum AtelierGeometry {
    static let ink = UIColor(red: 0.078, green: 0.082, blue: 0.145, alpha: 1)
    static let cobalt = UIColor(red: 0.271, green: 0.255, blue: 0.961, alpha: 1)
    static let acid = UIColor(red: 0.894, green: 1, blue: 0.341, alpha: 1)
    static let coral = UIColor(red: 1, green: 0.451, blue: 0.365, alpha: 1)
    static let chalk = UIColor(red: 0.949, green: 0.941, blue: 1, alpha: 1)
    static let lilac = UIColor(red: 0.722, green: 0.655, blue: 0.937, alpha: 1)

    /// One shared 256px painted surface. Generated once when this scene is made, never
    /// in a frame callback; tiny stipples stay subordinate to the graphic silhouettes.
    static func paintTexture() -> TextureResource? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let graphics = context.cgContext
            for index in 0..<850 {
                let x = CGFloat((index * 73 + 13) % 256)
                let y = CGFloat((index * 127 + index / 17) % 256)
                graphics.setFillColor(UIColor(white: 0.40, alpha: 0.07).cgColor)
                graphics.fillEllipse(in: CGRect(x: x, y: y, width: 0.6, height: 1.5))
            }
            for index in 0..<6 {
                graphics.setStrokeColor(UIColor(white: 0.75, alpha: 0.13).cgColor)
                graphics.setLineWidth(0.7)
                graphics.move(to: CGPoint(x: CGFloat(index * 47), y: 0))
                graphics.addLine(to: CGPoint(x: CGFloat(index * 47 + 13), y: 256))
                graphics.strokePath()
            }
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
    }

    static func material(_ color: UIColor, texture: TextureResource? = nil,
                         metallic: Float = 0, roughness: Float = 0.46) -> PhysicallyBasedMaterial {
        var result = PhysicallyBasedMaterial()
        result.baseColor = .init(tint: color, texture: texture.map { .init($0) })
        result.roughness = .init(floatLiteral: roughness)
        result.metallic = .init(floatLiteral: metallic)
        result.clearcoat = .init(floatLiteral: metallic > 0.5 ? 0.12 : 0.28)
        result.clearcoatRoughness = .init(floatLiteral: 0.35)
        return result
    }

    static func model(_ mesh: MeshResource, _ material: PhysicallyBasedMaterial,
                      at position: SIMD3<Float> = .zero, scale: SIMD3<Float> = .one) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        entity.scale = scale
        return entity
    }

    static func tube(_ points: [SIMD3<Float>], radius: Float, sides: Int = 8,
                     closed: Bool = false) -> MeshResource {
        guard points.count >= 2 else { return .generateSphere(radius: radius) }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        let count = points.count
        for index in 0..<count {
            let previous = points[index == 0 ? (closed ? count - 1 : 0) : index - 1]
            let next = points[index == count - 1 ? (closed ? 0 : count - 1) : index + 1]
            let tangent = simd_normalize(next - previous)
            let reference: SIMD3<Float> = abs(tangent.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
            let a = simd_normalize(simd_cross(tangent, reference))
            let b = simd_normalize(simd_cross(tangent, a))
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * .pi * 2
                let normal = cos(angle) * a + sin(angle) * b
                positions.append(points[index] + normal * radius)
                normals.append(normal)
                uv.append([Float(side) / Float(sides), Float(index) / Float(count - 1)])
            }
        }
        for index in 0..<(closed ? count : count - 1) {
            let next = (index + 1) % count
            for side in 0..<sides {
                let a = UInt32(index * sides + side)
                let b = UInt32(index * sides + (side + 1) % sides)
                let c = UInt32(next * sides + side)
                let d = UInt32(next * sides + (side + 1) % sides)
                triangles += [a, b, c, b, d, c]
            }
        }
        return mesh(positions: positions, normals: normals, uv: uv, triangles: triangles)
    }

    static func ring(radius: Float, tubeRadius: Float, arc: Float = .pi * 2,
                     start: Float = 0) -> MeshResource {
        let count = max(18, Int(arc / (.pi * 2) * 64))
        let closed = abs(arc - .pi * 2) < 0.001
        let points: [SIMD3<Float>] = (0..<(closed ? count : count + 1)).map { index in
            let angle = start + Float(index) / Float(count) * arc
            return [cos(angle) * radius, sin(angle) * radius, 0]
        }
        return tube(points, radius: tubeRadius, sides: 10, closed: closed)
    }

    static func cylinder(height: Float, radius: Float) -> MeshResource {
        lathe([[0, -height / 2], [radius, -height / 2], [radius, height / 2], [0, height / 2]])
    }

    static func lathe(_ profile: [SIMD2<Float>], sides: Int = 32) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        for row in profile.indices {
            let previous = profile[max(0, row - 1)]
            let next = profile[min(profile.count - 1, row + 1)]
            let direction = simd_normalize(next - previous)
            for side in 0...sides {
                let angle = Float(side) / Float(sides) * 2 * .pi
                positions.append([cos(angle) * profile[row].x, profile[row].y, sin(angle) * profile[row].x])
                normals.append([direction.y * cos(angle), -direction.x, direction.y * sin(angle)])
                uv.append([Float(side) / Float(sides), Float(row) / Float(profile.count - 1)])
            }
        }
        for row in 0..<(profile.count - 1) {
            for side in 0..<sides {
                let a = UInt32(row * (sides + 1) + side)
                let b = a + 1
                let c = a + UInt32(sides + 1)
                let d = c + 1
                triangles += [a, c, b, b, c, d]
            }
        }
        return mesh(positions: positions, normals: normals, uv: uv, triangles: triangles)
    }

    /// A gently bowed fabric panel: enough thickness and curvature to catch real light.
    static func sail() -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        let rows = 12
        for row in 0...rows {
            let y = Float(row) / Float(rows)
            for column in 0...rows {
                let x = Float(column) / Float(rows)
                positions.append([0.04 + x * (1 - y) * 0.62, y * 0.76,
                                  sin(x * .pi) * sin((y + 0.1) * .pi) * 0.16])
                normals.append(simd_normalize([-0.18 * cos(x * .pi), 0.1, 1]))
                uv.append([x, y])
            }
        }
        for row in 0..<rows {
            for column in 0..<rows {
                let a = UInt32(row * (rows + 1) + column)
                let c = a + UInt32(rows + 1)
                triangles += [a, a + 1, c, a + 1, c + 1, c]
            }
        }
        return mesh(positions: positions, normals: normals, uv: uv, triangles: triangles)
    }

    static func blade() -> MeshResource {
        // A swept, tapered propeller, deliberately distinct from a flat rectangle.
        let outline: [SIMD2<Float>] = [[0, 0], [0.08, 0.08], [0.18, 0.26], [0.16, 0.48],
                                      [0.06, 0.54], [-0.08, 0.47], [-0.13, 0.32], [-0.06, 0.1]]
        return extrude(outline, depth: 0.065)
    }

    static func extrude(_ outline: [SIMD2<Float>], depth: Float) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        let center = outline.reduce(SIMD2<Float>.zero, +) / Float(outline.count)
        for sign: Float in [-1, 1] {
            let start = UInt32(positions.count)
            positions.append([center.x, center.y, sign * depth / 2])
            normals.append([0, 0, sign]); uv.append(center)
            for point in outline {
                positions.append([point.x, point.y, sign * depth / 2])
                normals.append([0, 0, sign]); uv.append(point)
            }
            for index in outline.indices {
                let a = start + UInt32(index + 1)
                let b = start + UInt32((index + 1) % outline.count + 1)
                triangles += sign > 0 ? [start, a, b] : [start, b, a]
            }
        }
        for index in outline.indices {
            let a = outline[index]
            let b = outline[(index + 1) % outline.count]
            let edge = b - a
            let normal = simd_normalize(SIMD3<Float>(edge.y, -edge.x, 0))
            let start = UInt32(positions.count)
            positions += [[a.x, a.y, -depth / 2], [b.x, b.y, -depth / 2],
                          [a.x, a.y, depth / 2], [b.x, b.y, depth / 2]]
            normals += Array(repeating: normal, count: 4)
            uv += [[0, 0], [1, 0], [0, 1], [1, 1]]
            triangles += [start, start + 1, start + 2, start + 1, start + 3, start + 2]
        }
        return mesh(positions: positions, normals: normals, uv: uv, triangles: triangles)
    }

    private static func mesh(positions: [SIMD3<Float>], normals: [SIMD3<Float>],
                             uv: [SIMD2<Float>], triangles: [UInt32]) -> MeshResource {
        var descriptor = MeshDescriptor(name: "OddworksOriginal")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        descriptor.primitives = .triangles(triangles)
        // The fallback is limited to a malformed procedural part. Bundled world assets
        // have a separate visible loading-failure notice in the host.
        return (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: 0.15)
    }

    static func part(_ id: String, texture: TextureResource?) -> Entity {
        let root = Entity()
        root.name = id
        let dark = material(ink, texture: texture)
        let blue = material(cobalt, texture: texture)
        let yellow = material(acid, texture: texture)
        let red = material(coral, texture: texture)
        let purple = material(lilac, texture: texture)
        let white = material(chalk, texture: texture)
        let metal = material(chalk, metallic: 0.88, roughness: 0.14)
        @discardableResult
        func add(_ mesh: MeshResource, _ paint: PhysicallyBasedMaterial,
                 _ position: SIMD3<Float> = .zero, _ scale: SIMD3<Float> = .one) -> ModelEntity {
            let node = model(mesh, paint, at: position, scale: scale)
            root.addChild(node)
            return node
        }
        switch id {
        case "fan":
            add(.generateBox(size: [0.15, 0.4, 0.16], cornerRadius: 0.05), blue, [0, 0.20, 0])
            let rotor = Entity(); rotor.name = "rotor"; rotor.position = [0, 0.65, 0.04]
            root.addChild(rotor)
            for index in 0..<3 {
                let vane = model(blade(), index == 1 ? red : yellow)
                vane.orientation = simd_quatf(angle: Float(index) * 2 * .pi / 3, axis: [0, 0, 1])
                rotor.addChild(vane)
            }
            rotor.addChild(model(.generateSphere(radius: 0.13), dark, at: [0, 0, 0.06]))
            add(ring(radius: 0.55, tubeRadius: 0.022), blue, [0, 0.65, 0.02])
        case "bell":
            add(lathe(Array([[0.05, 0.68], [0.10, 0.67], [0.20, 0.55], [0.23, 0.34],
                       [0.31, 0.16], [0.39, 0.11], [0.40, 0.06], [0.34, 0.04],
                       [0.27, 0.16], [0.17, 0.37], [0.12, 0.54], [0.04, 0.59]].reversed())), yellow)
            add(ring(radius: 0.10, tubeRadius: 0.033), purple, [0, 0.75, 0])
            add(.generateSphere(radius: 0.09), red, [0, 0.10, 0])
        case "spring":
            let helix = (0...120).map { index -> SIMD3<Float> in
                let t = Float(index) / 120
                return [cos(t * .pi * 10) * 0.25, 0.10 + t * 0.72, sin(t * .pi * 10) * 0.25]
            }
            add(tube(helix, radius: 0.052), purple)
            add(cylinder(height: 0.09, radius: 0.37), red, [0, 0.02, 0])
            add(cylinder(height: 0.08, radius: 0.34), yellow, [0, 0.86, 0])
        case "mirror":
            add(.generateBox(size: [0.12, 0.36, 0.12], cornerRadius: 0.04), red, [0, 0.16, 0])
            add(ring(radius: 0.38, tubeRadius: 0.07), yellow, [0, 0.65, 0], [0.82, 1.1, 1])
            let face = add(cylinder(height: 0.035, radius: 0.36), metal,
                           [0, 0.65, 0], [0.82, 1, 1.1])
            face.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let glint = add(.generateBox(size: [0.04, 0.50, 0.015], cornerRadius: 0.018), white,
                            [-0.08, 0.69, 0.035])
            glint.orientation = simd_quatf(angle: -.pi / 5, axis: [0, 0, 1])
        case "sail":
            add(tube([[0, 0.04, 0], [0, 0.90, 0]], radius: 0.034), dark)
            var fabric = red; fabric.faceCulling = .none
            add(sail(), fabric, [0, 0.1, 0])
            add(lathe([[0.07, 0], [0.35, 0.04], [0.42, 0.10], [0.35, 0.18]]), blue,
                [0.1, 0, 0], [1, 1, 0.45])
        case "magnet":
            add(ring(radius: 0.30, tubeRadius: 0.115, arc: .pi * 1.15, start: -.pi * 0.075), red,
                [0, 0.50, 0])
            add(.generateBox(size: [0.19, 0.27, 0.22], cornerRadius: 0.04), white, [-0.29, 0.31, 0])
            add(.generateBox(size: [0.19, 0.27, 0.22], cornerRadius: 0.04), blue, [0.29, 0.31, 0])
            add(cylinder(height: 0.09, radius: 0.32), dark, [0, 0.02, 0])
        case "wheel":
            let rotor = Entity(); rotor.name = "rotor"; rotor.position = [0, 0.49, 0]
            root.addChild(rotor)
            rotor.addChild(model(ring(radius: 0.42, tubeRadius: 0.085), blue))
            for index in 0..<5 {
                let angle = Float(index) * .pi * 2 / 5
                let spoke = model(.generateBox(size: [0.052, 0.38, 0.06], cornerRadius: 0.02), yellow,
                                  at: [sin(angle) * 0.19, cos(angle) * 0.19, 0])
                spoke.orientation = simd_quatf(angle: -angle, axis: [0, 0, 1])
                rotor.addChild(spoke)
            }
            rotor.addChild(model(.generateSphere(radius: 0.12), red, scale: [1, 1, 0.7]))
        case "seed":
            let seed = add(lathe([[0.02, 0], [0.15, 0.06], [0.25, 0.22], [0.22, 0.42], [0.08, 0.53], [0, 0.55]]), yellow,
                           [0, 0, 0], [0.85, 1, 0.72])
            seed.orientation = simd_quatf(angle: -0.23, axis: [0, 0, 1])
            add(tube([[0, 0.42, 0], [-0.02, 0.68, 0], [0.08, 0.84, 0]], radius: 0.026), dark)
            let leaf = add(blade(), blue, [0, 0.56, 0], [0.65, 0.70, 0.6])
            leaf.orientation = simd_quatf(angle: -1.1, axis: [0, 0, 1])
            let other = add(blade(), red, [0, 0.65, 0], [0.5, 0.50, 0.6])
            other.orientation = simd_quatf(angle: 0.9, axis: [0, 0, 1])
        default: break
        }
        return root
    }
}
