# AVCam：构建相机应用程序

 使用iphone和ipad前后置相机捕获具有深度数据的照片，并录制视频

## 概述

iOS相机应用程序可以让您从前后置相机捕获照片和视频。根据设备，“相机”应用程序还支持深度数据、人像效果和实时照片的静态捕获。

该示例代码项目AVCam展示了如何在自己的相机应用程序中实现这些捕获功能。这个示例代码项目AVCam向您展示了如何在自己的相机应用程序中实现这些捕获功能。它利用了内置的iPhone和iPad前后摄像头的基本功能。

要使用AVCam，你需要一个运行ios13或更高版本的iOS设备。由于Xcode无法访问设备摄像头，因此此示例无法在模拟器中工作。AVCam隐藏了当前设备不支持的模式按钮，比如iPhone 7 Plus上的人像效果 曝光传送。

## 配置捕获会话

* AVCaptureSession接受来自摄像头和麦克风等捕获设备的输入数据。在接收到输入后， AVCaptureSession将数据封送到适当的输出进行处理，最终生成一个电影文件或静态照片。配置捕获会话的输入和输出之后，您将告诉它开始捕获，然后停止捕获。

```
private let session = AVCaptureSession()
```

* AVCam默认选择后摄像头，并配置摄像头捕获会话以将内容流到视频预览视图。PreviewView是一个由AVCaptureVideoPreviewLayer支持的自定义UIView子类。AVFoundation没有PreviewView类，但是示例代码创建了一个类来促进会话管理。

* 下图显示了会话如何管理输入设备和捕获输出:

