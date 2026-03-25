import SwiftUI

struct AutomationEditorView: View {
    @ObservedObject var engine: GridlockGameEngine
    let player: Int
    let onDismiss: () -> Void

    @State private var selectedPipelineIndex: Int = 0
    @State private var draggedNodeId: UUID?
    @State private var connectingFromId: UUID?
    @State private var connectingEndPoint: CGPoint = .zero
    @State private var showNodePicker = false
    @State private var canvasOffset: CGSize = .zero
    @State private var lastCanvasOffset: CGSize = .zero
    @State private var editingNodeId: UUID?

    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.1)
    private let gridColor = Color.white.opacity(0.03)

    private var pipelines: [AutomationPipeline] {
        engine.playerStates[player]?.pipelines ?? []
    }

    private var currentPipeline: AutomationPipeline? {
        guard selectedPipelineIndex < pipelines.count else { return nil }
        return pipelines[selectedPipelineIndex]
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Pipeline tabs
                pipelineTabBar

                // Canvas
                ZStack {
                    // Grid background
                    gridBackground

                    if let pipeline = currentPipeline {
                        // Connections
                        connectionsLayer(pipeline: pipeline)

                        // Active connection line
                        if let fromId = connectingFromId,
                           let fromNode = pipeline.nodes.first(where: { $0.id == fromId }) {
                            Path { path in
                                path.move(to: CGPoint(
                                    x: fromNode.position.x + canvasOffset.width + 60,
                                    y: fromNode.position.y + canvasOffset.height + 20
                                ))
                                let cp1 = CGPoint(
                                    x: (fromNode.position.x + canvasOffset.width + 60 + connectingEndPoint.x) / 2,
                                    y: fromNode.position.y + canvasOffset.height + 20
                                )
                                let cp2 = CGPoint(
                                    x: (fromNode.position.x + canvasOffset.width + 60 + connectingEndPoint.x) / 2,
                                    y: connectingEndPoint.y
                                )
                                path.addCurve(to: connectingEndPoint, control1: cp1, control2: cp2)
                            }
                            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }

                        // Nodes
                        ForEach(pipeline.nodes) { node in
                            nodeView(node: node)
                        }
                    } else {
                        emptyState
                    }
                }
                .clipped()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if draggedNodeId == nil && connectingFromId == nil {
                                canvasOffset = CGSize(
                                    width: lastCanvasOffset.width + value.translation.width,
                                    height: lastCanvasOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if draggedNodeId == nil && connectingFromId == nil {
                                lastCanvasOffset = canvasOffset
                            }
                        }
                )
            }

            // Node picker overlay
            if showNodePicker {
                nodePickerOverlay
            }

            // Node parameter editor
            if let editId = editingNodeId,
               let pIdx = selectedPipelineIndex < pipelines.count ? selectedPipelineIndex : nil,
               let node = pipelines[pIdx].nodes.first(where: { $0.id == editId }) {
                parameterEditorOverlay(node: node)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Close")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            Text("AUTOMATIONS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)
                .tracking(2)

            Spacer()

            Button {
                showNodePicker = true
                HapticManager.impact(.light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Node")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
                .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Pipeline Tabs

    private var pipelineTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(pipelines.enumerated()), id: \.element.id) { idx, pipeline in
                    Button {
                        selectedPipelineIndex = idx
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pipeline.isEnabled ? .green : .gray)
                                .frame(width: 6, height: 6)
                            Text(pipeline.name)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(idx == selectedPipelineIndex ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .stroke(idx == selectedPipelineIndex ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                    }
                }

                // Add pipeline button
                Button {
                    addPipeline()
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            let ox = canvasOffset.width.truncatingRemainder(dividingBy: spacing)
            let oy = canvasOffset.height.truncatingRemainder(dividingBy: spacing)

            for x in stride(from: ox, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }
            for y in stride(from: oy, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Connections Layer

    private func connectionsLayer(pipeline: AutomationPipeline) -> some View {
        Canvas { context, _ in
            for connection in pipeline.connections {
                guard let fromNode = pipeline.nodes.first(where: { $0.id == connection.fromNodeId }),
                      let toNode = pipeline.nodes.first(where: { $0.id == connection.toNodeId }) else { continue }

                let from = CGPoint(
                    x: fromNode.position.x + canvasOffset.width + 60,
                    y: fromNode.position.y + canvasOffset.height + 20
                )
                let to = CGPoint(
                    x: toNode.position.x + canvasOffset.width - 5,
                    y: toNode.position.y + canvasOffset.height + 20
                )

                var path = Path()
                path.move(to: from)
                let cp1 = CGPoint(x: (from.x + to.x) / 2, y: from.y)
                let cp2 = CGPoint(x: (from.x + to.x) / 2, y: to.y)
                path.addCurve(to: to, control1: cp1, control2: cp2)

                let fromColor = fromNode.nodeType.color
                context.stroke(path, with: .color(fromColor.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Node View

    private func nodeView(node: AutomationNode) -> some View {
        let nodeColor = node.nodeType.color

        return VStack(alignment: .leading, spacing: 4) {
            // Category label
            Text(node.nodeType.category)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(nodeColor)
                .tracking(1)

            // Node name
            Text(node.nodeType.displayName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)

            // Parameter
            if node.parameter > 0 {
                Text("val: \(node.parameter)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(nodeColor.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: nodeColor.opacity(0.3), radius: 6)
        )
        .position(
            x: node.position.x + canvasOffset.width + 60,
            y: node.position.y + canvasOffset.height + 20
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    draggedNodeId = node.id
                    updateNodePosition(nodeId: node.id, position: CGPoint(
                        x: value.location.x - canvasOffset.width - 60,
                        y: value.location.y - canvasOffset.height - 20
                    ))
                }
                .onEnded { _ in
                    draggedNodeId = nil
                }
        )
        .onTapGesture {
            editingNodeId = node.id
            HapticManager.impact(.light)
        }
        .onLongPressGesture {
            // Start connection
            connectingFromId = node.id
            HapticManager.impact(.medium)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundStyle(.cyan.opacity(0.3))

            Text("No Pipelines Yet")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            Text("Create a pipeline to automate your strategy")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)

            Button {
                addPipeline()
                HapticManager.impact(.light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Create Pipeline")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
                .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Node Picker

    private var nodePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { showNodePicker = false }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("ADD NODE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(2)
                    Spacer()
                    Button { showNodePicker = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Triggers
                        nodePickerSection(title: "TRIGGERS", color: Color(red: 0.2, green: 0.9, blue: 0.3),
                                          items: AutoTriggerType.allCases.map { .trigger($0) })

                        // Conditions
                        nodePickerSection(title: "CONDITIONS", color: Color(red: 0.95, green: 0.8, blue: 0.1),
                                          items: AutoConditionType.allCases.map { .condition($0) })

                        // Actions
                        nodePickerSection(title: "ACTIONS", color: Color(red: 0.95, green: 0.25, blue: 0.3),
                                          items: AutoActionType.allCases.map { .action($0) })
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(30)
        }
    }

    private func nodePickerSection(title: String, color: Color, items: [AutoNodeType]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .tracking(2)

            ForEach(items, id: \.displayName) { nodeType in
                Button {
                    addNode(nodeType)
                    showNodePicker = false
                    HapticManager.impact(.light)
                } label: {
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                        Text(nodeType.displayName)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(color.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Parameter Editor

    private func parameterEditorOverlay(node: AutomationNode) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { editingNodeId = nil }

            VStack(spacing: 16) {
                Text(node.nodeType.displayName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(node.nodeType.color)

                Text("Parameter Value")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 16) {
                    Button {
                        updateNodeParameter(nodeId: node.id, delta: -5)
                        HapticManager.impact(.light)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.red.opacity(0.7))
                    }

                    Text("\(node.parameter)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(minWidth: 60)

                    Button {
                        updateNodeParameter(nodeId: node.id, delta: 5)
                        HapticManager.impact(.light)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green.opacity(0.7))
                    }
                }

                HStack(spacing: 12) {
                    // Delete node
                    Button {
                        deleteNode(nodeId: node.id)
                        editingNodeId = nil
                        HapticManager.impact(.medium)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                    }

                    // Connect
                    Button {
                        connectingFromId = node.id
                        editingNodeId = nil
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("Connect")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    }

                    Button {
                        editingNodeId = nil
                    } label: {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(node.nodeType.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(40)
        }
    }

    // MARK: - Actions

    private func addPipeline() {
        let name = "Pipeline \((pipelines.count) + 1)"
        var pipeline = AutomationPipeline(name: name)
        pipeline.isEnabled = true
        engine.playerStates[player]?.pipelines.append(pipeline)
        selectedPipelineIndex = (engine.playerStates[player]?.pipelines.count ?? 1) - 1
    }

    private func addNode(_ type: AutoNodeType) {
        guard selectedPipelineIndex < (engine.playerStates[player]?.pipelines.count ?? 0) else {
            addPipeline()
            return
        }
        let position = CGPoint(x: CGFloat.random(in: 50...250), y: CGFloat.random(in: 50...300))
        let node = AutomationNode(nodeType: type, position: position, parameter: 10)
        engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes.append(node)
    }

    private func updateNodePosition(nodeId: UUID, position: CGPoint) {
        guard selectedPipelineIndex < (engine.playerStates[player]?.pipelines.count ?? 0) else { return }
        if let idx = engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
            engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes[idx].position = position
        }
    }

    private func updateNodeParameter(nodeId: UUID, delta: Int) {
        guard selectedPipelineIndex < (engine.playerStates[player]?.pipelines.count ?? 0) else { return }
        if let idx = engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
            let current = engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes[idx].parameter ?? 0
            engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes[idx].parameter = max(0, current + delta)
        }
    }

    private func deleteNode(nodeId: UUID) {
        guard selectedPipelineIndex < (engine.playerStates[player]?.pipelines.count ?? 0) else { return }
        engine.playerStates[player]?.pipelines[selectedPipelineIndex].nodes.removeAll { $0.id == nodeId }
        engine.playerStates[player]?.pipelines[selectedPipelineIndex].connections.removeAll {
            $0.fromNodeId == nodeId || $0.toNodeId == nodeId
        }
    }
}
