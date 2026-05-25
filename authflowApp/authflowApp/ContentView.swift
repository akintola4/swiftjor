//
//  ContentView.swift
//  authflowApp
//
//  Created by tope akintola on 13/12/2025.
//

import SwiftUI

//this is the first page the user see
struct ContentView: View {
    
    var body: some View {
        NavigationStack{
            
           
            VStack (spacing: 30){
                HStack{
                    Spacer()
                    NavigationLink {
                                       
                        OnboardingCardViewFinal()
                    }label: {
                        Label("Skip", systemImage: "arrow.right")
                    }
                                    .padding(.trailing, 20)
                                    .foregroundStyle(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                }
               
                VStack {
                    Text("Meet Planzia")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("Your Project Management App")
                        .font(.title)
                        .fontWeight(.light)
                        .multilineTextAlignment(.center)
                }
                Image("planzia-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                                    .imageScale(.small)

                NavigationLink{
                    OnboardingPagesView()
                }label: {
                    Label("Onboarding Page", systemImage: "arrow.right").bold().font(.headline).padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                    
                        .foregroundStyle(.white)
                        .clipShape(.capsule)
                        .padding(.horizontal, 50)
                        .padding(.top, 25)
                    }.buttonStyle(.plain)
                }
            }
            .padding()
        }
       
    }

struct OnboardingPagesView: View {
    var body: some View {
        // 1. TabView is the container
        TabView {
            
            // Your first swipable page
            //            OnboardingView()
            OnboardingCardView(
                imageName: "track-growth",
                title: "Track-growth",
                description: "Easily log and monitor the progress of all your projects and tasks in one dashboard."
            )
            
            // Your second swipable page
            //            InfoView()
            OnboardingCardView(
                imageName: "personal-calendar",
                title: "Personal Calander",
                description: "Never forget a task. Planzia saves your activities in your personal calendar"
            )
            
            // Your third swipable page
            //            LoginView()
            OnboardingCardView(
                imageName: "workspace-insight",
                title: "Workspace Calendar Insights",
                description: "See what is happening in your workspace From a bird eyes view"
            )
            
            // Your fourth, final page (WelcomeView)
            //            WelcomeView()
            OnboardingCardViewFinal()
                
        }
        
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct OnboardingCardViewFinal: View {
//    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Ready to Get Started?")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            
            Image("get-started")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(spacing:10){
                // Title
               
                // Description
                Text("Join thousands of users achieving their goals with Planzia.")
                    .font(.default)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            VStack{
                // Login Button with Naigation
                NavigationLink ("Log In") {
                                   
                    LoginView()
                }
                .bold().font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .padding(.horizontal, 40)
                .buttonStyle(.plain)
//                Button("Login") {
//                    dismiss()
//                    
//                    print("Final Action Button Tapped/Create account done")
//                }
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(.green)
//                .foregroundStyle(.white)
//                .clipShape(.capsule)
//                .padding(.horizontal, 40)
                
                // Create Button with Naigation
                NavigationLink ("Create My Account") {
                                   
                    CreateView()
                }.bold().font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
               
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.0039, green: 0.4863, blue: 0.3608), lineWidth: 2)
                )
                .clipShape(.capsule)
                .padding(.horizontal, 40)
                .buttonStyle(.plain)
                
//                Button("Create My Account") {
//                    dismiss()
//                    
//                    print("Final Action Button Tapped/Create account done")
//                }
//                .padding()
//                .frame(maxWidth: .infinity)
//                .foregroundStyle(.green)
//                .overlay(
//                    Capsule()
//                        .stroke(.green, lineWidth: 2)
//                )
//                .clipShape(.capsule)
//                .padding(.horizontal, 40)
            }
        
        }
        .padding(.top, 0)
        
        
    }
}

struct OnboardingCardView: View {
    
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            
            
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(spacing:10){
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.default)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,20)
            }
        }
    }
}

struct OnboardingView:View {
    var body: some View{
        NavigationStack{
            
            
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Onboarding Page")
                NavigationLink{
                    InfoView()
                }label: {
                        Label("Info Page", systemImage: ".user").padding().background(.black).foregroundStyle(.white).clipShape(.capsule)
                    }
                }
            }
            .padding()
        
    }
}

