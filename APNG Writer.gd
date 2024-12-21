class_name PNGWriter
extends RefCounted

const PNG_SIG = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
const ACTRL = [0x61, 0x63, 0x54, 0x4C]
const FCTL = [0x66, 0x63, 0x54, 0x4C]
const FDAT = [0x66, 0x64, 0x41, 0x54]

const UINT16_MAX = 65535
const UINT31_MAX = 0x7FFFFFFF

# State variables
var output_data: PackedByteArray
var sequence_number: int = 0
var total_frames: int = 0
var current_frame: int = 0
var prev_frame_data: PackedByteArray
var original_width: int = 0
var original_height: int = 0

class Chunk:
	var length: int
	var type: String
	var data: PackedByteArray
	var crc: int
	
	func _init(l: int, t: String, d: PackedByteArray, c: int):
		length = l
		type = t
		data = d
		crc = c
	
	func get_raw_data() -> PackedByteArray:
		var raw = PackedByteArray()
		# Length - big endian
		raw.append((length >> 24) & 0xFF)
		raw.append((length >> 16) & 0xFF)
		raw.append((length >> 8) & 0xFF)
		raw.append(length & 0xFF)
		# Type and data
		raw.append_array(type.to_ascii_buffer())
		raw.append_array(data)
		# CRC - big endian
		raw.append((crc >> 24) & 0xFF)
		raw.append((crc >> 16) & 0xFF)
		raw.append((crc >> 8) & 0xFF)
		raw.append(crc & 0xFF)
		return raw

func _init() -> void:
	output_data = PackedByteArray([])
	prev_frame_data = PackedByteArray([])
	output_data.append_array(PackedByteArray(PNG_SIG))

func set_number_of_frames(num_frames: int) -> void:
	total_frames = num_frames

func write_int32(value: int) -> PackedByteArray:
	print("write_int32 called with value: 0x%08X" % value)
	var data = PackedByteArray()
	data.append((value >> 24) & 0xFF)  # Most significant byte
	data.append((value >> 16) & 0xFF)  # Next byte
	data.append((value >> 8) & 0xFF)   # Next byte
	data.append(value & 0xFF)          # Least significant byte
	print("Wrote bytes: ", Array(data))
	return data

func write_int16(value: int) -> PackedByteArray:
	value = mini(value, UINT16_MAX)
	var data = PackedByteArray()
	data.append((value >> 8) & 0xFF)
	data.append(value & 0xFF)
	return data

func write_original_chunk(chunk: Chunk) -> void:
	print("\nWriting original chunk of type: ", chunk.type)
	print("Length: ", chunk.length)
	print("Data size: ", chunk.data.size())
	print("Original CRC: 0x%08X" % chunk.crc)
	
	# Write length
	var length_bytes = write_int32(chunk.length)
	print("Length bytes: ", Array(length_bytes))
	output_data.append_array(length_bytes)
	
	# Write type
	var type_bytes = chunk.type.to_ascii_buffer()
	print("Type bytes: ", Array(type_bytes))
	output_data.append_array(type_bytes)
	
	# Write data
	print("First few data bytes: ", Array(chunk.data.slice(0, min(10, chunk.data.size()))))
	if chunk.data.size() > 10:
		print("Last few data bytes: ", Array(chunk.data.slice(max(0, chunk.data.size() - 10), chunk.data.size())))
	output_data.append_array(chunk.data)
	
	# Write CRC
	var crc_bytes = write_int32(chunk.crc)
	print("CRC bytes: ", Array(crc_bytes))
	output_data.append_array(crc_bytes)
	
	# Verify CRC
	var calc_crc = calculate_crc(type_bytes, chunk.data)
	print("Calculated CRC: 0x%08X" % calc_crc)
	if calc_crc != chunk.crc:
		print("WARNING: CRC mismatch!")


func calculate_crc(type_bytes: PackedByteArray, data: PackedByteArray) -> int:
	print("Calculating CRC for ", type_bytes.get_string_from_ascii())
	print("Starting CRC calculation with initial value: 0xFFFFFFFF")
	var crc = 0xFFFFFFFF
	
	# Process type bytes
	print("Processing type bytes:")
	for b in type_bytes:
		var old_crc = crc
		crc = ((crc >> 8) & 0xFFFFFF) ^ CRC_TABLE[(crc ^ b) & 0xFF]
		print("  Byte: 0x%02X, CRC: 0x%08X -> 0x%08X" % [b, old_crc, crc])
	
	# Process data bytes
	print("Processing data bytes:")
	var byte_count = 0
	for b in data:
		var old_crc = crc
		crc = ((crc >> 8) & 0xFFFFFF) ^ CRC_TABLE[(crc ^ b) & 0xFF]
		if byte_count < 10 or byte_count > data.size() - 10:
			print("  Byte %d: 0x%02X, CRC: 0x%08X -> 0x%08X" % [byte_count, b, old_crc, crc])
		elif byte_count == 10:
			print("  ... (skipping middle bytes) ...")
		byte_count += 1
	
	var final_crc = ~crc & 0xFFFFFFFF
	print("Final CRC (after complement): 0x%08X" % final_crc)
	return final_crc

