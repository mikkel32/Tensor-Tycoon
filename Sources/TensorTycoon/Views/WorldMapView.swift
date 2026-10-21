import SwiftUI

// MARK: - 3.9: World Map

/// Your lab on a living map of the world: campuses sized by megawatts, offices, power plants and fabs; rival labs and
/// the training runs the rumour mill has found; foundries and suppliers; the agencies that buy programmes; export-control
/// zones; and animated flows of chips and money. Tap a pin for details and a link to its screen. Everything comes
/// from `WorldMap.snapshot`.
struct WorldMapView: View {
    @Environment(GameStore.self) private var store
    @State private var layers: Set<MapLayer>? = nil
    @State private var flows = true
    @State private var zones = WorldMapRender.zones
    @State private var camera = WorldMapRender.camera ?? MapCamera.world
    @State private var selected: String? = nil
    @State private var lastLook: Date? = nil
    @State private var looked = false
    @State private var replayStart: Date? = nil

    static let replaySeconds = 12.0

    var body: some View {
        let s = store.game
        let snap = WorldMap.snapshot(s)
        let shown = layers ?? Self.defaultLayers(s)
        Group {
            if WorldMapRender.offscreen {
                // ImageRenderer doesn't draw scroll views: the render check lays the page out flat.
                VStack(alignment: .leading, spacing: 18) { content(s, snap, shown) }.padding(Theme.pagePadding)
            } else {
                Page(title: "World Map", subtitle: "Where your lab lives and works, who you're racing and where the chips come from. Tap any pin for details; drag and pinch to explore.", screen: .worldMap) {
                    content(s, snap, shown)
                }
            }
        }
        .onAppear {
            guard !looked else { return }
            looked = true
            lastLook = s.worldMap.lastLook
        }
        .onDisappear {
            // Pins newer than this lose their "New" tag next time.
            store.mutate { $0.worldMap.lastLook = $0.date }
        }
    }

    @ViewBuilder
    private func content(_ s: GameState, _ snap: MapSnapshot, _ shown: Set<MapLayer>) -> some View {
            MapKPIs(snap: snap)
            Card(padding: Theme.Space.m) {
                MapToolbar(layers: Binding(get: { shown }, set: { layers = $0 }), flows: $flows, zones: $zones, camera: $camera,
                           replaying: replayStart != nil, counts: Self.counts(snap), fit: { fit(snap, shown) }, replay: startReplay)
                MapStageHost(snap: snap, layers: shown, flows: flows, zones: zones, camera: $camera, selected: $selected,
                             lastLook: lastLook, replayStart: replayStart, start: s.startDate, now: s.date,
                             company: Theme.logoColor(s.logoColor))
                MapLegend(snap: snap, layers: shown, flows: flows, zones: zones)
            }
            CardGrid(minWidth: 360, maxColumns: 2) {
                MapExposureCard(snap: snap)
                MapZonesCard(snap: snap, home: HQ.region(s), focus: { r in focus(WorldMapGeo.anchor(r), zoom: 2.2); zones = true })
            }
            CardGrid(minWidth: 360, maxColumns: 2) {
                MapExpansionCard(state: s, hq: snap.hq, focus: { p in focus(p, zoom: 3) })
                MapPlacesCard(snap: snap, select: { pin in
                    layers = shown.union([pin.layer])
                    focus(pin.point, zoom: 3)
                    selected = pin.id
                })
            }
    }

    /// Government shows once you've worked with an agency; the rest from the start.
    static func defaultLayers(_ s: GameState) -> Set<MapLayer> {
        s.advanced.engaged || !s.advanced.programmes.isEmpty ? Set(MapLayer.allCases) : [.yours, .rivals, .supply]
    }

    static func counts(_ snap: MapSnapshot) -> [MapLayer: Int] {
        Dictionary(grouping: snap.pins, by: \.layer).mapValues { $0.filter(\.active).count }
    }

    private func focus(_ p: GeoPoint, zoom: Double) {
        let target = MapCamera(zoom: zoom, center: p).clamped()
        if store.reduceAnimations { camera = target } else { withAnimation(.smooth(duration: 0.9)) { camera = target } }
    }

    /// Zoom to everything you have on the visible layers.
    private func fit(_ snap: MapSnapshot, _ shown: Set<MapLayer>) {
        let pts = snap.pins.filter { shown.contains($0.layer) && ($0.layer == .yours || $0.active) }.map(\.point)
        guard let minLon = pts.map(\.lon).min(), let maxLon = pts.map(\.lon).max(), let minLat = pts.map(\.lat).min(), let maxLat = pts.map(\.lat).max() else { return }
        let lonSpan = max(12, (maxLon - minLon) * 1.35)
        let latSpan = max(8, (maxLat - minLat) * 1.5)
        let zoom = min(6, max(1, min(350 / lonSpan, 134 / latSpan)))
        focus(GeoPoint((minLon + maxLon) / 2, (minLat + maxLat) / 2), zoom: zoom)
    }

    private func startReplay() {
        selected = nil
        replayStart = .now
        camera = .world
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.replaySeconds + 1.5))
            replayStart = nil
        }
    }
}

// MARK: - Camera and projection

/// What part of the world is in view: a zoom (1 = the whole map) and the point at the centre.
struct MapCamera: Equatable {
    var zoom: Double
    var center: GeoPoint

    static let world = MapCamera(zoom: 1, center: GeoPoint(5, 11))

    static let presets: [(name: String, camera: MapCamera)] = [
        ("World", .world),
        ("North America", MapCamera(zoom: 2.6, center: GeoPoint(-96, 40))),
        ("Europe", MapCamera(zoom: 3.4, center: GeoPoint(12, 51))),
        ("Middle East & India", MapCamera(zoom: 2.6, center: GeoPoint(62, 25))),
        ("East Asia", MapCamera(zoom: 2.8, center: GeoPoint(122, 32))),
    ]

