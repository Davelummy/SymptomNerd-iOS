import SwiftUI
import SceneKit
import UIKit

// MARK: - BodyLocationPicker

struct BodyLocationPicker: View {
    @Binding var location: BodyLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            HStack {
                Text("Body location")
                    .font(Typography.headline)
                Spacer()
                if location != nil {
                    Button("Clear") { location = nil }
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Body3DSceneView(location: $location)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: Theme.spacingXS) {
                Image(systemName: location != nil ? "mappin.circle.fill" : "rotate.3d")
                    .font(.caption)
                    .foregroundStyle(location != nil ? Theme.accent : Theme.textSecondary)
                Text(location?.regionName ?? "Tap to mark  •  Drag to rotate")
                    .font(Typography.body)
                    .foregroundStyle(location != nil ? Theme.textPrimary : Theme.textSecondary)
            }
        }
    }
}

// MARK: - UIViewRepresentable bridge

private struct Body3DSceneView: UIViewRepresentable {
    @Binding var location: BodyLocation?

    func makeCoordinator() -> Body3DCoordinator {
        Body3DCoordinator(location: $location)
    }

    func makeUIView(context: Context) -> SCNView {
        let sv = SCNView()
        sv.scene = BodySceneBuilder.build()
        sv.backgroundColor = UIColor(white: 0.09, alpha: 1)
        sv.allowsCameraControl = false
        sv.autoenablesDefaultLighting = false
        sv.antialiasingMode = .multisampling4X
        sv.isPlaying = false

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Body3DCoordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        sv.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Body3DCoordinator.handleTap(_:)))
        tap.require(toFail: pan)
        sv.addGestureRecognizer(tap)

        context.coordinator.scnView = sv
        return sv
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if location == nil {
            uiView.scene?.rootNode
                .childNode(withName: "pin", recursively: true)?
                .removeFromParentNode()
        }
    }
}

// MARK: - Coordinator

final class Body3DCoordinator: NSObject, UIGestureRecognizerDelegate {
    var locationBinding: Binding<BodyLocation?>
    weak var scnView: SCNView?
    private var yaw: Float = 0

    init(location: Binding<BodyLocation?>) {
        self.locationBinding = location
    }

    // Only capture horizontal drags so vertical scrolls pass through to the Form.
    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let pan = gr as? UIPanGestureRecognizer, let v = gr.view else { return true }
        let vel = pan.velocity(in: v)
        return abs(vel.x) > abs(vel.y)
    }

    @objc func handlePan(_ g: UIPanGestureRecognizer) {
        guard let v = scnView,
              let root = v.scene?.rootNode.childNode(withName: "bodyRoot", recursively: false)
        else { return }
        let dx = Float(g.translation(in: v).x)
        yaw += dx * 0.009
        root.eulerAngles.y = yaw
        g.setTranslation(.zero, in: v)
    }

    @objc func handleTap(_ g: UITapGestureRecognizer) {
        guard let v = scnView else { return }
        let pt = g.location(in: v)
        let hits = v.hitTest(pt, options: [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .ignoreHiddenNodes: true
        ])
        guard let hit = hits.first(where: { $0.node.name?.hasPrefix("bp.") == true }) else { return }

        let wx = Double(hit.worldCoordinates.x)
        let wy = Double(hit.worldCoordinates.y)

        // Determine front/back from the surface normal in body-root local space.
        let surface: BodyLocation.Surface
        if let root = hit.node.parent {
            let ln = root.convertVector(hit.worldNormal, from: nil)
            surface = ln.z >= 0 ? .front : .back
        } else {
            surface = .front
        }

        let side: BodyLocation.Side
        if wx < -0.05 { side = .left }
        else if wx > 0.05 { side = .right }
        else { side = .center }

        // Normalise to 0-1 over the body bounding box: x ±0.37, y -0.64…0.92
        let nx = min(max((wx + 0.37) / 0.74, 0), 1)
        let ny = min(max((0.92 - wy) / 1.56, 0), 1)

        let region = regionName(
            node: hit.node.name ?? "",
            localY: hit.localCoordinates.y,
            surface: surface,
            side: side
        )

        locationBinding.wrappedValue = BodyLocation(
            surface: surface, side: side, x: nx, y: ny, regionName: region
        )
        placePin(at: hit.worldCoordinates, in: v)
    }

    // MARK: Private

    private func placePin(at pos: SCNVector3, in v: SCNView) {
        v.scene?.rootNode.childNode(withName: "pin", recursively: true)?.removeFromParentNode()

        let pinNode = SCNNode()
        pinNode.name = "pin"
        pinNode.position = pos

        // Core sphere
        let sphere = SCNSphere(radius: 0.026)
        let smat = SCNMaterial()
        smat.lightingModel = .physicallyBased
        smat.diffuse.contents = UIColor.systemBlue
        smat.emission.contents = UIColor(red: 0.25, green: 0.45, blue: 1.0, alpha: 0.55)
        smat.roughness.contents = 0.2
        smat.metalness.contents = 0.7
        sphere.materials = [smat]
        pinNode.geometry = sphere

        // Pulsing ring
        let ring = SCNTorus(ringRadius: 0.052, pipeRadius: 0.007)
        let rmat = SCNMaterial()
        rmat.lightingModel = .constant
        rmat.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.55)
        ring.materials = [rmat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        pinNode.addChildNode(ringNode)

        v.scene?.rootNode.addChildNode(pinNode)

        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = SCNVector3(1, 1, 1)
        pulse.toValue = SCNVector3(1.7, 1.7, 1.7)
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ringNode.addAnimation(pulse, forKey: "pulse")
    }

    private func regionName(node: String, localY: Float,
                            surface: BodyLocation.Surface, side: BodyLocation.Side) -> String {
        switch node {
        case "bp.head":    return "Head"
        case "bp.neck":    return "Neck"
        case "bp.chest":
            if surface == .front {
                return side == .left ? "Left chest" : "Right chest"
            } else {
                return side == .left ? "Left upper back" : "Right upper back"
            }
        case "bp.abdomen":
            return surface == .front
                ? (localY > 0 ? "Upper abdomen" : "Lower abdomen")
                : "Mid back"
        case "bp.pelvis":
            return surface == .front ? "Hip" : "Lower back"
        case "bp.shoulder.l": return "Left shoulder"
        case "bp.shoulder.r": return "Right shoulder"
        case "bp.upper_arm.l": return "Left upper arm"
        case "bp.upper_arm.r": return "Right upper arm"
        case "bp.forearm.l":   return "Left forearm"
        case "bp.forearm.r":   return "Right forearm"
        case "bp.thigh.l":     return "Left thigh"
        case "bp.thigh.r":     return "Right thigh"
        case "bp.lower_leg.l": return "Left lower leg"
        case "bp.lower_leg.r": return "Right lower leg"
        default:               return "Body"
        }
    }
}

