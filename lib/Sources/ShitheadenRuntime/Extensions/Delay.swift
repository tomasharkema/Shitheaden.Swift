import Dispatch

public func delay(_ priority: DispatchQoS.QoSClass = .default, for delay: DispatchTime) async {
  await withUnsafeContinuation { cont in
    DispatchQueue.global(qos: priority).asyncAfter(deadline: delay) {
      cont.resume()
    }
  }
}