struct InfoView:View {
    var body: some View{
        NavigationStack{
            
            
            VStack {
                Image("planzia-logo")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Info Page")
                NavigationLink{
                    LoginView()
                }label: {
                        Label("Login Page", systemImage: ".user").padding().background(.black).foregroundStyle(.white).clipShape(.capsule)
                    }
                }
            }
            .padding()
        
    }
}
struct LoginView: View {
    @AppStorage("hasCompletedOnboarding") var onboardingComplete: Bool = false
    
    // State variables to hold the user input
    @State private var email: String = ""
    @State private var password: String = ""
    
    // A simple way to get the primary blue color from the image
    
    
    var body: some View {
        
        NavigationStack {
            
            // 2. A VStack organizes the elements vertically in the center
            VStack(spacing: 0) {
                
                // --- 1. Top Logo/Icon ---
                
              
                Image("planzia-logo")
                    .resizable()
                    .scaledToFit()
                // Set a frame and a fun color gradient to mimic the Instagram logo
                    .frame(width: 80, height: 80)
                
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                
                // --- 2. Input Fields ---
                
                // Text Field for Username/Email/Mobile
                TextField("email", text: $email)
                    .padding()
                    .background(Color.white) // Use a white background
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // Rounded corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Light gray border
                    )
                    .padding(.horizontal) // Apply padding on the left/right
                    .padding(.bottom, 15) // Space between the fields
                
                // Text Field for Password (SecureField hides the input)
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                // --- 3. Login Button ---
                NavigationLink ("Log In") {
                                   
                    WelcomeView()
                }
                .bold().font(.headline)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .padding(.horizontal, 10)
                .padding(.top, 25)
//                Button("Log in") {
//                    // Action to handle login attempt
//                    print("Attempting to log in with: \(email)")
//                    // In a real app, you would navigate to WelcomeView here after successful login
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 14) // Vertical padding for button height
//                
//                .foregroundStyle(.white)
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//                .padding(.horizontal)
//                .padding(.top, 25)
                
                // --- 4. Forgot Password Link ---
                
                Button("Forgot password?") {
                    // Action to handle password reset
                }
                
                .padding(.top, 20)
                .foregroundStyle(.black)
                
                // This Spacer pushes all the content to the top
                Spacer()
                
                // --- 5. Create New Account Button (at the bottom) ---
                
                // Horizontal divider line

                
                NavigationLink ("Create My Account") {
                    
                    CreateView()
                }
                .bold().font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
             
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.0039, green: 0.4863, blue: 0.3608), lineWidth: 2)
                )
                .clipShape(.capsule)
                .padding(.horizontal, 10)
            }
            
            .background(Color.white)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}


struct CreateView: View {
    @AppStorage("hasCompletedOnboarding") var onboardingComplete: Bool = false
    
    // State variables to hold the user input
    @State private var fullname: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmpassword: String = ""
    
    // A simple way to get the primary blue color from the image
    
    
    var body: some View {
        
        NavigationStack {
            
            // 2. A VStack organizes the elements vertically in the center
            VStack(spacing: 0) {
                
                // --- 1. Top Logo/Icon ---
                
              
                Image("planzia-logo")
                    .resizable()
                    .scaledToFit()
                // Set a frame and a fun color gradient to mimic the Instagram logo
                    .frame(width: 80, height: 80)
                
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                
                // --- 2. Input Fields ---
                TextField("Full Name", text: $fullname)
                    .padding()
                    .background(Color.white) // Use a white background
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // Rounded corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Light gray border
                    )
                    .padding(.horizontal) // Apply padding on the left/right
                    .padding(.bottom, 15) // Space between the fields
                
                // Text Field for Username/Email/Mobile
                TextField("email", text: $email)
                    .padding()
                    .background(Color.white) // Use a white background
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // Rounded corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Light gray border
                    )
                    .padding(.horizontal) // Apply padding on the left/right
                    .padding(.bottom, 15) // Space between the fields
                
                
                
                // Text Field for Password (SecureField hides the input)
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 15) // Space between the fields
                
                SecureField("Confirm Password", text: $confirmpassword)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 15) // Space between the fields
                
                // --- 3. Login Button ---
                NavigationLink ("Create Account") {
                                   
                    WelcomeView()
                }
                .bold().font(.headline)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .padding(.horizontal, 10)
                .padding(.top, 25)