// MARK: - Scene builder

private enum BodySceneBuilder {

    static func build() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Camera — slightly elevated, looking slightly down
        let camNode = SCNNode()
        camNode.name = "cam"
        let cam = SCNCamera()
        cam.fieldOfView = 38
        cam.zNear = 0.05
        cam.zFar = 30
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0.08, 2.55)
        scene.rootNode.addChildNode(camNode)

        addLights(to: scene)

        let bodyRoot = SCNNode()
        bodyRoot.name = "bodyRoot"
        buildBody(into: bodyRoot)
        scene.rootNode.addChildNode(bodyRoot)

        return scene
    }

    // MARK: Lighting

    private static func addLights(to scene: SCNScene) {
        func lightNode(_ type: SCNLight.LightType,
                       color: UIColor,
                       intensity: CGFloat,
                       euler: SCNVector3 = SCNVector3(0, 0, 0)) -> SCNNode {
            let n = SCNNode()
            let l = SCNLight()
            l.type = type
            l.color = color
            l.intensity = intensity
            n.light = l
            n.eulerAngles = euler
            return n
        }

        // Soft ambient fill
        scene.rootNode.addChildNode(
            lightNode(.ambient,
                      color: UIColor(white: 0.30, alpha: 1),
                      intensity: 500)
        )

        // Warm key light (front-left-top)
        let key = lightNode(.directional,
                            color: UIColor(red: 1.0, green: 0.94, blue: 0.83, alpha: 1),
                            intensity: 880,
                            euler: SCNVector3(-Float.pi / 4, -Float.pi / 5.5, 0))
        key.light?.castsShadow = true
        key.light?.shadowRadius = 5
        key.light?.shadowColor = UIColor.black.withAlphaComponent(0.38)
        scene.rootNode.addChildNode(key)

        // Cool fill light (right)
        scene.rootNode.addChildNode(
            lightNode(.directional,
                      color: UIColor(red: 0.50, green: 0.62, blue: 1.0, alpha: 1),
                      intensity: 260,
                      euler: SCNVector3(-Float.pi / 9, Float.pi / 2.2, 0))
        )

        // Rim / back light
        scene.rootNode.addChildNode(
            lightNode(.directional,
                      color: UIColor(red: 0.38, green: 0.48, blue: 0.88, alpha: 1),
                      intensity: 210,
                      euler: SCNVector3(-Float.pi / 12, Float.pi, 0))
        )
    }

    // MARK: Material

    private static func skinMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        // Warm neutral clay — looks good in both dark/light UI
        m.diffuse.contents = UIColor(red: 0.82, green: 0.72, blue: 0.64, alpha: 1.0)
        m.roughness.contents = 0.76
        m.metalness.contents = 0.03
        return m
    }

    // MARK: Body construction

    private static func node(_ geo: SCNGeometry,
                             name: String,
                             pos: SCNVector3,
                             euler: SCNVector3 = SCNVector3(0, 0, 0)) -> SCNNode {
        geo.materials = [skinMaterial()]
        let n = SCNNode(geometry: geo)
        n.name = name
        n.position = pos
        n.eulerAngles = euler
        return n
    }

    private static func buildBody(into root: SCNNode) {
        // ── Head & neck ──────────────────────────────────────────────────────
        root.addChildNode(node(SCNSphere(radius: 0.115),
                               name: "bp.head",
                               pos: SCNVector3(0, 0.800, 0)))

        root.addChildNode(node(SCNCylinder(radius: 0.044, height: 0.085),
                               name: "bp.neck",
                               pos: SCNVector3(0, 0.660, 0)))

        // ── Torso ─────────────────────────────────────────────────────────────
        // Chest — wider, deeper
        root.addChildNode(node(SCNBox(width: 0.292, height: 0.215,
                                     length: 0.140, chamferRadius: 0.042),
                               name: "bp.chest",
                               pos: SCNVector3(0, 0.460, 0)))

        // Abdomen — slightly narrower and shallower
        root.addChildNode(node(SCNBox(width: 0.238, height: 0.130,
                                     length: 0.110, chamferRadius: 0.034),
                               name: "bp.abdomen",
                               pos: SCNVector3(0, 0.270, 0)))

        // Pelvis — slightly wider again (hips)
        root.addChildNode(node(SCNBox(width: 0.262, height: 0.118,
                                     length: 0.118, chamferRadius: 0.034),
                               name: "bp.pelvis",
                               pos: SCNVector3(0, 0.138, 0)))

        // ── Shoulders ────────────────────────────────────────────────────────
        root.addChildNode(node(SCNSphere(radius: 0.070),
                               name: "bp.shoulder.l",
                               pos: SCNVector3(-0.202, 0.535, 0)))
        root.addChildNode(node(SCNSphere(radius: 0.070),
                               name: "bp.shoulder.r",
                               pos: SCNVector3( 0.202, 0.535, 0)))

        // ── Arms (slight outward lean) ────────────────────────────────────────
        let armLean: Float = 0.06   // radians of outward tilt

        root.addChildNode(node(SCNCapsule(capRadius: 0.042, height: 0.215),
                               name: "bp.upper_arm.l",
                               pos: SCNVector3(-0.318, 0.375, 0),
                               euler: SCNVector3(0, 0,  armLean)))
        root.addChildNode(node(SCNCapsule(capRadius: 0.042, height: 0.215),
                               name: "bp.upper_arm.r",
                               pos: SCNVector3( 0.318, 0.375, 0),
                               euler: SCNVector3(0, 0, -armLean)))

        root.addChildNode(node(SCNCapsule(capRadius: 0.033, height: 0.195),
                               name: "bp.forearm.l",
                               pos: SCNVector3(-0.325, 0.132, 0)))
        root.addChildNode(node(SCNCapsule(capRadius: 0.033, height: 0.195),
                               name: "bp.forearm.r",
                               pos: SCNVector3( 0.325, 0.132, 0)))

        // ── Legs ─────────────────────────────────────────────────────────────
        root.addChildNode(node(SCNCapsule(capRadius: 0.060, height: 0.272),
                               name: "bp.thigh.l",
                               pos: SCNVector3(-0.088, -0.215, 0)))
        root.addChildNode(node(SCNCapsule(capRadius: 0.060, height: 0.272),
                               name: "bp.thigh.r",
                               pos: SCNVector3( 0.088, -0.215, 0)))

        root.addChildNode(node(SCNCapsule(capRadius: 0.046, height: 0.254),
                               name: "bp.lower_leg.l",
                               pos: SCNVector3(-0.090, -0.508, 0)))
        root.addChildNode(node(SCNCapsule(capRadius: 0.046, height: 0.254),
                               name: "bp.lower_leg.r",
                               pos: SCNVector3( 0.090, -0.508, 0)))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        CardView {
            BodyLocationPicker(location: .constant(nil))
        }
        .screenPadding()
        .padding(.vertical, Theme.spacingL)
    }
}