![](https://docs-assets.developer.apple.com/published/03c342d2de/641b82d0-4d99-4c1e-bce5-dcfc135d094c.png)

* 将与avcapturesessiessie的任何交互(包括它的输入和输出)委托给一个专门的串行调度队列(sessionQueue)，这样交互就不会阻塞主队列。在单独的调度队列上执行任何涉及更改会话拓扑或中断其正在运行的视频流的配置，因为会话配置总是阻塞其他任务的执行，直到队列处理更改为止。类似地，样例代码将其他任务分派给会话队列，比如恢复中断的会话、切换捕获模式、切换摄像机、将媒体写入文件，这样它们的处理就不会阻塞或延迟用户与应用程序的交互。

* 相反，代码将影响UI的任务(比如更新预览视图)分派给主队列，因为AVCaptureVideoPreviewLayer是CALayer的一个子类，是示例预览视图的支持层。您必须在主线程上操作UIView子类，以便它们以及时的、交互的方式显示。

* 在viewDidLoad中，AVCam创建一个会话并将其分配给preview视图

``` swift
previewView.session = session
```

* 有关配置图像捕获会话的更多信息，请参见设置捕获会话。

![](https://docs-assets.developer.apple.com/published/90ad0ad032/b9c65b62-3728-43f1-8d25-08fd42bc6bb7.png)

## 请求访问输入设备的授权

* 配置会话之后，它就可以接受输入了。每个avcapturedevice—不管是照相机还是麦克风—都需要用户授权访问。AVFoundation使用AVAuthorizationStatus枚举授权状态，该状态通知应用程序用户是否限制或拒绝访问捕获设备。

* 有关准备应用程序信息的更多信息。有关自定义授权请求，请参阅iOS上的媒体捕获请求授权。

## 在前后摄像头之间切换

* changeCamera方法在用户点击UI中的按钮时处理相机之间的切换。它使用一个发现会话，该会话按优先顺序列出可用的设备类型，并接受它的设备数组中的第一个设备。例如，AVCam中的videoDeviceDiscoverySession查询应用程序所运行的设备，查找可用的输入设备。此外，如果用户的设备有一个坏了的摄像头，它将不能在设备阵列中使用。

``` swift
switch currentPosition {
case .unspecified, .front:
    preferredPosition = .back
    preferredDeviceType = .builtInDualCamera
    
case .back:
    preferredPosition = .front
    preferredDeviceType = .builtInTrueDepthCamera
    
@unknown default:
    print("Unknown capture position. Defaulting to back, dual-camera.")
    preferredPosition = .back
    preferredDeviceType = .builtInDualCamera
}
```

* 如果发现会话发现相机处于适当的位置，它将从捕获会话中删除以前的输入，并将新相机添加为输入。

``` swift
// Remove the existing device input first, because AVCaptureSession doesn't support
// simultaneous use of the rear and front cameras.
self.session.removeInput(self.videoDeviceInput)

if self.session.canAddInput(videoDeviceInput) {
    NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
    NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
    
    self.session.addInput(videoDeviceInput)
    self.videoDeviceInput = videoDeviceInput
} else {
    self.session.addInput(self.videoDeviceInput)
}
```

## 处理中断和错误

在捕获会话期间，可能会出现诸如电话呼叫、其他应用程序通知和音乐播放等中断。通过添加观察者来处理这些干扰，以监听AVCaptureSessionWasInterrupted:

``` swift
NotificationCenter.default.addObserver(self,
                                       selector: #selector(sessionWasInterrupted),
                                       name: .AVCaptureSessionWasInterrupted,
                                       object: session)
NotificationCenter.default.addObserver(self,
                                       selector: #selector(sessionInterruptionEnded),
                                       name: .AVCaptureSessionInterruptionEnded,
                                       object: session)
```

* 当AVCam接收到中断通知时，它可以暂停或挂起会话，并提供一个在中断结束时恢复活动的选项。AVCam将sessionwas注册为接收通知的处理程序，当捕获会话出现中断时通知用户:

``` swift
if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
    showResumeButton = true
} else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
    // Fade-in a label to inform the user that the camera is unavailable.
    cameraUnavailableLabel.alpha = 0
    cameraUnavailableLabel.isHidden = false
    UIView.animate(withDuration: 0.25) {
        self.cameraUnavailableLabel.alpha = 1
    }
} else if reason == .videoDeviceNotAvailableDueToSystemPressure {
    print("Session stopped running due to shutdown system pressure level.")
}
```

* 摄像头视图控制器观察AVCaptureSessionRuntimeError，当错误发生时接收通知:

``` swift
NotificationCenter.default.addObserver(self,
                                       selector: #selector(sessionRuntimeError),
                                       name: .AVCaptureSessionRuntimeError,
                                       object: session)
```

* 当运行时错误发生时，重新启动捕获会话:

``` swift
// If media services were reset, and the last start succeeded, restart the session.
if error.code == .mediaServicesWereReset {
    sessionQueue.async {
        if self.isSessionRunning {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        } else {
            DispatchQueue.main.async {
                self.resumeButton.isHidden = false
            }
        }
    }
} else {
    resumeButton.isHidden = false
}
```

* 如果设备承受系统压力，比如过热，捕获会话也可能停止。相机本身不会降低拍摄质量或减少帧数;为了避免让你的用户感到惊讶，你可以让你的应用手动降低帧速率，关闭深度，或者根据AVCaptureDevice.SystemPressureState:的反馈来调整性能。

``` swift
let pressureLevel = systemPressureState.level
if pressureLevel == .serious || pressureLevel == .critical {
    if self.movieFileOutput == nil || self.movieFileOutput?.isRecording == false {
        do {
            try self.videoDeviceInput.device.lockForConfiguration()
            print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
            self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
            self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            self.videoDeviceInput.device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }
} else if pressureLevel == .shutdown {
    print("Session stopped running due to shutdown system pressure level.")
}
```

## 捕捉一张照片

在会话队列上拍照。该过程首先更新AVCapturePhotoOutput连接以匹配视频预览层的视频方向。这使得相机能够准确地捕捉到用户在屏幕上看到的内容:

``` swift
if let photoOutputConnection = self.photoOutput.connection(with: .video) {
    photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
}
```

对齐输出后，AVCam继续创建AVCapturePhotoSettings来配置捕获参数，如焦点、flash和分辨率:

``` swift
var photoSettings = AVCapturePhotoSettings()

// Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
}

if self.videoDeviceInput.device.isFlashAvailable {
    photoSettings.flashMode = .auto
}

photoSettings.isHighResolutionPhotoEnabled = true
if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
}
// Live Photo capture is not supported in movie mode.
if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported {
    let livePhotoMovieFileName = NSUUID().uuidString
    let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
    photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
}

photoSettings.isDepthDataDeliveryEnabled = (self.depthDataDeliveryMode == .on
    && self.photoOutput.isDepthDataDeliveryEnabled)

photoSettings.isPortraitEffectsMatteDeliveryEnabled = (self.portraitEffectsMatteDeliveryMode == .on
    && self.photoOutput.isPortraitEffectsMatteDeliveryEnabled)

if photoSettings.isDepthDataDeliveryEnabled {
    if !self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
        photoSettings.enabledSemanticSegmentationMatteTypes = self.selectedSemanticSegmentationMatteTypes
    }
}

photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
```

该示例使用一个单独的对象PhotoCaptureProcessor作为照片捕获委托，以隔离每个捕获生命周期。对于实时照片来说，这种清晰的捕获周期分离是必要的，因为单个捕获周期可能涉及多个帧的捕获。

每次用户按下中央快门按钮时，AVCam都会通过调用capturePhoto(带有:delegate:)来使用之前配置的设置捕捉照片:

``` swift
self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
```

capturePhoto方法接受两个参数:

* 一个avcapturephotoset对象，它封装了用户通过应用配置的设置，比如曝光、闪光、对焦和手电筒。
* 一个符合AVCapturePhotoCaptureDelegate协议的委托，以响应系统在捕获照片期间传递的后续回调。

一旦应用程序调用capturePhoto(with:delegate:)，开始拍照的过程就结束了。此后，对单个照片捕获的操作将在委托回调中发生。

## 通过照片捕获委托跟踪结果

capturePhoto方法只是开始拍照的过程。剩下的过程发生在应用程序实现的委托方法中。

![](https://docs-assets.developer.apple.com/published/9682e6da8f/ddbcc979-3cd8-4f5d-a9b3-2b8b155c65e4.png)

* 当你调用capturePhoto时，photoOutput(_:willBeginCaptureFor:)首先到达。解析的设置表示相机将为即将到来的照片应用的实际设置。AVCam仅将此方法用于特定于活动照片的行为。AVCam通过检查livephotomovieviedimensions尺寸来判断照片是否为活动照片;如果照片是活动照片，AVCam会增加一个计数来跟踪活动中的照片:

``` swift
self.sessionQueue.async {
    if capturing {
        self.inProgressLivePhotoCapturesCount += 1
    } else {
        self.inProgressLivePhotoCapturesCount -= 1
    }
    
    let inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount
    DispatchQueue.main.async {
        if inProgressLivePhotoCapturesCount > 0 {
            self.capturingLivePhotoLabel.isHidden = false
        } else if inProgressLivePhotoCapturesCount == 0 {
            self.capturingLivePhotoLabel.isHidden = true
        } else {
            print("Error: In progress Live Photo capture count is less than 0.")
        }
    }
}
```

- photoOutput(_:willCapturePhotoFor:)正好在系统播放快门声之后到达。AVCam利用这个机会来闪烁屏幕，提醒用户照相机捕获了一张照片。示例代码通过将预览视图层的不透明度从0调整到1来实现此flash。

``` swift
// Flash the screen to signal that AVCam took a photo.
DispatchQueue.main.async {
    self.previewView.videoPreviewLayer.opacity = 0
    UIView.animate(withDuration: 0.25) {
        self.previewView.videoPreviewLayer.opacity = 1
    }
}
```

- photoOutput(_:didFinishProcessingPhoto:error:)在系统完成深度数据处理和人像效果处理后到达。AVCam检查肖像效果，曝光和深度元数据在这个阶段:

``` swift
// A portrait effects matte gets generated only if AVFoundation detects a face.
if var portraitEffectsMatte = photo.portraitEffectsMatte {
    if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
        portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
    }
    let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
    let portraitEffectsMatteImage = CIImage( cvImageBuffer: portraitEffectsMattePixelBuffer, options: [ .auxiliaryPortraitEffectsMatte: true ] )
```

- photoOutput(_:didFinishProcessingPhoto:error:)在系统完成深度数据处理和人像效果处理后到达。AVCam检查肖像效果，曝光和深度元数据在这个阶段:

``` swift
self.sessionQueue.async {
    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
}
```

您可以在此委托方法中应用其他视觉效果，例如动画化捕获照片的预览缩略图。

有关通过委托回调跟踪照片进度的更多信息，请参见跟踪照片捕获进度。

## 捕捉实时的照片

* 当您启用实时照片捕捉功能时，相机会在捕捉瞬间拍摄一张静止图像和一段短视频。该应用程序以与静态照片捕获相同的方式触发实时照片捕获:通过对capturePhotoWithSettings的单个调用，您可以通过livePhotoMovieFileURL属性传递实时照片短视频的URL。您可以在AVCapturePhotoOutput级别启用活动照片，也可以在每次捕获的基础上在avcapturephotoset级别配置活动照片。

* 由于Live Photo capture创建了一个简短的电影文件，AVCam必须表示将电影文件保存为URL的位置。此外，由于实时照片捕捉可能会重叠，因此代码必须跟踪正在进行的实时照片捕捉的数量，以确保实时照片标签在这些捕捉期间保持可见。上一节中的photoOutput(_:willBeginCaptureFor:)委托方法实现了这个跟踪计数器。

![](https://docs-assets.developer.apple.com/published/b286f39fa5/02d45702-e78f-4e15-9603-fa1f97f53d3e.png)

- photoOutput(_:didFinishRecordingLivePhotoMovieForEventualFileAt:resolvedSettings:)在录制短片结束时触发。AVCam取消了这里的活动标志。因为摄像机已经完成了短片的录制，AVCam执行Live Photo处理器递减完成计数器:livePhotoCaptureHandler(false)

``` swift
livePhotoCaptureHandler(false)
```

- photoOutput(_:didFinishProcessingLivePhotoToMovieFileAt:duration:photoDisplayTime:resolvedSettings:error:)最后触发，表示影片已完全写入磁盘，可以使用了。AVCam利用这个机会来显示任何捕获错误，并将保存的文件URL重定向到它的最终输出位置:

``` swift
if error != nil {
    print("Error processing Live Photo companion movie: \(String(describing: error))")
    return
}
livePhotoCompanionMovieURL = outputFileURL
```

有关将实时照片捕捉功能整合到应用程序中的更多信息，请参见“捕捉静态照片”和“实时照片”。

## 捕获深度数据和人像效果曝光

使用AVCapturePhotoOutput, AVCam查询捕获设备，查看其配置是否可以将深度数据和人像效果传送到静态图像。如果输入设备支持这两种模式中的任何一种，并且您在捕获设置中启用了它们，则相机将深度和人像效果作为辅助元数据附加到每张照片请求的基础上。如果设备支持深度数据、人像效果或实时照片的传输，应用程序会显示一个按钮，用来切换启用或禁用该功能的设置。

``` swift
           if self.photoOutput.isDepthDataDeliverySupported {
               self.photoOutput.isDepthDataDeliveryEnabled = true
               
               DispatchQueue.main.async {
                   self.depthDataDeliveryButton.isEnabled = true
               }
           }
           
           if self.photoOutput.isPortraitEffectsMatteDeliverySupported {
               self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = true
               
               DispatchQueue.main.async {
                   self.portraitEffectsMatteDeliveryButton.isEnabled = true
               }
           }
           
           if !self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
self.photoOutput.enabledSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
               self.selectedSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
               
               DispatchQueue.main.async {
                   self.semanticSegmentationMatteDeliveryButton.isEnabled = (self.depthDataDeliveryMode == .on) ? true : false
               }
           }
           
           DispatchQueue.main.async {
               self.livePhotoModeButton.isHidden = false
               self.depthDataDeliveryButton.isHidden = false
               self.portraitEffectsMatteDeliveryButton.isHidden = false
               self.semanticSegmentationMatteDeliveryButton.isHidden = false
               self.photoQualityPrioritizationSegControl.isHidden = false
               self.photoQualityPrioritizationSegControl.isEnabled = true
           }
```

相机存储深度和人像效果的曝光元数据作为辅助图像，可通过图像I/O API发现和寻址。AVCam通过搜索kCGImageAuxiliaryDataTypePortraitEffectsMatte类型的辅助图像来访问这个元数据:

```
if var portraitEffectsMatte = photo.portraitEffectsMatte {
    if let orientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32 {
        portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
    }
    let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
```

有关深度数据捕获的更多信息，请参见使用深度捕获照片。

## 捕捉语义分割

使用AVCapturePhotoOutput, AVCam还可以捕获语义分割图像，将一个人的头发、皮肤和牙齿分割成不同的图像。将这些辅助图像与你的主要照片一起捕捉，可以简化照片效果的应用，比如改变一个人的头发颜色或让他们的笑容更灿烂。
通过将照片输出的enabledSemanticSegmentationMatteTypes属性设置为首选值(头发、皮肤和牙齿)，可以捕获这些辅助图像。要捕获所有受支持的类型，请设置此属性以匹配照片输出的availableSemanticSegmentationMatteTypes属性。

```swift
// Capture all available semantic segmentation matte types.
photoOutput.enabledSemanticSegmentationMatteTypes = 
    photoOutput.availableSemanticSegmentationMatteTypes
```

当照片输出完成捕获一张照片时，您可以通过查询照片的semanticSegmentationMatte(for:)方法来检索相关的分割matte图像。此方法返回一个AVSemanticSegmentationMatte，其中包含matte图像和处理图像时可以使用的其他元数据。示例应用程序将语义分割的matte图像数据添加到一个数组中，这样您就可以将其写入用户的照片库。

``` swift
// Find the semantic segmentation matte image for the specified type.
guard var segmentationMatte = photo.semanticSegmentationMatte(for: ssmType) else { return }

// Retrieve the photo orientation and apply it to the matte image.
if let orientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
    let exifOrientation = CGImagePropertyOrientation(rawValue: orientation) {
    // Apply the Exif orientation to the matte image.
    segmentationMatte = segmentationMatte.applyingExifOrientation(exifOrientation)
}

var imageOption: CIImageOption!

// Switch on the AVSemanticSegmentationMatteType value.
switch ssmType {
case .hair:
    imageOption = .auxiliarySemanticSegmentationHairMatte
case .skin:
    imageOption = .auxiliarySemanticSegmentationSkinMatte
case .teeth:
    imageOption = .auxiliarySemanticSegmentationTeethMatte
default:
    print("This semantic segmentation type is not supported!")
    return
}

guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }

// Create a new CIImage from the matte's underlying CVPixelBuffer.
let ciImage = CIImage( cvImageBuffer: segmentationMatte.mattingImage,
                       options: [imageOption: true,
                                 .colorSpace: perceptualColorSpace])

// Get the HEIF representation of this image.
guard let imageData = context.heifRepresentation(of: ciImage,
                                                 format: .RGBA8,
                                                 colorSpace: perceptualColorSpace,
                                                 options: [.depthImage: ciImage]) else { return }

// Add the image data to the SSM data array for writing to the photo library.
semanticSegmentationMatteDataArray.append(imageData)
```

## 保存照片到用户的照片库

在将图像或电影保存到用户的照片库之前，必须首先请求访问该库。请求写授权的过程镜像捕获设备授权:使用Info.plist中提供的文本显示警报。
AVCam在fileOutput(_:didFinishRecordingTo:from:error:)回调方法中检查授权，其中AVCaptureOutput提供了要保存为输出的媒体数据。

```
PHPhotoLibrary.requestAuthorization { status in
```

有关请求访问用户的照片库的更多信息，请参见请求访问照片的授权。

## 录制视频文件

AVCam通过使用.video限定符查询和添加输入设备来支持视频捕获。该应用程序默认为后双摄像头，但如果设备没有双摄像头，该应用程序默认为广角摄像头。

``` swift
if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
    defaultVideoDevice = dualCameraDevice
} else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
    // If a rear dual camera is not available, default to the rear wide angle camera.
    defaultVideoDevice = backCameraDevice
} else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
    // If the rear wide angle camera isn't available, default to the front wide angle camera.
    defaultVideoDevice = frontCameraDevice
}
```

不像静态照片那样将设置传递给系统，而是像活动照片那样传递输出URL。委托回调提供相同的URL，因此应用程序不需要将其存储在中间变量中。

一旦用户点击记录开始捕获，AVCam调用startRecording(to:recordingDelegate:):

``` swift
movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
```

与capturePhoto为still capture触发委托回调一样，startRecording为影片录制触发一系列委托回调。

与capturePhoto为still capture触发委托回调一样，startRecording为影片录制触发一系列委托回调。

通过委托回调链跟踪影片录制的进度。与其实现AVCapturePhotoCaptureDelegate，不如实现AVCaptureFileOutputRecordingDelegate。由于影片录制委托回调需要与捕获会话进行交互，因此AVCam将CameraViewController作为委托，而不是创建单独的委托对象。

- fileOutput(_:didStartRecordingTo:from:)，当文件输出开始向文件写入数据时触发。AVCam利用这个机会将记录按钮更改为停止按钮:

``` swift
DispatchQueue.main.async {
    self.recordButton.isEnabled = true
    self.recordButton.setImage(#imageLiteral(resourceName: "CaptureStop"), for: [])
}
```

- fileOutput(_:didFinishRecordingTo:from:error:)最后触发，表示影片已完全写入磁盘，可以使用了。AVCam利用这个机会将临时保存的影片从给定的URL移动到用户的照片库或应用程序的文档文件夹:

``` swift
PHPhotoLibrary.shared().performChanges({
    let options = PHAssetResourceCreationOptions()
    options.shouldMoveFile = true
    let creationRequest = PHAssetCreationRequest.forAsset()
    creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
}, completionHandler: { success, error in
    if !success {
        print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
    }
    cleanup()
}
)
```

如果AVCam进入后台——例如用户接受来电时——应用程序必须获得用户的许可才能继续录制。AVCam通过后台任务从系统请求时间来执行此保存。这个后台任务确保有足够的时间将文件写入照片库，即使AVCam退到后台。为了结束后台执行，AVCam在保存记录文件后[`didFinishRecordingTo`]调用[`endBackgroundTask`]

``` swift
self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
```

## 录制视频时要抓拍图片

与iOS摄像头应用程序一样，AVCam也可以在拍摄录像的同时拍照。AVCam以与视频相同的分辨率捕捉这些照片。实现代码如下：

``` swift
let movieFileOutput = AVCaptureMovieFileOutput()

if self.session.canAddOutput(movieFileOutput) {
    self.session.beginConfiguration()
    self.session.addOutput(movieFileOutput)
    self.session.sessionPreset = .high
    if let connection = movieFileOutput.connection(with: .video) {
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }
    self.session.commitConfiguration()
    
    DispatchQueue.main.async {
        captureModeControl.isEnabled = true
    }
    
    self.movieFileOutput = movieFileOutput
    
    DispatchQueue.main.async {
        self.recordButton.isEnabled = true
        
        /*
         For photo captures during movie recording, Speed quality photo processing is prioritized
         to avoid frame drops during recording.
         */
        self.photoQualityPrioritizationSegControl.selectedSegmentIndex = 0
        self.photoQualityPrioritizationSegControl.sendActions(for: UIControl.Event.valueChanged)
    }
}
```
