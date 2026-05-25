import SwiftUI
import UIKit
struct SourceItem: Identifiable {
    let id = UUID()
    let sourceType: UIImagePickerController.SourceType
}
struct ContentView: View {
    // 1. The image we are LOOKING at
    @State private var profileImage: UIImage?
    
    // 2. The "Staging Area" for NEW incoming photos
    @State private var inputImage: UIImage?
    
    @State private var showImagePicker = false
//    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    @State private var activeSheet: SourceItem? = nil
    // NEW STATE: Tells the sheet *which* source to use, but only when it's present.
//    @State private var requestedSourceType: UIImagePickerController.SourceType? = nil
    @State private var showEmptyWarning = false
    @State private var savedImagePaths: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                Text("Camera & Gallery App").font(.title).fontWeight(.bold)
                
                // --- Image Display ---
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipShape(Rectangle())
                        .overlay(Rectangle().stroke(.blue, lineWidth: 4))
                        .shadow(radius: 7)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 200, height: 200)
                        .foregroundStyle(.gray.opacity(0.3))
                }
                
                // --- Buttons ---
                HStack(spacing: 20) {
                    // Button A: Camera
                    Button {
                        activeSheet = SourceItem(sourceType: .camera)
                        showImagePicker = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    
                    // Button B: Photo Library
                    Button {
                        activeSheet = SourceItem(sourceType: .photoLibrary)
                        showImagePicker = true
                    } label: {
                        Label("Gallery", systemImage: "photo.on.rectangle")
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    
                    // Button C: Go to Grid View
                    NavigationLink {
                        GalleryGridView()
                    } label: {
                        Label("Grid", systemImage: "square.grid.2x2")
                            .padding()
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                
                // Button D: Delete Logic
                Button {
                    if savedImagePaths.isEmpty {
                        showEmptyWarning = true
                    } else {
                        if let lastImageName = savedImagePaths.last {
                            // USE FILEUTILS HERE
                            _ = FileUtils.deleteImageFromDisk(fileName: lastImageName)
                            
                            savedImagePaths.removeLast()
                            
                            if let newLastImage = savedImagePaths.last {
                                // USE FILEUTILS HERE
                                profileImage = FileUtils.loadImageFromDisk(fileName: newLastImage)
                            } else {
                                profileImage = nil
                            }
                            // USE FILEUTILS HERE
                            FileUtils.saveJSONList(paths: savedImagePaths)
                        }
                    }
                } label: {
                    Label("Delete Last Photo", systemImage: "trash")
                        .padding()
                        .background(savedImagePaths.isEmpty ? Color.gray : Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .alert("No Photos", isPresented: $showEmptyWarning) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("There are no photos left to delete.")
                }
            }
            // --- Handlers ---
            .sheet(item: $activeSheet) { sourceItem in
                            ImagePicker(selectedImage: $inputImage, sourceType: sourceItem.sourceType)
                            
                            .onDisappear {
                                // This logic remains perfect for refreshing the main view!
                                savedImagePaths = FileUtils.loadJSONList()
                                if let lastImageName = savedImagePaths.last {
                                    profileImage = FileUtils.loadImageFromDisk(fileName: lastImageName)
                                } else {
                                    profileImage = nil
                                }
                            }
                        }
            .onChange(of: inputImage) { oldImage, newImage in
                if let img = newImage {
                    print("📸 New photo received!")
                    
                    // USE FILEUTILS HERE
                    if let filename = FileUtils.saveImageToDisk(image: img) {
                        print("Saved as: \(filename)")
                        savedImagePaths.append(filename)
                        FileUtils.saveJSONList(paths: savedImagePaths)
//                        profileImage = img
                    }
                    inputImage = nil
                }
            }
            .onAppear {
                // USE FILEUTILS HERE
                savedImagePaths = FileUtils.loadJSONList()
                                if let lastImageName = savedImagePaths.last {
                                    profileImage = FileUtils.loadImageFromDisk(fileName: lastImageName)
                                }
            }
        }
    }
}


// Keep your ImagePicker struct here at the bottom, it's fine!
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
//        if sourceType == .camera && !UIImagePickerController.isSourceTypeAvailable(.camera) {
//            picker.sourceType = .photoLibrary
//        } else {
//            picker.sourceType = sourceType
//        }
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
    }
}
