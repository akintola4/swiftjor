//
//  ContentView.swift
//  cryptoApp
//
//  Created by tope akintola on 16/12/2025.
//

import SwiftUI
internal import Combine

@MainActor
class CryptoViewModel: ObservableObject {
    //api key
    let apiKey = Secerts.ThisApiKey
    @Published var usd: Double = 0 // Changed to Double to match your struct
    @Published var cryptoname: String = ""
    @Published var usd_market_cap: Int = 0
    @Published var usd_24h_vol: Double = 0
    @Published var usd_24h_change: Double = 0
    @Published var last_updated_at: Double = 0
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    func formattedDate(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func fetchCrypto() async {
        isLoading = true
        usd = 0
        
        usd_market_cap = 0
        usd_24h_vol = 0
        usd_24h_change = 0
        last_updated_at = 0
        errorMessage = ""
        defer {
            isLoading = false
        }
        let cleanedName = cryptoname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=\(cleanedName)&include_tokens=top&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true") else {
                return
            }
        var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("\(apiKey)", forHTTPHeaderField: "x-cg-demo-api-key")
        
        do {
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedResponse = try JSONDecoder().decode([String: DataForCrypto].self, from: data)
            guard let cryptoData = decodedResponse[cleanedName] else{
                errorMessage = "\(cryptoname) was not found, Typing it again"
                    return
            }

            usd = cryptoData.usd
                
            usd_market_cap = Int(cryptoData.usd_market_cap)
            usd_24h_vol = cryptoData.usd_24h_vol
            usd_24h_change = cryptoData.usd_24h_change
            last_updated_at = cryptoData.last_updated_at
            
            
            
            
        }catch{
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        
    }
}


struct CryptoResponse :Codable {
    let cryptoName : String
    let cryptoMainData : DataForCrypto
}
struct DataForCrypto: Codable {
    let usd: Double
    let usd_market_cap : Double
    let usd_24h_vol : Double
    let usd_24h_change : Double
    let last_updated_at : Double
}
struct ContentView: View {
    @StateObject private var vm = CryptoViewModel()
  
    @FocusState private var isInputFocused: Bool
    
    
    
   
    //url path https://api.coingecko.com/api/v3/ this works for demo testing
    
    //https://api.coingeck.com/api/v3/ping?x_cg_demo_api_key=YOUR_API_KEY
    //example
    
    //curl --request GET \--url'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin&names=Bitcoin&symbols=btc&include_tokens=top&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true' \--header 'x-cg-demo-api-key: YOUR_API_KEY'
    
    
    var body: some View {
        ScrollView {
            VStack (spacing: 20) {
                
                Text("Crypto Overview").font(.largeTitle).bold()
                
                TextField("Search Crypto E.g Bitcoin", text: $vm.cryptoname)
                    .textFieldStyle(.plain)
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12)) // Custom glass shape
                    .focused($isInputFocused)
                    .padding(.horizontal)
                
                Button{
                    isInputFocused = false
                    Task{await vm.fetchCrypto()}
                }label: {
                    Text("Get Crypto Info")
                        .frame(maxWidth: .infinity) // Stretches the label, which stretches the glass button
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                    
                }  .bold().font(.headline)
                    .buttonStyle(.glassProminent)
                    .tint(.white.opacity(0.1))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .disabled(vm.cryptoname.isEmpty)
                
                if vm.isLoading {
                    ProgressView()
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                if !vm.errorMessage.isEmpty {
                    Text(vm.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }else if vm.usd != 0{
                    //                VStack(spacing: 4){
                    //                    Text("\(vm.usd)")
                    //
                    //                }
                    VStack (spacing: 20) {
                        HStack(spacing: 5){
                            Image(systemName: "coloncurrencysign.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(vm.usd_24h_change >= 0 ? .green : .red)
                            
                            Text(vm.cryptoname).font(.largeTitle).bold()
                        }
                        
                        VStack (spacing:10) {
                            Text(vm.usd, format: .currency(code: "USD"))
                                .font(.largeTitle).bold()
                            Text("\(vm.usd_24h_change >= 0 ? "+" : "")\(String(format: "%.2f", vm.usd_24h_change))% Today")
                                .font(.callout)
                                .bold()
                            
                                .foregroundStyle(vm.usd_24h_change >= 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 40)
                    
                    HStack(spacing: 12) {
                        // 1. Market Cap Card
                        VStack(spacing: 8) {
                            Text("Market Cap")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            
                            
                            Text(vm.usd_market_cap, format: .currency(code: "USD").notation(.compactName))
                                .font(.title2)
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(white: 0.12))
                        .cornerRadius(20)
                        
                        
                        VStack(spacing: 8) {
                            Text("24h Volume")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text(vm.usd_24h_vol, format: .currency(code: "USD").notation(.compactName))
                                .font(.title2)
                                .bold()
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(white: 0.12))
                        .cornerRadius(20)
                    } .padding()
                    HStack {
                        Text("Updated at")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Text("\(vm.formattedDate(from: vm.last_updated_at))")
                            .font(.footnote)
                        
                    } .padding(.vertical, 40)
                    
                }
//                Spacer()
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}


#Preview {
    ContentView()
}
