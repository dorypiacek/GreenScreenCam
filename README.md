# GreenScreenCam

**GreenScreenCam** is a cross-platform application (macOS and iPadOS) that applies a green screen (virtual background) effect in real-time using Apple's Vision framework. On macOS, it can output a virtual camera feed, allowing other applications to select it as a camera source. On iPad, it simply displays the processed frames within the app.

## Features

- **Real-Time Person Segmentation**: Leverages `VNGeneratePersonSegmentationRequest` with `.balanced` quality for a stable balance of speed and accuracy.
- **Background Options**:
  - `selectedImage`: Replace the background with a chosen image.
  - `backgroundBlur`: If no image is selected, apply a Gaussian blur to the original background.
- **Cross-Platform**:
  - **macOS**: Integrates with a Core Media I/O camera extension and a system extension, enabling a virtual camera device. Other apps (Zoom, QuickTime, etc.) can select this virtual camera for the processed green screen feed.
  - **iPad**: Provides the same green screen processing and displays the result directly in the UI, but does not offer a virtual camera device.

## How It Works

1. **Segmentation**:  
   Captures frames from the device camera (via `AVManager`), uses Vision to identify the person, and creates a segmentation mask.

2. **Compositing**:  
   Scales the background image or blurs the original background, then uses `CIBlendWithMask` to composite the person over the chosen background.

3. **Virtual Camera Output (macOS)**:  
   - Uses a camera extension (`CMIOExtensionDeviceSource`) and a system extension to register a virtual camera device with the OS.
   - The main app communicates with the extension by sending frames through a sink/source setup.
   - When the main app is **open and running**, processed frames are continuously sent to the extension, providing a real-time green screen feed to other apps.
   - **If the main app is closed** or not providing frames, the virtual camera shows a single placeholder frame (e.g., "Open GreenScreenCam app to start streaming") to indicate that no live feed is available.
   - In order for the extension to be installed and running, **the app needs to be in Applications folder**

## App-Extension Communication

- The app uses a combination of `CMIOExtensionDevice`, `CMIOExtensionStream`, and `CMSimpleQueue` to enqueue processed frames from the main app (via `VirtualCameraStreamManager`) to the virtual camera extension.
- When the extension receives frames from the main app, it outputs them as the virtual camera feed.
- If no frames are being received (the app is closed or not streaming), the extension falls back to a placeholder frame.
  
This ensures that:
- **When the app is open**: Other apps see the real-time, segmented feed.
- **When the app is closed**: The virtual camera device still exists, but only shows a placeholder image, so users know the app must be opened to receive a live feed.

## Usage

1. **Enable Green Screen**:
   - Set `isEnabled = true`.
   - Provide `selectedImage` for a custom background or set `backgroundBlur = true` for a blurred background.
   
2. **Selecting the Virtual Camera (macOS)**:
   - With the app running, open another application (e.g., Zoom).
   - Choose the virtual camera device from the camera selection menu.
   - The green screen feed appears if the app is currently running and providing frames. Otherwise, a placeholder image is shown.

3. **On iPad**:
   - Processed frames are displayed directly in the app.
   - No virtual camera device is provided.

4. **Resetting**:
   - Call `reset()` to stop processing and clear any selected image or state.

## Performance Notes

- `.balanced` segmentation quality ensures reasonable performance and stable segmentation.
- GPU acceleration is used if Metal is available, improving efficiency.
- Asynchronous processing is employed to maintain frame rates.

## Troubleshooting

- **No Virtual Camera in Other Apps (macOS)**:
  - Ensure you approved the system extension in System Settings.
  - Make sure the app is located in the Applications folder
  
- **Placeholder Image Displayed**:
  - If you see the placeholder, ensure the main app is open and `isEnabled` is true, with either a background image or `backgroundBlur` enabled.

- **Low Frame Rate**:
  - Consider lowering resolution or complexity.
  - Ensure running on hardware with GPU support.

## References & Resources

- **Apple Documentation**:
  - [Vision Framework](https://developer.apple.com/documentation/vision)
  - [Core Media I/O](https://developer.apple.com/documentation/coremediaio)
  - [System Extensions](https://developer.apple.com/documentation/systemextensions)

## License (MIT)

This project is licensed under the MIT License.