    /// Keeps the view on the map: at zoom 1 the whole map is centred; zoomed in, the centre can't wander off the edge.
    func clamped() -> MapCamera {
        let z = min(8, max(1, zoom))
        let halfLon = 175 / z, halfLat = 67 / z
        let lon = min(180 - halfLon, max(-170 + halfLon, center.lon))
        let lat = min(78 - halfLat * 0.8, max(-56 + halfLat * 0.8, center.lat))
        return MapCamera(zoom: z, center: z <= 1.001 ? MapCamera.world.center : GeoPoint(lon, lat))
    }
}

/// Miller cylindrical projection: like Mercator in the tropics, with the high latitudes tamed.
struct MapProjection {
    let size: CGSize
    let zoom: Double
    let center: GeoPoint

    static func millerY(_ lat: Double) -> Double { 1.25 * log(tan(.pi / 4 + 0.4 * lat * .pi / 180)) }
    static let worldW = (WorldMapGeo.lonRange.upperBound - WorldMapGeo.lonRange.lowerBound) * .pi / 180
    static let worldH = millerY(WorldMapGeo.latRange.upperBound) - millerY(WorldMapGeo.latRange.lowerBound)
    /// The map's natural width over height.
    static let aspect = worldW / worldH

    var scale: Double { min(size.width / Self.worldW, size.height / Self.worldH) * zoom }

    func point(_ g: GeoPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + (g.lon - center.lon) * .pi / 180 * scale,
                y: size.height / 2 - (Self.millerY(g.lat) - Self.millerY(center.lat)) * scale)
    }

    /// Degrees of longitude and latitude a screen move of `d` points covers (near the centre).
    func degrees(_ d: CGSize) -> (lon: Double, lat: Double) {
        let lon = d.width / scale * 180 / .pi
        let dy = d.height / scale
        let y0 = Self.millerY(center.lat)
        let lat = (atan(exp((y0 + dy) / 1.25)) - .pi / 4) / 0.4 * 180 / .pi
        return (lon, lat - center.lat)
    }

    /// Point size of one dot of the matrix.
    var dotPitch: Double { WorldMapGeo.dotStep * .pi / 180 * scale }
}

// MARK: - Colours

enum MapPalette {
    static let mine = Color(red: 0.13, green: 0.68, blue: 1.0)
    static let building = Color(red: 1.0, green: 0.62, blue: 0.1)
    static let power = Color(red: 0.98, green: 0.78, blue: 0.1)
    static let supply = Color(red: 0.62, green: 0.45, blue: 1.0)
    static let alien = Color(red: 0.25, green: 1.0, blue: 0.62)
    static let government = Color(red: 0.12, green: 0.78, blue: 0.7)
    static let money = Color(red: 0.2, green: 0.85, blue: 0.4)
    static let cost = Color(red: 1.0, green: 0.45, blue: 0.25)

    static func color(_ t: MapTone) -> Color {
        switch t {
        case .mine: mine
        case .building: building
        case .power: power
        case .supply: supply
        case .alien: alien
        case .government: government
        case .money: money
        case .cost: cost
        case .rival(let hex): Theme.competitorColor(hex)
        }
    }

    static func ocean(_ dark: Bool) -> LinearGradient {
        dark ? LinearGradient(colors: [Color(red: 0.035, green: 0.06, blue: 0.12), Color(red: 0.06, green: 0.1, blue: 0.19)], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.88, green: 0.92, blue: 0.96)], startPoint: .top, endPoint: .bottom)
    }

    static func land(_ dark: Bool) -> Color { dark ? Color.white.opacity(0.24) : Color(red: 0.3, green: 0.37, blue: 0.47).opacity(0.38) }
    static func grid(_ dark: Bool) -> Color { dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }

    /// Land tint in a region under export controls: orange by strictness, red where the controls are aimed.
    static func zoneTint(_ z: MapZone, targeted: Bool) -> Color? {
        if targeted { return Color.red.opacity(0.75) }
        guard z.level >= 40, !z.targets.isEmpty else { return nil }
        return Color.orange.opacity(0.3 + 0.5 * min(1, (z.level - 40) / 50))
    }
}

// MARK: - KPIs

private struct MapKPIs: View {
    let snap: MapSnapshot

    var body: some View {
        let f = snap.footprint
        let runs = snap.pins.filter { $0.kind == .rivalRun }.count
        KPIRow(minWidth: 180) {
            StatTile(title: "Compute online", value: Fmt.watts(f.onlineMW * 1e6), detail: "\(f.sites) site\(f.sites == 1 ? "" : "s") at \(f.locations) location\(f.locations == 1 ? "" : "s")",
                     symbol: "bolt.fill", tint: MapPalette.mine)
            StatTile(title: "Being built", value: Fmt.watts(f.buildingMW * 1e6), detail: f.chipsEnRoute > 0 ? "\(Fmt.int(f.chipsEnRoute)) chips on the way" : "No chips on the way",
                     symbol: "hammer.fill", tint: MapPalette.building)
            StatTile(title: "Continents", value: "\(f.continents.count)", detail: f.continents.joined(separator: ", "), symbol: "globe.americas.fill", tint: .teal)
            StatTile(title: "Revenue last month", value: Fmt.money(f.revenueMonth), detail: "Booked from \(snap.flows.filter { $0.id.hasPrefix("rev:") }.count) regions (estimate)",
                     symbol: "dollarsign.circle.fill", tint: MapPalette.money)
            StatTile(title: "Rivals on the map", value: "\(f.rivalsTracked)", detail: runs > 0 ? "\(runs) training run\(runs == 1 ? "" : "s") located" : "No runs located yet",
                     symbol: "binoculars.fill", tint: .orange)
        }
    }
}

