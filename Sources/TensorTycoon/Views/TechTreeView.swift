import SwiftUI

// MARK: - Layout (computed once per launch)

/// Where every technique in the research tree sits on the graph: one lane per category, one column per era, and the
/// prerequisite edges between them. The catalogue never changes during a game, so the layout is built once (a static)
/// and every redraw only reads it.
struct TechTreeLayout {
    struct Node {
        let item: ResearchItem
        /// Centre of the node, in unzoomed graph points.
        let center: CGPoint
        let column: Int
    }

    struct Edge: Hashable {
        let from: Int
        let to: Int
    }

    struct Lane {
        let category: ResearchCategory
        let top: CGFloat
        let height: CGFloat
    }

    struct Column {
        let label: String
        let x: CGFloat
    }

    static let nodeWidth: CGFloat = 176
    static let nodeHeight: CGFloat = 50
    static let columnWidth: CGFloat = 204
    static let rowHeight: CGFloat = 60
    static let headerHeight: CGFloat = 34
    static let laneGutter: CGFloat = 150
    static let lanePadding: CGFloat = 10

    let nodes: [Node]
    let index: [String: Int]
    let edges: [Edge]
    let lanes: [Lane]
    let columns: [Column]
    let width: CGFloat
    let height: CGFloat
    /// Prerequisites of each node (node indices), and the nodes that need it.
    let parents: [[Int]]
    let children: [[Int]]
    /// Every node downstream of each node (for the "locked by" filter).
    let descendants: [[Int]]
    /// Longest prerequisite chain under each node (for ordering a path to here).
    let depth: [Int]

    /// The tree the Research screen shows: the same techniques as the grid view.
    static let shared = TechTreeLayout(ResearchCatalog.core + ResearchCatalog.lateGame + ResearchCatalog.capabilityTech)

    /// Columns are whole years before 2022 and after 2027 (few techniques) and half years in between (most of them).
    static func bucket(_ year: Double) -> Int {
        let y = max(2016, year)
        if y < 2022 || y >= 2028 { return Int(y.rounded(.down)) * 2 }
        return Int((y * 2).rounded(.down))
    }

    static func bucketLabel(_ b: Int) -> String {
        let year = b / 2
        if year < 2022 || year >= 2028 { return "\(year)" }
        return b % 2 == 0 ? "\(year) H1" : "\(year) H2"
    }

