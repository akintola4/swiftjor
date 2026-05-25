//
//  ContentView.swift
//  welcomepage
//
//  Created by tope akintola on 12/12/2025.
//

import SwiftUI

struct ContentView: View {
    @State var counter = 1
    var body: some View {
        VStack (spacing: 20){
            HStack(spacing:50){
                Image(systemName: "swift")
                    .imageScale(.large)
                    .foregroundStyle(.orange)
                    .font(.system(size: 50))
                Image(systemName: "hammer.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint).font(.system(size: 50))
            }
            
            Text("SwiftUI + Xcode!").font(.largeTitle)
                .fontWeight(.bold).fontWeight(.bold)
            
            Text("Count is \(counter)")
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            
            HStack(spacing:10){
                Button {
                                    counter += 1
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                }
                Button {
                                    counter -= 1
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.title)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                }
            }
            
            
            Text("Edit `ContentView.swift` to test HMR")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                        
                        
                        Link("Click here to learn more", destination: URL(string: "https://developer.apple.com")!)
                            .foregroundStyle(.blue)
                    }
        .padding()
    }
}

#Preview {
    ContentView()
}
