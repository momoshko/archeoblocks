/* Mechanical sprite export and review assembly. No Godot scene/resource writes. */
const fs = require('fs');
const path = require('path');
const sharp = require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const ROOT = __dirname;
const OUT = path.join(ROOT, 'artifacts');
const REVIEW = path.join(ROOT, 'review');
const SIZE = 512;
const INNER = 384;
const items = [];
const reports = [];

function bounds(data, w, h, cutoff = 0) {
  let l=w, t=h, r=-1, b=-1;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++) if(data[(y*w+x)*4+3]>cutoff){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);}
  if(r<0) throw Error('Empty alpha');
  return {left:l,top:t,width:r-l+1,height:b-t+1};
}

async function normalize(source, name, material, usage) {
  const src=path.join(ROOT,'sources',source);
  const metadata=await sharp(src).metadata();
  const {data,info}=await sharp(src).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let removed=0;
  if(!metadata.hasAlpha) {
    // The generated RGB matte is achromatic; the relics have saturated warm
    // edges. Flood only connected background (plus the amulet's loop hole),
    // never globally discard neutral highlights on the object.
    const seen=new Uint8Array(info.width*info.height), queue=new Int32Array(seen.length);
    let head=0, tail=0;
    function push(x,y){
      if(x<0||y<0||x>=info.width||y>=info.height) return;
      const i=y*info.width+x, k=i*4;
      if(seen[i]) return;
      const hi=Math.max(data[k],data[k+1],data[k+2]), lo=Math.min(data[k],data[k+1],data[k+2]);
      if(hi-lo>36 || Math.abs(data[k]-data[k+2])>30) return;
      seen[i]=1;queue[tail++]=i;
    }
    for(let x=0;x<info.width;x++){push(x,0);push(x,info.height-1);}
    for(let y=0;y<info.height;y++){push(0,y);push(info.width-1,y);}
    if(name==='stone_amulet_full_v1') push(Math.round(info.width*.5),Math.round(info.height*.115));
    while(head<tail){const i=queue[head++],x=i%info.width,y=Math.floor(i/info.width);push(x-1,y);push(x+1,y);push(x,y-1);push(x,y+1);}
    // One source-pixel matte contraction removes checker fringe before downsample.
    const matte=seen.slice();
    for(let y=1;y<info.height-1;y++) for(let x=1;x<info.width-1;x++){
      const i=y*info.width+x;
      if(seen[i-1]||seen[i+1]||seen[i-info.width]||seen[i+info.width]) matte[i]=1;
    }
    for(let i=0;i<matte.length;i++) if(matte[i]){data[i*4+3]=0;data[i*4]=0;data[i*4+1]=0;data[i*4+2]=0;removed++;}
  }
  const box=bounds(data,info.width,info.height,5);
  const fitted=await sharp(data,{raw:info}).extract(box).resize(INNER,INNER,{fit:'inside',kernel:'lanczos3'}).png().toBuffer();
  const fm=await sharp(fitted).metadata();
  const left=Math.floor((SIZE-fm.width)/2),top=Math.floor((SIZE-fm.height)/2);
  const file=path.join(OUT,name+'.png');
  await sharp({create:{width:SIZE,height:SIZE,channels:4,background:'#00000000'}}).composite([{input:fitted,left,top}]).png().toFile(file);
  items.push({name,file:'artifacts/'+name+'.png',type:'full_artifact',canvas_size:[SIZE,SIZE],transparent_background:true,material,recommended_usage:usage});
  reports.push({name,source_has_alpha:metadata.hasAlpha,background_pixels_removed:removed});
  return file;
}

function lineY(points,x){
  for(let i=1;i<points.length;i++) if(x<=points[i][0]) {const a=points[i-1],b=points[i];return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]);}
  return points.at(-1)[1];
}

function chippedLine(points, seed) {
  // Complementary irregular facets: no jigsaw tabs, no missing pixels.
  const result=[];
  let x=0;
  const rand=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  while(x<512){result.push([x,lineY(points,x)+(rand()-.5)*9]);x+=5+Math.floor(rand()*10);}
  result.push([512,lineY(points,512)]);
  return result;
}

