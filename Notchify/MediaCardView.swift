import SwiftUI

struct MediaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon / Album Art
            ZStack {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "airpodspro")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentSong)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.currentArtist)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Checkmark button (from the reference image)
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 24))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
