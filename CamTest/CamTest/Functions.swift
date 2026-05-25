import UIKit

struct FileUtils {
    
    // 1. Get the directory
//    static func getDocumentsDirectory() -> URL {
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        return paths[0]
//    }
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // 2. Save Image -> Returns Filename
    static func saveImageToDisk(image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
            return fileName
        }
        return nil
    }

    // 3. Load Image
    static func loadImageFromDisk(fileName: String) -> UIImage? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        if let imageData = try? Data(contentsOf: fileURL) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    // 4. Delete Image
    static func deleteImageFromDisk(fileName: String) -> String? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            return fileName
        } catch {
            print("Error deleting file: \(error)")
            return nil
        }
    }

    // 5. Save List to JSON (The "Catalog Card")
    static func saveJSONList(paths: [String]) {
        // IMPORTANT: We use "saved_photos.json" everywhere!
        let url = getDocumentsDirectory().appendingPathComponent("saved_photos.json")
        do {
            let data = try JSONEncoder().encode(paths)
            try data.write(to: url)
        } catch {
            print("Failed to save JSON: \(error)")
        }
    }

    // 6. Load List from JSON
    static func loadJSONList() -> [String] {
        let url = getDocumentsDirectory().appendingPathComponent("saved_photos.json")
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
        }
        return []
    }
    
}

