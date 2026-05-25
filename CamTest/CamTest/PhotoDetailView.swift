import SwiftUI

// Struct to hold image metadata
struct ImageMetadata {
    let dateString: String
    let resolution: String
}

// Struct to represent a swipeable photo item
//struct SourceItem: Identifiable {
//    let id = UUID()
//    let sourceType: UIImagePickerController.SourceType
//}

// MARK: - PhotoDetailView (Swipeable Album Viewer)

struct PhotoDetailView: View {
    // 1. INPUT: The complete list of all photo filenames (Binding for deletion update)
    @Binding var allFileNames: [String]
    
    // 2. INPUT: The currently visible photo's index in the list
    @State var currentIndex: Int
    
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDeleteAlert = false

    // MARK: - Haptic Utility
    // A simple function to trigger light vibration
    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Deletion Function
    func deletePhoto() {
        // Trigger haptic feedback before deleting
        triggerHapticFeedback()
        
        // 1. Get the name of the photo to be deleted
        let fileNameToDelete = allFileNames[currentIndex]
        
        // 2. Delete the file from the disk and list
        _ = FileUtils.deleteImageFromDisk(fileName: fileNameToDelete)
        allFileNames.remove(at: currentIndex)
        
        // 3. Update the JSON list on disk
        FileUtils.saveJSONList(paths: allFileNames)
        
        // 4. Check if the album is now empty.
        if allFileNames.isEmpty {
            dismiss()
        }
    }

    var body: some View {
        
        TabView(selection: $currentIndex) {
            
            ForEach(allFileNames.indices, id: \.self) { index in
                
                let fileName = allFileNames[index]
                
                // Use the PhotoPageView to display the image and its metadata
                PhotoPageView(fileName: fileName)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
//        .background(Color.black.ignoresSafeArea())
//        .onDisappear {
//            // This runs when the view is removed from the Navigation Stack,
//            // which happens when the user presses the Back button or swipes back.
//            triggerHapticFeedback()
//        }
        // Navigation Bar Settings
        .navigationTitle("Photo \(currentIndex + 1) of \(allFileNames.count)")
        .navigationBarTitleDisplayMode(.inline)
        
        // Toolbar with Delete Button
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Trigger haptic feedback on button press
                    triggerHapticFeedback()
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        // Confirmation Alert
        .alert("Delete Photo", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive, action: deletePhoto)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this photo?")
        }
    }
}


// MARK: - PhotoPageView (Handles Image Display, Zoom, and Metadata)

struct PhotoPageView: View {
    let fileName: String
    
    @State private var image: UIImage?
    @State private var metadata: ImageMetadata?
    
    // States for Zoom/Pinch feature
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // MARK: - Metadata Loading Helper
    func loadMetadata(for image: UIImage) -> ImageMetadata {
        // Get resolution
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        let resolution = "\(width) x \(height) px"
        
        // Get Date (Using File Creation Date - best we can do without EXIF)
        let fileURL = FileUtils.getDocumentsDirectory().appendingPathComponent(fileName)
        let dateString: String
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let creationDate = attributes[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            dateString = formatter.string(from: creationDate)
        } else {
            dateString = "Date Unknown"
        }
        
        return ImageMetadata(dateString: dateString, resolution: resolution)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
//            Color.black.ignoresSafeArea()
            
            // Image Display (Zoom/Pinch Applied)
            if let loadedImage = image {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    // Apply scale effect for Zoom/Pinch
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            // Adjust the scale based on the pinch gesture
                            let delta = value / lastScale
                            scale *= delta
                            lastScale = value
                        }
                        .onEnded { value in
                            // Reset state for next pinch, and clamp scale between 1.0 and 3.0
                            lastScale = 1.0
                            if scale < 1.0 { scale = 1.0 }
                            if scale > 3.0 { scale = 3.0 }
                        }
                    )
                    .onTapGesture(count: 2) {
                        // Double-tap to reset zoom
                        withAnimation {
                            scale = 1.0
                        }
                    }
            } else {
                ProgressView().controlSize(.large)
            }
            
            // MARK: - Metadata Overlay
            if let meta = metadata {
                VStack(alignment: .leading) {
                    Text(meta.dateString)
                        .font(.caption)
                    Text(meta.resolution)
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                // Hide metadata when zoomed in
                .opacity(scale == 1.0 ? 1 : 0)
            }
        }
        .onAppear {
            // Load image and metadata when the page becomes visible
            if let loadedImage = FileUtils.loadImageFromDisk(fileName: fileName) {
                image = loadedImage
                metadata = loadMetadata(for: loadedImage)
            }
        }
    }
}
