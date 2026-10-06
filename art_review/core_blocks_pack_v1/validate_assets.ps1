$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$pack = 'C:/dev/archeoblocks/assets/blocks/core_blocks_pack_v1'
$names = @('green','blue','red','amber','purple','turquoise')
$referenceHash = $null
$results = foreach($name in $names) {
    $path = "$pack/block_${name}_v1.png"
    $bytes = [IO.File]::ReadAllBytes($path)
    if($bytes[24] -ne 8 -or $bytes[25] -ne 6) { throw "Not PNG RGBA8: $name" }
    $b = [Drawing.Bitmap]::new($path)
    if($b.Width -ne 256 -or $b.Height -ne 256) { throw "Wrong canvas: $name" }
    $alpha = [byte[]]::new(65536)
    $transparent=0; $partial=0; $opaque=0
    $minX=256; $minY=256; $maxX=-1; $maxY=-1
    for($y=0;$y -lt 256;$y++) { for($x=0;$x -lt 256;$x++) {
        $a=$b.GetPixel($x,$y).A; $alpha[$y*256+$x]=$a
        if(($x -lt 16 -or $y -lt 16 -or $x -ge 240 -or $y -ge 240) -and $a -ne 0) { throw "Padding not transparent: $name" }
        if($a -eq 0){$transparent++}elseif($a -eq 255){$opaque++}else{$partial++}
        if($a -gt 0){$minX=[Math]::Min($minX,$x);$minY=[Math]::Min($minY,$y);$maxX=[Math]::Max($maxX,$x);$maxY=[Math]::Max($maxY,$y)}
        if($x -ge 48 -and $x -lt 208 -and $y -ge 48 -and $y -lt 208 -and $a -ne 255){throw "Translucent interior: $name"}
    }}
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($alpha)).ToLowerInvariant()
    if($null -eq $referenceHash){$referenceHash=$hash}elseif($hash -ne $referenceHash){throw "Alpha mismatch: $name"}
    $b.Dispose()
    [ordered]@{file="block_${name}_v1.png";size=@(256,256);format='PNG_RGBA8';alpha_sha256=$hash;bounds_inclusive=@($minX,$minY,$maxX,$maxY);transparent_pixels=$transparent;partial_pixels=$partial;opaque_pixels=$opaque;opaque_center=$true}
}
[ordered]@{passed=$true;asset_count=6;identical_alpha=$true;minimum_clear_padding_px=16;checks=@('256x256','PNG color type6 bit depth8','transparent padding','pixel-identical alpha and origin','opaque stone center');assets=@($results)} | ConvertTo-Json -Depth 6
