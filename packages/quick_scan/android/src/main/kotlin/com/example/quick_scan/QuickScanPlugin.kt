package com.example.quick_scan

import android.content.Context
import android.graphics.ImageFormat
import android.view.View
import androidx.annotation.NonNull
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.zxing.*
import com.google.zxing.common.HybridBinarizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** QuickScanPlugin */
class QuickScanPlugin : FlutterPlugin {
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val factory = ScanViewFactory(flutterPluginBinding.binaryMessenger)
        flutterPluginBinding.platformViewRegistry.registerViewFactory("scan_view", factory)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {

    }
}

class ScanViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val scanView = ScanView(context!!)
        EventChannel(messenger, "quick_scan/scanview_$viewId/event").setStreamHandler(scanView)
        return scanView
    }
}

class ScanView(context: Context) : PlatformView, EventChannel.StreamHandler, LifecycleOwner {
    private val viewFinder = PreviewView(context)

    private val lifecycleRegistry: LifecycleRegistry = LifecycleRegistry(this)

    private var sink: EventChannel.EventSink? = null

    init {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val targetAspectRatio = AspectRatio.RATIO_16_9
            val rotation = viewFinder.display.rotation

            val preview = buildPreviewUseCase(targetAspectRatio, rotation)
            val imageAnalysis = buildImageAnalysisUseCase(targetAspectRatio, rotation)

            val cameraSelector = CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_BACK).build()
            cameraProviderFuture.get().bindToLifecycle(this, cameraSelector, preview, imageAnalysis)
        }, ContextCompat.getMainExecutor(context))
    }

    /** Blocking camera operations are performed using this executor */
    private lateinit var cameraExecutor: ExecutorService

    override fun getView(): View {
        if (lifecycleRegistry.currentState < Lifecycle.State.RESUMED) {
            lifecycleRegistry.currentState = Lifecycle.State.RESUMED
            // Initialize our background executor
            cameraExecutor = Executors.newSingleThreadExecutor()
        }
        return viewFinder
    }

    override fun dispose() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        cameraExecutor.shutdown()
    }

    override fun getLifecycle() = lifecycleRegistry

    private fun buildPreviewUseCase(aspectRatio: Int, rotation: Int): Preview {
        // Build the viewfinder use case
        val preview = Preview.Builder()
                // We request aspect ratio but no resolution
                .setTargetAspectRatio(aspectRatio)
                // Set initial target rotation
                .setTargetRotation(rotation)
                .build()

        // Attach the viewfinder's surface provider to preview use case
        preview.setSurfaceProvider(viewFinder.surfaceProvider)
        return preview
    }

    private fun buildImageAnalysisUseCase(aspectRatio: Int, rotation: Int): ImageAnalysis {
        val imageAnalyzer = ImageAnalysis.Builder()
                // We request aspect ratio but no resolution
                .setTargetAspectRatio(aspectRatio)
                // Set initial target rotation, we will have to call this again if rotation changes
                // during the lifecycle of this use case
                .setTargetRotation(rotation)
                .build()

        // Build the image analysis use case and instantiate our analyzer
        imageAnalyzer.setAnalyzer(cameraExecutor, QRCodeAnalyzer())
        return imageAnalyzer
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private inner class QRCodeAnalyzer : ImageAnalysis.Analyzer {
        private val reader = MultiFormatReader().apply {
            setHints(mapOf(DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE)))
        }

        override fun analyze(image: ImageProxy) {
            if (image.format != ImageFormat.YUV_420_888) {
                println("Unsupported format: ${image.format}")
                return
            }

            val bytes = image.planes[0].buffer.toByteArray()
            val luminanceSource = PlanarYUVLuminanceSource(
                    bytes,
                    image.width,
                    image.height,
                    0,
                    0,
                    image.width,
                    image.height,
                    false
            )
            val binaryBitmap = BinaryBitmap(HybridBinarizer(luminanceSource))

            try {
                val result = reader.decode(binaryBitmap)
                viewFinder.post { sink?.success(result.text) }
            } catch (e: NotFoundException) {
                // Empty
            }

            image.close()
        }

        private fun ByteBuffer.toByteArray(): ByteArray {
            rewind()    // Rewind the buffer to zero
            val data = ByteArray(remaining())
            get(data)   // Copy the buffer into a byte array
            return data // Return the byte array
        }
    }
}
