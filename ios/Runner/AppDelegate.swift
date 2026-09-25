import Flutter
import UIKit
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var silentAudioPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    // Method Channel for Admin Background Keep-Alive
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.mahameek.app/admin_keep_alive",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "enableKeepAlive":
          self?.startSilentAudioKeepAlive()
          result(true)
        case "disableKeepAlive":
          self?.stopSilentAudioKeepAlive()
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound, .list])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Mahameek APNs registration notice: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  private func startSilentAudioKeepAlive() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)

      if silentAudioPlayer == nil {
        let data = createSilentWavData()
        silentAudioPlayer = try AVAudioPlayer(data: data)
        silentAudioPlayer?.numberOfLoops = -1 // Infinite loop
        silentAudioPlayer?.volume = 0.01 // Inaudible
      }
      silentAudioPlayer?.play()
      print("Mahameek: Admin Background Keep-Alive Activated")
    } catch {
      print("Mahameek: Failed to start silent keep-alive: \(error)")
    }
  }

  private func stopSilentAudioKeepAlive() {
    silentAudioPlayer?.stop()
    silentAudioPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    print("Mahameek: Admin Background Keep-Alive Deactivated")
  }

  private func createSilentWavData() -> Data {
    let sampleRate: Int32 = 8000
    let numChannels: Int16 = 1
    let bitsPerSample: Int16 = 16
    let byteRate: Int32 = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
    let blockAlign: Int16 = numChannels * (bitsPerSample / 8)
    let numSamples: Int = 8000 // 1 second
    let dataSize: Int32 = Int32(numSamples * 2)
    let chunkSize: Int32 = 36 + dataSize

    var data = Data()
    data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
    data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
    data.append(contentsOf: [0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20]) // "WAVEfmt "
    var subchunk1Size: Int32 = 16
    var audioFormat: Int16 = 1
    data.append(withUnsafeBytes(of: subchunk1Size.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
    data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
    data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
    data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
    data.append(Data(count: Int(dataSize))) // 1 second of silence
    return data
  }
}
