# NOOP rebuild

A from-scratch rebuild of NOOP, done layer by layer to understand how it works.
The original tree on `main` is kept as a read-only reference.

Planned order (bottom of the stack first):

1. `WhoopProtocol`: BLE frame parsing and CRC (pure Swift, testable on Linux)
2. `StrandAnalytics`: HRV, recovery, strain and sleep math (pure)
3. `WhoopStore`: SQLite persistence
4. BLE transport (CoreBluetooth or Android)
5. App UI
