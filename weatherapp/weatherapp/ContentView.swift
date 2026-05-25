//

//  ContentView.swift

//  weatherapp

//

//  Created by tope akintola on 16/12/2025.

//


import SwiftUI



struct WeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: WeatherWind
    let dt: TimeInterval
}

struct MainWeather: Codable {
    let temp: Double
    let humidity: Double
}

struct WeatherDescription: Codable {
    let description: String
    let icon: String
}

struct WeatherWind: Codable {
    let speed: Double
    let deg: Double
    let gust: Double?
}



struct ContentView: View {
    
    @State private var city: String = ""
    @State private var temperature: String = ""
    @State private var humidity: String = ""
    @State private var description: String = ""
    @State private var icon: String = ""
    @State private var errorMessage: String = ""
    @FocusState private var isInputFocused: Bool
    
    @State private var windSpeed: String = ""
    @State private var windDirection: String = ""
    @State private var windGust: String = ""
   
    
    @State private var dateTime: TimeInterval = 0
    @State private var isLoading: Bool = false
    
    let apiKey = Secrets.weatherAPIKey
    
    
    var body: some View {
        ScrollView{
            
            
            VStack(spacing: 20) {
                Text("Weather Check")
                    .font(.largeTitle)
                    .bold()
                
                
                
                
                TextField("Enter city name", text: $city)
                    .textFieldStyle(.plain)
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12)) // Custom glass shape
                    .focused($isInputFocused)
                    .padding(.horizontal)
                
                Button {
                    isInputFocused = false
                    Task { await fetchWeather() }
                } label: {
                    Text("Get Weather")
                        .frame(maxWidth: .infinity) // Stretches the label, which stretches the glass button
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                }
                .bold().font(.headline)
                .buttonStyle(.glassProminent)
                .tint(.black)
                .padding(.vertical, 14)
                .padding(.horizontal, 40)
                .disabled(city.isEmpty)
                
                
                if isLoading {
                    ProgressView()
                }
                
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else if !temperature.isEmpty {
                    VStack(spacing: 10) {
                        
                        VStack {
                            if !icon.isEmpty {
                                AsyncImage(url: URL(string: "https://openweathermap.org/img/wn/\(icon)@4x.png")) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 200, height: 200)
                            }
                            
                            Text(temperature)
                                .font(.system(size: 50, weight: .bold))
                        }
                        
                        Text(description.capitalized)
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        
                        if dateTime != 0 {
                            Text(formattedDate(from: dateTime))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider() // A nice line separator
                        
                        
                        HStack(spacing: 100) {
                            
                            VStack {
                                Image(systemName: "humidity")
                                    .font(.title)
                                Text(humidity)
                                    .font(.headline)
                                Text("Humidity")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            
                            VStack {
                                Image(systemName: "wind")
                                    .font(.title)
                                Text(windSpeed)
                                    .font(.headline)
                                
                                
                                if !windGust.isEmpty {
                                    Text("Gust: \(windGust)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("Wind")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            //                        .background(.ultraThinMaterial)
                        }
                        .padding()
                        
                        .cornerRadius(20)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // --- LOGIC ---
    
    func fetchWeather() async {
        
        isLoading = true
        errorMessage = ""
        
        temperature = ""
        description = ""
        humidity = ""
        windSpeed = ""
        windGust = ""
        icon = ""
        
        //i will put a defer fucntion here to help in case the guard fails and since it exist the code and doesn't read the code below it will help us stop the spinner
        
        defer { isLoading = false }
        
        guard let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCity)&appid=\(apiKey)&units=metric") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            
            temperature = "\(String(format: "%.1f", decodedResponse.main.temp))°C"
            description = decodedResponse.weather.first?.description ?? ""
            icon = decodedResponse.weather.first?.icon ?? ""
            dateTime = decodedResponse.dt
            
            
            humidity = "\(String(format: "%.0f", decodedResponse.main.humidity))%"
            
            
            windSpeed = "\(String(format: "%.1f", decodedResponse.wind.speed)) m/s"
            
            
            if let gustVal = decodedResponse.wind.gust {
                windGust = "\(String(format: "%.1f", gustVal)) m/s"
            } else {
                windGust = ""
            }
            //notice how i commented out the isloading here that's because we don't need it since the defer acts as the options below and make sure the isLoading is set to false when the function close or stops half way 
//            isLoading = false
            
        } catch {
            errorMessage = "City not found or connection error."
            
//            isLoading = false
        }
    }
}


func formattedDate(from timestamp: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    return date.formatted(date: .abbreviated, time: .shortened)
}

#Preview {
    ContentView()
}
