import MetalKit

class MetalRenderer: NSObject, MTKViewDelegate {

    // metal interface to GPU
    let device: MTLDevice

    // organizes command buffers for the GPU to execute
    // use queue to create one more command buffer objects, then
    // encode commands into those objects and commit them
    let commandQueue: MTLCommandQueue

    // graphics functions and config state for a render pass
    // (create early in app lifetime and save)
    private let computePipelineState: MTLComputePipelineState

    // shader params
    private let startTime: Double
    private let texture: MTLTexture
    private let uniformsBuffer: MTLBuffer

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = device
        self.commandQueue = commandQueue

        // setup a pipeline using a default shader
        guard let computePipeline = MetalRenderer.buildComputePipeline(device, function: "grayscaleKernel") else {
            fatalError("Could not build compute pipeline.")
        }
        self.computePipelineState = computePipeline

        let textureLoader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "dog-small", withExtension: "jpg")!
        texture = try! textureLoader.newTexture(URL: url, options: [:])

        // create uniforms buffer with defaults
        startTime = CACurrentMediaTime()
        var initUniforms = Uniforms(time: 0.0)
        guard let uniformsBuffer = device.makeBuffer(bytes: &initUniforms, length: MemoryLayout<Uniforms>.stride, options: []) else {
            fatalError("Could not setup Uniforms buffer")
        }
        self.uniformsBuffer = uniformsBuffer

        super.init()
    }

    private static func buildComputePipeline(_ device: MTLDevice, function: String) -> MTLComputePipelineState? {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default Metal library")
        }

        do {
            guard let function = library.makeFunction(name: function) else {
                return nil
            }
            return try device.makeComputePipelineState(function: function)
        } catch {
            let compilerMessages = parseCompilerOutput(error.localizedDescription)
            fatalError("Unable to compile render pipeline state due to error:\(compilerMessages)")
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func update() {
        // cast? as original struct type to access underlying memory
        let ptr = uniformsBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        ptr.pointee.time = Float(CACurrentMediaTime() - startTime)
    }

    func draw(in view: MTKView) {
        // PER FRAME:
        // create a command buffer and use it to create one or more command
        // encoders with render commands
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
            let drawable = view.currentDrawable else {
                return
        }

        update()

        // setup encoder to use our previously created pipeline instructions
        commandEncoder.setComputePipelineState(computePipelineState)

        // input texture
        commandEncoder.setTexture(texture, index: 0)

        // output texture
        commandEncoder.setTexture(drawable.texture, index: 1)

        // assign uniforms
        commandEncoder.setBuffer(uniformsBuffer, offset: 0, index: 0)

        // split texture size into thread groups
        // NOTE: the last groups may not be full size, shader will need to bounds check
        let threadGroupSize = MTLSizeMake(16, 16, 1)
        let threadGroups = MTLSizeMake((drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                       (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                       1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)

        // enqueu command and present
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

