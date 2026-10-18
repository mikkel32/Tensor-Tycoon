import SwiftUI

struct TeamView: View {
    @Environment(GameStore.self) private var store
    @State private var roleFilter: Role? = nil
    @State private var firing: Employee?

    var body: some View {
        let s = store.game
        let office = Economy.officeLevels[min(s.officeLevel, Economy.officeLevels.count - 1)]
        let next = s.officeLevel + 1 < Economy.officeLevels.count ? Economy.officeLevels[s.officeLevel + 1] : nil
        Page(title: "Team", subtitle: "AI talent is the scarcest resource after GPUs. Underpaid stars get poached. Stars bring traits; promote veterans (a year in, skill 65+) into the trait you choose.") {
            ScreenHint(.team)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Photo(key: office.image).frame(height: 130).frame(maxWidth: .infinity).clipped()
                        .overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom))
                        .overlay(alignment: .bottomLeading) {
                            Text(office.name).font(.title3.weight(.bold)).foregroundStyle(.white).padding(12)
                        }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Headcount").font(.caption)
                            Spacer()
                            Text("\(s.employees.count) / \(office.capacity)").font(.caption.monospacedDigit())
                        }
                        Meter(value: Double(s.employees.count) / Double(office.capacity), tint: s.employees.count >= office.capacity ? .orange : .green)
                        Text("Rent \(Fmt.money(office.monthly))/mo · payroll \(Fmt.money(Economy.payrollYear(s) / 12))/mo").font(.caption).foregroundStyle(.secondary)
                        if let next {
                            Button("Move to \(next.name) (\(next.capacity) seats, \(Fmt.money(next.monthly))/mo)") {
                                store.act("Moved offices") { $0.upgradeOffice() }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(12)
                }
                .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
                .clipShape(.rect(cornerRadius: Theme.corner))
                .frame(width: 320)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(Role.allCases) { r in
                        let staff = s.employees.filter { $0.role == r }
                        let avg = staff.isEmpty ? 0 : staff.reduce(0) { $0 + $1.skill } / Double(staff.count)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: r.symbol).foregroundStyle(.white).frame(width: 24, height: 24)
                                    .background(Theme.roleColor(r).gradient, in: .rect(cornerRadius: 6))
                                Text(r.plural).font(.callout.weight(.semibold))
                                Spacer()
                                Text("\(staff.count)").font(.title3.weight(.bold).monospacedDigit())
                            }
                            Text(staff.isEmpty ? "None hired" : "Avg skill \(Int(avg)) · \(Fmt.money(staff.reduce(0) { $0 + $1.salary }))/yr")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(r.effect).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                        }
                        .padding(10)
                        .background(.background.secondary, in: .rect(cornerRadius: 12))
                    }
                }
            }

            NotablePeopleCard()   // 3.4: your people the industry knows by name
            HStack {
                Text("Candidates").font(.title3.weight(.semibold))
                Spacer()
                Picker("Role", selection: $roleFilter) {
                    Text("All roles").tag(Role?.none)
                    ForEach(Role.allCases) { r in Text(r.title).tag(Role?.some(r)) }
                }
                .frame(width: 220)
            }
            let cands = s.candidates.filter { roleFilter == nil || $0.role == roleFilter }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                ForEach(cands) { c in CandidateCard(candidate: c, year: s.year) }
            }
            if cands.isEmpty { Text("No candidates right now — new people enter the market every month.").foregroundStyle(.secondary) }

            Text("Employees").font(.title3.weight(.semibold))
            if s.employees.isEmpty {
                Text("It's just you. Hire from the candidates above: researchers speed up research, an ML engineer makes training more efficient.").foregroundStyle(.secondary)
            } else {
                Card(padding: 0) {
                    Table(s.employees.filter { roleFilter == nil || $0.role == roleFilter }.sorted { $0.skill > $1.skill }) {
                        TableColumn("Name") { e in
                            HStack(spacing: 6) {
                                Image(systemName: e.role.symbol).foregroundStyle(Theme.roleColor(e.role))
                                Text(e.name)
                                if e.star { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                            }
                        }
                        TableColumn("Role") { e in Text(e.role.title).foregroundStyle(.secondary) }
                        TableColumn("Trait") { e in
                            if let t = e.talent {
                                Label(t.title, systemImage: t.symbol).font(.caption).help(t.detail)
                            } else if s.canPromote(e) {
                                Menu("Promote…") {
                                    ForEach(TalentTrait.promotions(e.role)) { t in
                                        Button("\(t.title) — \(t.detail)") { store.act("Promoted \(e.name)") { $0.promote(e.id, to: t) } }
                                    }
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .font(.caption)
                            } else {
                                Text("—").foregroundStyle(.tertiary)
                            }
                        }
                        .width(140)
                        TableColumn("Skill") { e in Text("\(Int(e.skill))").monospacedDigit() }.width(45)
                        TableColumn("Salary") { e in Text(Fmt.money(e.salary)).monospacedDigit() }.width(80)
                        TableColumn("Morale") { e in Meter(value: e.morale / 100, tint: e.morale < 40 ? .red : (e.morale < 65 ? .orange : .green), height: 6) }.width(90)
                        TableColumn("Since") { e in Text(e.hired.gameMonth).foregroundStyle(.secondary) }.width(80)
                        TableColumn("") { e in
                            HStack {
                                Button("Raise +15%") { store.mutate { $0.giveRaise(e.id) } }.buttonStyle(.borderless)
                                Button("Let go…") { firing = e }.buttonStyle(.borderless).foregroundStyle(.red)
                            }
                            .font(.caption)
                        }
                        .width(150)
                    }
                    .frame(minHeight: CGFloat(min(14, s.employees.count + 1)) * 26 + 30)
                }
            }
        }
        .confirmationDialog("Let \(firing?.name ?? "them") go?", isPresented: Binding(get: { firing != nil }, set: { if !$0 { firing = nil } }),
                            titleVisibility: .visible) {
            Button("Let go", role: .destructive) {
                if let e = firing { store.mutate { $0.fire(e.id) } }
                firing = nil
            }
            Button("Cancel", role: .cancel) { firing = nil }
        } message: {
            Text("Three months of salary in severance, and everyone else's morale dips a little.")
        }
    }
}

private struct CandidateCard: View {
    @Environment(GameStore.self) private var store
    let candidate: Candidate
    let year: Double

    var body: some View {
        let c = candidate
        let market = Macro.salary(c.role, year) * pow(c.skill / 50, 1.6)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: c.role.symbol).foregroundStyle(.white).frame(width: 30, height: 30)
                    .background(Theme.roleColor(c.role).gradient, in: .circle)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(c.name).font(.headline)
                        if c.star { Pill(text: "Star", color: .yellow, symbol: "star.fill") }
                    }
                    Text(c.role.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(c.skill))").font(.title2.weight(.bold).monospacedDigit())
                    Text("skill").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(c.bio).font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
            if let t = c.talent {
                Label("\(t.title): \(t.detail)", systemImage: t.symbol).font(.caption.weight(.semibold))
                    .foregroundStyle(t == .diva ? .orange : .purple)
                    .lineLimit(2)
            }
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Fmt.money(c.salary))/yr").font(.callout.weight(.semibold).monospacedDigit())
                    Text(c.equity > 0.001 ? "+ \(Fmt.trim(c.equity, 2))% equity" : (c.salary > market * 1.1 ? "Above market" : "Market rate")).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hire") { store.act("Welcome aboard, \(c.name.split(separator: " ").first ?? "")!") { $0.hire(c.id) } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(c.star ? Color.yellow.opacity(0.6) : .clear, lineWidth: 1.5))
    }
}
