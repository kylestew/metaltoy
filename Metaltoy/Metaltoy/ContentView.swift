import SwiftUI

struct ContentView: View {
    var body: some View {
        PreviewView()
            .statusBar(hidden: true)
            .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
