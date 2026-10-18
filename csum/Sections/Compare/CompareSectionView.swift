import SwiftUI

struct CompareSectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Compare", systemImage: "doc.on.doc")
        } description: {
            Text("Compare a .csum.csv file with the folder it describes.")
        }
    }
}