    init(_ items: [ResearchItem]) {
        let cats = ResearchCategory.allCases.filter { c in items.contains { $0.category == c } }
        let buckets = Array(Set(items.map { Self.bucket($0.year) })).sorted()
        var colOf: [Int: Int] = [:]
        for (i, b) in buckets.enumerated() { colOf[b] = i }

        // Cells: lane × column → techniques, oldest first.
        var cells: [ResearchCategory: [Int: [ResearchItem]]] = [:]
        for it in items { cells[it.category, default: [:]][colOf[Self.bucket(it.year)] ?? 0, default: []].append(it) }
        for c in cells.keys {
            for col in cells[c]!.keys {
                cells[c]![col]!.sort { $0.year != $1.year ? $0.year < $1.year : $0.name < $1.name }
            }
        }

        // Lane geometry.
        var lanes: [Lane] = []
        var laneTop: [ResearchCategory: CGFloat] = [:]
        var y = Self.headerHeight
        for c in cats {
            let rows = max(1, cells[c]?.values.map(\.count).max() ?? 1)
            let h = CGFloat(rows) * Self.rowHeight + 2 * Self.lanePadding
            lanes.append(Lane(category: c, top: y, height: h))
            laneTop[c] = y
            y += h
        }

        func center(_ c: ResearchCategory, col: Int, row: Int) -> CGPoint {
            CGPoint(x: Self.laneGutter + CGFloat(col) * Self.columnWidth + Self.columnWidth / 2,
                    y: (laneTop[c] ?? 0) + Self.lanePadding + CGFloat(row) * Self.rowHeight + Self.rowHeight / 2)
        }

        // First pass: rows by date. Second pass, column by column: order each cell by where its prerequisites sit
        // (barycentre), which untangles most of the edges.
        var pos: [String: CGPoint] = [:]
        for c in cats { for (col, list) in cells[c] ?? [:] { for (r, it) in list.enumerated() { pos[it.id] = center(c, col: col, row: r) } } }
        for col in 0..<buckets.count {
            for c in cats {
                guard var list = cells[c]?[col], list.count > 1 else { continue }
                let key: [String: Double] = Dictionary(uniqueKeysWithValues: list.map { it in
                    let ys = it.prereqs.compactMap { pos[$0]?.y }
                    return (it.id, ys.isEmpty ? Double(pos[it.id]?.y ?? 0) : Double(ys.reduce(0, +)) / Double(ys.count))
                })
                list.sort { (key[$0.id] ?? 0, $0.year) < (key[$1.id] ?? 0, $1.year) }
                cells[c]![col] = list
                for (r, it) in list.enumerated() { pos[it.id] = center(c, col: col, row: r) }
            }
        }

        // Nodes in a stable order: lane, then column, then row.
        var nodes: [Node] = []
        for c in cats {
            for col in (cells[c] ?? [:]).keys.sorted() {
                for it in cells[c]![col]! { nodes.append(Node(item: it, center: pos[it.id] ?? .zero, column: col)) }
            }
        }
        var index: [String: Int] = [:]
        for (i, n) in nodes.enumerated() { index[n.item.id] = i }

        var parents = Array(repeating: [Int](), count: nodes.count)
        var children = Array(repeating: [Int](), count: nodes.count)
        var edges: [Edge] = []
        for (i, n) in nodes.enumerated() {
            for p in n.item.prereqs {
                guard let j = index[p], j != i else { continue }
                parents[i].append(j)
                children[j].append(i)
                edges.append(Edge(from: j, to: i))
            }
        }

        var depth = Array(repeating: -1, count: nodes.count)
        func depthOf(_ i: Int, _ guardSet: inout Set<Int>) -> Int {
            if depth[i] >= 0 { return depth[i] }
            if guardSet.contains(i) { return 0 }   // a cycle would be a catalogue bug; don't hang on it
            guardSet.insert(i)
            let d = parents[i].map { depthOf($0, &guardSet) + 1 }.max() ?? 0
            guardSet.remove(i)
            depth[i] = d
            return d
        }
        for i in nodes.indices {
            var g = Set<Int>()
            _ = depthOf(i, &g)
        }

        var descendants = Array(repeating: [Int](), count: nodes.count)
        for i in nodes.indices {
            var seen = Set<Int>()
            var stack = children[i]
            while let k = stack.popLast() {
                if seen.insert(k).inserted { stack.append(contentsOf: children[k]) }
            }
            descendants[i] = seen.sorted()
        }

        self.nodes = nodes
        self.index = index
        self.edges = edges
        self.lanes = lanes
        self.columns = buckets.enumerated().map { i, b in
            Column(label: Self.bucketLabel(b), x: Self.laneGutter + CGFloat(i) * Self.columnWidth + Self.columnWidth / 2)
        }
        self.width = Self.laneGutter + CGFloat(buckets.count) * Self.columnWidth + 16
        self.height = y + 12
        self.parents = parents
        self.children = children
        self.descendants = descendants
        self.depth = depth
    }

    /// Every prerequisite above a node, nearest last: the path you'd research to get here.
    func ancestors(of i: Int) -> Set<Int> {
        var seen = Set<Int>()
        var stack = parents[i]
        while let k = stack.popLast() {
            if seen.insert(k).inserted { stack.append(contentsOf: parents[k]) }
        }
        return seen
    }
}

// MARK: - Node state

enum TechStatus: Equatable {
    case researched, researching, queued(Int), available, locked

    var word: String {
        switch self {
        case .researched: "Researched"
        case .researching: "Researching"
        case .queued(let n): "Queued #\(n + 1)"
        case .available: "Available"
        case .locked: "Locked"
        }
    }

    var symbol: String {
        switch self {
        case .researched: "checkmark.seal.fill"
        case .researching: "hourglass"
        case .queued: "list.number"
        case .available: "play.circle.fill"
        case .locked: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .researched: Theme.good
        case .researching, .queued: .pink
        case .available: .teal
        case .locked: Theme.neutral
        }
    }

