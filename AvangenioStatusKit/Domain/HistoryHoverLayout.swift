import CoreGraphics

/// Colocación de la caja flotante del historial respecto del cursor.
/// Geometría pura, sin SwiftUI, para poder probar los volteos contra los bordes.
public enum HistoryHoverLayout {
    public static let defaultMargin: CGFloat = 12

    /// Esquina superior izquierda de la caja. Por defecto va arriba a la derecha del
    /// cursor; si no cabe, se voltea al lado opuesto y luego se recorta al contenedor.
    public static func readoutOrigin(
        cursor: CGPoint,
        boxSize: CGSize,
        container: CGSize,
        margin: CGFloat = defaultMargin
    ) -> CGPoint {
        var x = cursor.x + margin
        if x + boxSize.width > container.width {
            x = cursor.x - margin - boxSize.width
        }

        var y = cursor.y - margin - boxSize.height
        if y < 0 {
            y = cursor.y + margin
        }

        return CGPoint(
            x: clamp(x, limit: container.width - boxSize.width),
            y: clamp(y, limit: container.height - boxSize.height)
        )
    }

    /// Recorta al rango visible. Si la caja es más grande que el contenedor, se ancla
    /// al origen en lugar de salirse por el lado contrario.
    private static func clamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(0, value), max(0, limit))
    }
}
