import SwiftUI
import ChecksumCore

struct ReportView: View {
    let comparison: CsvComparison

    private enum Item {
        case header(String, Color, Int)
        case row([(title: String, width: CGFloat)], [String])
    }

    var body: some View {
        let report = comparison.report

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("First: \(comparison.firstName) · Second: \(comparison.secondName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Unchanged \(report.unchanged.count) · Added \(report.added.count) · Removed \(report.removed.count) · Moved \(report.moved.count) · Renamed \(report.renamed.count) · Changed \(report.changed.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if report.isEmpty {
                Text("Nothing to compare.")
                    .foregroundStyle(.secondary)
            }

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items(report).enumerated()), id: \.offset) { _, item in
                        switch item {
                        case .header(let title, let color, let count):
                            Text("\(title) (\(count))")
                                .font(.headline)
                                .foregroundStyle(color)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                        case .row(let columns, let values):
                            HStack(spacing: 0) {
                                ForEach(Array(values.enumerated()), id: \.offset) { cellIndex, value in
                                    BorderedCell(width: columns[cellIndex].width) {
                                        Text(value).font(cellFont(columns[cellIndex].title))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private func items(_ report: ComparisonReport) -> [Item] {
        var items: [Item] = []

        func appendSection(_ title: String, _ color: Color, _ columns: [(title: String, width: CGFloat)], _ rows: [[String]]) {
            items.append(.header(title, color, rows.count))
            items.append(contentsOf: rows.map { .row(columns, $0) })
        }

        let standardColumns: [(title: String, width: CGFloat)] = [
            ("Filename", 170), ("Checksum", 470), ("Algorithm", 90),
            ("Size", 110), ("Created", 100), ("Modified", 100), ("Path", 340)
        ]

        if !report.unchanged.isEmpty {
            appendSection("Unchanged", .green, standardColumns, report.unchanged.map(\.fields))
        }

        if !report.added.isEmpty {
            appendSection("Added", .blue, standardColumns, report.added.map(\.fields))
        }

        if !report.removed.isEmpty {
            appendSection("Removed", .red, standardColumns, report.removed.map(\.fields))
        }

        if !report.moved.isEmpty {
            let columns: [(title: String, width: CGFloat)] = [
                ("Filename", 170), ("Checksum", 470), ("Size", 110), ("From", 340), ("To", 340)
            ]
            let rows = report.moved.map { [$0.to.filename, $0.to.checksum, $0.to.size, $0.from.path, $0.to.path] }

            appendSection("Moved", .orange, columns, rows)
        }

        if !report.renamed.isEmpty {
            let columns: [(title: String, width: CGFloat)] = [
                ("Filename", 170), ("Checksum", 470), ("Size", 110), ("From", 340), ("To", 340)
            ]
            let rows = report.renamed.map { [$0.to.filename, $0.to.checksum, $0.to.size, $0.from.path, $0.to.path] }

            appendSection("Renamed", .pink, columns, rows)
        }

        if !report.changed.isEmpty {
            let columns: [(title: String, width: CGFloat)] = [
                ("Filename", 170), ("Path", 340), ("Old Size", 110), ("New Size", 110),
                ("Old Checksum", 470), ("New Checksum", 470)
            ]
            let rows = report.changed.map { [$0.new.filename, $0.new.path, $0.old.size, $0.new.size, $0.old.checksum, $0.new.checksum] }

            appendSection("Changed", .purple, columns, rows)
        }

        return items
    }
}
