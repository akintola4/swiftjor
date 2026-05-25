//
//  ContentView.swift
//  HelloWorld
//
//  Created by tope akintola on 12/12/2025.
//

import SwiftUI

struct ContentView: View {
    
    @State var name = "SwiftUI"
    @State var counter = 1
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            //this uses the state called name
            Text("Hello, world its \(name)!")
            
            Button("Click Me To Change Name"){
                name = "swift Developer Tope"
            }.padding()
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(.capsule)
            
            //this is a counter I'm testing lol
            Text("Counter goes below")
            Text("\(counter)")
            
            HStack(spacing:10){
                Button("increase"){
                    counter += 1
                }.padding()
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(.capsule)
                Button("decrease"){
                    counter -= 1
                }.padding()
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(.capsule)
            }
           
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
