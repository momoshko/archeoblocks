class_name ArtifactTextureUtil
extends RefCounted


static func fit_visible_alpha(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO or used_rect.size == image.get_size():
		return texture
	var fitted := AtlasTexture.new()
	fitted.atlas = texture
	fitted.region = Rect2(used_rect)
	fitted.filter_clip = true
	return fitted


static func source_texture(texture: Texture2D) -> Texture2D:
	if texture is AtlasTexture:
		return (texture as AtlasTexture).atlas
	return texture
