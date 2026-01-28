import SwiftUI
import PhotosUI
import UIKit

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var navigateToResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("生活随手拍")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("地道学英语")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Camera Preview Placeholder
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 40)

                Spacer()

                // Buttons
                HStack(spacing: 60) {
                    // Album
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                            Text("相册")
                                .font(.caption)
                        }
                        .foregroundStyle(.primary)
                    }

                    // Camera
                    Button {
                        showCamera = true
                    } label: {
                        Circle()
                            .fill(.blue)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .padding(4)
                            }
                    }

                    // Placeholder for symmetry
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.slash")
                            .font(.title)
                        Text("闪光灯")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                PhotoPicker(selectedImage: $selectedImage)
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if newImage != nil {
                    navigateToResult = true
                }
            }
            .navigationDestination(isPresented: $navigateToResult) {
                if let image = selectedImage {
                    ResultView(image: image)
                }
            }
        }
    }
}

// MARK: - Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Camera Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView()
}
