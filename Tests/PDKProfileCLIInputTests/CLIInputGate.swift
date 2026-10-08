actor CLIInputGate {
    private var arrived = false
    private var arrival: CheckedContinuation<Void, Never>?
    private var paused: CheckedContinuation<Void, Never>?
    func waitForArrival() async {
        if arrived { return }
        await withCheckedContinuation { arrival = $0 }
    }
    func pause() async {
        arrived = true; arrival?.resume(); arrival = nil
        await withCheckedContinuation { paused = $0 }
    }
    func release() { paused?.resume(); paused = nil }
}
