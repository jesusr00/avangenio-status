import SwiftUI

/// El logo de Avangenio sobre un fondo blanco redondeado.
struct LogoBadge: View {
    var size: CGFloat = 28

    var body: some View {
        Image("AvangenioLogo")
            .resizable()
            .scaledToFit()
            .padding(size * 0.15)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
            .accessibilityLabel("Avangenio")
    }
}
