//
//  MainAppView.swift
//  authflowApp
//
//  Created by tope akintola on 14/12/2025.
//
import SwiftUI
// This is what the user sees once onboarding is complete


struct MainView: View {
    // Keep track of the active tab
    @AppStorage("selectedTab") private var selectedTab = 0
    
    @State private var showsheet = false

    @Namespace private var nameSpace
    var body: some View {
        // iOS 18+ TabView syntax (Make sure you have Xcode 16+)
        TabView(selection: $selectedTab) {
            
            Tab("Home", systemImage: "house", value: 0) {
                ViewOne()
            }
            
            Tab("Projects", systemImage: "folder", value: 1) {
                ViewTwo()
            }
            
            Tab("Tasks", systemImage: "checklist", value: 2) {
                ViewThree()
            }
            
//            Tab("Notifcations", systemImage: "bell.fill", value: 3) {
//                ViewFour()
//            }
//            Tab(value: 4, role: .search  ){
//                SearchView()
//            }
            Tab("Notifcations", systemImage: "ellipsis", value: 5, role: .search ) {
                ViewFour()
            }
        }.tint(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
            .tabBarMinimizeBehavior(.onScrollDown)
                .onChange(of:selectedTab) {
                        oldValue, newValue in
                    if newValue == 5 {
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

// MARK: - Home View
struct ViewOne: View {
    var body: some View {
        // Main Container (Fixes the layout error)
        VStack(spacing: 30) {
            Image("get-started") // Make sure this image is in your Assets folder
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                // specific "flat" style gray placeholder if image is missing
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
            
            VStack(spacing: 12) {
                Text("Main App page For Planzia")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Let's take you on a Guided Tour")
                    .font(.body) // Changed from .default (invalid) to .body
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}

// MARK: - Projects View
struct ViewTwo: View {
    @State private var showAddProjectSheet = false
    @Namespace private var nameSpace
    @State var projects = [
        Project (title: "Fasco", description: "Fasco is a E-com store that handle merch for devakintola"),
        
    ]
    
    func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: "SavedProjects")
        }
    }
    
    func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: "SavedProjects"){
            if let decoded = try? JSONDecoder().decode([Project].self, from: data)
            {projects = decoded}
        }
    }
              
    var body: some View {
        NavigationStack {
            List {
                // Using a Loop instead of hardcoding text
                ForEach(projects) { project in
                    NavigationLink(destination: DeatiledProjectView(project:project)) {
                        Label("\(project.title)", systemImage: "folder.fill").padding(6)
                        
                    }
                }.onDelete{indexSet in
                    projects.remove(atOffsets: indexSet)
                    saveProjects()
                }
                
            }
            .navigationTitle("Projects")
            .listRowSpacing(16)
            .toolbar{
                Button{
                    //now a state to handle it
                    showAddProjectSheet.toggle()
                }label: {
                    Image(systemName: "plus")
                }
//                now the sheet
                .sheet(isPresented: $showAddProjectSheet){
                    DeatiledProjectFormView{newProject in
                        projects.append(newProject)
                    saveProjects()
                        
                    }   .presentationDetents([.medium, .large])
                        .navigationTransition(.zoom(sourceID: "eil", in: nameSpace))
                }
                .onAppear{
                    loadProjects()
                }
                .matchedTransitionSource(id: "eil", in: nameSpace)
                ////
            }
        }
    }
}


//main json to collect both projects and task together so we can store it locally
struct AppDataJson:Codable {
    var projects: [Project]
    var tasks: [Task]
}



struct Project: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description:String
}

struct DeatiledProjectView: View {
    let project: Project
    var body: some View {
        VStack(spacing:20){
            Text("Title: \(project.title)").font(.largeTitle).fontWeight(.bold)
            Text("Decription: \(project.description) ").padding().background(Color.gray.opacity(0.1)).font(.subheadline).fontWeight(.light).clipShape(RoundedRectangle(cornerRadius: 10))
            Spacer()
        }
        .padding()
    }
}

struct DeatiledProjectFormView: View {
    @State private var title = ""
@State private var description = ""
    
    @Environment(\.dismiss) var dismiss
    
    var onSave: (Project) -> Void
    
    var body: some View{
        NavigationStack {
            Form{
                TextField("Title", text: $title)
                TextField("Enter Project description...", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }.navigationTitle("New Project")
                .toolbar{
                    ToolbarItem(placement: .cancellationAction){
                        Button("Cancel"){
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction){
                        Button("Save"){
                            let newProject = Project(title: title,description: description)
                            
                            onSave(newProject)
                            
                            dismiss()
                        }
                        .disabled(title.isEmpty || description.isEmpty)
                    }
                    
                }
        }
    }
}



// MARK: - Tasks View
struct ViewThree: View {
    
    var body: some View {
     
        NavigationStack {
            List {
                // Using a Loop instead of hardcoding text
                ForEach(1...5, id: \.self) { index in
                    NavigationLink(destination: Text("Details for Task \(index)")) {
                        Label("Task \(index)", systemImage: "circle")
                    }
                }
            }
            .navigationTitle("Tasks")
            .listRowSpacing(10)
            .toolbar{
                Button{
                    //now a state to handle it
//                    showAddProjectSheet.toggle()
                    
                    //sample to test
//                    print("Add tapped!!")
                }label: {
                    Image(systemName: "plus")
                }
                //now the sheet
//                .sheet(isPresented: $showAddSheet){
//                    DeatiledFormView{newDeveloper in
//                        developers.append(newDeveloper)
//                    saveDevelopers()
//                    }
//                }
//                .onAppear{
//                    loadDevelopers()
//                }
                
                ////
            }
        }
    }
}

struct Task: Identifiable,Codable {
    var id: UUID
    var title:String
    var description: String
    
    
}

// MARK: - Calendar View
struct ViewFour: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: Text("Details about Meeting with Team")) {
                    Label("Meeting with Team", systemImage: "bell.circle")
                }
                NavigationLink(destination: Text("Details about Project Deadline")) {
                    Label("Project Deadline", systemImage: "bell.circle")
                }
                NavigationLink(destination: Text("Details about Code Review")) {
                    Label("Code Review", systemImage: "bell.circle")
                }
            }
            .navigationTitle("Notifcations")
            .listRowSpacing(10)
            .toolbar{
                Button{
                    //now a state to handle it
//                    showAddSheet.toggle()
                    
                    //sample to test
//                    print("Add tapped!!")
                }label: {
                    Image(systemName: "plus")
                }
                //now the sheet
//                .sheet(isPresented: $showAddSheet){
//                    DeatiledFormView{newDeveloper in
//                        developers.append(newDeveloper)
//                    saveDevelopers()
//                    }
//                }
//                .onAppear{
//                    loadDevelopers()
//                }
                
                ////
            }

        }
    }
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


#Preview {
    MainView()
}

