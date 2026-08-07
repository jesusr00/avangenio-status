import Foundation

/// Formatea el timestamp de "última actualización" del API a español.
public enum DateDisplay {
    /// El API entrega algo como "Fri Aug  7 16:59:01 CDT 2026" (locale C / inglés).
    private static let apiParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss zzz yyyy"
        return formatter
    }()

    /// Reformatea el timestamp del API a español preservando la hora y zona reportadas
    /// (ej. "vie 7 ago 2026, 16:59 CDT"). Si no parsea, devuelve el texto original.
    public static func spanish(fromAPITimestamp raw: String) -> String {
        // Colapsa espacios múltiples (el día de 1 dígito viene con doble espacio).
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let normalized = tokens.joined(separator: " ")

        guard let date = apiParser.date(from: normalized) else { return raw }

        // Penúltimo token = abreviatura de zona (ej. "CDT"), para conservar la hora tal cual.
        let zoneAbbreviation = tokens.count >= 2 ? tokens[tokens.count - 2] : nil

        let output = DateFormatter()
        output.locale = Locale(identifier: "es")
        output.timeZone = zoneAbbreviation.flatMap(TimeZone.init(abbreviation:)) ?? apiParser.timeZone
        output.dateFormat = "EEE d MMM yyyy, HH:mm"

        var result = output.string(from: date)
        if let zoneAbbreviation {
            result += " \(zoneAbbreviation)"
        }
        return result
    }
}
