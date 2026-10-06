// Targeted offline ART V2A checks. Does not launch Godot or edit game resources.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert');
const sharp=require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const HERE=__dirname,REPO=path.resolve(HERE,'../..');
const provenance='Generated with the available built-in ImageGen; exact underlying image model/quality tier was not exposed by the tool.';
const read=n=>JSON.parse(fs.readFileSync(path.join(HERE,n)));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const write=(n,v)=>fs.writeFileSync(path.join(HERE,n),JSON.stringify(v,null,2)+'\n');
const checks=[];function check(name,ok,evidence){checks.push({name,pass:!!ok,evidence});assert(ok,name);}
const reviews={gameplay_material_sheet:[1090,980],readability_48px:[1040,800],grayscale_readability_48px:[1040,800],stress_test_board_8x8:[384,384],stress_test_hint_valid:[384,384],stress_test_invalid:[384,384]};
async function main(){
 const items=read('export_report.json'),prompts=read('prompts.json'),entries=[],metrics={};
 const actual=fs.readdirSync(path.join(REPO,'assets/art_v2a'),{recursive:true}).filter(n=>n.endsWith('.png'));
 check('exactly_16_production_pngs',items.length===16&&actual.length===16,actual.length);
 for(const it of items){
  const file=path.join(REPO,it.file),bytes=fs.readFileSync(file),meta=await sharp(bytes).metadata();
  const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  check(it.name+'_format',meta.width===256&&meta.height===256&&meta.channels===4&&meta.hasAlpha&&meta.depth==='uchar'&&meta.space==='srgb'&&!!meta.icc,{size:[meta.width,meta.height],channels:meta.channels,depth:meta.depth,space:meta.space,icc:!!meta.icc});
  let padding=true,alphaSum=0,centerAlpha=0,transparent=0;const alpha=Buffer.alloc(256*256);
  for(let y=0;y<256;y++)for(let x=0;x<256;x++){const i=y*256+x,a=data[i*4+3];alpha[i]=a;alphaSum+=a;if(a===0)transparent++;if((x<8||y<8||x>=248||y>=248)&&a)padding=false;if(x>=80&&x<176&&y>=80&&y<176)centerAlpha+=a;}
  check(it.name+'_alpha',padding&&alphaSum>0&&sha(alpha)===it.alphaSha256,{padding8Transparent:padding,alphaSha256:sha(alpha),transparentFraction:transparent/65536});
  if(it.name.startsWith('preview_')||it.name==='root_growth_warning')check(it.name+'_empty_center',centerAlpha===0,{centerRect:[80,80,96,96],alphaSum:centerAlpha});
  const gray=await sharp(file).extract({left:64,top:64,width:128,height:128}).grayscale().removeAlpha().raw().toBuffer();
  metrics[it.name]={grayMean:Number((gray.reduce((a,b)=>a+b,0)/gray.length).toFixed(2)),alphaArea:alphaSum/255};
  entries.push({...it,size:[256,256],role:it.label,review:false,sha256:sha(bytes),usage:it.category==='cells'?'Base cell material':it.category==='blocks'?'Placed block; same file reused for hint':it.name==='root_growth_warning'?'Threatened destination signal; top layer':it.category==='overlays'?'Transparent board signal':'Obstacle above terrain',notes:it.colorNormalization,sourceSha256:sha(fs.readFileSync(path.join(HERE,it.source)))});
 }
 for(const category of ['cells','blocks'])check(category+'_shared_alpha',new Set(items.filter(i=>i.category===category).map(i=>i.alphaSha256)).size===1,'Exact byte-identical alpha planes within family');
 for(const category of ['cells','blocks'])check(category+'_shared_transform',new Set(items.filter(i=>i.category===category).map(i=>JSON.stringify(i.sourceCrop))).size===1,'Same source crop and output transform');
 check('preview_shared_transform',JSON.stringify(items.find(i=>i.name==='preview_valid').sourceCrop)===JSON.stringify(items.find(i=>i.name==='preview_invalid').sourceCrop),'Both use preview_valid_master source rect');
 const grayOrder=Object.entries(metrics).filter(([n])=>n.startsWith('block_')).sort((a,b)=>a[1].grayMean-b[1].grayMean);
 const grayGaps=grayOrder.slice(1).map((v,i)=>Number((v[1].grayMean-grayOrder[i][1].grayMean).toFixed(2)));
 check('block_grayscale_value_separation',Math.min(...grayGaps)>=10,{method:'Sharp grayscale, central128x128, 8-bit mean; supporting metric, not a perception guarantee',ordered:grayOrder.map(([name,v])=>({name,value:v.grayMean})),adjacentGaps:grayGaps});
 check('warning_signal_area',metrics.root_growth_warning.alphaArea>metrics.artifact_target_marker.alphaArea*2,{warning:metrics.root_growth_warning.alphaArea,marker:metrics.artifact_target_marker.alphaArea,note:'Area supports visual review; prominence also depends on underlay.'});
 for(const [name,size] of Object.entries(reviews)){const file=path.join(HERE,name+'.png'),bytes=fs.readFileSync(file),m=await sharp(bytes).metadata();check(name+'_size',m.width===size[0]&&m.height===size[1],size);entries.push({file:'art_review/art_v2a/'+name+'.png',category:'review',role:name,size,production:false,review:true,sha256:sha(bytes),usage:name.includes('48px')?'Native48px matrix; view at 100%':name.startsWith('stress')?'8x8 board at48px pitch,47px content +1px separator':'Grouped128px art overview'});}
 const grayRGB=await sharp(path.join(HERE,'grayscale_readability_48px.png')).removeAlpha().toColourspace('srgb').raw().toBuffer();let neutral=true;for(let i=0;i<grayRGB.length;i+=3)if(grayRGB[i]!==grayRGB[i+1]||grayRGB[i]!==grayRGB[i+2]){neutral=false;break;}check('grayscale_has_no_chroma',neutral,'All RGB triples equal');
 const b=read('review_board_state.json'),key=p=>p.join(','),blocks=Object.values(b.blockGroups).flat().map(key),obs=Object.values(b.obstacles).flat().map(key),occupied=[...blocks,...obs];
 check('board_no_block_obstacle_overlap',new Set(occupied).size===occupied.length,occupied.length);
 check('hint_and_valid_legal',[...b.hintCells,...b.validCells].every(p=>!occupied.includes(key(p))),'All demonstration cells free');
 check('invalid_conflicts_with_block_and_obstacle',b.invalidCells.some(p=>blocks.includes(key(p)))&&b.invalidCells.some(p=>obs.includes(key(p))),b.invalidCells);
 check('warning_free_and_root_adjacent',!occupied.includes(key(b.warning))&&b.obstacles.root_obstacle.some(p=>Math.abs(p[0]-b.warning[0])+Math.abs(p[1]-b.warning[1])===1),b.warning);
 check('generation_lineage',prompts.generations.length===17&&items.every(i=>prompts.generations.some(g=>g.name===i.name)),{successfulSourceCount:17,productionCount:16,intermediate:'preview_valid_master'});
 check('integration_guard',fs.existsSync(path.join(REPO,'assets/art_v2a/.gdignore'))&&fs.existsSync(path.join(HERE,'.gdignore')),'Both asset and review directories excluded from Godot import');
 const visual=[
  ['terrain','PASS','Shared warm earth family: dark recessed depth0, light regular depth1, denser cracked depth2; quiet repeated surface.'],
  ['blocks','PASS','Consistent mineral bevel, upper-left light and lower-right shadow; strongest material accents. Value separation checked in actual grayscale conversion.'],
  ['stone','PASS','Matte chipped rubble; damaged version has major Y fractures visible at48px; no metallic crate cues or durability UI.'],
  ['roots','PASS','Open branching silhouette with transparent gaps; warning is a four-corner olive root signal rather than a token.'],
  ['marker','PASS','Gold ring with keyed edge remains readable on all12 tested underlays:3 terrain,6 blocks,2 stones,1 root.'],
  ['warning','PASS','Larger corner silhouette remains visible above hint and marker on all3 terrains; visually stronger temporary signal.'],
  ['placement','PASS','Thin contours and check/X retain underlying terrain, block and roots. No opaque backing or terrain replacement.'],
  ['hint','PASS','Real block art at0.52 alpha with0.72 contrast factor is visibly flatter and translucent; marker and warning remain visible.'],
  ['stress_boards','PASS','All6 colors, mixed depths and obstacles read at48px pitch; invalid example conflicts with placed block and roots.']
 ].map(([gate,status,evidence])=>({gate,status,evidence}));
 const limitations=['Static agent visual review at48px and grayscale; not a player study or a complete color-vision accessibility certification.','Runtime filtering, scaling, animation and compression were not tested because integration is outside ART V2A.','Source images contained a painted neutral checkerboard; true alpha was extracted and normalized during export. Retain sources and scripts for audit.','Depth0 and depth2 also depend on recessed-edge versus broad-crack form, not brightness alone.','Hint and valid footprints coexist only in the comparative fixture on separate cells. Runtime chooses hint OR placement.'];
 write('manifest.json',{schemaVersion:1,milestone:'ART V2A',status:'accepted_offline_art_review',provenance,pathBase:'repository root',style:'ART V1 Light Sandstone Courtyard',geometry:{canvas:[256,256],pivot:[128,128],terrainRect:[8,8,240,240],blockRect:[18,18,220,220],reviewSourceRect:[8,8,240,240],reviewCellPx:48,boardSpritePx:47,boardSeparatorPx:1,light:'upper-left'},hint:{reuse:'real block texture',alpha:.52,contrast:.72,formula:'RGB = meanRGB + (RGB - meanRGB)*0.72; alpha = originalAlpha*0.52',mean:'Per-channel mean over alpha>200 pixels after sampling'},layerOrder:b.layerOrder,entries});
 write('verification.json',{milestone:'ART V2A',status:'PASS_OFFLINE_ART_ACCEPTANCE',provenance,automated:{passed:checks.length,total:checks.length,checks},visualReview:{reviewer:'Codex agent',method:'Direct inspection of all6 generated review images, including native48px and grayscale matrices',gates:visual},metrics,limitations,integration:{godotRun:false,gameplayOrScenesEdited:false,trackedPreexistingEdits:['AGENTS.md','EDITOR_GUIDE_RU.md','YANDEX_RELEASE_CHECKLIST.md'],scope:'Only assets/art_v2a and art_review/art_v2a created or edited'}});
 prompts.status='final_exports_verified';prompts.provenance=provenance;
 for(const g of prompts.generations){g.status='succeeded';g.selectedForProduction=g.name!=='preview_valid_master';g.tool='available built-in ImageGen';}
 prompts.postprocessing={script:'export_pack.cjs',sourceAlpha:'All17 stored source PNGs are RGB with a neutral generated checkerboard; alpha repaired at export.',steps:['Remove edge-connected neutral matte; remove neutral internal gaps for roots and overlays; one source-pixel contraction','Shared family source crops; Lanczos3 downsample; shared terrain cutline and exact green-master alpha for all6 blocks','sRGB RGBA8 PNG,256x256, transparent padding'],paletteNormalization:items.filter(i=>i.colorNormalization!=='none').map(i=>({name:i.name,operation:i.colorNormalization})),failedOptionalRefinements:{count:2,targets:['block_purple','root_growth_warning'],result:'usage_limit_reached; no images produced or selected',resolution:'Numeric palette normalization of existing generated sources; no alternate generator used'}};
 write('prompts.json',prompts);
 console.log(JSON.stringify({status:'PASS',checks:checks.length,grayscale:grayOrder.map(([name,v])=>({name,value:v.grayMean})),minGrayGap:Math.min(...grayGaps)},null,2));
}
main().catch(e=>{console.error(e);process.exit(1)});