    static func of(_ item: ResearchItem, _ s: GameState) -> TechStatus {
        if s.researched.contains(item.id) { return .researched }
        if let q = s.researchQueue.firstIndex(of: item.id) { return q == 0 ? .researching : .queued(q) }
        if item.isExotic && !s.exoticOwned.contains(item.id) { return .locked }
        if !XenoScience.researchUnlocked(item.id, s) { return .locked }
        return item.prereqs.allSatisfy { s.researched.contains($0) } ? .available : .locked
    }
}

// MARK: - The tree

/// A navigable graph of the research catalogue: eras left to right, categories top to bottom, prerequisite edges between.
/// Pan by scrolling, zoom with a pinch or the buttons, filter and search; select a technique to see its card, the path
/// that leads to it, and research it (the same queue action as the grid).
struct TechTreeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: GameState

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Everything", available = "Available now", researched = "Researched", locked = "Locked", queue = "In the queue"
        var id: String { rawValue }
    }

    @State private var selectedID: String? = nil
    @State private var category: ResearchCategory? = nil
    @State private var statusFilter: StatusFilter = .all
    @State private var blocker: String? = nil
    @State private var query = ""
    @State private var zoom: CGFloat = 0.8
    @State private var pinchStart: CGFloat? = nil
    /// A technique to bring into view (search hits and path steps; clicking a node never scrolls under the pointer).
    @State private var scrollTarget: String? = nil

    private static let zoomRange: ClosedRange<CGFloat> = 0.3...1.6

    var body: some View {
        let s = state
        let layout = TechTreeLayout.shared
        let statuses = layout.nodes.map { TechStatus.of($0.item, s) }
        let selected = selectedID.flatMap { layout.index[$0] }
        let path = selected.map { layout.ancestors(of: $0) } ?? []
        let blockerIndex = blocker.flatMap { layout.index[$0] }
        let blocked: Set<Int> = blockerIndex.map { Set(layout.descendants[$0]) } ?? []
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let visible: [Bool] = layout.nodes.indices.map { i in
            let it = layout.nodes[i].item
            if let category, it.category != category { return false }
            switch statusFilter {
            case .all: break
            case .available: if statuses[i] != .available { return false }
            case .researched: if statuses[i] != .researched { return false }
            case .locked: if statuses[i] != .locked { return false }
            case .queue:
                switch statuses[i] { case .researching, .queued: break; default: return false }
            }
            if blockerIndex != nil && !blocked.contains(i) { return false }
            if !q.isEmpty && !it.name.lowercased().contains(q) && !it.blurb.lowercased().contains(q) { return false }
            return true
        }
        let filtering = category != nil || statusFilter != .all || blockerIndex != nil || !q.isEmpty
        let shown = visible.filter { $0 }.count

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            controls(s, layout: layout, statuses: statuses, shown: shown, filtering: filtering)
            legend
            graph(layout: layout, statuses: statuses, selected: selected, path: path, visible: visible, filtering: filtering)
            if let i = selected {
                TechDetailPanel(index: i, path: path, statuses: statuses, state: s) { id in
                    select(id)
                    scrollTarget = id
                }
            } else {
                Text("Select a technique to see what it does, everything it needs, and research it. Pinch or use the zoom buttons; scroll to pan.")
                    .font(TypeRamp.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(_ s: GameState, layout: TechTreeLayout, statuses: [TechStatus], shown: Int, filtering: Bool) -> some View {
        // The techniques holding back the most locked work, for the "locked by" filter.
        let blockers: [Blocker] = layout.nodes.indices.compactMap { i in
            guard statuses[i] != .researched else { return nil }
            let n = layout.descendants[i].filter { statuses[$0] == .locked }.count
            return n > 0 ? Blocker(id: layout.nodes[i].item.id, name: layout.nodes[i].item.name, count: n) : nil
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        HStack(spacing: Theme.Space.s) {
            TextField("Search techniques", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)
                .onSubmit { jumpToFirstMatch(layout) }
            Picker("Category", selection: $category) {
                Text("All categories").tag(ResearchCategory?.none)
                Divider()
                ForEach(layout.lanes.map(\.category)) { c in
                    Label(c.rawValue, systemImage: c.symbol).tag(Optional(c))
                }
            }
            .labelsHidden()
            .frame(width: 190)
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .labelsHidden()
            .frame(width: 150)
            Picker("Locked by", selection: $blocker) {
                Text("Locked by anything").tag(String?.none)
                Divider()
                ForEach(Array(blockers.prefix(25))) { b in
                    Text("\(b.name) — holds back \(b.count)").tag(Optional(b.id))
                }
            }
            .labelsHidden()
            .frame(width: 210)
            .help("Show only what a technique you haven't researched yet is holding back.")
            if filtering {
                Button("Clear") {
                    category = nil
                    statusFilter = .all
                    blocker = nil
                    query = ""
                }
                .buttonStyle(.borderless)
                Text("\(shown) shown").font(TypeRamp.captionNumber).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private struct Blocker: Identifiable {
        let id: String
        let name: String
        let count: Int
    }

    private var zoomControls: some View {
        HStack(spacing: Theme.Space.xs) {
            Button { setZoom(zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .help("Zoom out")
                .accessibilityLabel("Zoom out")
                .disabled(zoom <= Self.zoomRange.lowerBound + 0.001)
            Text("\(Int((zoom * 100).rounded()))%")
                .font(TypeRamp.captionNumber)
                .frame(width: 40)
                .accessibilityLabel("Zoom \(Int((zoom * 100).rounded())) percent")
            Button { setZoom(zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .help("Zoom in")
                .accessibilityLabel("Zoom in")
                .disabled(zoom >= Self.zoomRange.upperBound - 0.001)
            Button("Overview") { setZoom(Self.zoomRange.lowerBound) }
                .help("Zoom out to see the whole tree")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var legend: some View {
        HStack(spacing: Theme.Space.m) {
            ForEach([TechStatus.researched, .researching, .available, .locked], id: \.word) { st in
                Label(st == .researching ? "In progress / queued" : st.word, systemImage: st.symbol)
                    .font(TypeRamp.caption)
                    .foregroundStyle(st.color)
            }
            Label("Path to selection", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                .font(TypeRamp.caption)
                .foregroundStyle(Theme.accent)
            Spacer(minLength: 0)
            zoomControls
        }
    }

    // MARK: Graph

    private func graph(layout: TechTreeLayout, statuses: [TechStatus], selected: Int?, path: Set<Int>, visible: [Bool], filtering: Bool) -> some View {
        let z = zoom
        let onPath: Set<Int> = selected.map { path.union([$0]) } ?? []
        let edgeState: [TechEdgeLayer.EdgeStyle] = layout.edges.map { e in
            if onPath.contains(e.to) && onPath.contains(e.from) { return .path }
            if filtering && !(visible[e.from] && visible[e.to]) { return .faded }
            if statuses[e.from] == .researched && statuses[e.to] == .researched { return .done }
            return .normal
        }
        return ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    TechEdgeLayer(zoom: z, styles: edgeState).equatable()
                        .frame(width: layout.width * z, height: layout.height * z)
                        .accessibilityHidden(true)
                    ForEach(Array(layout.columns.enumerated()), id: \.offset) { _, col in
                        Text(col.label)
                            .font(TypeRamp.label)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .scaleEffect(max(z, 0.6))
                            .position(x: col.x * z, y: TechTreeLayout.headerHeight / 2 * z)
                            .accessibilityHidden(true)
                    }
                    ForEach(layout.lanes, id: \.category) { lane in
                        Label(lane.category.rawValue, systemImage: lane.category.symbol)
                            .font(TypeRamp.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(width: TechTreeLayout.laneGutter - 16, alignment: .leading)
                            .scaleEffect(z, anchor: .leading)
                            .position(x: (TechTreeLayout.laneGutter - 16) / 2 + 6 * z, y: (lane.top + 18) * z)
                            .id("lane-\(lane.category.rawValue)")
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(layout.nodes.indices, id: \.self) { i in
                        let n = layout.nodes[i]
                        let id = n.item.id
                        TechNodeView(name: n.item.name, category: n.item.category, year: n.item.year, status: statuses[i],
                                     progress: progress(n.item),
                                     selected: selected == i, onPath: path.contains(i), dimmed: filtering && !visible[i] && selected != i,
                                     missing: statuses[i] == .locked ? n.item.prereqs.filter { !state.researched.contains($0) }.count : 0) {
                            select(selectedID == id ? nil : id)
                        }
                        .equatable()
                        .frame(width: TechTreeLayout.nodeWidth, height: TechTreeLayout.nodeHeight)
                        .scaleEffect(z)
                        .position(x: n.center.x * z, y: n.center.y * z)
                        .id(id)
                    }
                }
                .frame(width: layout.width * z, height: layout.height * z, alignment: .topLeading)
            }
            .frame(height: 560)
            .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.tile))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(Theme.hairline, lineWidth: 0.5))
            .clipShape(.rect(cornerRadius: Theme.Radius.tile))
            .gesture(
                MagnifyGesture()
                    .onChanged { v in
                        if pinchStart == nil { pinchStart = zoom }
                        zoom = clamp((pinchStart ?? zoom) * v.magnification, Self.zoomRange.lowerBound, Self.zoomRange.upperBound)
                    }
                    .onEnded { _ in pinchStart = nil }
            )
            .onChange(of: category) { _, c in
                guard let c else { return }
                scroll(proxy, to: "lane-\(c.rawValue)", anchor: .topLeading)
            }
            .onChange(of: scrollTarget) { _, id in
                guard let id else { return }
                scroll(proxy, to: id, anchor: .center)
                scrollTarget = nil
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Research tree graph")
        }
    }

    private func progress(_ item: ResearchItem) -> Double {
        guard let p = state.researchProgress[item.id], p > 0 else { return 0 }
        let cost = Sim.researchCost(item, year: state.year)
        return (min(1, p / max(cost, 1)) * 50).rounded() / 50   // 2% steps: nodes redraw only when it visibly moves
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: anchor)
        } else {
            withAnimation(.smooth) { proxy.scrollTo(id, anchor: anchor) }
        }
    }

    private func setZoom(_ z: CGFloat) {
        let v = clamp(z, Self.zoomRange.lowerBound, Self.zoomRange.upperBound)
        if reduceMotion { zoom = v } else { withAnimation(.snappy) { zoom = v } }
    }

    private func select(_ id: String?) {
        if reduceMotion { selectedID = id } else { withAnimation(.snappy) { selectedID = id } }
    }

    private func jumpToFirstMatch(_ layout: TechTreeLayout) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return }
        let hit = layout.nodes.first { $0.item.name.lowercased().contains(q) } ?? layout.nodes.first { $0.item.blurb.lowercased().contains(q) }
        if let hit {
            select(hit.item.id)
            scrollTarget = hit.item.id
        } else { store.show("No technique matches “\(query)”", error: true) }
    }
}

// MARK: - Edges (one Canvas for all of them)

private struct TechEdgeLayer: View, Equatable {
    enum EdgeStyle: Equatable { case normal, done, path, faded }

    let zoom: CGFloat
    let styles: [EdgeStyle]

    var body: some View {
        Canvas { ctx, _ in
            let layout = TechTreeLayout.shared
            let z = zoom
            // Lane bands and column rules first, so edges sit on top.
            for (i, lane) in layout.lanes.enumerated() where i % 2 == 1 {
                ctx.fill(Path(CGRect(x: 0, y: lane.top * z, width: layout.width * z, height: lane.height * z)),
                         with: .color(Color.primary.opacity(0.035)))
            }
            for col in layout.columns {
                let x = (col.x - TechTreeLayout.columnWidth / 2) * z
                var rule = Path()
                rule.move(to: CGPoint(x: x, y: 0))
                rule.addLine(to: CGPoint(x: x, y: layout.height * z))
                ctx.stroke(rule, with: .color(Color.primary.opacity(0.06)), lineWidth: 1)
            }
            // Batch edges by style: four strokes for the whole tree.
            var paths: [EdgeStyle: Path] = [.normal: Path(), .done: Path(), .path: Path(), .faded: Path()]
            let hw = TechTreeLayout.nodeWidth / 2
            let hh = TechTreeLayout.nodeHeight / 2
            for (k, e) in layout.edges.enumerated() where k < styles.count {
                let a = layout.nodes[e.from].center
                let b = layout.nodes[e.to].center
                var p = paths[styles[k]] ?? Path()
                if b.x > a.x + 1 {
                    let start = CGPoint(x: (a.x + hw) * z, y: a.y * z)
                    let end = CGPoint(x: (b.x - hw) * z, y: b.y * z)
                    let dx = max(24 * z, (end.x - start.x) * 0.45)
                    p.move(to: start)
                    p.addCurve(to: end, control1: CGPoint(x: start.x + dx, y: start.y), control2: CGPoint(x: end.x - dx, y: end.y))
                } else {
                    // Same era: drop from one node's edge to the other's.
                    let down = b.y > a.y
                    let start = CGPoint(x: a.x * z, y: (a.y + (down ? hh : -hh)) * z)
                    let end = CGPoint(x: b.x * z, y: (b.y + (down ? -hh : hh)) * z)
                    p.move(to: start)
                    p.addCurve(to: end, control1: CGPoint(x: start.x + 30 * z, y: start.y), control2: CGPoint(x: end.x + 30 * z, y: end.y))
                }
                paths[styles[k]] = p
            }
            if let p = paths[.faded] { ctx.stroke(p, with: .color(Color.secondary.opacity(0.08)), lineWidth: 1) }
            if let p = paths[.normal] { ctx.stroke(p, with: .color(Color.secondary.opacity(0.3)), lineWidth: 1) }
            if let p = paths[.done] { ctx.stroke(p, with: .color(Theme.good.opacity(0.4)), lineWidth: 1.2) }
            if let p = paths[.path] { ctx.stroke(p, with: .color(Theme.accent), lineWidth: max(1.5, 2.5 * z)) }
        }
    }
}

// MARK: - Node

private struct TechNodeView: View, Equatable {
    let name: String
    let category: ResearchCategory
    let year: Double
    let status: TechStatus
    let progress: Double
    let selected: Bool
    let onPath: Bool
    let dimmed: Bool
    let missing: Int
    let action: () -> Void

    static func == (a: TechNodeView, b: TechNodeView) -> Bool {
        a.name == b.name && a.status == b.status && a.progress == b.progress && a.selected == b.selected
            && a.onPath == b.onPath && a.dimmed == b.dimmed && a.missing == b.missing
    }

    var body: some View {
        let tint = status.color
        let border: Color = selected ? Theme.accent : (onPath ? Theme.accent.opacity(0.7) : tint.opacity(status == .locked ? 0.35 : 0.8))
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: status.symbol)
                        .font(.caption2)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status == .locked ? Color.secondary : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 4) {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: category.symbol).font(.caption2).foregroundStyle(.tertiary).accessibilityHidden(true)
                }
                .padding(.leading, 17)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fill, in: .rect(cornerRadius: Theme.Radius.control))
            .overlay(alignment: .bottom) {
                if progress > 0 && status != .researched {
                    GeometryReader { geo in
                        Capsule().fill(Color.pink).frame(width: max(3, geo.size.width * progress), height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 3)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(border, lineWidth: selected ? 3 : (onPath ? 2 : 1)))
            .contentShape(.rect(cornerRadius: Theme.Radius.control))
        }
        .buttonStyle(.plain)
        .opacity(dimmed ? 0.22 : 1)
        .help(help)
        .accessibilityLabel("\(name), \(category.rawValue), \(status.word)\(missing > 0 ? ", needs \(missing) more" : "")")
        .accessibilityHint("Shows the technique and the path to it")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: Color {
        switch status {
        case .researched: Theme.good.opacity(0.14)
        case .researching, .queued: Color.pink.opacity(0.12)
        case .available: Color.teal.opacity(0.10)
        case .locked: Color.primary.opacity(0.04)
        }
    }

    private var subtitle: String {
        let era = year >= 2027 ? "Future" : "\(Int(year))"
        switch status {
        case .locked: return missing > 0 ? "\(era) · needs \(missing)" : "\(era) · locked"
        case .researching: return "\(era) · \(Int((progress * 100).rounded()))%"
        default: return "\(era) · \(status.word)"
        }
    }

    private var help: String {
        "\(name) — \(status.word)" + (missing > 0 ? ". \(missing) prerequisite\(missing == 1 ? "" : "s") still to research." : "")
    }
}

// MARK: - Detail

/// The selected technique: its card (the same one as the grid), the path that leads to it, and the research action.
private struct TechDetailPanel: View {
    @Environment(GameStore.self) private var store
    let index: Int
    let path: Set<Int>
    let statuses: [TechStatus]
    let state: GameState
    let onSelect: (String?) -> Void

    var body: some View {
        let layout = TechTreeLayout.shared
        let s = state
        let item = layout.nodes[index].item
        let status = statuses[index]
        // Remaining steps, in an order you could research them: shallowest first.
        let steps = path.filter { statuses[$0] != .researched }
            .sorted { (layout.depth[$0], layout.nodes[$0].item.year) < (layout.depth[$1], layout.nodes[$1].item.year) }
        let done = path.count - steps.count
        let lockedReason: String? = {
            guard status == .locked else { return nil }
            if let why = ResearchLab.blockReason(s, item.id) { return why }   // 3.9: names the alien find it needs, or the blocked prerequisite
            let names = item.prereqs.filter { !s.researched.contains($0) }.compactMap { ResearchCatalog.byID[$0]?.name }
            return names.isEmpty ? nil : "Locked by: " + names.joined(separator: ", ")
        }()
        let unlocks = layout.children[index].map { layout.nodes[$0].item }
        HStack(alignment: .top, spacing: Theme.gap) {
            ResearchCard.make(item, state: s).equatable()
                .frame(maxWidth: 380)
            Card {
                CardHeader(title: "Path to here", symbol: "point.topleft.down.to.point.bottomright.curvepath.fill",
                           subtitle: path.isEmpty ? "No prerequisites." : "\(done) of \(path.count) prerequisites researched") {
                    Button { onSelect(nil) } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical) }
                        .buttonStyle(.borderless)
                        .help("Close")
                        .accessibilityLabel("Close details")
                }
                if let lockedReason {
                    Label(lockedReason, systemImage: "lock.fill").font(TypeRamp.caption).foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !steps.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        ForEach(Array(steps.prefix(12).enumerated()), id: \.element) { n, i in
                            let step = layout.nodes[i].item
                            Button { onSelect(step.id) } label: {
                                HStack(spacing: 6) {
                                    Text("\(n + 1).").font(TypeRamp.captionNumber).foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
                                    Image(systemName: statuses[i].symbol).foregroundStyle(statuses[i].color).font(.caption)
                                        .accessibilityHidden(true)
                                    Text(step.name).font(TypeRamp.caption).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("\(Fmt.count(Sim.researchCost(step, year: s.year))) RP").font(TypeRamp.captionNumber).foregroundStyle(.secondary)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Step \(n + 1): \(step.name), \(statuses[i].word)")
                        }
                        if steps.count > 12 {
                            Text("…and \(steps.count - 12) more").font(TypeRamp.micro).foregroundStyle(.secondary)
                        }
                    }
                    let total = steps.reduce(0.0) { $0 + Sim.researchCost(layout.nodes[$1].item, year: s.year) }
                        + (status == .researched ? 0 : Sim.researchCost(item, year: s.year))
                    Text("About \(Fmt.count(total)) RP to get here from what you know today.")
                        .font(TypeRamp.micro).foregroundStyle(.secondary)
                }
                if !unlocks.isEmpty {
                    Text("Leads to: " + unlocks.map(\.name).joined(separator: ", "))
                        .font(TypeRamp.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    researchButton(item, status: status, missing: steps.count)
                }
            }
        }
    }

    @ViewBuilder
    private func researchButton(_ item: ResearchItem, status: TechStatus, missing: Int) -> some View {
        switch status {
        case .researched:
            Label("Researched", systemImage: "checkmark.seal.fill").font(TypeRamp.body).foregroundStyle(Theme.good)
        case .researching, .queued:
            Button("Remove from queue") {
                store.act("Removed \(item.name) from the queue") { $0.removeResearch(item.id) }
            }
        case .available, .locked:
            // The same action as the grid's card: queue it; missing prerequisites are researched first.
            Button(missing > 0 ? "Research (\(missing) prerequisite\(missing == 1 ? "" : "s") first)" : "Research") {
                store.act(missing == 0 ? "Queued \(item.name)" : "Queued \(item.name) (prerequisites will be researched first)") { $0.queueResearch(item.id) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(lockedOut(item))
        }
    }

    /// Exotic techniques you don't own and alien-gated ones can't be queued at all, nor can anything that needs one.
    private func lockedOut(_ item: ResearchItem) -> Bool { ResearchLab.blocked(state, item.id) }
}
