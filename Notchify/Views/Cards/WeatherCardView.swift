import SwiftUI

// MARK: - Weather Card View
struct WeatherCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            weatherHeader
            weatherDetails
        }
        .onAppear { fetchWeather() }
    }
    
    private var weatherHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: viewModel.weatherIcon)
                .font(.system(size: 36))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.weatherTemp)°C")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(viewModel.weatherCondition)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    private var weatherDetails: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            Text(viewModel.weatherCity)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: { fetchWeather() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func fetchWeather() {
        WeatherManager.shared.fetchWeather { temp, condition, icon, city in
            viewModel.weatherTemp = temp
            viewModel.weatherCondition = condition
            viewModel.weatherIcon = icon
            viewModel.weatherCity = city
        }
    }
}

