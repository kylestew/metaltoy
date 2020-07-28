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
    private var pipelineState: MTLRenderPipelineState

    // parameter buffers
    var timeBuffer: MTLBuffer?
    var resBuffer: MTLBuffer?

    // render surface geometry buffers
    private var vertPosBuffer: MTLBuffer?
    private var texCoordBuffer: MTLBuffer?
    private var colorBuffer: MTLBuffer?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device.")
        }
        self.device = device
        self.commandQueue = commandQueue

        // setup a pipeline using a default shader
        // TODO: allow live shader compilation
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default Metal library")
        }

        do {
            let pipelineStateDescriptor = try MetalRenderer.buildRenderPipelineDescriptor(library,
                                                                                          vertexFunction: "vertexShader",
                                                                                          fragmentFunction: "fragmentShader")
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            fatalError("Unable to compile render pipeline state due to error:\(error)")
        }

        super.init()

        prepareParamBuffers()
        prepareRenderQuad()
    }

    enum RendererError: Error {
        case shaderLoadError(String)
    }

    private static func buildRenderPipelineDescriptor(_ library: MTLLibrary, vertexFunction: String, fragmentFunction: String) throws -> MTLRenderPipelineDescriptor {
        // A MTLRenderPipelineDescriptor object that describes the attributes of the render pipeline state.
        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        guard let vertexFunction = library.makeFunction(name: vertexFunction),
            let fragmentFunction = library.makeFunction(name: fragmentFunction) else {
                throw RendererError.shaderLoadError("unable to load shader function")
        }

        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false

        return pipelineDescriptor
    }

    private func prepareParamBuffers() {
        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        resBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.size, options: [])
    }

    private func prepareRenderQuad() {
        // primitive quad used as flat render plane
        let quad = RenderQuad()

        vertPosBuffer =
            device.makeBuffer(bytes: quad.vertices,
                              length: quad.vertices.count * MemoryLayout.size(ofValue: quad.vertices[0]),
                              options: .storageModeShared)

        texCoordBuffer =
            device.makeBuffer(bytes: quad.texCoords,
                              length: quad.texCoords.count * MemoryLayout.size(ofValue: quad.texCoords[0]),
                              options: .storageModeShared)

        colorBuffer =
            device.makeBuffer(bytes: quad.colorArray,
                              length: quad.colorArray.count * MemoryLayout.size(ofValue: quad.colorArray[0]),
                              options: .storageModeShared)
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
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let drawable = view.currentDrawable else {
                return
        }

        // setup encoder to use our previously created pass instructions
        commandEncoder.setRenderPipelineState(pipelineState)


        // TODO: bind uniforms
//        var fragUniforms = FragmentUniforms(time: seconds,
//                                            resolution: float2(Float(1920), Float(1080)),
//                                            audio0: 1.0,
//                                            audio1: 1.0,
//                                            audio2: 1.0)
//        renderEncoder.setFragmentBytes(&fragUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)


        // draw quad as triangle strip to make display surface
        commandEncoder.setVertexBuffer(vertPosBuffer, offset:0, index:0)
        commandEncoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        commandEncoder.setVertexBuffer(colorBuffer, offset:0, index: 2)
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)

        // enqueu command and present
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

