// Offline image normalization and review assembly. Never writes gameplay files.
const fs=require('fs'), path=require('path'), crypto=require('crypto');
const sharp=require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const HERE=__dirname, OUT=path.resolve(HERE,'../../assets/art_v2a');
const specs=[
 ['cell_excavated_depth0','cells','Excavated / depth 0'],['cell_soil_depth1','cells','Soil / depth 1'],['cell_soil_depth2','cells','Dense soil / depth 2'],
 ...['green','blue','red','amber','purple','turquoise'].map(c=>['block_'+c,'blocks',c]),
 ['stone_intact','obstacles','Stone / 2 hits'],['stone_cracked','obstacles','Stone / 1 hit'],['root_obstacle','obstacles','Root'],['root_growth_warning','obstacles','Root warning'],
 ['artifact_target_marker','overlays','Artifact target'],['preview_valid','overlays','Valid preview'],['preview_invalid','overlays','Invalid preview']
];
function bbox(alpha,w,h){let l=w,t=h,r=-1,b=-1;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(alpha[y*w+x]>8){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y)}if(r<l)throw Error('Empty image');return {left:l,top:t,width:r-l+1,height:b-t+1};}
function hash(b){return crypto.createHash('sha256').update(b).digest('hex')}
function hsl(r,g,b){r/=255;g/=255;b/=255;const hi=Math.max(r,g,b),lo=Math.min(r,g,b),d=hi-lo,l=(hi+lo)/2;return {s:d===0?0:d/(1-Math.abs(2*l-1)),l};}
function rgb(h,s,l){const c=(1-Math.abs(2*l-1))*s,x=c*(1-Math.abs((h/60)%2-1)),m=l-c/2;const v=h<60?[c,x,0]:h<120?[x,c,0]:h<180?[0,c,x]:h<240?[0,x,c]:h<300?[x,0,c]:[c,0,x];return v.map(a=>Math.round((a+m)*255));}
function colorNormalize(raw,name){
 // Final numeric palette normalization of generated art; no shape, texture,
 // alpha or feature-position edits. Original ImageGen sources remain intact.
 if(name==='block_green'||name==='block_purple')for(let k=0;k<raw.length;k+=4)if(raw[k+3])for(let c=0;c<3;c++)raw[k+c]=Math.round(255*Math.pow(raw[k+c]/255,name==='block_green'?1.20:.65));
 if(name==='root_growth_warning')for(let k=0;k<raw.length;k+=4)if(raw[k+3]){const p=hsl(raw[k],raw[k+1],raw[k+2]),out=rgb(85,Math.min(.42,p.s*.55),Math.min(1,p.l+.07*Math.sin(Math.PI*p.l)));for(let c=0;c<3;c++)raw[k+c]=out[c];}
}
async function matte(name){
 const source=path.join(HERE,'sources',name+'.png'),meta=await sharp(source).metadata();
 const {data,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const w=info.width,h=info.height,n=w*h,a=new Uint8Array(n),candidate=new Uint8Array(n),seen=new Uint8Array(n),q=new Int32Array(n);
 let removed=0;
 if(meta.hasAlpha){for(let i=0;i<n;i++)a[i]=data[i*4+3];}
 else{
  // Remove only edge-connected achromatic generated matte. Roots/overlays also
  // have open internal gaps; their chromatic artwork allows neutral gap cleanup.
  for(let i=0;i<n;i++){let k=i*4;candidate[i]=(Math.max(data[k],data[k+1],data[k+2])-Math.min(data[k],data[k+1],data[k+2])<=12 && Math.min(data[k],data[k+1],data[k+2])>=90)?1:0;}
  let head=0,tail=0;function push(i){if(i<0||i>=n||seen[i]||!candidate[i])return;seen[i]=1;q[tail++]=i}
  for(let x=0;x<w;x++){push(x);push((h-1)*w+x)}for(let y=0;y<h;y++){push(y*w);push(y*w+w-1)}
  while(head<tail){let i=q[head++],x=i%w; if(x>0)push(i-1);if(x<w-1)push(i+1);push(i-w);push(i+w)}
  if(name.startsWith('root_')||name.startsWith('preview_')||name.startsWith('artifact_'))for(let i=0;i<n;i++)if(candidate[i])seen[i]=1;
  // Contract matte by one source pixel before resampling to remove pale fringe.
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;const edge=seen[i]||(x>0&&seen[i-1])||(x<w-1&&seen[i+1])||(y>0&&seen[i-w])||(y<h-1&&seen[i+w]);a[i]=edge?0:255;if(edge)removed++;}
 }
 for(let i=0;i<n;i++){data[i*4+3]=a[i];if(!a[i])data.fill(0,i*4,i*4+3)}
 return {data,info,alpha:a,box:bbox(a,w,h),source,sourceHasAlpha:!!meta.hasAlpha,removed};
}
async function rasterFrom(src,box,width,height){return sharp(src.data,{raw:src.info}).extract(box).resize(width,height,{fit:'fill',kernel:'lanczos3'}).ensureAlpha().raw().toBuffer();}
const report=[];
async function exportAll(){
 const available=specs.filter(([n])=>fs.existsSync(path.join(HERE,'sources',n+'.png')));
 const sources={};for(const [n] of available)sources[n]=await matte(n);
 sources.preview_valid_master=await matte('preview_valid_master');
 let blockAlpha;
 if(sources.block_green){const master=await rasterFrom(sources.block_green,sources.block_green.box,220,220);blockAlpha=Buffer.alloc(220*220);for(let i=0;i<blockAlpha.length;i++)blockAlpha[i]=master[i*4+3];}
 for(const [name,category,label] of available){
  const src=sources[name];let size=220,left=18,top=18,box=src.box;
  if(category==='cells'){size=240;left=8;top=8;const shared=sources.cell_soil_depth1.box;box={left:shared.left+8,top:shared.top+8,width:shared.width-16,height:shared.height-16};}
  if(category==='blocks')box=sources.block_green.box;
  if(category==='overlays'||name==='root_growth_warning'){size=240;left=8;top=8;}
  if(name.startsWith('preview_'))box=sources.preview_valid_master.box;
  // For reference-derived stones, use master's source region if dimensions match.
  if(name==='stone_cracked'&&sources.stone_intact&&src.info.width===sources.stone_intact.info.width)box=sources.stone_intact.box;
  let raw=await rasterFrom(src,box,size,size);
  if(category==='cells'){
   const mask=await sharp(Buffer.from('<svg width="240" height="240"><rect width="240" height="240" rx="6" fill="white"/></svg>')).ensureAlpha().raw().toBuffer();
   for(let i=0;i<size*size;i++)raw[i*4+3]=mask[i*4+3];
  }
  if(category==='blocks')for(let i=0;i<size*size;i++)raw[i*4+3]=blockAlpha[i];
  colorNormalize(raw,name);
  const canvas=Buffer.alloc(256*256*4);
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){let si=(y*size+x)*4,di=((y+top)*256+x+left)*4;raw.copy(canvas,di,si,si+4);if(!canvas[di+3])canvas.fill(0,di,di+3);}
  const output=path.join(OUT,category,name+'_v2a.png');fs.mkdirSync(path.dirname(output),{recursive:true});
  await sharp(canvas,{raw:{width:256,height:256,channels:4}}).withIccProfile('srgb').png().toFile(output);
  const alpha=Buffer.alloc(256*256);let transparent=0;for(let i=0;i<alpha.length;i++){alpha[i]=canvas[i*4+3];if(alpha[i]===0)transparent++;}
  report.push({name,category,label,file:path.relative(path.resolve(HERE,'../..'),output).replaceAll('\\','/'),source:'sources/'+name+'.png',sourceHasAlpha:src.sourceHasAlpha,mattePixelsRemoved:src.removed,sourceCrop:box,sourceSize:[src.info.width,src.info.height],targetSize:[256,256],alphaSha256:hash(alpha),alphaBounds:bbox(alpha,256,256),transparentPixelFraction:transparent/alpha.length,colorNormalization:name==='block_green'?'RGB power curve exponent 1.20 for grayscale value separation':name==='block_purple'?'RGB power curve exponent 0.65 for grayscale value separation':name==='root_growth_warning'?'HSL hue 85 degrees, saturation min(0.42, original*0.55), lightness original+0.07*sin(pi*original)':'none',production:true});
 }
 fs.writeFileSync(path.join(HERE,'export_report.json'),JSON.stringify(report,null,2)+'\n');
 console.log('Exported '+report.length+' / '+specs.length+' sprites.');
}
exportAll().catch(e=>{console.error(e);process.exit(1)});
