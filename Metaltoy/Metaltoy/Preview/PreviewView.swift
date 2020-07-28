import SwiftUI
import Metal

struct PreviewView: UIViewControllerRepresentable {
    typealias UIViewControllerType = PreviewViewController

    func makeUIViewController(context: Context) -> PreviewViewController {
        return PreviewViewController()
    }

    func updateUIViewController(_ controller: PreviewViewController, context: Context) {
    }
}

struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
            .statusBar(hidden: true)
            .edgesIgnoringSafeArea(.all)
    }
}
