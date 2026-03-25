import SwiftUI

// MARK: - Hex Grid View

struct HexGridView: View {
    @ObservedObject var engine: GridlockGameEngine
    let currentPlayer: Int
    let hexSize: CGFloat
    let action: GridlockAction
    let onHexTap: (HexCoord) -> Void

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 0.6
    @State private var lastScale: CGFloat = 0.6
    @State private var glowPhase: Bool = false

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.07)

    var body: some View {
        GeometryReader { geo in
            let visibleHexes = engine.visibleHexes(for: currentPlayer)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                bgColor.ignoresSafeArea()

                // Grid layer
                Canvas { context, size in
                    let mid = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)

                    for (coord, cell) in engine.cells {
                        let pixel = coord.toPixel(size: hexSize * scale)
                        let pos = CGPoint(x: mid.x + pixel.x, y: mid.y + pixel.y)

                        // Culling: skip hexes outside visible rect
                        let margin: CGFloat = hexSize * scale * 2
                        guard pos.x > -margin && pos.x < size.width + margin &&
                              pos.y > -margin && pos.y < size.height + margin else { continue }

                        let isVisible = visibleHexes.contains(coord)
                        let path = hexPath(center: pos, size: hexSize * scale)

                        if isVisible {
                            // Resource fill
                            if let resType = cell.resourceType {
                                context.fill(path, with: .color(resourceColor(resType).opacity(0.2)))
                            } else {
                                context.fill(path, with: .color(Color.white.opacity(0.02)))
                            }

                            // Territory border color
                            let ownerBuilding = engine.buildings.first { $0.position == coord }
                            let borderColor: Color
                            if ownerBuilding?.owner == 1 {
                                borderColor = Color.cyan.opacity(0.5)
                            } else if ownerBuilding?.owner == 2 {
                                borderColor = Color.red.opacity(0.5)
                            } else {
                                // Check territory proximity
                                let nearP1 = engine.buildings.filter({ $0.owner == 1 }).contains { coord.distance(to: $0.position) <= $0.type.visionRange }
                                let nearP2 = engine.buildings.filter({ $0.owner == 2 }).contains { coord.distance(to: $0.position) <= $0.type.visionRange }
                                if nearP1 && !nearP2 {
                                    borderColor = Color.cyan.opacity(0.15)
                                } else if nearP2 && !nearP1 {
                                    borderColor = Color.red.opacity(0.15)
                                } else if nearP1 && nearP2 {
                                    borderColor = Color.purple.opacity(0.2)
                                } else {
                                    borderColor = Color.white.opacity(0.08)
                                }
                            }
                            context.stroke(path, with: .color(borderColor), lineWidth: 1)
                        } else {
                            // Fog of war
                            context.fill(path, with: .color(Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.95)))
                            context.stroke(path, with: .color(Color.white.opacity(0.02)), lineWidth: 0.5)
                        }
                    }
                }
                .allowsHitTesting(false)

                // Interactive overlay for buildings, units, tap targets
                ForEach(Array(engine.cells.values), id: \.id) { cell in
                    let coord = cell.coord
                    let isVisible = visibleHexes.contains(coord)
                    let pixel = coord.toPixel(size: hexSize * scale)
                    let pos = CGPoint(x: center.x + offset.width + pixel.x,
                                      y: center.y + offset.height + pixel.y)

                    if isVisible {
                        // Tap target
                        hexTapTarget(coord: coord, pos: pos)

                        // Resource indicator
                        if let resType = cell.resourceType, cell.resourceAmount > 0 {
                            resourceIndicator(type: resType, amount: cell.resourceAmount, pos: pos)
                        }

                        // Building
                        if let building = engine.building(at: coord) {
                            buildingView(building: building, pos: pos)
                        }

                        // Units
                        let unitsHere = engine.units(at: coord)
                        if !unitsHere.isEmpty {
                            unitStackView(units: unitsHere, pos: pos)
                        }
                    }
                }

                // Placement preview
                if case .placingBuilding(let type) = action {
                    placementGuides(type: type, visibleHexes: visibleHexes, center: center)
                }
            }
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .onAppear {
                // Center on player's HQ
                if let hq = engine.buildings.first(where: { $0.type == .hq && $0.owner == currentPlayer }) {
                    let pixel = hq.position.toPixel(size: hexSize * scale)
                    offset = CGSize(width: -pixel.x, height: -pixel.y)
                    lastOffset = offset
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
            }
        }
    }

    // MARK: - Hex Path

    private func hexPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat.pi / 180 * (60 * CGFloat(i) - 30)
            let x = center.x + size * cos(angle)
            let y = center.y + size * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Sub-views

    private func hexTapTarget(coord: HexCoord, pos: CGPoint) -> some View {
        Circle()
            .fill(Color.clear)
            .frame(width: hexSize * scale * 1.5, height: hexSize * scale * 1.5)
            .position(pos)
            .contentShape(Circle())
            .onTapGesture { onHexTap(coord) }
    }

    private func resourceIndicator(type: ResourceType, amount: Int, pos: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(resourceColor(type).opacity(0.3))
                .frame(width: hexSize * scale * 0.4, height: hexSize * scale * 0.4)
            Circle()
                .fill(resourceColor(type).opacity(glowPhase ? 0.6 : 0.3))
                .frame(width: hexSize * scale * 0.25, height: hexSize * scale * 0.25)
        }
        .position(pos)
        .allowsHitTesting(false)
    }

    private func buildingView(building: Building, pos: CGPoint) -> some View {
        let color: Color = building.owner == 1 ? .cyan : .red
        let s = hexSize * scale * 0.7

        return ZStack {
            // Glow
            Circle()
                .fill(color.opacity(glowPhase ? 0.25 : 0.15))
                .frame(width: s * 1.6, height: s * 1.6)
                .blur(radius: 4)

            // Building icon background
            RoundedRectangle(cornerRadius: 4)
                .fill(bgColor)
                .frame(width: s, height: s)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.8), lineWidth: 1.5)
                )

            // Icon
            Image(systemName: building.type.icon)
                .font(.system(size: s * 0.45))
                .foregroundStyle(building.type.color)

            // HP bar
            if building.hp < building.type.hp {
                VStack {
                    Spacer()
                    GeometryReader { _ in
                        let pct = CGFloat(building.hp) / CGFloat(building.type.hp)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(pct > 0.5 ? .green : (pct > 0.25 ? .yellow : .red))
                            .frame(width: s * pct, height: 2)
                    }
                    .frame(width: s, height: 2)
                }
                .frame(width: s, height: s + 4)
            }
        }
        .position(pos)
        .allowsHitTesting(false)
    }

    private func unitStackView(units: [GameUnit], pos: CGPoint) -> some View {
        let size = hexSize * scale * 0.3
        let yOffset = hexSize * scale * 0.45

        return ZStack {
            ForEach(Array(units.prefix(3).enumerated()), id: \.element.id) { idx, unit in
                let color: Color = unit.owner == 1 ? .cyan : .red
                let xOff = CGFloat(idx - min(units.count - 1, 2) / 2) * size * 0.8

                ZStack {
                    // Unit triangle
                    GridlockTriangle()
                        .fill(color.opacity(0.8))
                        .frame(width: size, height: size)
                        .shadow(color: color.opacity(0.5), radius: 3)

                    // Unit type indicator
                    if unit.type == .tank {
                        Circle()
                            .fill(color)
                            .frame(width: size * 0.4, height: size * 0.4)
                    }
                }
                .offset(x: xOff)
            }

            // Count badge
            if units.count > 1 {
                Text("\(units.count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .offset(x: size * 1.2)
            }
        }
        .position(CGPoint(x: pos.x, y: pos.y + yOffset))
        .allowsHitTesting(false)
    }

    private func placementGuides(type: BuildingType, visibleHexes: Set<HexCoord>, center: CGPoint) -> some View {
        ForEach(Array(engine.cells.keys.filter { engine.canPlaceBuilding(type, at: $0) }), id: \.self) { coord in
            let pixel = coord.toPixel(size: hexSize * scale)
            let pos = CGPoint(x: center.x + offset.width + pixel.x,
                              y: center.y + offset.height + pixel.y)

            Circle()
                .stroke(Color.green.opacity(glowPhase ? 0.6 : 0.3), lineWidth: 2)
                .frame(width: hexSize * scale * 1.2, height: hexSize * scale * 1.2)
                .position(pos)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 0.3), 1.5)
            }
            .onEnded { value in
                scale = min(max(lastScale * value.magnification, 0.3), 1.5)
                lastScale = scale
            }
    }

    private func resourceColor(_ type: ResourceType) -> Color {
        type.color
    }
}

// MARK: - Triangle Shape

struct GridlockTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
