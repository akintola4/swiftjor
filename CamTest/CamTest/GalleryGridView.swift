import SwiftUI

struct GalleryGridView: View {
    // We change this to a @Binding if you want the grid to update immediately
    // after deleting a photo from the detail view.
    @State private var savedImagePaths: [String] = []
    
    // 2. Grid Layout: 3 equal columns
    let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        ScrollView {
            // FIX: Loop through the INDICES (0, 1, 2...) for correct indexing
            LazyVGrid(columns: columns, spacing: 1) {
                
                // Use .indices to get the numeric index (0, 1, 2...)
                ForEach(savedImagePaths.indices, id: \.self) { index in
                    
                    // The element at this index IS the file name string
                    let fileName = savedImagePaths[index]
                    
                    NavigationLink {
                        // Pass the list (with $) and the starting index (index)
                        PhotoDetailView(allFileNames: $savedImagePaths, currentIndex: index)
                    } label: {
                        // FIX: Use the 'fileName' string, not 'index' (which is now the number 0, 1, 2...)
                        if let image = FileUtils.loadImageFromDisk(fileName: fileName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .padding(1)
                        } else {
                            // Grey square if image fails to load
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                                .padding(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
        .navigationTitle("Gallery")
        .onAppear {
            savedImagePaths = FileUtils.loadJSONList()
        }
    }
}