async function splitMask(maskFile){
  const {data,info}=await sharp(maskFile).raw().toBuffer({resolveWithObject:true});
  const guides=[
    [[0,207],[96,214],[115,205],[140,199],[160,211],[185,215],[205,207],[235,213],[252,240],[263,231],[280,208],[306,203],[327,211],[350,219],[375,207],[400,209],[512,207]],
    [[0,277],[120,277],[138,283],[155,299],[176,307],[199,315],[220,318],[237,327],[252,322],[267,329],[281,318],[303,316],[325,308],[344,300],[367,282],[390,277],[512,277]]
  ];
  const seams=guides.map((p,i)=>chippedLine(p,9173+i*71));
  const parts=[Buffer.alloc(data.length),Buffer.alloc(data.length),Buffer.alloc(data.length)];
  for(let y=0;y<SIZE;y++) for(let x=0;x<SIZE;x++){
    const part=y<lineY(seams[0],x)?0:y<lineY(seams[1],x)?1:2;
    const k=(y*SIZE+x)*4;data.copy(parts[part],k,k,k+4);
  }
  const assembled=Buffer.alloc(data.length);
  const descriptions=['forehead, crown band and central boss','eyes, nose and upper cheeks','mouth, chin, lower cheeks and round ear ornaments'];
  for(let i=0;i<3;i++){
    const name='golden_mask_fragment_'+String.fromCharCode(97+i)+'_v1';
    const box=bounds(parts[i],SIZE,SIZE);
    const left=Math.floor((SIZE-box.width)/2),top=Math.floor((SIZE-box.height)/2);
    const centered=Buffer.alloc(data.length);
    for(let y=0;y<box.height;y++)for(let x=0;x<box.width;x++){
      const from=((box.top+y)*SIZE+box.left+x)*4,to=((top+y)*SIZE+left+x)*4;
      parts[i].copy(centered,to,from,from+4);
    }
    // Direct integer translation avoids repeated alpha premultiply rounding.
    await sharp(centered,{raw:info}).png().toFile(path.join(OUT,name+'.png'));
    items.push({name,file:'artifacts/'+name+'.png',type:'fragment',canvas_size:[SIZE,SIZE],transparent_background:true,description:descriptions[i],parent:'golden_mask_full_v1',scale_relative_to_full:1,assembly_translation_px:[box.left-left,box.top-top],assembly_source_rect_px:box,centered_sprite_rect_px:{left,top,width:box.width,height:box.height},recommended_usage:'Fragment reveal, collection progress. Centered sprite for display; apply assembly translation to restore full-mask coordinates.'});
    // Validate the delivered centered PNG, not only the intermediate partition.
    const exported=await sharp(path.join(OUT,name+'.png')).ensureAlpha().raw().toBuffer();
    for(let y=0;y<box.height;y++)for(let x=0;x<box.width;x++){
      const from=((top+y)*SIZE+left+x)*4,to=((box.top+y)*SIZE+box.left+x)*4;
      if(exported[from+3]>0)exported.copy(assembled,to,from,from+4);
    }
  }
  let mismatch=0;for(let k=0;k<data.length;k+=4) if(data[k+3]>0 && !data.subarray(k,k+4).equals(assembled.subarray(k,k+4)))mismatch++;
  if(mismatch) throw Error('Fragment partition did not reconstruct mask');
  await sharp(assembled,{raw:info}).png().toFile(path.join(REVIEW,'golden_mask_reconstructed.png'));
  return {method:'Complementary irregular alpha partitions of one normalized generated master, centered by integer translation only.',seams_master_px:seams,pixel_mismatch_visible_rgba:mismatch,shared_scale:1,broken_edge_note:'Irregular cut silhouettes; face artwork is unchanged. No independently invented faces or duplicated features.'};
}