// MARK: - Toolbar

private struct MapToolbar: View {
    @Binding var layers: Set<MapLayer>
    @Binding var flows: Bool
    @Binding var zones: Bool
    @Binding var camera: MapCamera
    let replaying: Bool
    let counts: [MapLayer: Int]
    let fit: () -> Void
    let replay: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MapLayer.allCases) { l in
                MapChip(title: l.title, symbol: l.symbol, count: counts[l] ?? 0, on: layers.contains(l)) {
                    if layers.contains(l) { layers.remove(l) } else { layers.insert(l) }
                }
            }
            Divider().frame(height: 18)
            MapChip(title: "Flows", symbol: "arrow.triangle.swap", count: nil, on: flows) { flows.toggle() }
            MapChip(title: "Export controls", symbol: "shippingbox.and.arrow.backward.fill", count: nil, on: zones) { zones.toggle() }
            Spacer(minLength: 8)
            Menu {
                ForEach(MapCamera.presets, id: \.name) { p in
                    Button(p.name) { withAnimation(.smooth(duration: 0.8)) { camera = p.camera } }
                }
                Divider()
                Button("Fit everything shown", action: fit)
            } label: {
                Label("View", systemImage: "scope")
            }
            .menuStyle(.button)
            .fixedSize()
            Button(action: replay) {
                Label(replaying ? "Replaying…" : "Replay", systemImage: "play.fill")
            }
            .disabled(replaying)
            .help("Watch your lab and the industry grow from the day you started")
        }
        .controlSize(.small)
    }
}

/// A filter capsule.
private struct MapChip: View {
    let title: String
    let symbol: String
    let count: Int?
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.caption2.weight(.bold))
                Text(title).font(.caption.weight(.semibold))
                if let count, count > 0 {
                    Text("\(count)").font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(on ? Color.white.opacity(0.25) : Theme.insetFill, in: .capsule)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(on ? Color.white : Color.secondary)
            .background(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.insetFill), in: .capsule)
            .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Stage

/// Sizes the map to its natural shape and hosts the replay clock.
private struct MapStageHost: View {
    let snap: MapSnapshot
    let layers: Set<MapLayer>
    let flows: Bool
    let zones: Bool
    @Binding var camera: MapCamera
    @Binding var selected: String?
    let lastLook: Date?
    let replayStart: Date?
    let start: Date
    let now: Date
    let company: Color

    var body: some View {
        GeometryReader { geo in
            if let replayStart {
                TimelineView(.animation) { tl in
                    let t = min(1, tl.date.timeIntervalSince(replayStart) / WorldMapView.replaySeconds)
                    let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                    stage(geo.size, replay: start.addingTimeInterval(now.timeIntervalSince(start) * eased))
                }
            } else {
                stage(geo.size, replay: nil)
            }
        }
        .aspectRatio(MapProjection.aspect * 0.98, contentMode: .fit)
        .frame(minHeight: 300)
        .clipShape(.rect(cornerRadius: Theme.Radius.inset))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.inset).strokeBorder(Theme.hairline, lineWidth: 0.5))
    }

    private func stage(_ size: CGSize, replay: Date?) -> some View {
        MapStage(snap: snap, layers: layers, flows: flows && replay == nil, zones: zones, size: size, selected: $selected, camera: $camera,
                 lastLook: lastLook, replay: replay, company: company,
                 zoom: camera.zoom, lon: camera.center.lon, lat: camera.center.lat)
    }
}

