import Flutter
import UIKit
import AVFoundation
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var multiCamChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RastroMultiCam") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "rastro/multicam", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isSupported":
        result(AVCaptureMultiCamSession.isMultiCamSupported)
      case "captureDual":
        self?.presentMultiCam(result: result)
      case "scanFace":
        self?.presentFaceScan(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.multiCamChannel = channel
  }

  private func presentMultiCam(result: @escaping FlutterResult) {
    guard AVCaptureMultiCamSession.isMultiCamSupported else {
      result(FlutterError(code: "unsupported",
                          message: "MultiCam no soportado", details: nil))
      return
    }
    DispatchQueue.main.async {
      guard let presenter = Self.topViewController() else {
        result(FlutterError(code: "no_window",
                            message: "No se encontró ventana para presentar", details: nil))
        return
      }
      let vc = MultiCamController { paths in
        result(paths) // ["back": path, "front": path]  o  nil si canceló
      }
      vc.modalPresentationStyle = .fullScreen
      presenter.present(vc, animated: true)
    }
  }

  private func presentFaceScan(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = Self.topViewController() else {
        result(FlutterError(code: "no_window", message: "Sin ventana", details: nil))
        return
      }
      let vc = FaceScanController { path in result(path) }
      vc.modalPresentationStyle = .fullScreen
      presenter.present(vc, animated: true)
    }
  }

  /// Encuentra el view controller visible en el sistema de escenas (iOS 13+),
  /// donde AppDelegate.window es nil.
  static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
      ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
    let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

// ───────────────────────────────────────── Cámara dual simultánea (BeReal)

/// Captura la trasera y la frontal **al mismo tiempo** con AVCaptureMultiCamSession.
/// Muestra ambas previsualizaciones y un botón; al disparar guarda las dos fotos
/// y devuelve sus rutas por el closure.
final class MultiCamController: UIViewController {
  private let onDone: ([String: String]?) -> Void

  private let session = AVCaptureMultiCamSession()
  private let sessionQueue = DispatchQueue(label: "rastro.multicam.session")

  private let backOutput = AVCapturePhotoOutput()
  private let frontOutput = AVCapturePhotoOutput()
  private var backPreview: AVCaptureVideoPreviewLayer?
  private var frontPreview: AVCaptureVideoPreviewLayer?

  private var backPath: String?
  private var frontPath: String?
  private let group = DispatchGroup()
  private var backDelegate: PhotoDelegate?
  private var frontDelegate: PhotoDelegate?

  private var finished = false

  init(onDone: @escaping ([String: String]?) -> Void) {
    self.onDone = onDone
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    setupPreviews()
    setupControls()
    AVCaptureDevice.requestAccess(for: .video) { granted in
      guard granted else {
        self.finish(nil)
        return
      }
      self.sessionQueue.async { self.configureSession() }
    }
  }

