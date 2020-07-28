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
    private var computePipelineState: MTLComputePipelineState

    // parameter buffers
    var timeBuffer: MTLBuffer?
    var resBuffer: MTLBuffer?

    var texture: MTLTexture!

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = device
        self.commandQueue = commandQueue

        // setup a pipeline using a default shader
        guard let computePipeline = MetalRenderer.buildComputePipeline(device, function: "computeFunc") else {
            fatalError("Could not build compute pipeline.")
        }
        self.computePipelineState = computePipeline

        super.init()

        let textureLoader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "dog-small", withExtension: "jpg")!
        texture = try! textureLoader.newTexture(URL: url, options: [:])

//        prepareParamBuffers()
//        prepareRenderQuad()
    }

    private static func buildRenderPipeline(_ library: MTLLibrary, vertexFunction: String, fragmentFunction: String) -> MTLRenderPipelineDescriptor? {
        // A MTLRenderPipelineDescriptor object that describes the attributes of the render pipeline state.
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        guard let vertexFunction = library.makeFunction(name: vertexFunction),
            let fragmentFunction = library.makeFunction(name: fragmentFunction) else {
                return nil
        }

        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false

        return pipelineDescriptor
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

    private func prepareParamBuffers() {
        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        resBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.size, options: [])
    }

    private func prepareRenderQuad() {
//        // primitive quad used as flat render plane
//        let quad = RenderQuad()
//
//        vertPosBuffer =
//            device.makeBuffer(bytes: quad.vertices,
//                              length: quad.vertices.count * MemoryLayout.size(ofValue: quad.vertices[0]),
//                              options: .storageModeShared)
//
//        texCoordBuffer =
//            device.makeBuffer(bytes: quad.texCoords,
//                              length: quad.texCoords.count * MemoryLayout.size(ofValue: quad.texCoords[0]),
//                              options: .storageModeShared)
//
//        colorBuffer =
//            device.makeBuffer(bytes: quad.colorArray,
//                              length: quad.colorArray.count * MemoryLayout.size(ofValue: quad.colorArray[0]),
//                              options: .storageModeShared)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateResolution(size)
    }

    private func updateResolution(_ size: CGSize) {
        guard let buffer = resBuffer else {
            return
        }

        // TODO: correct buffer writing code (modern)
        var res = float2(Float(size.width), Float(size.height))
        let ptr = buffer.contents()
        memcpy(ptr, &res, MemoryLayout<float2>.size)
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

        // setup encoder to use our previously created pipeline instructions
        commandEncoder.setComputePipelineState(computePipelineState)

        // input texture
        commandEncoder.setTexture(texture, index: 0)

        // output texture
        commandEncoder.setTexture(drawable.texture, index: 1)


        let threadGroupCount = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width,
                                       drawable.texture.height / threadGroupCount.height,
                                       1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)


        // enqueu command and present
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

