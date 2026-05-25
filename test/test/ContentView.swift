//
//  ContentView.swift
//  test
//
//  Created by tope akintola on 12/12/2025.
//

import SwiftUI

struct ContentView: View {
    
//    single state
//    @State var name = "Fola"
    
    //array of objects hardcoded
//    let developers = [
//        Developer(name: "Fola", role: "Frontend", icon: "desktopcomputer"),
//        Developer(name: "Devakintola", role: "Full stack",icon: "paintpalette.fill"),
//        Developer(name: "Tosin", role: "BackEnd", icon: "network")
//    ]
    
    //dynamic state array
    @State var developers =  [
                Developer(name: "Fola", role: "Frontend", icon: "desktopcomputer", bio: "Not Set Yet"),
                Developer(name: "Devakintola", role: "Full stack",icon: "paintpalette.fill", bio: "Not Set Yet"),
                Developer(name: "Tosin", role: "BackEnd", icon: "network", bio: "Not Set Yet")
            ]
    
    
    //new state
    @State private var showAddSheet = false
    
    
    //function to enable saving and load
    
  
    func saveDevelopers() {
        if let encoded = try? JSONEncoder().encode(developers) {
            UserDefaults.standard.set(encoded, forKey: "SavedDevelopers")
        }
    }
    
    func loadDevelopers() {
        if let data = UserDefaults.standard.data(forKey: "SavedDevelopers"){
            if let decoded = try? JSONDecoder().decode([Developer].self, from: data)
            {developers = decoded}
        }
    }
    var body: some View {
        //this is what format the content for links
        NavigationStack{
            
            
            //vertical orientation
            //            VStack {
            //            HStack {
            ////                Image(systemName: "globe")
            ////                    .imageScale(.large)
            ////                    .foregroundStyle(.tint)
            //
            //                }
            
            //this is the list from the object
            //                List(developers){ developer in
            
            List{
                ForEach(developers) {
                    developer in
                    
                    //this is the navigation that forwards to another screen where the desination content is what we pass in the Text here
                    //                    NavigationLink(destination:Text("Details for \(developer.name)")){
                    //
                    
                    NavigationLink(destination:DetailView(developer:developer)){
                        
                        HStack{
                            Image(systemName: developer.icon).font(.title)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.blue)
                                .clipShape(Circle())
                            VStack(alignment: .leading){
                                Text(developer.name).font(.headline)
                                Text(developer.role).font(.subheadline)
                               
                            }
                            
                            
                        }}}.onDelete{indexSet in
                            developers.remove(atOffsets: indexSet)
                            saveDevelopers()
                        }
                
                //                Text("Hello, \(name)!")
            }.listRowSpacing(10)
            
            
            //            Button("Click Me") {
            //                name = "Swift Developer Fola"
            //            }.padding()
            //                .background(.blue)
            //                .foregroundStyle(.white)
            //                .clipShape(Capsule())
            //            }
            //            .padding()
            
            // i added this here to allow the title for the nav title
            .navigationTitle("Developers")
            
            //this is the plus button for adding new users
            .toolbar{
                Button{
                    //now a state to handle it
                    showAddSheet.toggle()
                    
                    //sample to test
//                    print("Add tapped!!")
                }label: {
                    Image(systemName: "plus")
                }
                //now the sheet
                .sheet(isPresented: $showAddSheet){
                    DeatiledFormView{newDeveloper in
                        developers.append(newDeveloper)
                    saveDevelopers()
                    }
                }
                .onAppear{
                    loadDevelopers()
                }
                
                ////
            }        }
        }
    }


struct Developer : Identifiable, Codable {
    var id = UUID()
    var name: String
    var role:String
    var icon : String
    var bio : String
}


struct DetailView: View {
    let developer: Developer
    
    var body: some View{
        VStack(spacing:20){
            
            //first style
//            Image(systemName: developer.icon).resizable().scaledToFit().frame(width: 200, height: 200).foregroundStyle(.blue)
            
            
            //new profile style
            Image(systemName: developer.icon).resizable().scaledToFit().frame(width: 100, height: 100).foregroundStyle(.white).padding(30).background(.blue).clipShape(Circle()).shadow(radius: 10)

            Text("Name: \(developer.name)").font(.largeTitle).fontWeight(.bold)
           
            Text("Role: \(developer.role) ").font(.title2).fontWeight(.semibold)
            
            Text("Bio: \(developer.bio) ").padding().background(Color.gray.opacity(0.1)).font(.caption).fontWeight(.light).clipShape(RoundedRectangle(cornerRadius: 10))
            Spacer()
        }
        .padding()
        
    }
        
}


struct DeatiledFormView: View {
    
    @State private var name = ""
    @State private var role = ""
    @State private var bio = ""
    
    @Environment(\.dismiss) var dismiss
    
    var onSave: (Developer) -> Void
    
    var body: some View {
        NavigationStack {
            Form{
                TextField("Name", text: $name)
                TextField("role", text: $role)
                TextField("Enter developer bio...", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }  .navigationTitle("New Developer")
                .toolbar{
                    ToolbarItem(placement: .cancellationAction){
                        Button("Cancel"){
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction){
                        Button("Save"){
                            let newDev = Developer(name: name, role: role,icon: "person.crop.circle.badge.plus",bio:bio)
                            
                            onSave(newDev)
                            
                            dismiss()
                        }
                        .disabled(name.isEmpty || role.isEmpty)
                    }
                    
                }
          
        }
        
    }
}
#Preview {
    ContentView()
}