  /// Deja la cámara en un formato compatible con multicam (por si un escaneo
  /// previo la dejó en un formato que no lo es → preview en negro).
  static func ensureMultiCamFormat(_ device: AVCaptureDevice) {
    if device.activeFormat.isMultiCamSupported { return }
    guard let fmt = device.formats.first(where: { $0.isMultiCamSupported }) else { return }
    do {
      try device.lockForConfiguration()
      device.activeFormat = fmt
      device.unlockForConfiguration()
    } catch {}
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  private func setupPreviews() {
    let back = AVCaptureVideoPreviewLayer()
    back.videoGravity = .resizeAspectFill
    back.frame = view.bounds
    view.layer.addSublayer(back)
    backPreview = back

    let front = AVCaptureVideoPreviewLayer()
    front.videoGravity = .resizeAspectFill
    front.cornerRadius = 14
    front.masksToBounds = true
    front.frame = CGRect(x: 18, y: 70, width: 110, height: 150)
    view.layer.addSublayer(front)
    frontPreview = front
  }

  private func setupControls() {
    let shutter = UIButton(type: .custom)
    shutter.backgroundColor = .white
    shutter.layer.cornerRadius = 36
    shutter.layer.borderColor = UIColor(red: 0.78, green: 0.95, blue: 0.11, alpha: 1).cgColor
    shutter.layer.borderWidth = 4
    shutter.translatesAutoresizingMaskIntoConstraints = false
    shutter.addTarget(self, action: #selector(capture), for: .touchUpInside)
    view.addSubview(shutter)

    let cancel = UIButton(type: .system)
    cancel.setTitle("cancelar", for: .normal)
    cancel.setTitleColor(.white, for: .normal)
    cancel.translatesAutoresizingMaskIntoConstraints = false
    cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    view.addSubview(cancel)

    NSLayoutConstraint.activate([
      shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
      shutter.widthAnchor.constraint(equalToConstant: 72),
      shutter.heightAnchor.constraint(equalToConstant: 72),
      cancel.centerYAnchor.constraint(equalTo: shutter.centerYAnchor),
      cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    backPreview?.frame = view.bounds
  }

  // ── Sesión ──────────────────────────────────────────────────────────────
  private func configureSession() {
    session.beginConfiguration()

    // Trasera
    guard let backCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
          let backInput = try? AVCaptureDeviceInput(device: backCam),
          session.canAddInput(backInput) else { session.commitConfiguration(); finish(nil); return }
    session.addInputWithNoConnections(backInput)
    Self.ensureMultiCamFormat(backCam)
    guard session.canAddOutput(backOutput) else { session.commitConfiguration(); finish(nil); return }
    session.addOutputWithNoConnections(backOutput)
    if let backPort = backInput.ports(for: .video, sourceDeviceType: backCam.deviceType, sourceDevicePosition: .back).first {
      let conn = AVCaptureConnection(inputPorts: [backPort], output: backOutput)
      if session.canAddConnection(conn) { session.addConnection(conn) }
      if let pl = backPreview {
        pl.setSessionWithNoConnection(session)
        let pconn = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: pl)
        if session.canAddConnection(pconn) { session.addConnection(pconn) }
      }
    }

    // Frontal
    guard let frontCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let frontInput = try? AVCaptureDeviceInput(device: frontCam),
          session.canAddInput(frontInput) else { session.commitConfiguration(); finish(nil); return }
    session.addInputWithNoConnections(frontInput)
    Self.ensureMultiCamFormat(frontCam)
    guard session.canAddOutput(frontOutput) else { session.commitConfiguration(); finish(nil); return }
    session.addOutputWithNoConnections(frontOutput)
    if let frontPort = frontInput.ports(for: .video, sourceDeviceType: frontCam.deviceType, sourceDevicePosition: .front).first {
      let conn = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
      if session.canAddConnection(conn) { session.addConnection(conn) }
      if let pl = frontPreview {
        pl.setSessionWithNoConnection(session)
        let pconn = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: pl)
        if pconn.isVideoMirroringSupported { pconn.automaticallyAdjustsVideoMirroring = false; pconn.isVideoMirrored = true }
        if session.canAddConnection(pconn) { session.addConnection(pconn) }
      }
    }

    session.commitConfiguration()
    session.startRunning()
  }

  // ── Captura ─────────────────────────────────────────────────────────────
  @objc private func capture() {
    let settings1 = AVCapturePhotoSettings()
    let settings2 = AVCapturePhotoSettings()

    group.enter()
    backDelegate = PhotoDelegate { data in
      self.backPath = self.saveJPEG(data, name: "back")
      self.group.leave()
    }
    group.enter()
    frontDelegate = PhotoDelegate { data in
      self.frontPath = self.saveJPEG(data, name: "front")
      self.group.leave()
    }

    backOutput.capturePhoto(with: settings1, delegate: backDelegate!)
    frontOutput.capturePhoto(with: settings2, delegate: frontDelegate!)

    group.notify(queue: .main) {
      guard let b = self.backPath else { self.finish(nil); return }
      var map = ["back": b]
      if let f = self.frontPath { map["front"] = f }
      self.finish(map)
    }
  }

  private func saveJPEG(_ data: Data?, name: String) -> String? {
    guard let data = data else { return nil }
    let dir = NSTemporaryDirectory()
    let path = (dir as NSString).appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
    return (try? data.write(to: URL(fileURLWithPath: path))) != nil ? path : nil
  }

  @objc private func cancelTapped() { finish(nil) }

  private func finish(_ paths: [String: String]?) {
    guard !finished else { return }
    finished = true
    sessionQueue.async {
      if self.session.isRunning { self.session.stopRunning() }
    }
    DispatchQueue.main.async {
      self.dismiss(animated: true) { self.onDone(paths) }
    }
  }
}

/// Delegado de una sola foto: devuelve los bytes JPEG.
final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let onData: (Data?) -> Void
  init(onData: @escaping (Data?) -> Void) { self.onData = onData }
  func photoOutput(_ output: AVCapturePhotoOutput,
                   didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    onData(photo.fileDataRepresentation())
  }
}

// ──────────────────────────── Escáner facial en vivo (estilo banco)

/// Verificación biométrica interactiva: preview frontal en vivo + detección de
/// rostro real (Vision). El anillo se llena mientras hay un rostro centrado; al
/// completarse, captura el rostro de referencia y lo devuelve.
final class FaceScanController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