//                Button("Log in") {
//                    // Action to handle login attempt
//                    print("Attempting to log in with: \(email)")
//                    // In a real app, you would navigate to WelcomeView here after successful login
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 14) // Vertical padding for button height
//
//                .foregroundStyle(.white)
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//                .padding(.horizontal)
//                .padding(.top, 25)
                
                // --- 4. Forgot Password Link ---
                
               
                
                
                Spacer()
        
            }
            
            .background(Color.white)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}



struct WelcomeView:View {
    var body: some View{
        NavigationStack{
            
            VStack(spacing: 30) {
                
                
                Image("get-started")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                VStack(spacing:10){
                    // Title
                    Text("Welcome To Planzia")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Description
                    Text("Lets take you on a Guided Tour")
                        .font(.default)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                NavigationLink ("Take Me") {
                    MainView()
                }
                // Action Button
//                Button("Take Me") {
//                    // TODO: Add code to dismiss the onboarding flow and show the main app
//                    print("Goes to the main app")
//                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
                .foregroundStyle(.white)
                .clipShape(.capsule)
                .padding(.horizontal, 40)
            }
            .padding(.top, 50)
        }
    }}


//
//struct MainView: View {
//    // Keep track of the active tab
//    @AppStorage("selectedTab") private var selectedTab = 0
//    
//    var body: some View {
//        // iOS 18+ TabView syntax (Make sure you have Xcode 16+)
//        TabView(selection: $selectedTab) {
//            
//            Tab("Home", systemImage: "house", value: 0) {
//                ViewOne()
//            }
//            
//            Tab("Projects", systemImage: "folder", value: 1) {
//                ViewTwo()
//            }
//            
//            Tab("Tasks", systemImage: "checklist", value: 2) {
//                ViewThree()
//            }
//            
//            Tab("Notifcations", systemImage: "bell.fill", value: 3) {
//                ViewFour()
//            }
//        }.tint(Color(red: 0.0039, green: 0.4863, blue: 0.3608))
//    }
//}
//
//// MARK: - Home View
//struct ViewOne: View {
//    var body: some View {
//        // Main Container (Fixes the layout error)
//        VStack(spacing: 30) {
//            Image("get-started") // Make sure this image is in your Assets folder
//                .resizable()
//                .scaledToFit()
//                .frame(width: 250, height: 250)
//                .clipShape(RoundedRectangle(cornerRadius: 20))
//                // specific "flat" style gray placeholder if image is missing
//                .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
//            
//            VStack(spacing: 12) {
//                Text("Main App page For Planzia")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .multilineTextAlignment(.center)
//                
//                Text("Let's take you on a Guided Tour")
//                    .font(.body) // Changed from .default (invalid) to .body
//                    .foregroundStyle(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 40)
//            }
//        }
//        .padding()
//    }
//}
//
//// MARK: - Projects View
//struct ViewTwo: View {
//    var body: some View {
//        NavigationStack {
//            List {
//                // Using a Loop instead of hardcoding text
//                ForEach(1...5, id: \.self) { index in
//                    NavigationLink(destination: Text("Details for Project \(index)")) {
//                        Label("Project \(index)", systemImage: "folder.fill")
//                    }
//                }
//            }
//            .navigationTitle("Projects")
//            .listRowSpacing(10)
//        }
//    }
//}
//
//// MARK: - Tasks View
//struct ViewThree: View {
//    var body: some View {
//     
//        NavigationStack {
//            List {
//                // Using a Loop instead of hardcoding text
//                ForEach(1...5, id: \.self) { index in
//                    NavigationLink(destination: Text("Details for Task \(index)")) {
//                        Label("Task \(index)", systemImage: "circle")
//                    }
//                }
//            }
//            .navigationTitle("Tasks")
//            .listRowSpacing(10)
//        }
//    }
//}
//
//// MARK: - Calendar View
//struct ViewFour: View {
//    var body: some View {
//        NavigationStack {
//            List {
//                NavigationLink(destination: Text("Details about Meeting with Team")) {
//                    Label("Meeting with Team", systemImage: "bell.circle")
//                }
//                NavigationLink(destination: Text("Details about Project Deadline")) {
//                    Label("Project Deadline", systemImage: "bell.circle")
//                }
//                NavigationLink(destination: Text("Details about Code Review")) {
//                    Label("Code Review", systemImage: "bell.circle")
//                }
//            }
//            .navigationTitle("Notifcations")
//            .listRowSpacing(10)
//
//        }
//    }
//}



#Preview {
    ContentView()
}