/// The map itself. Animatable in its camera so flying between places redraws every layer smoothly.
private struct MapStage: View, Animatable {
    let snap: MapSnapshot
    let layers: Set<MapLayer>
    let flows: Bool
    let zones: Bool
    let size: CGSize
    @Binding var selected: String?
    @Binding var camera: MapCamera
    let lastLook: Date?
    let replay: Date?
    let company: Color
    var zoom: Double
    var lon: Double
    var lat: Double

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GameStore.self) private var store
    @State private var dragFrom: MapCamera? = nil
    @State private var pinchFrom: Double? = nil

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(zoom, AnimatablePair(lon, lat)) }
        set { zoom = newValue.first; lon = newValue.second.first; lat = newValue.second.second }
    }

    var body: some View {
        let proj = MapProjection(size: size, zoom: zoom, center: GeoPoint(lon, lat))
        let dark = scheme == .dark
        let pins = visiblePins
        let placed = MapLayout.spread(pins, proj)
        let calm = reduceMotion || store.reduceAnimations
        let tints = zoneTints
        ZStack(alignment: .topLeading) {
            Rectangle().fill(MapPalette.ocean(dark))
            MapBaseLayer(size: size, zoom: zoom, lon: lon, lat: lat, dark: dark, tints: tints)
                .equatable()
            MapMotionLayer(proj: proj, flows: flows ? visibleFlows : [], zones: zones ? snap.zones : [], placed: placed, calm: calm, dark: dark)
            MapLeaders(placed: placed, dark: dark)
            ForEach(placed, id: \.pin.id) { item in
                MapPinView(pin: item.pin, radius: item.radius, isNew: isNew(item.pin), selected: $selected, company: company,
                           pop: popScale(item.pin), dark: dark)
                    .position(item.at)
            }
            // Labels above every pin, so a neighbour never covers one.
            ForEach(placed.filter { showsLabel($0.pin) }, id: \.pin.id) { item in
                Text(item.pin.kind == .hq ? "\(item.pin.title) HQ" : item.pin.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(.ultraThinMaterial, in: .capsule)
                    .position(x: item.at.x, y: item.at.y + item.radius + 11)
                    .allowsHitTesting(false)
            }
            if zones { MapZoneLabels(zones: snap.zones, proj: proj) }
            if let replay { MapReplayBadge(date: replay) }
            MapZoomControls(camera: $camera)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(pan(proj), including: zoom > 1.01 ? .all : .subviews)
        .simultaneousGesture(pinch)
        .onTapGesture(count: 2) { withAnimation(.smooth(duration: 0.5)) { camera = MapCamera(zoom: camera.zoom * 1.8, center: camera.center).clamped() } }
        .onTapGesture { selected = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("World map")
    }

    private var visiblePins: [MapPin] {
        snap.pins.filter { p in
            guard layers.contains(p.layer) else { return false }
            // Suppliers you don't use and agencies you don't work for stay off the world view until you zoom in.
            if !p.active && (p.kind == .packaging || p.kind == .memory) && zoom < 2 { return false }
            if !p.active && p.kind == .agency && zoom < 1.6 && layers.count > 1 { return false }
            if let replay, let since = p.since, since > replay { return false }
            return true
        }
    }

    private var visibleFlows: [MapFlow] {
        snap.flows.filter { layers.contains($0.layer) }
    }

    /// One optional tint per region (Region.allCases order).
    private var zoneTints: [Color?] {
        guard zones else { return Array(repeating: nil, count: Region.allCases.count) }
        let targeted = Set(snap.zones.flatMap(\.targets))
        return snap.zones.map { MapPalette.zoneTint($0, targeted: targeted.contains($0.region)) }
    }

    private func isNew(_ p: MapPin) -> Bool {
        guard replay == nil, let lastLook, let since = p.since, p.layer != .supply else { return false }
        return since > lastLook
    }

    private func showsLabel(_ p: MapPin) -> Bool {
        if p.id == selected { return false }
        switch p.kind {
        case .hq: return true
        case .campus: return p.size >= 50 || zoom >= 2.2
        case .rival: return zoom >= 1.8
        case .foundry: return p.active && zoom >= 2.4
        case .rivalRun, .fab, .alienFab: return zoom >= 2.4
        default: return zoom >= 4
        }
    }

    /// During a replay a pin pops in over the first months after it appears.
    private func popScale(_ p: MapPin) -> Double {
        guard let replay, let since = p.since else { return 1 }
        let days = replay.timeIntervalSince(since) / 86_400
        return days >= 60 ? 1 : max(0.05, 1 + 0.35 * sin(days / 60 * .pi)) * min(1, days / 20 + 0.1)
    }

    private func pan(_ proj: MapProjection) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                let from = dragFrom ?? camera
                if dragFrom == nil { dragFrom = camera }
                let d = proj.degrees(CGSize(width: -v.translation.width, height: v.translation.height))
                camera = MapCamera(zoom: from.zoom, center: GeoPoint(from.center.lon + d.lon, from.center.lat + d.lat)).clamped()
            }
            .onEnded { _ in dragFrom = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let from = pinchFrom ?? camera.zoom
                if pinchFrom == nil { pinchFrom = camera.zoom }
                camera = MapCamera(zoom: from * v.magnification, center: camera.center).clamped()
            }
            .onEnded { _ in pinchFrom = nil }
    }
}

// MARK: - Layers

/// The land as dots, the graticule and the export-control tint. Equatable so the daily tick doesn't redraw it.
private struct MapBaseLayer: View, Equatable {
    let size: CGSize
    let zoom: Double
    let lon: Double
    let lat: Double
    let dark: Bool
    let tints: [Color?]

    var body: some View {
        Canvas { ctx, _ in
            let proj = MapProjection(size: size, zoom: zoom, center: GeoPoint(lon, lat))
            // Graticule every 30°.
            var grid = Path()
            for lonLine in stride(from: -150.0, through: 180, by: 30) {
                grid.move(to: proj.point(GeoPoint(lonLine, WorldMapGeo.latRange.lowerBound)))
                grid.addLine(to: proj.point(GeoPoint(lonLine, WorldMapGeo.latRange.upperBound)))
            }
            for latLine in stride(from: -30.0, through: 60, by: 30) {
                grid.move(to: proj.point(GeoPoint(WorldMapGeo.lonRange.lowerBound, latLine)))
                grid.addLine(to: proj.point(GeoPoint(WorldMapGeo.lonRange.upperBound, latLine)))
            }
            ctx.stroke(grid, with: .color(MapPalette.grid(dark)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
            // Dots, batched by colour.
            let r = max(0.7, min(3, proj.dotPitch * 0.34))
            let view = CGRect(origin: .zero, size: size).insetBy(dx: -8, dy: -8)
            var plain = Path()
            var tinted = Array(repeating: Path(), count: tints.count)
            for d in WorldMapGeo.dots {
                let p = proj.point(d.point)
                guard view.contains(p) else { continue }
                let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
                if d.region >= 0, Int(d.region) < tints.count, tints[Int(d.region)] != nil {
                    tinted[Int(d.region)].addEllipse(in: rect)
                } else {
                    plain.addEllipse(in: rect)
                }
            }
            ctx.fill(plain, with: .color(MapPalette.land(dark)))
            for (i, path) in tinted.enumerated() { if let c = tints[i] { ctx.fill(path, with: .color(c)) } }
        }
        .allowsHitTesting(false)
    }

    static func == (a: MapBaseLayer, b: MapBaseLayer) -> Bool {
        a.size == b.size && a.zoom == b.zoom && a.lon == b.lon && a.lat == b.lat && a.dark == b.dark && a.tints == b.tints
    }
}

/// Flows, pulses and export-control arrows, redrawn every frame while anything moves.
private struct MapMotionLayer: View {
    let proj: MapProjection
    let flows: [MapFlow]
    let zones: [MapZone]
    let placed: [MapLayout.Placed]
    let calm: Bool
    let dark: Bool

    var body: some View {
        let pulsing = placed.filter { $0.pin.building || $0.pin.kind == .rivalRun || $0.pin.kind == .alienFab || $0.pin.kind == .hq }
        TimelineView(.animation(minimumInterval: 1 / 30, paused: calm)) { tl in
            let t = calm ? 0.35 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                for f in flows { drawFlow(&ctx, f, t) }
                for z in zones where !z.targets.isEmpty { for target in z.targets { drawArrow(&ctx, from: WorldMapGeo.anchor(z.region), to: WorldMapGeo.anchor(target), hits: z.hitsYou, t) } }
                for item in pulsing { drawPulse(&ctx, item, t) }
            }
        }
        .allowsHitTesting(false)
    }

    /// The flight-path curve for a flow; a Pacific crossing goes off one edge and in at the other.
    private func arcs(_ a: GeoPoint, _ b: GeoPoint) -> [(CGPoint, CGPoint, CGPoint)] {
        func arc(_ a: GeoPoint, _ b: GeoPoint) -> (CGPoint, CGPoint, CGPoint) {
            let p = proj.point(a), q = proj.point(b)
            let mid = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
            let dx = q.x - p.x, dy = q.y - p.y
            let len = max(1, (dx * dx + dy * dy).squareRoot())
            // Bow the curve upward (north), more for longer hops.
            var nx = -dy / len, ny = dx / len
            if ny > 0 { nx = -nx; ny = -ny }
            let bow = min(120, len * 0.22)
            return (p, CGPoint(x: mid.x + nx * bow, y: mid.y + ny * bow), q)
        }
        if b.lon - a.lon > 180 { return [arc(a, b.offset(-360, 0)), arc(a.offset(360, 0), b)] }
        if a.lon - b.lon > 180 { return [arc(a, b.offset(360, 0)), arc(a.offset(-360, 0), b)] }
        return [arc(a, b)]
    }

    private static func at(_ c: (CGPoint, CGPoint, CGPoint), _ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * c.0.x + 2 * u * t * c.1.x + t * t * c.2.x, y: u * u * c.0.y + 2 * u * t * c.1.y + t * t * c.2.y)
    }

