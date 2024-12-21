# Godot APNG Writer

A lightweight and efficient APNG (Animated PNG) writer implementation for Godot 4.x. This tool allows you to create animated PNG files programmatically within your Godot projects.

## Features

- Pure GDScript implementation
- Frame-by-frame APNG creation
- Support for custom frame delays
- Proper chunk handling and CRC validation
- Compatible with Godot 4.x viewport captures
- Handles IHDR, acTL, fcTL, IDAT, and fdAT chunks according to the APNG specification

## Usage

1. Add the `APNG Writer.gd` script to your project.

2. Create an instance of the APNG writer:
```gdscript
var writer = APNGWriter.new()
writer.set_number_of_frames(total_frames)  # Set the total number of frames
```

3. Process your frames:
```gdscript
# For each frame
for frame in frames:
    writer.process_frame(frame)  # frame should be an Image object
```

4. Finalize and save the APNG:
```gdscript
var file = FileAccess.open("res://output.apng", FileAccess.WRITE)
file.store_buffer(writer.finalize())
file.close()
```

## Example

Here's a complete example that captures viewport frames and creates an APNG:

```gdscript
extends Node

var frames: Array[Image] = []

func capture_frame() -> Image:
    await get_tree().process_frame
    await get_tree().process_frame
    
    var viewport_texture = get_viewport().get_texture()
    var frame = Image.create(viewport_texture.get_width(), 
                           viewport_texture.get_height(), 
                           false, 
                           Image.FORMAT_RGBA8)
    frame.copy_from(viewport_texture.get_image())
    return frame

func _ready() -> void:
    # Capture frames
    for i in range(number_of_frames):
        frames.append(await capture_frame())
        # Update your scene here
    
    # Create APNG
    var writer = APNGWriter.new()
    writer.set_number_of_frames(frames.size())
    
    # Process frames
    for frame in frames:
        writer.process_frame(frame)
    
    # Save the final APNG
    var file = FileAccess.open("res://output.apng", FileAccess.WRITE)
    file.store_buffer(writer.finalize())
    file.close()
```

## Technical Details

The writer implements the APNG specification by:
- Writing proper PNG signature and chunks
- Handling chunk CRC calculation and validation
- Managing sequence numbers for animation frames
- Supporting frame control (fcTL) chunks for animation control
- Converting IDAT chunks to fdAT chunks for subsequent frames

## Limitations

- Currently supports basic APNG creation with fixed frame delays
- Does not support frame disposal methods
- Limited to viewport captures or Image objects as input

## Contributing

Contributions are welcome! Feel free to use this as you please.

## License

No license, I know it says MIT, disregard that.

## Credits

Created Entirely by Claude with my prompts, this README too.
