import Dispatch

// extension Task {
    public func delay(_ priority: DispatchQoS.QoSClass = .default, for delay: DispatchTime) async {
        return await withUnsafeContinuation { g in
            DispatchQueue.global(qos: priority).asyncAfter(deadline: delay) {
                g.resume()
            }
        }
    } 
// }