function svg(w,h,body){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="#211b16"/>${body}</svg>`);}
function text(x,y,str,size=18,fill='#eee0bf'){return `<text x="${x}" y="${y}" font-family="Arial" font-size="${size}" fill="${fill}">${str}</text>`;}
async function fitted(file,size){const b=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});return sharp(b.data,{raw:b.info}).extract(bounds(b.data,b.info.width,b.info.height,5)).resize(size,size,{fit:'inside'}).png().toBuffer();}
async function centerLayer(buffer,x,y,w,h){const m=await sharp(buffer).metadata();return{input:buffer,left:x+Math.floor((w-m.width)/2),top:y+Math.floor((h-m.height)/2)};}
const labels=['Courtyard Seal','Stone Amulet','Golden Mask','A / Forehead','B / Face','C / Mouth + chin'];

async function reviews(){
  let body=text(32,40,'ANCIENT COURTYARD / ARTIFACT PRESENTATION PACK v1',25)+text(32,70,'Generated relic art / transparent production sprites / no gameplay markers',16);
  const layers=[];
  for(let i=0;i<items.length;i++){
    const x=32+(i%3)*384,y=104+Math.floor(i/3)*300;
    body+=`<rect x="${x}" y="${y}" width="352" height="248" rx="12" fill="${i<3?'#3a2c21':'#30261d'}"/>`+text(x+14,y+276,labels[i],20);
    layers.push(await centerLayer(await fitted(path.join(ROOT,items[i].file),216),x,y,352,248));
  }
  await sharp(svg(1200,725,body)).composite(layers).png().toFile(path.join(REVIEW,'artifact_pack_overview.png'));

  body=text(24,35,'48 px review / actual size',23)+text(24,61,'Top: original 512 canvas at 48 px. Middle: alpha bounds fitted to 40 px. Bottom: 3x nearest-neighbor.',14);
  const small=[];
  for(let i=0;i<items.length;i++){
    const x=24+i*160;
    body+=text(x,93,labels[i],15);
    body+=`<rect x="${x}" y="110" width="144" height="60" fill="#e7d4af"/><rect x="${x}" y="184" width="144" height="60" fill="#35271c"/>`;
    const raw48=await sharp(path.join(ROOT,items[i].file)).resize(48,48).png().toBuffer();
    small.push({input:raw48,left:x+48,top:116});
    const fit40=await fitted(path.join(ROOT,items[i].file),40);
    const fitted48=await sharp({create:{width:48,height:48,channels:4,background:'#00000000'}}).composite([await centerLayer(fit40,0,0,48,48)]).png().toBuffer();
    small.push({input:fitted48,left:x+48,top:190});
    small.push({input:await sharp(fitted48).resize(144,144,{kernel:'nearest'}).png().toBuffer(),left:x,top:272});
  }
  await sharp(svg(984,446,body)).composite(small).png().toFile(path.join(REVIEW,'readability_48px.png'));

  body=text(28,38,'A + B + C / ONE MASK',25)+text(28,65,'Left: exploded at shared scale. Center: actual parts reassembled. Right: restored master.',17);
  const assembly=[];
  for(let i=0;i<3;i++){
    const item=items[i+3];
    const crop=await sharp(path.join(ROOT,item.file)).extract(item.centered_sprite_rect_px).png().toBuffer();
    assembly.push({input:crop,left:12+item.assembly_source_rect_px.left,top:110+item.assembly_source_rect_px.top+(i-1)*28});
  }
  assembly.push({input:path.join(REVIEW,'golden_mask_reconstructed.png'),left:540,top:110});
  assembly.push({input:path.join(OUT,'golden_mask_full_v1.png'),left:1068,top:110});
  body+=text(45,654,'Exploded / no independent scaling',18)+text(570,654,'Reassembled / pixel-exact face',18)+text(1100,654,'Restored reward artwork',18);
  await sharp(svg(1600,684,body)).composite(assembly).png().toFile(path.join(REVIEW,'golden_mask_fragments_assembly.png'));

  body=text(24,35,'DEPTH 0 / REVEAL SUPPORT',24)+text(24,62,'Core Cell Pack v2 + alpha-fitted artifact (70% of cell). Review only; no UI markers.',16);
  const mocks=[];const chosen=[0,1,3,4,5];
  const tilePath=path.resolve(ROOT,'../../assets/cells/core_cell_pack_v2/cell_excavated_depth0_v2.png');
  for(let i=0;i<chosen.length;i++){
    const idx=chosen[i],x=24+i*192;
    const tile=await sharp(tilePath).resize(144,144).png().toBuffer();
    const obj=await fitted(path.join(ROOT,items[idx].file),100);
    const mock=await sharp(tile).composite([await centerLayer(obj,0,0,144,144)]).png().toBuffer();
    mocks.push({input:mock,left:x,top:90});
    mocks.push({input:await sharp(mock).resize(48,48).png().toBuffer(),left:x+48,top:278});
    body+=text(x,262,labels[idx],16);
  }
  body+=text(24,358,'Upper row 144 px / lower row 48 px. Dark base and relic contrast are not player-tested.',16);
  await sharp(svg(984,385,body)).composite(mocks).png().toFile(path.join(REVIEW,'depth0_cell_mockups.png'));
}

async function validate(){
  for(const item of items){
    const file=path.join(ROOT,item.file),m=await sharp(file).metadata();
    const raw=await sharp(file).ensureAlpha().raw().toBuffer();
    const b=bounds(raw,SIZE,SIZE);let zero=0,solid=0;
    for(let i=3;i<raw.length;i+=4){if(raw[i]===0)zero++;if(raw[i]===255)solid++;}
    if(m.width!==SIZE||m.height!==SIZE||m.channels!==4||!zero||!solid)throw Error('Invalid production PNG: '+item.name);
    if(b.left<32||b.top<32||b.left+b.width>480||b.top+b.height>480)throw Error('Insufficient padding: '+item.name);
    item.alpha_bounds_px=b;
    reports.push({name:item.name,dimensions:[m.width,m.height],channels:m.channels,transparent_pixels:zero,opaque_pixels:solid,alpha_bounds:b});
  }
}

(async()=>{
  fs.mkdirSync(OUT,{recursive:true});fs.mkdirSync(REVIEW,{recursive:true});
  await normalize('courtyard_seal_generated.png','courtyard_seal_full_v1','sandstone and bronze','First expedition reward, collection, full-artifact reveal');
  await normalize('stone_amulet_generated.png','stone_amulet_full_v1','carved warm limestone, bronze, opaque turquoise','Second expedition reward, collection, full-artifact reveal');
  const mask=await normalize('golden_mask_generated.png','golden_mask_full_v1','warm gold relief','Third expedition victory reward and collection');
  const assembly=await splitMask(mask);
  await reviews();await validate();
  const reviewNames=['artifact_pack_overview.png','golden_mask_fragments_assembly.png','readability_48px.png','depth0_cell_mockups.png','golden_mask_reconstructed.png'];
  const reviewAssets=[];for(const file of reviewNames){const m=await sharp(path.join(REVIEW,file)).metadata();reviewAssets.push({file:'review/'+file,type:'review',canvas_size:[m.width,m.height],transparent_background:file==='golden_mask_reconstructed.png',recommended_usage:'Readability / reconstruction review only'});}
  fs.writeFileSync(path.join(ROOT,'manifest.json'),JSON.stringify({pack:'ancient_courtyard_artifact_presentation_v1',milestone:'M2.5B',status:'production_export_for_visual_review',scene_integration:false,format:'PNG RGBA8 sRGB',lighting:'upper_left',camera:'front_facing_orthographic_relief',canvas_size:[512,512],minimum_padding_px:64,production_assets:items,reviews:reviewAssets,mask_assembly:assembly,generation:'built_in_imagegen',technical_export:'Alpha matte cleanup where generated RGB had a checkerboard; resize and integer-centered complementary mask partitions. No game changes.',readability_notes:['At 48 px, silhouette and broad relief survive; tiny engraving is decorative.','Fit alpha bounds for standalone fragment icons; use recorded translation without independent resizing for reconstruction.','In-cell artwork uses 70% of cell size and is review support only.']},null,2)+'\n');
  fs.writeFileSync(path.join(ROOT,'validation.json'),JSON.stringify({production_count:items.length,assembly_pixel_mismatch:assembly.pixel_mismatch_visible_rgba,results:reports},null,2)+'\n');
  console.log(JSON.stringify({production_assets:items.length,reviews:reviewNames.length,assembly_pixel_mismatch:assembly.pixel_mismatch_visible_rgba,output:ROOT}));
})().catch(e=>{console.error(e);process.exit(1);});
