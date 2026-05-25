//
//  ContentView.swift
//  navproject
//
//  Created by tope akintola on 27/12/2025.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var showsheet = false

    @Namespace private var nameSpace
    
    var body: some View {
       
        
        
        TabView(selection: $selectedTab){
            Tab("Heart", systemImage: "heart", value: 0){
                ViewOne()
            }
            Tab("Star", systemImage: "star", value: 1){
                ViewTwo()
            }
            Tab("Magic", systemImage: "hat.widebrim" , value: 2){
                ViewMagic()
            }
            
            
            Tab(value: 3, role: .search  ){
                SearchView()
            }
        }.tabBarMinimizeBehavior(.onScrollDown)
            .onChange(of:selectedTab) {
                    oldValue, newValue in
                if newValue == 2 {
                    showsheet = true
                    selectedTab = oldValue
                }
            }
            .sheet(isPresented: $showsheet){
                ViewMagic()
//                ViewMagic(SheetPresented: $SheetPresented)
                    .presentationDetents([.medium, .large])
                    .navigationTransition(.zoom(sourceID: "eil", in: nameSpace))
            }
    }
}

#Preview {
    ContentView()
}

struct ViewMagic: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack{
            VStack(spacing: 20){
                Image(systemName: "lungs.fill")
                    .font(.system(size: 60))
                    .imageScale(.large)
                    .foregroundStyle(.yellow)
                Text("Hello this is a Custom sheet view ")
                
                Text("The reason why i built this section is to see if i can add a custom sheet view in a tab list, i could alse repurpose this for a search view using this method")
                    
                Spacer()
            }
            .padding()
            .navigationTitle("More Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button{
                    dismiss()
                } label: {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
        }
    }
}

struct ViewOne: View {
    var body: some View {
//        VStack {
//            Image(systemName: "heart")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, heart items!")
//        }
        NavigationStack {
                    List {
                        Text("My Favorite Item 1")
                        Text("My Favorite Item 2")
                        Text("My Favorite Item 3")
                        
                    }
                    .navigationTitle("Favorites")
                }

    }
}
struct ViewTwo: View {
    var body: some View {
//        VStack {
//            Image(systemName: "star")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, star items!")
//        }
        NavigationStack {
                    List {
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                        Text("My star Item 1")
                        Text("My star Item 2")
                        Text("My star Item 3")
                    }
                    .navigationTitle("Stars")
                    .listRowSpacing(10)
                }
    }
}


struct SearchView: View {
    
    @State private var searchItems = ""
    // Sample Data
        let animals = ["Ant", "Bear", "Cat", "Dog", "Elephant", "Fox", "Giraffe", "Hippo", "Iguana", "Jaguar"]
        //logic
    private var fillteredItem: [String] {
        if searchItems.isEmpty {
            return animals
        }else {
            return animals.filter {$0.localizedCaseInsensitiveContains(searchItems)}
        }
    }
    var body: some View {
//        VStack {
//            Image(systemName: "magnifyingglass.circle.fill")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, search section!")
//        }
        NavigationStack {
            List(fillteredItem, id: \.self) {
                item in Text(item)
                       
                    }
                    .navigationTitle("animals")
                    .listRowSpacing(10)
                }
        .searchable(text: $searchItems)
    }
}