  private let onDone: (String?) -> Void
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "rastro.facescan")
  private let videoOutput = AVCaptureVideoDataOutput()
  private let photoOutput = AVCapturePhotoOutput()
  private var preview: AVCaptureVideoPreviewLayer?

  private let dimLayer = CAShapeLayer()
  private let ring = CAShapeLayer()
  private let promptLabel = UILabel()
  private var ovalRect = CGRect.zero

  // Enrolamiento por pasos: el usuario mueve la cabeza (estilo Face ID).
  private struct Paso { let prompt: String; let ok: (Double, Double) -> Bool }
  private let pasos: [Paso] = [
    Paso(prompt: "Mira de frente a la cámara") { yaw, box in abs(yaw) < 0.14 && box > 0.17 },
    Paso(prompt: "Acércate un poco") { _, box in box > 0.33 },
    Paso(prompt: "Gira la cabeza a un lado") { yaw, _ in yaw > 0.27 },
    Paso(prompt: "Ahora gírala al otro lado") { yaw, _ in yaw < -0.27 },
  ]
  private var pasoIdx = 0
  private var hold = 0
  private var yaw: Double = 0
  private var boxW: Double = 0
  private var avatarPath: String?
  private var capturaPedida = false
  private var frameCount = 0
  private var finished = false
  private var timer: Timer?

  init(onDone: @escaping (String?) -> Void) {
    self.onDone = onDone
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    setupUI()
    AVCaptureDevice.requestAccess(for: .video) { granted in
      guard granted else { self.finish(nil); return }
      self.sessionQueue.async { self.configure() }
    }
  }

  // ── UI ──
  private func setupUI() {
    let pv = AVCaptureVideoPreviewLayer(session: session)
    pv.videoGravity = .resizeAspectFill
    pv.frame = view.bounds
    if let conn = pv.connection, conn.isVideoMirroringSupported {
      conn.automaticallyAdjustsVideoMirroring = false
      conn.isVideoMirrored = false // sin espejo: muestra la imagen real
    }
    view.layer.addSublayer(pv)
    preview = pv

    dimLayer.fillRule = .evenOdd
    dimLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
    view.layer.addSublayer(dimLayer)

    ring.fillColor = UIColor.clear.cgColor
    ring.strokeColor = UIColor(red: 0.78, green: 0.95, blue: 0.11, alpha: 1).cgColor
    ring.lineWidth = 5
    ring.lineCap = .round
    ring.strokeEnd = 0
    view.layer.addSublayer(ring)

    promptLabel.text = "Sigue las instrucciones\npara registrar tu rostro"
    promptLabel.textColor = .white
    promptLabel.font = .monospacedSystemFont(ofSize: 19, weight: .bold)
    promptLabel.textAlignment = .center
    promptLabel.numberOfLines = 3
    promptLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(promptLabel)

    // Instrucción fija arriba.
    let titulo = UILabel()
    titulo.text = "REGISTRO FACIAL"
    titulo.textColor = UIColor(red: 0.78, green: 0.95, blue: 0.11, alpha: 1)
    titulo.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
    titulo.textAlignment = .center
    titulo.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(titulo)
    NSLayoutConstraint.activate([
      titulo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      titulo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
    ])

    let cancel = UIButton(type: .system)
    cancel.setTitle("cancelar", for: .normal)
    cancel.setTitleColor(.white, for: .normal)
    cancel.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    cancel.translatesAutoresizingMaskIntoConstraints = false
    cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    view.addSubview(cancel)

    NSLayoutConstraint.activate([
      promptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      promptLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
      promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
      promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
      cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview?.frame = view.bounds
    let w = min(view.bounds.width * 0.72, 300)
    let h = w * 1.28
    ovalRect = CGRect(x: (view.bounds.width - w) / 2,
                      y: view.bounds.height * 0.26,
                      width: w, height: h)
    let oval = UIBezierPath(ovalIn: ovalRect)
    let full = UIBezierPath(rect: view.bounds)
    full.append(oval)
    dimLayer.path = full.cgPath
    ring.path = oval.cgPath
  }

  // ── Sesión ──
  private func configure() {
    session.beginConfiguration()
    session.sessionPreset = .photo
    guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: cam),
          session.canAddInput(input) else { session.commitConfiguration(); finish(nil); return }
    session.addInput(input)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
    if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
    // Sin espejo también en la foto capturada.
    if let pc = photoOutput.connection(with: .video), pc.isVideoMirroringSupported {
      pc.automaticallyAdjustsVideoMirroring = false
      pc.isVideoMirrored = false
    }
    session.commitConfiguration()
    session.startRunning()
    DispatchQueue.main.async {
      // El espejo del preview hay que apagarlo con la conexión ya viva.
      if let c = self.preview?.connection, c.isVideoMirroringSupported {
        c.automaticallyAdjustsVideoMirroring = false
        c.isVideoMirrored = false
      }
      self.startTimer()
    }
  }

  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
      self?.tick()
    }
  }

  private func tick() {
    if finished { return }
    let total = pasos.count
    if pasoIdx >= total {
      promptLabel.text = "¡listo!"
      ring.strokeEnd = 1
      if avatarPath != nil { finish(avatarPath) }
      return
    }
    let paso = pasos[pasoIdx]
    let detecta = paso.ok(yaw, boxW)
    promptLabel.text = "paso \(pasoIdx + 1) de \(pasos.count)\n\(paso.prompt)"
    + (detecta ? "\n✓" : "")
    hold = detecta ? hold + 1 : max(0, hold - 1)
    if hold >= 7 {                       // mantenido ~0.45 s
      if pasoIdx == 0, !capturaPedida {  // el avatar es la toma de frente
        capturaPedida = true
        sessionQueue.async {
          self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
      }
      pasoIdx += 1
      hold = 0
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.25)
      ring.strokeEnd = CGFloat(pasoIdx) / CGFloat(total)
      CATransaction.commit()
    }
  }

  // ── Detección de rostro por frame (posición + giro) ──
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    frameCount += 1
    if frameCount % 2 != 0 { return }
    guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let req = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .leftMirrored, options: [:])
    try? handler.perform([req])
    let faces = req.results ?? []
    let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width })
    let w = Double(face?.boundingBox.width ?? 0)
    let y = face?.yaw?.doubleValue ?? 0
    DispatchQueue.main.async { self.boxW = w; self.yaw = y }
  }

  func photoOutput(_ output: AVCapturePhotoOutput,
                   didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let data = photo.fileDataRepresentation() else { return }
    let dir = NSTemporaryDirectory()
    let path = (dir as NSString).appendingPathComponent("rostro_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
    if (try? data.write(to: URL(fileURLWithPath: path))) != nil {
      DispatchQueue.main.async { self.avatarPath = path }
    }
  }

  @objc private func cancelTapped() { finish(nil) }

  private func finish(_ path: String?) {
    guard !finished else { return }
    finished = true
    DispatchQueue.main.async { self.timer?.invalidate() }
    sessionQueue.async {
      if self.session.isRunning { self.session.stopRunning() }
    }
    DispatchQueue.main.async {
      self.dismiss(animated: true) { self.onDone(path) }
    }
  }
}