    private func drawFlow(_ ctx: inout GraphicsContext, _ f: MapFlow, _ t: Double) {
        let color = MapPalette.color(f.tone)
        let w = f.weight
        for c in arcs(f.from, f.to) {
            var path = Path()
            path.move(to: c.0)
            path.addQuadCurve(to: c.2, control: c.1)
            let dash: [CGFloat] = f.kind == .moneyOut ? [3, 4] : (f.kind == .rivalRun ? [6, 5] : [])
            ctx.stroke(path, with: .color(color.opacity(dark ? 0.28 : 0.35)), style: StrokeStyle(lineWidth: 0.8 + 1.8 * w, lineCap: .round, dash: dash))
            // Particles: more and bigger for bigger flows; chips are little squares, money and power dots.
            let n = 2 + Int((w * 5).rounded())
            let speed = f.kind == .power ? 0.35 : (f.kind == .rivalRun ? 0.12 : 0.18)
            for i in 0..<n {
                let u = (t * speed + Double(i) / Double(n)).truncatingRemainder(dividingBy: 1)
                let p = Self.at(c, u)
                let r = 1.4 + 1.8 * w
                let fade = min(1, min(u, 1 - u) * 6)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 2.4, y: p.y - r * 2.4, width: r * 4.8, height: r * 4.8)), with: .color(color.opacity(0.18 * fade)))
                let shape = f.kind == .chips ? Path(roundedRect: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r), cornerRadius: r * 0.3)
                                             : Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(shape, with: .color(color.opacity(fade)))
            }
        }
    }

    private func drawArrow(_ ctx: inout GraphicsContext, from: GeoPoint, to: GeoPoint, hits: Bool, _ t: Double) {
        guard let c = arcs(from, to).first else { return }
        var path = Path()
        path.move(to: c.0)
        path.addQuadCurve(to: c.2, control: c.1)
        let color = hits ? Color.red : Color.orange
        ctx.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 6], dashPhase: CGFloat(-t * 24)))
        // Arrowhead along the last stretch of the curve.
        let tip = c.2, back = Self.at(c, 0.94)
        let ang = atan2(tip.y - back.y, tip.x - back.x)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: tip.x - 11 * cos(ang - 0.45), y: tip.y - 11 * sin(ang - 0.45)))
        head.addLine(to: CGPoint(x: tip.x - 11 * cos(ang + 0.45), y: tip.y - 11 * sin(ang + 0.45)))
        head.closeSubpath()
        ctx.fill(head, with: .color(color))
    }

    private func drawPulse(_ ctx: inout GraphicsContext, _ item: MapLayout.Placed, _ t: Double) {
        let period = item.pin.kind == .hq ? 3.2 : 2.0
        let phase = (t / period + Double(item.pin.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 97) / 97).truncatingRemainder(dividingBy: 1)
        let r = item.radius + 3 + 16 * phase
        let color = item.pin.kind == .hq ? MapPalette.mine : MapPalette.color(item.pin.building ? .building : item.pin.tone)
        let ring = Path(ellipseIn: CGRect(x: item.at.x - r, y: item.at.y - r, width: 2 * r, height: 2 * r))
        ctx.stroke(ring, with: .color(color.opacity(0.7 * (1 - phase))), lineWidth: 1.5)
    }
}

/// Thin lines from pins nudged apart (a crowded city) back to where they really are.
private struct MapLeaders: View {
    let placed: [MapLayout.Placed]
    let dark: Bool