func write_chunk_with_crc(type_bytes: PackedByteArray, data: PackedByteArray) -> void:
	var length = data.size()
	print("\nWriting chunk: ", type_bytes.get_string_from_ascii())
	print("Length: ", length, " bytes")
	
	# Write length
	var length_bytes = write_int32(length)
	print("Length bytes: ", Array(length_bytes))
	output_data.append_array(length_bytes)
	
	# Write type and data
	print("Type bytes: ", Array(type_bytes))
	print("First few data bytes: ", Array(data.slice(0, min(10, data.size()))))
	if data.size() > 10:
		print("Last few data bytes: ", Array(data.slice(max(0, data.size() - 10), data.size())))
	output_data.append_array(type_bytes)
	output_data.append_array(data)
	
	# Calculate CRC
	var crc = calculate_crc(type_bytes, data)
	
	# Write CRC
	var crc_bytes = write_int32(crc)
	print("CRC bytes: ", Array(crc_bytes))
	output_data.append_array(crc_bytes)

func parse_png_buffer(buffer: PackedByteArray) -> Array[Chunk]:
	var chunks: Array[Chunk] = []
	var pos = 8  # Skip PNG signature
	
	print("\nParsing PNG buffer of size: ", buffer.size())
	while pos < buffer.size():
		# Read chunk length (4 bytes, big endian)
		var chunk_length = (buffer[pos] << 24) | (buffer[pos + 1] << 16) | \
						  (buffer[pos + 2] << 8) | buffer[pos + 3]
		print("Reading chunk at position ", pos, " with length: ", chunk_length)
		
		# Read chunk type (4 bytes)
		var chunk_type = ""
		for i in range(4):
			chunk_type += char(buffer[pos + 4 + i])
		print("Chunk type: ", chunk_type)
		
		# For IHDR chunks, properly decode dimensions
		if chunk_type == "IHDR":
			var width = (buffer[pos + 8] << 24) | (buffer[pos + 9] << 16) | \
						(buffer[pos + 10] << 8) | buffer[pos + 11]
			var height = (buffer[pos + 12] << 24) | (buffer[pos + 13] << 16) | \
						(buffer[pos + 14] << 8) | buffer[pos + 15]
			print("Decoded IHDR dimensions: ", width, "x", height)
			print("Raw IHDR bytes: [", 
				buffer[pos + 8], " ", buffer[pos + 9], " ", 
				buffer[pos + 10], " ", buffer[pos + 11], "] x [",
				buffer[pos + 12], " ", buffer[pos + 13], " ", 
				buffer[pos + 14], " ", buffer[pos + 15], "]")
		
		var chunk_data = buffer.slice(pos + 8, pos + 8 + chunk_length)
		var crc = (buffer[pos + 8 + chunk_length] << 24) | \
				  (buffer[pos + 8 + chunk_length + 1] << 16) | \
				  (buffer[pos + 8 + chunk_length + 2] << 8) | \
				  buffer[pos + 8 + chunk_length + 3]
		
		chunks.append(Chunk.new(chunk_length, chunk_type, chunk_data, crc))
		pos += 8 + chunk_length + 4  # Move to next chunk
	
	return chunks

func create_fctl_data(width: int, height: int, x_offset: int, y_offset: int,
					delay_num: int, delay_den: int, dispose_op: int, blend_op: int) -> PackedByteArray:
	print("Creating fcTL data with dimensions: ", width, "x", height)
	
	# Use original dimensions from first frame for all subsequent frames
	if original_width > 0 and original_height > 0:
		print("Using original dimensions: ", original_width, "x", original_height)
		width = original_width
		height = original_height
	else:
		print("Setting original dimensions to: ", width, "x", height)
		original_width = width
		original_height = height
	
	var data = PackedByteArray()
	data.append_array(write_int32(sequence_number))
	data.append_array(write_int32(width))
	data.append_array(write_int32(height))
	data.append_array(write_int32(x_offset))
	data.append_array(write_int32(y_offset))
	data.append_array(write_int16(delay_num))
	data.append_array(write_int16(delay_den))
	data.append(dispose_op)
	data.append(blend_op)
	return data

