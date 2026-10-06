// Offline normalization of generated UI artwork. Writes ART V2B only.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const HERE=__dirname,REPO=path.resolve(HERE,'../..'),OUT=path.join(REPO,'assets/art_v2b');
const specs=[
 ['board_frame',1024,1024,'sandstone','frame',32],
 ['panel_header_large',768,224,'sandstone','header',24],['panel_header_small',512,160,'sandstone','support',16],['panel_label_small',384,128,'sandstone','label',16],['popup_panel',768,1024,'sandstone','modal',32],
 ['button_primary',768,192,'green','primary',24],['button_secondary',768,192,'sandstone','secondary',24],['button_disabled',768,192,'disabled','disabled',24],['button_small_back',192,192,'sandstone','back_pause_base',16],['button_selected_frame',768,192,'gold_accent','selected_overlay',24],
 ['piece_slot',384,320,'sandstone','piece_slot',16],['chapter_card_open',768,320,'sandstone','open',24],['chapter_card_locked',768,320,'disabled','locked',24],['chapter_card_completed',768,320,'sandstone_olive_accent','completed',24],['collection_card_known',384,480,'sandstone_gold_accent','known',16],['collection_card_unknown',384,480,'disabled','unknown',16]
];
const familyMaster={button_secondary:'button_primary',button_disabled:'button_primary',button_selected_frame:'button_primary',chapter_card_locked:'chapter_card_open',chapter_card_completed:'chapter_card_open',collection_card_unknown:'collection_card_known'};
const sameAlpha=new Set(['button_secondary','button_disabled','chapter_card_locked','chapter_card_completed','collection_card_unknown']);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function box(a,w,h,threshold=8){let l=w,t=h,r=-1,b=-1;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(a[y*w+x]>threshold){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);}if(r<l)throw Error('Empty alpha');return{left:l,top:t,width:r-l+1,height:b-t+1};}
async function source(name){
 const file=path.join(HERE,'sources',name+'.png'),meta=await sharp(file).metadata(),{data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const w=info.width,h=info.height,n=w*h,a=new Uint8Array(n);let removed=0;
 if(meta.hasAlpha){for(let i=0;i<n;i++)a[i]=data[i*4+3];}
 else{
  const neutral=new Uint8Array(n),seen=new Uint8Array(n),q=new Int32Array(n);let head=0,tail=0;
  for(let i=0;i<n;i++){const k=i*4,hi=Math.max(data[k],data[k+1],data[k+2]),lo=Math.min(data[k],data[k+1],data[k+2]);neutral[i]=(hi-lo<=12&&lo>=70)?1:0;}
  function push(i){if(i<0||i>=n||seen[i]||!neutral[i])return;seen[i]=1;q[tail++]=i;}
  for(let x=0;x<w;x++){push(x);push((h-1)*w+x);}for(let y=0;y<h;y++){push(y*w);push(y*w+w-1);}
  if(name==='board_frame'||name==='button_selected_frame')push(Math.floor(h/2)*w+Math.floor(w/2));
  while(head<tail){const i=q[head++],x=i%w;if(x>0)push(i-1);if(x<w-1)push(i+1);push(i-w);push(i+w);}
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;const edge=seen[i]||(x>0&&seen[i-1])||(x<w-1&&seen[i+1])||(y>0&&seen[i-w])||(y<h-1&&seen[i+w]);a[i]=edge?0:255;if(edge)removed++;}
 }
 // Remove detached alpha dust only. Retain all alpha of the main connected art.
 const seen=new Uint8Array(n),q=new Int32Array(n);let best=[];
 for(let i=0;i<n;i++)if(a[i]>8&&!seen[i]){let head=0,tail=0;q[tail++]=i;seen[i]=1;while(head<tail){const j=q[head++],x=j%w;for(const v of [x>0?j-1:-1,x<w-1?j+1:-1,j-w,j+w])if(v>=0&&v<n&&!seen[v]&&a[v]>8){seen[v]=1;q[tail++]=v;}}if(tail>best.length)best=Array.from(q.subarray(0,tail));}
 const keep=new Uint8Array(n);for(const i of best){keep[i]=1;const x=i%w;for(const v of [x>0?i-1:-1,x<w-1?i+1:-1,i-w,i+w])if(v>=0&&v<n)keep[v]=1;}
 let dust=0;for(let i=0;i<n;i++){if(!keep[i]){if(a[i])dust++;a[i]=0;}data[i*4+3]=a[i];if(!a[i])data.fill(0,i*4,i*4+3);}
 return {data,info,a,box:box(a,w,h),file,hasAlpha:!!meta.hasAlpha,removed,dust};
}
// Nine-region resize: corners use uniform scale; central face absorbs aspect change.
async function resize9(src,rect,w,h,cornerScale=1){
 const input=await sharp(src.data,{raw:src.info}).extract(rect).png().toBuffer();
 const scale=Math.min(w/rect.width,h/rect.height)*cornerScale,sx=Math.round(Math.min(rect.width*.18,rect.height*.28)),sy=Math.round(Math.min(rect.height*.22,rect.width*.18)),dx=Math.max(1,Math.round(sx*scale)),dy=Math.max(1,Math.round(sy*scale));
 const xs=[0,sx,rect.width-sx,rect.width],ys=[0,sy,rect.height-sy,rect.height],xd=[0,dx,w-dx,w],yd=[0,dy,h-dy,h],layers=[];
 for(let y=0;y<3;y++)for(let x=0;x<3;x++)layers.push({input:await sharp(input).extract({left:xs[x],top:ys[y],width:xs[x+1]-xs[x],height:ys[y+1]-ys[y]}).resize(xd[x+1]-xd[x],yd[y+1]-yd[y],{fit:'fill',kernel:'lanczos3'}).png().toBuffer(),left:xd[x],top:yd[y]});
 const raw=await sharp({create:{width:w,height:h,channels:4,background:'#00000000'}}).composite(layers).raw().toBuffer();
 return{raw,insets:[dx,dy,dx,dy],sourceSlices:[sx,sy,sx,sy]};
}
async function main(){const sources={},rendered={},report=[];for(const [name] of specs)sources[name]=await source(name);
 for(const [name,w,h,family,state,pad] of specs){const src=sources[name],master=familyMaster[name]||name,m=sources[master];let rect=m.box;
  // References share canvas proportions; normalize coordinates when tool resolution differs.
  if(src.info.width!==m.info.width||src.info.height!==m.info.height)rect={left:Math.round(rect.left*src.info.width/m.info.width),top:Math.round(rect.top*src.info.height/m.info.height),width:Math.round(rect.width*src.info.width/m.info.width),height:Math.round(rect.height*src.info.height/m.info.height)};
  // Shared family alpha supplies the exact cutline; material RGB remains generated state art.
  if(sameAlpha.has(name)){
   const original=await sharp(src.file).ensureAlpha().raw().toBuffer();src.data=original;
  }
  const targetW=w-pad*2,targetH=h-pad*2,{raw,insets,sourceSlices}=await resize9(src,rect,targetW,targetH,name==='board_frame'?.70:1);
  if(sameAlpha.has(name)){const ref=rendered[master];for(let i=0;i<targetW*targetH;i++)raw[i*4+3]=ref[i*4+3];}
  const canvas=Buffer.alloc(w*h*4);for(let y=0;y<targetH;y++)raw.copy(canvas,((y+pad)*w+pad)*4,y*targetW*4,(y+1)*targetW*4);
  const alpha=Buffer.alloc(w*h);let transparent=0;for(let i=0;i<w*h;i++){alpha[i]=canvas[i*4+3];if(!alpha[i]){transparent++;canvas.fill(0,i*4,i*4+3);}}
  const file=path.join(OUT,name+'_v2b.png');await sharp(canvas,{raw:{width:w,height:h,channels:4}}).withIccProfile('srgb').png().toFile(file);rendered[name]=raw;
  let opening=null;if(name==='board_frame'){let radius=0;outer:for(let r=1;r<w/2;r++){const lo=w/2-r,hi=w/2+r-1;for(let x=lo;x<=hi;x++)if(alpha[lo*w+x]>1||alpha[hi*w+x]>1||alpha[x*w+lo]>1||alpha[x*w+hi]>1)break outer;radius=r;}radius-=2;opening={left:w/2-radius,top:h/2-radius,width:radius*2,height:radius*2};}
  report.push({filename:name+'_v2b.png',file:'assets/art_v2b/'+name+'_v2b.png',name,purpose:state,width:w,height:h,family,state,production:true,source:'sources/'+name+'.png',sourceSize:[src.info.width,src.info.height],sourceHasAlpha:src.hasAlpha,mattePixelsRemoved:src.removed,detachedAlphaPixelsRemoved:src.dust,master,sourceCrop:rect,sourceSlices,contentRect:[pad,pad,targetW,targetH],resizeMode:'nine-region; uniformly scaled corners',ninePatchMargins:[pad+insets[0],pad+insets[1],pad+insets[2],pad+insets[3]],textSafeRect:name==='board_frame'||name==='button_selected_frame'?null:[pad+insets[0]+8,pad+insets[1]+8,targetW-2*insets[0]-16,targetH-2*insets[1]-16],boardGridSafeRect:opening,alphaBounds:box(alpha,w,h),alphaSha256:sha(alpha),transparentFraction:transparent/(w*h),sha256:sha(fs.readFileSync(file)),sourceSha256:sha(fs.readFileSync(src.file))});
 }
 for(const it of report)it.cornerScale=it.name==='board_frame'?.70:1;
 fs.writeFileSync(path.join(HERE,'export_report.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({exported:report.length,boardGridSafeRect:report[0].boardGridSafeRect,alphaSources:report.filter(i=>i.sourceHasAlpha).map(i=>i.name)},null,2));
}
main().catch(e=>{console.error(e);process.exit(1)});
