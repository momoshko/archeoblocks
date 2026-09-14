class_name BlockTextureResolver
extends RefCounted


static func texture_for_color(texture_set: BlockTextureSet, color: Color) -> Texture2D:
	if texture_set == null:
		return null
	var count := mini(texture_set.reference_colors.size(), texture_set.textures.size())
	if count == 0:
		return null
	var best_index := 0
	var best_distance := INF
	for index in count:
		var reference := texture_set.reference_colors[index]
		var delta := Vector3(color.r - reference.r, color.g - reference.g, color.b - reference.b)
		var distance := delta.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return texture_set.textures[best_index]