func flush_frame(next_frame: Image = null) -> void:
	print("\nFlushing frame ", current_frame)
	var chunks = parse_png_buffer(prev_frame_data)
	var frame_width: int = 0
	var frame_height: int = 0
	
	# Get frame dimensions first
	for chunk in chunks:
		if chunk.type == "IHDR":
			frame_width = (chunk.data[0] << 24) | (chunk.data[1] << 16) | \
						 (chunk.data[2] << 8) | chunk.data[3]
			frame_height = (chunk.data[4] << 24) | (chunk.data[5] << 16) | \
						  (chunk.data[6] << 8) | chunk.data[7]
			print("Frame dimensions from IHDR data: ", frame_width, "x", frame_height)
			break
	
	if current_frame == 0:
		print("Processing first frame")
		for chunk in chunks:
			if chunk.type == "IHDR":
				print("Writing IHDR chunk")
				write_original_chunk(chunk)
				
				# Write animation control chunk
				print("Writing acTL chunk")
				var actl_data = PackedByteArray()
				actl_data.append_array(write_int32(total_frames))
				actl_data.append_array(write_int32(0))
				write_chunk_with_crc(PackedByteArray(ACTRL), actl_data)
				
				# Write frame control chunk
				print("Writing first frame fcTL")
				var fctl_data = create_fctl_data(
					frame_width, frame_height,
					0, 0,
					100, 1000,
					0, 0
				)
				write_chunk_with_crc(PackedByteArray(FCTL), fctl_data)
				sequence_number += 1
				
			elif chunk.type == "IDAT":
				print("Writing first frame IDAT")
				write_original_chunk(chunk)
			elif chunk.type != "IEND":
				print("Writing other chunk: ", chunk.type)
				write_original_chunk(chunk)
	else:
		print("Processing subsequent frame")
		# Write frame control for this frame
		var fctl_data = create_fctl_data(
			frame_width, frame_height,
			0, 0,
			100, 1000,
			0, 0
		)
		print("\nWriting fcTL for subsequent frame")
		write_chunk_with_crc(PackedByteArray(FCTL), fctl_data)
		sequence_number += 1
		
		# Collect IDAT chunks
		var idat_data = PackedByteArray()
		for chunk in chunks:
			if chunk.type == "IDAT":
				print("Found IDAT chunk, size: ", chunk.data.size())
				print("First few IDAT bytes: ", Array(chunk.data.slice(0, min(10, chunk.data.size()))))
				idat_data.append_array(chunk.data)
		
		print("Combined IDAT size: ", idat_data.size())
		
		if idat_data.size() > 0:
			# Create fdAT data - ONLY add sequence number
			var fdat_data = PackedByteArray()
			fdat_data.append_array(write_int32(sequence_number))
			sequence_number += 1
			
			# Add original IDAT data without modification
			fdat_data.append_array(idat_data)
			
			print("Final fdAT size: ", fdat_data.size())
			print("Sequence number in fdAT: ", Array(fdat_data.slice(0, 4)))
			print("First few data bytes after sequence: ", Array(fdat_data.slice(4, 14)))
			
			write_chunk_with_crc(PackedByteArray(FDAT), fdat_data)
	
	current_frame += 1
	
	if next_frame:
		print("Storing next frame data")
		prev_frame_data = next_frame.save_png_to_buffer()
	elif current_frame == total_frames:
		print("Writing final IEND chunk")
		write_chunk_with_crc("IEND".to_ascii_buffer(), PackedByteArray())

func process_frame(image: Image, is_first_frame: bool = false) -> void:
	print("\nProcessing frame ", current_frame)
	print("Image dimensions: ", image.get_width(), "x", image.get_height())
	
	if prev_frame_data.is_empty():
		print("First frame - storing PNG data")
		prev_frame_data = image.save_png_to_buffer()
	else:
		print("Subsequent frame - flushing previous frame")
		flush_frame(image)

func finalize() -> PackedByteArray:
	print("\nFinalizing APNG")
	if not prev_frame_data.is_empty():
		flush_frame(null)
	return output_data
#CRC Table for chunk validation
const CRC_TABLE = [
	0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
	0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
	0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91, 0x1DB71064, 0x6AB020F2,
	0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
	0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9,
	0xFA0F3D63, 0x8D080DF5, 0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
	0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B, 0x35B5A8FA, 0x42B2986C,
	0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
	0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423,
	0xCFBA9599, 0xB8BDA50F, 0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
	0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D, 0x76DC4190, 0x01DB7106,
	0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
	0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D,
	0x91646C97, 0xE6635C01, 0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
	0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457, 0x65B0D9C6, 0x12B7E950,
	0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
	0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7,
	0xA4D1C46D, 0xD3D6F4FB, 0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
	0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9, 0x5005713C, 0x270241AA,
	0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
	0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81,
	0xB7BD5C3B, 0xC0BA6CAD, 0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
	0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683, 0xE3630B12, 0x94643B84,
	0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
	0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB,
	0x196C3671, 0x6E6B06E7, 0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
	0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5, 0xD6D6A3E8, 0xA1D1937E,
	0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
	0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55,
	0x316E8EEF, 0x4669BE79, 0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
	0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F, 0xC5BA3BBE, 0xB2BD0B28,
	0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
	0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F,
	0x72076785, 0x05005713, 0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
	0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21, 0x86D3D2D4, 0xF1D4E242,
	0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
	0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69,
	0x616BFFD3, 0x166CCF45, 0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
	0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB, 0xAED16A4A, 0xD9D65ADC,
	0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
	0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693,
	0x54DE5729, 0x23D967BF, 0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
	0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
]
