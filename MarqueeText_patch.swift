    private func startScrolling() {
        guard textWidth > containerWidth else { 
            withAnimation(nil) { offset = 0 }
            return 
        }
        
        // Matikan animasi yang sedang berjalan dan kembalikan ke titik awal
        withAnimation(nil) {
            offset = 0
        }
        
        let scrollDistance = textWidth + 40
        
        // Beri sedikit jeda (0.1 detik) sebelum memulai animasi baru, 
        // agar SwiftUI meregistrasi bahwa posisi sudah benar-benar di-reset ke 0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Pastikan masih butuh scroll setelah jeda
            guard textWidth > containerWidth else { return }
            
            withAnimation(.linear(duration: Double(scrollDistance) / 30.0).repeatForever(autoreverses: false)) {
                offset = -scrollDistance
            }
        }
    }
