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
      if conn.isVideoMirroringSupported { conn.automaticallyAdjustsVideoMirroring = false; conn.isVideoMirrored = false }
      if session.canAddConnection(conn) { session.addConnection(conn) }
      if let pl = frontPreview {
        pl.setSessionWithNoConnection(session)
        let pconn = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: pl)
        // Preview chico CON espejo (natural al encuadrar); la foto guardada
        // (conn, arriba) queda sin espejo.
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

/// Verificación biométrica interactiva: preview frontal en vivo (sin espejo, al
/// igual que la foto final) + detección de rostro real (Vision). Primero centra
/// y toma la foto de referencia (solo si sale nítida); luego pide seguir con la
/// nariz un punto que salta de segmento en segmento hasta completar el anillo.
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

  // Enrolamiento por PUNTO A SEGUIR: en vez de pedir que "dibuje un círculo"
  // (poco intuitivo, no queda claro hacia dónde ni qué tan rápido), se marca un
  // punto en el anillo y la persona mueve la nariz hasta él; al llegar, se
  // cubre ese segmento y el punto salta al siguiente. Secuencial y concreto.
  private let segTotal = 10
  private var cubiertos = Set<Int>()
  private var objetivo = 0
  private var yaw: Double = 0
  private var pitch: Double = 0
  private var boxW: Double = 0
  private var avatarPath: String?
  private var avatarCapturado = false
  private var calidad: Float = 0 // VNDetectFaceCaptureQualityRequest: 0..1, incluye nitidez/luz/pose
  private let calidadMinima: Float = 0.25 // ⚠️ umbral empírico, ajustar tras probar en el teléfono
  private var frameCount = 0
  private var finished = false
  private var timer: Timer?
  private var inicio = Date()
  private let ringFill = CAShapeLayer()
  private let objetivoDot = CAShapeLayer() // punto que la persona debe seguir con la nariz

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
    // Sin sesión todavía: la conexión (y su mirroring) se arma a mano en
    // configure(), igual que en MultiCamController — así se controla de verdad
    // y no depende de que iOS la conecte sola.
    let pv = AVCaptureVideoPreviewLayer()
    pv.videoGravity = .resizeAspectFill
    pv.frame = view.bounds
    view.layer.addSublayer(pv)
    preview = pv

    dimLayer.fillRule = .evenOdd
    dimLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
    view.layer.addSublayer(dimLayer)

    // Anillo base tenue + segmentos que se llenan (blanco).
    ring.fillColor = UIColor.clear.cgColor
    ring.strokeColor = UIColor.white.withAlphaComponent(0.22).cgColor
    ring.lineWidth = 6
    view.layer.addSublayer(ring)
    ringFill.fillColor = UIColor.clear.cgColor
    ringFill.strokeColor = UIColor.white.cgColor
    ringFill.lineWidth = 6
    ringFill.lineCap = .round
    view.layer.addSublayer(ringFill)

    objetivoDot.fillColor = UIColor(red: 0.78, green: 0.95, blue: 0.11, alpha: 1).cgColor
    view.layer.addSublayer(objetivoDot)

    promptLabel.text = "Centra tu cara en el círculo"
    promptLabel.textColor = .white
    promptLabel.font = .monospacedSystemFont(ofSize: 19, weight: .bold)
    promptLabel.textAlignment = .center
    promptLabel.numberOfLines = 3
    promptLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(promptLabel)

    // Instrucción fija arriba.
    let titulo = UILabel()
    titulo.text = "REGISTRO FACIAL"
    titulo.textColor = .white
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
    let d = min(view.bounds.width * 0.88, 380)
    ovalRect = CGRect(x: (view.bounds.width - d) / 2,
                      y: view.bounds.height * 0.20,
                      width: d, height: d)
    let circle = UIBezierPath(ovalIn: ovalRect)
    let full = UIBezierPath(rect: view.bounds)
    full.append(circle)
    dimLayer.path = full.cgPath
    ring.path = circle.cgPath
  }

  // ── Sesión ──
  // Conexiones armadas a mano (sin addInput/addOutput automáticos) para que el
  // mirroring de cada una (preview, video de análisis, foto) quede fijo en
  // false de verdad, sin que iOS lo reponga a su default al conectar solo.
  private func configure() {
    session.beginConfiguration()
    session.sessionPreset = .photo
    guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: cam),
          session.canAddInput(input) else { session.commitConfiguration(); finish(nil); return }
    session.addInputWithNoConnections(input)
    guard let port = input.ports(for: .video, sourceDeviceType: cam.deviceType,
                                  sourceDevicePosition: .front).first else {
      session.commitConfiguration(); finish(nil); return
    }

    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    if session.canAddOutput(videoOutput) { session.addOutputWithNoConnections(videoOutput) }
    if session.canAddOutput(photoOutput) { session.addOutputWithNoConnections(photoOutput) }

    let videoConn = AVCaptureConnection(inputPorts: [port], output: videoOutput)
    if videoConn.isVideoMirroringSupported {
      videoConn.automaticallyAdjustsVideoMirroring = false
      videoConn.isVideoMirrored = false
    }
    if session.canAddConnection(videoConn) { session.addConnection(videoConn) }

    let photoConn = AVCaptureConnection(inputPorts: [port], output: photoOutput)
    if photoConn.isVideoMirroringSupported {
      photoConn.automaticallyAdjustsVideoMirroring = false
      photoConn.isVideoMirrored = false
    }
    if session.canAddConnection(photoConn) { session.addConnection(photoConn) }

    if let pv = preview {
      pv.setSessionWithNoConnection(session)
      let pvConn = AVCaptureConnection(inputPort: port, videoPreviewLayer: pv)
      // El preview EN VIVO sí va espejado: moverse a la derecha debe verse a
      // la derecha en pantalla, como en un espejo (si no, se siente invertido
      // al seguir el punto). La foto final (photoConn, arriba) queda SIN
      // espejo: así se ve "normal"/consistente cuando se mira después.
      if pvConn.isVideoMirroringSupported {
        pvConn.automaticallyAdjustsVideoMirroring = false
        pvConn.isVideoMirrored = true
      }
      if session.canAddConnection(pvConn) { session.addConnection(pvConn) }
    }

    session.commitConfiguration()
    session.startRunning()
    DispatchQueue.main.async { self.startTimer() }
  }

  private func startTimer() {
    inicio = Date()
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.tick()
    }
  }

  private func tick() {
    if finished { return }
    let mag = (yaw * yaw + pitch * pitch).squareRoot()

    // Avatar: la toma de frente (una sola vez, cuando está centrado Y nítida).
    // Si la cara está centrada pero la calidad es baja (borrosa, poca luz, en
    // movimiento), NO se acepta: se sigue esperando un frame mejor.
    let centrada = mag < 0.12 && boxW > 0.17
    if !avatarCapturado, centrada, calidad >= calidadMinima {
      avatarCapturado = true
      sessionQueue.async {
        self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
      }
    }

    // Una vez tomada la foto de referencia, hay que alcanzar con la nariz el
    // punto marcado en el anillo; al llegar, ese segmento se cubre y el punto
    // salta al siguiente segmento sin cubrir (secuencial, no circular libre).
    if avatarCapturado, mag > 0.10 {
      let ang = atan2(pitch, -yaw) // −yaw: compensa el espejo del preview
      var seg = Int((ang / (2 * .pi) * Double(segTotal)).rounded())
      seg = ((seg % segTotal) + segTotal) % segTotal
      let dist = min((seg - objetivo + segTotal) % segTotal,
                      (objetivo - seg + segTotal) % segTotal)
      if dist <= 1 {
        cubiertos.insert(objetivo)
        avanzarObjetivo()
      }
    }
    dibujarSegmentos()

    if !avatarCapturado, centrada, calidad < calidadMinima {
      promptLabel.text = "Mantente firme y con buena luz"
    } else if !avatarCapturado {
      promptLabel.text = "Mira de frente a la cámara\ny centra tu cara en el círculo"
    } else if cubiertos.count < segTotal {
      let pct = min(100, cubiertos.count * 100 / segTotal)
      promptLabel.text = "Sigue el punto con la nariz\n\(pct)%"
    } else {
      promptLabel.text = "¡Listo!"
    }

    let suficiente = cubiertos.count >= Int(Double(segTotal) * 0.8)
    let timeout = Date().timeIntervalSince(inicio) > 28
    if avatarPath != nil, suficiente {
      finish(avatarPath)
    } else if timeout {
      finish(avatarPath)
    }
  }

  private func avanzarObjetivo() {
    var next = (objetivo + 1) % segTotal
    var vueltas = 0
    while cubiertos.contains(next), vueltas < segTotal {
      next = (next + 1) % segTotal
      vueltas += 1
    }
    objetivo = next
  }

  private func dibujarSegmentos() {
    let center = CGPoint(x: ovalRect.midX, y: ovalRect.midY)
    let radius = ovalRect.width / 2
    let step = CGFloat(2 * Double.pi) / CGFloat(segTotal)
    let path = UIBezierPath()
    for i in cubiertos {
      let a = CGFloat(i) * step
      let s = a - step * 0.42, e = a + step * 0.42
      path.move(to: CGPoint(x: center.x + radius * cos(s), y: center.y + radius * sin(s)))
      path.addArc(withCenter: center, radius: radius, startAngle: s, endAngle: e, clockwise: true)
    }
    ringFill.path = path.cgPath

    // El punto a seguir, visible solo durante el enrolamiento.
    if avatarCapturado, cubiertos.count < segTotal {
      let a = CGFloat(objetivo) * step
      let p = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
      objetivoDot.path = UIBezierPath(ovalIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)).cgPath
      objetivoDot.isHidden = false
    } else {
      objetivoDot.isHidden = true
    }
  }

  // ── Detección de rostro por frame (posición + giro) ──
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    frameCount += 1
    if frameCount % 2 != 0 { return }
    guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let req = VNDetectFaceRectanglesRequest()
    req.revision = VNDetectFaceRectanglesRequestRevision3  // habilita pitch (iOS 15+)
    let qualityReq = VNDetectFaceCaptureQualityRequest() // nitidez/luz/pose, 0..1
    let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .leftMirrored, options: [:])
    try? handler.perform([req, qualityReq])
    let faces = req.results ?? []
    let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width })
    let w = Double(face?.boundingBox.width ?? 0)
    let y = face?.yaw?.doubleValue ?? 0
    let p = face?.pitch?.doubleValue ?? 0
    let q = (qualityReq.results ?? []).compactMap { $0.faceCaptureQuality }.max() ?? 0
    DispatchQueue.main.async {
      self.boxW = w; self.yaw = y; self.pitch = p; self.calidad = q
    }
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