    var body: some View {
        Canvas { ctx, _ in
            for item in placed where item.moved {
                var p = Path()
                p.move(to: item.origin)
                p.addLine(to: item.at)
                ctx.stroke(p, with: .color((dark ? Color.white : Color.black).opacity(0.35)), lineWidth: 0.8)
                ctx.fill(Path(ellipseIn: CGRect(x: item.origin.x - 1.5, y: item.origin.y - 1.5, width: 3, height: 3)), with: .color((dark ? Color.white : Color.black).opacity(0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Layout

enum MapLayout {
    struct Placed {
        let pin: MapPin
        let origin: CGPoint
        let at: CGPoint
        let radius: Double
        var moved: Bool { abs(origin.x - at.x) > 0.5 || abs(origin.y - at.y) > 0.5 }
    }

    static func radius(_ p: MapPin) -> Double {
        let r: Double
        switch p.kind {
        case .hq: r = 12
        case .campus: r = min(26, max(6.5, 5 + 4.2 * log10(1 + p.size)))
        case .power: r = min(13, max(5, 4 + 2.4 * log10(1 + p.size)))
        case .office: r = 7
        case .partner: r = 6
        case .fab: r = 8 + 4 * p.size
        case .alienFab: r = 10
        case .rival: r = 6 + 8 * p.size
        case .rivalRun: r = 5 + 7 * p.size
        case .foundry: r = 6 + 6 * p.size
        case .packaging, .memory: r = 5
        case .agency: r = 4.5 + 6 * p.size
        }
        return p.active ? r : r * 0.8
    }

    /// Pins that would overlap are fanned out in a ring around their shared spot (the Bay Area holds four labs).
    static func spread(_ pins: [MapPin], _ proj: MapProjection) -> [Placed] {
        let order = pins.sorted { radius($0) > radius($1) }
        var groups: [[(pin: MapPin, p: CGPoint, r: Double)]] = []
        for pin in order {
            let p = proj.point(pin.point)
            let r = radius(pin)
            if let g = groups.firstIndex(where: { grp in grp.contains { hypot($0.p.x - p.x, $0.p.y - p.y) < ($0.r + r) * 0.8 + 3 } }) {
                groups[g].append((pin, p, r))
            } else {
                groups.append([(pin, p, r)])
            }
        }
        var out: [Placed] = []
        for g in groups {
            if g.count == 1 { out.append(Placed(pin: g[0].pin, origin: g[0].p, at: g[0].p, radius: g[0].r)); continue }
            let cx = g.map(\.p.x).reduce(0, +) / Double(g.count), cy = g.map(\.p.y).reduce(0, +) / Double(g.count)
            let ring = max(16, g.map(\.r).max()! * 0.9 + Double(g.count) * 4.5)
            for (i, m) in g.enumerated() {
                let a = -Double.pi / 2 + 2 * .pi * Double(i) / Double(g.count)
                out.append(Placed(pin: m.pin, origin: m.p, at: CGPoint(x: cx + ring * cos(a), y: cy + ring * sin(a)), radius: m.r))
            }
        }
        // Small pins on top of big ones.
        return out.sorted { $0.radius > $1.radius }
    }
}

// MARK: - Pins

private struct MapPinView: View {
    let pin: MapPin
    let radius: Double
    let isNew: Bool
    @Binding var selected: String?
    let company: Color
    let pop: Double
    let dark: Bool

    @State private var hover = false

    var body: some View {
        let color = pin.kind == .hq ? company : MapPalette.color(pin.building && pin.kind == .campus ? .building : pin.tone)
        let d = radius * 2
        let isSel = selected == pin.id
        Button {
            selected = isSel ? nil : pin.id
        } label: {
            ZStack {
                shape(color, d)
                if radius >= 6.5 {
                    Image(systemName: pin.symbol)
                        .font(.system(size: max(6, radius * 0.95), weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0.5)
                }
                if isNew {
                    Text("NEW").font(.system(size: 7, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.red, in: .capsule)
                        .offset(x: radius * 0.9, y: -radius * 0.9)
                }
            }
            .frame(width: d + 6, height: d + 6)
            .contentShape(Circle())
            .scaleEffect((hover || isSel ? 1.18 : 1) * pop)
            .opacity(pin.active ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.snappy(duration: 0.15)) { hover = h } }
        .help("\(pin.title) — \(pin.subtitle)")
        .popover(isPresented: Binding(get: { isSel }, set: { if !$0 && selected == pin.id { selected = nil } }), arrowEdge: .bottom) {
            MapPinDetail(pin: pin, isNew: isNew) { selected = nil }
        }
        .accessibilityLabel("\(pin.kind.label): \(pin.title), \(pin.subtitle)")
    }

    @ViewBuilder
    private func shape(_ color: Color, _ d: Double) -> some View {
        let stroke = dark ? Color.white.opacity(0.9) : Color.white
        switch pin.kind {
        case .rival, .rivalRun:
            RoundedRectangle(cornerRadius: d * 0.22)
                .fill(color.gradient)
                .overlay(RoundedRectangle(cornerRadius: d * 0.22).strokeBorder(stroke, lineWidth: 1.2))
                .frame(width: d * 0.86, height: d * 0.86)
                .rotationEffect(.degrees(pin.kind == .rivalRun ? 45 : 0))
                .shadow(color: color.opacity(0.6), radius: 4)
        case .foundry, .packaging, .memory, .fab:
            RoundedRectangle(cornerRadius: d * 0.18)
                .fill(color.gradient)
                .overlay(RoundedRectangle(cornerRadius: d * 0.18).strokeBorder(stroke, lineWidth: 1))
                .frame(width: d * 0.9, height: d * 0.9)
                .shadow(color: color.opacity(0.5), radius: 3)
        case .hq:
            Circle().fill(color.gradient)
                .overlay(Circle().strokeBorder(stroke, lineWidth: 2))
                .frame(width: d, height: d)
                .shadow(color: color.opacity(0.8), radius: 6)
        default:
            Circle().fill(color.gradient)
                .overlay(Circle().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1.2, dash: pin.building ? [2.5, 2] : [])))
                .frame(width: d, height: d)
                .shadow(color: color.opacity(0.6), radius: pin.kind == .campus ? 5 : 3)
        }
    }
}

/// The popover: what the pin is, its numbers, and a way to its screen.
private struct MapPinDetail: View {
    @Environment(GameStore.self) private var store
    let pin: MapPin
    let isNew: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: pin.symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(MapPalette.color(pin.tone).gradient, in: .rect(cornerRadius: Theme.Radius.chip))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(pin.subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Pill(text: pin.kind.label, color: MapPalette.color(pin.tone))
                if pin.building { Pill(text: "Building", color: MapPalette.building, symbol: "hammer.fill") }
                if isNew { Pill(text: "New since your last look", color: .red, symbol: "sparkles") }
                if !pin.active && pin.layer != .yours { Pill(text: "Not working with you", color: .secondary) }
            }
            if !pin.lines.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    ForEach(Array(pin.lines.enumerated()), id: \.offset) { _, l in
                        GridRow {
                            Text(l.label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            Text(l.value).font(.caption.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !pin.note.isEmpty {
                Text(pin.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let since = pin.since, pin.layer == .yours || pin.kind == .rivalRun {
                Text("\(pin.kind == .rivalRun ? "Training since" : "Since") \(since.gameMonth)").font(.caption2).foregroundStyle(.tertiary)
            }
            if let screen = pin.screen {
                Button {
                    close()
                    if let lab = pin.labID, pin.kind == .rival { store.openLab(lab) } else { store.open(screen) }
                } label: {
                    Label(pin.kind == .rival ? "Open lab profile" : "Open \(screen.title)", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
    }
}

// MARK: - Overlays

private struct MapZoneLabels: View {
    let zones: [MapZone]
    let proj: MapProjection

    var body: some View {
        ForEach(zones.filter { $0.level >= 40 || !$0.targets.isEmpty }) { z in
            HStack(spacing: 4) {
                Image(systemName: z.hitsYou ? "exclamationmark.triangle.fill" : "shippingbox.and.arrow.backward.fill")
                Text("\(z.region.short) \(Int(z.level.rounded()))")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(z.hitsYou ? Color.red : (z.targets.isEmpty ? Color.secondary : Color.orange))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.ultraThinMaterial, in: .capsule)
            .position(proj.point(WorldMapGeo.anchor(z.region).offset(0, 4)))
            .allowsHitTesting(false)
        }
    }
}

private struct MapReplayBadge: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(Int(date.decimalYear))).font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
            Text(date.gameMonth).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.tile))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(14)
        .allowsHitTesting(false)
    }
}

private struct MapZoomControls: View {
    @Binding var camera: MapCamera

    var body: some View {
        VStack(spacing: 0) {
            button("plus") { camera = MapCamera(zoom: camera.zoom * 1.6, center: camera.center).clamped() }
            Divider().frame(width: 26)
            button("minus") { camera = MapCamera(zoom: camera.zoom / 1.6, center: camera.center).clamped() }
            Divider().frame(width: 26)
            button("globe") { camera = .world }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.hairline, lineWidth: 0.5))
    }

    private func button(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.smooth(duration: 0.45)) { action() } } label: {
            Image(systemName: symbol).font(.caption.weight(.bold)).frame(width: 28, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legend

private struct MapLegend: View {
    let snap: MapSnapshot
    let layers: Set<MapLayer>
    let flows: Bool
    let zones: Bool

    var body: some View {
        let kinds = Set(snap.flows.filter { layers.contains($0.layer) }.map(\.kind))
        HStack(spacing: 14) {
            if layers.contains(.yours) {
                LegendItem(color: MapPalette.mine, label: "Your sites (size = MW)")
                LegendItem(color: MapPalette.building, label: "Building")
                LegendItem(color: MapPalette.power, label: "Power deals")
            }
            if layers.contains(.supply) { LegendItem(color: MapPalette.supply, label: "Chipmakers") }
            if layers.contains(.government) { LegendItem(color: MapPalette.government, label: "Agencies") }
            if layers.contains(.rivals) { LegendItem(color: .orange, label: "Rivals (◇ = training run)") }
            if flows {
                if kinds.contains(.chips) { LegendItem(color: MapPalette.mine, label: "Chips", dashed: true) }
                if kinds.contains(.moneyIn) { LegendItem(color: MapPalette.money, label: "Money in", dashed: true) }
                if kinds.contains(.moneyOut) { LegendItem(color: MapPalette.cost, label: "Money out", dashed: true) }
            }
            if zones { LegendItem(color: .red, label: "Targeted by export controls") }
            Spacer(minLength: 0)
            if snap.footprint.unplaced > 0 {
                Text("\(snap.footprint.unplaced) site\(snap.footprint.unplaced == 1 ? "" : "s") at places the map doesn't know").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Cards

private struct MapExposureCard: View {
    let snap: MapSnapshot

    var body: some View {
        Card {
            CardHeader("Exposure", symbol: "shield.lefthalf.filled", subtitle: "What your geography makes you vulnerable to")
            if snap.exposure.isEmpty {
                Text("Nothing to worry about yet: you don't have enough on the map.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(snap.exposure) { e in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: e.symbol)
                        .foregroundStyle(e.good.map { $0 ? Theme.good : Theme.warning } ?? .secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(.callout.weight(.semibold))
                        Text(e.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct MapZonesCard: View {
    @Environment(GameStore.self) private var store
    let snap: MapSnapshot
    let home: Region
    let focus: (Region) -> Void

    var body: some View {
        Card {
            CardHeader(title: "Export controls", symbol: "shippingbox.and.arrow.backward.fill", subtitle: "Who keeps chips, tools and minerals from whom (0–100)") {
                Button("Nations") { store.open(.nations) }.buttonStyle(.link).font(.caption)
            }
            ForEach(snap.zones.sorted { $0.level > $1.level }) { z in
                Button { focus(z.region) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(z.region.title).font(.callout.weight(.semibold))
                            if z.region == home { Pill(text: "Home", color: MapPalette.mine) }
                            if z.hitsYou { Pill("Hits you", tone: .bad) }
                            Spacer()
                            if !z.stance.isEmpty { Text(z.stance).font(.caption).foregroundStyle(.secondary) }
                            Text("\(Int(z.level.rounded()))").font(.callout.weight(.semibold).monospacedDigit())
                        }
                        Meter(value: z.level / 100, tint: z.hitsYou ? .red : (z.targets.isEmpty ? .secondary : .orange), height: 5)
                        Text(z.targets.isEmpty ? z.aim : "\(z.aim) → \(z.targets.map(\.short).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MapExpansionCard: View {
    let state: GameState
    let hq: GeoPoint
    let focus: (GeoPoint) -> Void

    var body: some View {
        let log = state.worldMap.log
        Card {
            CardHeader("Your expansion", symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", subtitle: "Every new place you've opened, newest first. Tap one to fly there.")
            ForEach(log.prefix(10)) { m in
                row(date: m.date, text: m.text, symbol: symbol(m.kind), point: GeoPoint(m.lon, m.lat))
            }
            row(date: state.startDate, text: "Founded \(state.companyName) in \(HQ.city(state).name)", symbol: "star.fill", point: hq)
            if log.isEmpty {
                Text("New campuses, offices and fabs appear here at the month end after they open.").font(.caption).foregroundStyle(.secondary)
            } else if log.count > 10 {
                Text("and \(log.count - 10) earlier").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func symbol(_ kind: String) -> String {
        switch kind {
        case "office": "building.2.fill"
        case "continent": "globe.americas.fill"
        case "fab": "cpu.fill"
        case "alien": "atom"
        default: "building.columns.fill"
        }
    }

    private func row(date: Date, text: String, symbol: String, point: GeoPoint) -> some View {
        Button { focus(point) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(MapPalette.mine).frame(width: 18)
                Text(text).font(.callout).lineLimit(1)
                Spacer(minLength: 6)
                Text(date.gameMonth).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MapPlacesCard: View {
    let snap: MapSnapshot
    let select: (MapPin) -> Void

    var body: some View {
        let campuses = snap.pins.filter { $0.kind == .campus }.sorted { $0.size > $1.size }
        let top = campuses.first?.size ?? 1
        Card {
            CardHeader("Your places", symbol: "building.columns.fill", subtitle: "Campuses by planned megawatts, then everything else of yours")
            if campuses.isEmpty {
                Text("No datacenters yet: your chips live in the server room at headquarters. Build or lease a site on Datacenters & Power.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(campuses.prefix(8)) { p in
                Button { select(p) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(p.title).font(.callout.weight(.semibold))
                            if p.building { Pill(text: "Building", color: MapPalette.building) }
                            Spacer()
                            Text(Fmt.watts(p.size * 1e6)).font(.callout.monospacedDigit())
                        }
                        Meter(value: p.size / max(0.001, top), tint: p.building ? MapPalette.building : MapPalette.mine, height: 4)
                        Text(p.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            let others = snap.pins.filter { $0.layer == .yours && $0.kind != .campus && $0.kind != .hq }
            if !others.isEmpty {
                Divider()
                ForEach(others.prefix(8)) { p in
                    Button { select(p) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: p.symbol).foregroundStyle(MapPalette.color(p.tone)).frame(width: 18)
                            Text(p.title).font(.callout).lineLimit(1)
                            Spacer()
                            Text(p.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Render check

/// `TensorTycoon --render-map <save.json> <out-prefix> [zones] [<zoom>:<lon>:<lat>]`: draws the World Map screen for a
/// save to `<out-prefix>-light.png` and `-dark.png` without opening a window (a check on both appearances; popovers
/// and materials don't render offscreen).
@MainActor
enum WorldMapRender {
    nonisolated(unsafe) static var zones = false
    nonisolated(unsafe) static var offscreen = false
    nonisolated(unsafe) static var camera: MapCamera? = nil

    static func main(_ args: [String]) -> Int32 {
        guard args.count >= 2 else { print("usage: --render-map <save.json> <out-prefix> [zones] [zoom:lon:lat]"); return 1 }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: args[0])), var s = try? SaveCoding.decoder().decode(GameState.self, from: data) else {
            print("FAILED to load \(args[0])")
            return 1
        }
        StableID.resume(s)
        SaveMigration.migrate(&s)
        BenchmarkCatalog.resetCache()
        HardwareCatalog.register(s.customChips)
        for a in args.dropFirst(2) {
            if a == "zones" { zones = true }
            let p = a.split(separator: ":").compactMap { Double($0) }
            if p.count == 3 { camera = MapCamera(zoom: p[0], center: GeoPoint(p[1], p[2])).clamped() }
        }
        offscreen = true
        let store = GameStore()
        store.state = s
        store.refreshDerived()
        store.screen = .worldMap
        for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            let view = WorldMapView()
                .environment(store)
                .environment(\.colorScheme, scheme)
                .frame(width: 1320, height: 1850)
                .background(scheme == .dark ? Color(white: 0.11) : Color(white: 0.96))
            let r = ImageRenderer(content: view)
            r.scale = 1.5
            guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                print("render failed")
                return 1
            }
            let url = URL(fileURLWithPath: "\(args[1])-\(name).png")
            do { try png.write(to: url) } catch { print("could not write \(url.path)"); return 1 }
            print("wrote \(url.path)")
        }
        return 0
    }
}
