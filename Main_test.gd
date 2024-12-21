extends Node

@onready var sprite = $sprite
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
	await get_tree().process_frame
	
	# Initial position capture
	frames.append(await capture_frame())
	
	# Capture 6 more frames, moving 10 pixels each time
	for i in range(60):
		sprite.position.x += 10
		frames.append(await capture_frame())
	
	# Create APNG
	var writer = APNGWriter.new()
	writer.set_number_of_frames(frames.size())
	
	# Process each frame
	for frame in frames:
		writer.process_frame(frame)
	
	# Save the final APNG
	var file = FileAccess.open("res://output.apng", FileAccess.WRITE)
	file.store_buffer(writer.finalize())
	file.close()
