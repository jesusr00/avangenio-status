import Foundation

/// Formato canónico de las métricas mostradas, fuente única para app y notificaciones.
public enum MetricFormat {
    /// Ancho de banda con 2 decimales, ej. "4.42 Mbps".
    public static func mbps(_ value: Double) -> String {
        String(format: "%.2f Mbps", value)
    }

    /// Porcentaje sin decimales, ej. "26%".
    public static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }
}
