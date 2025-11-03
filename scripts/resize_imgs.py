import os
from PIL import Image

# Root folder to start searching
root_folder = "./"   # Change this if needed

# Target and original sizes
original_size = (1178, 2556)
target_size = (1179, 2556)

# Walk through all subdirectories
for dirpath, _, filenames in os.walk(root_folder):
    for filename in filenames:
        if filename.lower().endswith(".png"):
            file_path = os.path.join(dirpath, filename)
            try:
                with Image.open(file_path) as img:
                    if img.size == original_size:
                        resized_img = img.resize(target_size, Image.LANCZOS)
                        resized_img.save(file_path)
                        print(f"Resized: {file_path}")
                    else:
                        print(f"Skipped (size {img.size}): {file_path}")
            except Exception as e:
                print(f"Error processing {file_path}: {e}")

print("✅ Done resizing images recursively.")
