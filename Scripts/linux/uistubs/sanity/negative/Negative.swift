// Each `bad_N` view must FAIL to type-check against the stubs exactly as it fails against the real SDK.
// `good_N` views must pass. Run with sanity/negative/run.sh.
import SwiftUI
import Charts

struct Row: Identifiable { let id: Int; let name: String }

struct good_1: View { @State var t = ""; var body: some View { TextField("x", text: $t).padding(.horizontal, 4).font(.caption.weight(.bold)) } }
struct good_2: View { var body: some View { ForEach(0..<3, id: \.self) { i in Text("\(i)") } } }
struct good_3: View { let rows: [Row]; var body: some View { Table(rows) { TableColumn("A") { r in Text(r.name) }; TableColumn("B") { r in Text("\(r.id)") } } } }
struct good_4: View { var body: some View { Chart { LineMark(x: .value("x", 1.0), y: .value("y", 2)) }.chartYScale(domain: 0...10) } }
struct good_5: View { @State var on = false; var body: some View { Toggle("x", isOn: $on).toggleStyle(.checkbox).onChange(of: on) { old, new in } } }
struct good_6: View { var body: some View { Text("a").foregroundStyle(true ? .orange : .secondary) } }
struct good_7: View { var body: some View { Image(systemName: "x").symbolEffect(.pulse, isActive: true).contentTransition(.numericText()) } }

struct bad_1: View { var body: some View { Text(5) } }
struct bad_2: View { var body: some View { Text("x").frame(width: "10") } }
struct bad_3: View { var body: some View { Text("x").foregroundStyle(5) } }
struct bad_4: View { var body: some View { ForEach([1, 2, 3]) { Text("\($0)") } } }
struct bad_5: View { var body: some View { Button("x") } }
struct bad_6: View { var body: some View { Text("x").sheet(isPresented: true) { Text("y") } } }
struct bad_7: View { @State var n = 0; var body: some View { TextField("x", text: $n) } }
struct bad_8: View { var body: some View { Chart { LineMark(x: .value("x", CGFloat(1)), y: .value("y", 2)) } } }
struct bad_9: View { var body: some View { Chart { Text("x") } } }
struct bad_10: View { @State var on = false; var body: some View { Text("x").onChange(of: on) { a, b, c in } } }
struct bad_11: View { var body: some View { Image(systemImage: "x") } }
struct bad_12: View { var body: some View { HStack(spacing: 4, alignment: .top) { Text("x") } } }
struct bad_13: View { var body: some View { Button("x") {}.buttonStyle(.segmented) } }
struct bad_14: View { var body: some View { Text("x").font(.headline.bold) } }
struct bad_15: View { let rows: [Row]; var body: some View { Table(rows) {
    TableColumn("1") { r in Text(r.name) }; TableColumn("2") { r in Text(r.name) }; TableColumn("3") { r in Text(r.name) }
    TableColumn("4") { r in Text(r.name) }; TableColumn("5") { r in Text(r.name) }; TableColumn("6") { r in Text(r.name) }
    TableColumn("7") { r in Text(r.name) }; TableColumn("8") { r in Text(r.name) }; TableColumn("9") { r in Text(r.name) }
    TableColumn("10") { r in Text(r.name) }; TableColumn("11") { r in Text(r.name) } } } }
struct bad_16: View { @State var s = 0; var body: some View { Picker("x", selection: $s) { Text("a") }.pickerStyle(.wheel) } }
struct bad_17: View { var body: some View { Color.systemBlue } }
struct bad_18: View { let s: String? = nil; var body: some View { Text(s) } }
struct bad_19: View { var body: some View { Text("x").disabled() } }
struct bad_20: View { var body: some View { VStack { for i in 0..<3 { Text("\(i)") } } } }
struct bad_21: View { @Environment(\.dismisss) var dismiss; var body: some View { Text("x") } }
struct bad_22: View { var body: some View { Text("x").task(id: Row(id: 1, name: "")) {} } }
struct bad_23: View { var body: some View { Text("x").background(.rect(cornerRadius: 4), in: .red) } }
struct bad_24: View { var body: some View { Label("x", systemName: "y") } }
struct bad_25: View { var body: some View { Text("x").accessibilityAddTraits(.isHeading) } }
struct bad_26: View { var body: some View { RoundedRectangle(radius: 4) } }
struct bad_27: View { var body: some View { Text("x").navigationBarTitleDisplayMode(.inline) } }
struct bad_28: View { var body: some View { Text("x").onTapGesture { location in } .onTapGesture(count: "2") {} } }
