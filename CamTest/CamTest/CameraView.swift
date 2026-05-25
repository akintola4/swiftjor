import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    // 1. This binding lets us send the photo back to the main screen
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    // 2. This dismisses the camera screen
    @Environment(\.dismiss) var dismiss
    
    // 3. The "Coordinator" listens for the "Photo Taken" event
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    // 4. Create the system camera controller
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    // 5. The "Listener" Class
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(parent: CameraView) {
            self.parent = parent
        }
        
        // This runs when the user snaps a photo
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
    }
}
