import UIKit
import MetalKit

class PreviewViewController : UIViewController {

    var renderer: MetalRenderer!
    var mtlView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = MetalRenderer()

        mtlView = MTKView(frame: view.frame, device: renderer.device)
        mtlView.framebufferOnly = false
        mtlView.translatesAutoresizingMaskIntoConstraints = false
        mtlView.delegate = renderer

        mtlView.clearColor = MTLClearColor(red: 1, green: 0, blue: 0.8, alpha: 1)

        view.addSubview(mtlView)
    }

    func pause() {
        mtlView.isPaused = true
    }
}

