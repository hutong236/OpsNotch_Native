public enum SensorMouseEventPolicy {
    /// Idle Sensor panels must pass ordinary pointer events through to the app below.
    /// Once DragSessionCoordinator recognizes a real external drag, hit testing is
    /// temporarily enabled so the existing NSDraggingDestination can receive the drop.
    public static func ignoresMouseEvents(externalDragSessionActive: Bool) -> Bool {
        !externalDragSessionActive
    }

    /// A process-wide mouse-up monitor is only useful while a recognized external drag
    /// is in flight. Keeping it installed while idle wakes the app for every ordinary click.
    public static func shouldMonitorGlobalMouseUp(externalDragSessionActive: Bool) -> Bool {
        externalDragSessionActive
    }
}
