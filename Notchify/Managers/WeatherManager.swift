import Foundation
import CoreLocation


// MARK: - Weather Manager
class WeatherManager {
    static let shared = WeatherManager()
    
    func fetchWeather(completion: @escaping (String, String, String, String) -> Void) {
        guard let url = URL(string: "https://wttr.in/?format=j1") else { return }
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            if let current = (json["current_condition"] as? [[String: Any]])?.first,
               let area = (json["nearest_area"] as? [[String: Any]])?.first {
                
                let tempC = current["temp_C"] as? String ?? "--"
                let code = current["weatherCode"] as? String ?? "116"
                let city = (area["areaName"] as? [[String: String]])?.first?["value"] ?? ""
                
                let descArr = current["weatherDesc"] as? [[String: String]]
                let desc = descArr?.first?["value"] ?? "Unknown"
                
                let icon = Self.weatherCodeToIcon(code)
                
                DispatchQueue.main.async {
                    completion(tempC, desc, icon, city)
                }
            }
        }.resume()
    }
    
    static func weatherCodeToIcon(_ code: String) -> String {
        switch code {
        case "113": return "sun.max.fill"
        case "116": return "cloud.sun.fill"
        case "119", "122": return "cloud.fill"
        case "143", "248", "260": return "cloud.fog.fill"
        case "176", "263", "266", "293", "296": return "cloud.drizzle.fill"
        case "299", "302", "305", "308", "311", "314", "356", "359": return "cloud.rain.fill"
        case "200", "386", "389", "392", "395": return "cloud.bolt.rain.fill"
        case "227", "230", "320", "323", "326", "329", "332", "335", "338", "350", "368", "371", "374", "377": return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
}
