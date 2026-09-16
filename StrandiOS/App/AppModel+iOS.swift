#if os(iOS)
import Foundation

/// What the "Sync Strap" shortcut observed when it asked for a sync. Each case names only what was seen.
enum StrapSyncShortcutOutcome {
    /// `syncNow` ran and a sync session is now in progress.
    case started
    /// A sync was already running when the shortcut arrived, so nothing new was requested.
    case alreadyRunning
    /// No app model, or the strap link never reached `historyReady` within the wait.
    case strapNotReady
    /// The link was ready and `syncNow` ran, but no session started. The strap log says why.
    case notStarted
}

extension AppModel {
    /// Execute any actions queued by App Intents while the app was suspended (mark moment, buzz,
    /// ask coach). Call when the app becomes active. The optional `router` lets the ask-coach
    /// intent navigate to the Coach tab after sending the question.
    func drainPendingIntents(router: NavRouter? = nil) {
        for item in PendingIntents.drain() {
            switch item.action {
            case .markMoment: markMoment(at: item.date ?? Date())
            // #921: the "Buzz Strap" Siri shortcut logged its write but a WHOOP 4.0 never vibrated.
            // The one-shot routine sends the confirmed pattern + RUN_ALARM sequence, acked, so a
            // busy just-foregrounded BLE link can't silently drop it.
            case .buzz:       buzzStrapOnce()
            // K9: "Ask Coach" via Siri — send the queued question to the Coach engine and navigate
            // to the Coach tab so the user sees the response. The question is consumed from a
            // dedicated key (one at a time).
            case .askCoach:
                if let question = PendingIntents.consumeCoachQuestion() {
                    router?.openCoach()
                    Task { @MainActor in
                        await coach.send(question)
                    }
                }
            }
        }
    }

    /// Background entry point for the "Sync Strap" shortcut. When iOS launches NOOP in the background to run
    /// the intent, the model and the strap link may still be coming up, and `BLEManager.syncNow` declines until
    /// the connect handshake has run (`LiveState.historyReady`). Wait up to `waitSeconds` for that, then ask once.
    /// The wait stays short because an App Intent has a limited time to return.
    static func startStrapSyncFromShortcut(waitSeconds: Int = 15) async -> StrapSyncShortcutOutcome {
        for _ in 0..<waitSeconds {
            if let model = shared, model.live.historyReady { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard let model = shared, model.live.historyReady else { return .strapNotReady }
        if model.live.backfilling { return .alreadyRunning }
        model.ble.syncNow()
        return model.live.backfilling ? .started : .notStarted
    }
}
#endif
