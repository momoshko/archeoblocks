// Deterministic assembly of supplied production sprites; no new material drawing.
const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const ROOT=__dirname,REPO=path.resolve(ROOT,'../..');
const items=JSON.parse(fs.readFileSync(path.join(ROOT,'export_report.json')));
const byName=Object.fromEntries(items.map(x=>[x.name,x]));
const PAPER='#e6dbc8',DARK='#302820',INK='#302a23';
const labels={cell_excavated_depth0:'Depth 0',cell_soil_depth1:'Depth 1',cell_soil_depth2:'Depth 2',block_green:'Green',block_blue:'Blue',block_red:'Red',block_amber:'Amber',block_purple:'Purple',block_turquoise:'Turquoise',stone_intact:'Stone intact',stone_cracked:'Stone cracked',root_obstacle:'Root',root_growth_warning:'Root warning',artifact_target_marker:'Artifact target',preview_valid:'Valid',preview_invalid:'Invalid'};
function text(x,y,s,size=16,fill='#e8d7b3'){return `<text x="${x}" y="${y}" fill="${fill}" font-family="Arial" font-size="${size}">${s}</text>`}
function rect(x,y,w,h,fill){return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"/>`}
function svg(w,h,body,bg='#211e19'){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${rect(0,0,w,h,bg)}${body}</svg>`)}
async function imageFor(name,size=48,ghost=false){
 let pipe=sharp(path.join(REPO,byName[name].file)).extract({left:8,top:8,width:240,height:240}).resize(size,size,{kernel:'lanczos3'});
 if(!ghost)return pipe.png().toBuffer();
 const {data,info}=await pipe.ensureAlpha().raw().toBuffer({resolveWithObject:true});
 // Single reusable treatment, not new production sprites. Compress contrast
 // around the block's mean RGB, then set 0.52 of original alpha.
 const sums=[0,0,0];let count=0;
 for(let k=0;k<data.length;k+=4)if(data[k+3]>200){for(let c=0;c<3;c++)sums[c]+=data[k+c];count++;}
 const mean=sums.map(s=>s/Math.max(1,count));
 for(let k=0;k<data.length;k+=4){for(let c=0;c<3;c++)data[k+c]=Math.round(mean[c]+(data[k+c]-mean[c])*.72);data[k+3]=Math.round(data[k+3]*.52)}
 return sharp(data,{raw:info}).png().toBuffer();
}
async function cell(layers,size=48,bg=DARK){
 const inputs=[];for(const layer of layers){const [name,ghost]=Array.isArray(layer)?layer:[layer,false];inputs.push({input:await imageFor(name,size,ghost),left:0,top:0});}
 return sharp({create:{width:size,height:size,channels:4,background:bg}}).composite(inputs).png().toBuffer();
}
async function materialSheet(){
 const groups=[['TERRAIN',items.filter(x=>x.category==='cells')],['MINERAL BLOCKS',items.filter(x=>x.category==='blocks')],['OBSTACLES / WARNING',items.filter(x=>x.category==='obstacles')],['TARGET / PLACEMENT',items.filter(x=>x.category==='overlays')]];
 let body=text(32,40,'ARCHEOBLOCKS / CORE GAMEPLAY MATERIALS / ART V2A',25)+text(32,68,'Selected production sprites. Upper-left light. No text baked into assets.',16);const layers=[];
 groups.forEach(([title,list],row)=>{const y=102+row*212;body+=text(32,y+18,title,17,'#bfcaab');list.forEach((it,i)=>{const x=32+i*171;body+=rect(x,y+32,150,144,row===3?PAPER:'#383126')+text(x,y+197,labels[it.name],15);layers.push({name:it.name,x:x+11,y:y+40});});});
 const overlays=[];for(const l of layers)overlays.push({input:await imageFor(l.name,128),left:l.x,top:l.y});
 await sharp(svg(1090,980,body)).composite(overlays).png().toFile(path.join(ROOT,'gameplay_material_sheet.png'));
}
async function smallSheet(){
 let body=text(24,35,'48 PX / EXACT DISPLAY SIZE',24)+text(24,60,'Each pair: light neutral / dark board. Shared cell region, no per-item fit.',16);const layers=[];
 for(let i=0;i<items.length;i++){
  const it=items[i],x=24+(i%8)*124,y=90+Math.floor(i/8)*122;
  body+=text(x,y,`${String(i+1).padStart(2,'0')} ${labels[it.name]}`,12)+rect(x,y+12,56,60,PAPER)+rect(x+58,y+12,56,60,DARK);
  const sample=await imageFor(it.name,48);layers.push({input:sample,left:x+4,top:y+18},{input:sample,left:x+62,top:y+18});
 }
 body+=text(24,355,'MARKER ON EVERY UNDERLAY / same 48 px',18);
 const underlays=['cell_excavated_depth0','cell_soil_depth1','cell_soil_depth2',...['green','blue','red','amber','purple','turquoise'].map(x=>'block_'+x),'stone_intact','stone_cracked','root_obstacle'];
 for(let i=0;i<underlays.length;i++){
  const name=underlays[i],x=24+i*80;body+=text(x,381,String(i+1).padStart(2,'0'),12);
  const stack=name.startsWith('cell')?[name]:['cell_excavated_depth0',name];
  layers.push({input:await cell([...stack,'artifact_target_marker']),left:x,top:391});
  body+=text(x,458,labels[name].replace('Stone ','S.').replace('Turquoise','Turq.'),10);
 }
 body+=text(24,506,'REAL / HINT 0.52 / VALID / INVALID',18)+text(490,506,'WARNING ABOVE HINT + MARKER',18);
 const states=[['block_green'],[['block_green',true]],['preview_valid'],['preview_invalid']];
 for(let depth=0;depth<3;depth++){
  const terrain=['cell_excavated_depth0','cell_soil_depth1','cell_soil_depth2'][depth];
  body+=text(24,545+depth*62,'D'+depth,12);
  for(let col=0;col<4;col++)layers.push({input:await cell([terrain,...states[col]]),left:66+col*83,top:520+depth*62});
  layers.push({input:await cell([terrain,['block_green',true],'artifact_target_marker','root_growth_warning']),left:504+depth*80,top:532});
 }
 body+=text(24,744,'48 px is the test size. Larger material sheet is for art review only.',15)+text(24,770,'Gold: target. Olive corner warning: urgent destination. Check / X: temporary placement.',15);
 const file=path.join(ROOT,'readability_48px.png');await sharp(svg(1040,800,body)).composite(layers).png().toFile(file);
 await sharp(file).grayscale().png().toFile(path.join(ROOT,'grayscale_readability_48px.png'));
}
const terrainRows=['11122211','11002211','10002221','00111221','00112220','11122200','21210002','21110012'];
const blockGroups={blue:[[0,0],[1,0],[2,0]],green:[[5,1],[6,1],[7,1],[6,2]],red:[[0,3],[1,3],[0,4],[1,4]],amber:[[3,3],[3,4],[3,5],[4,5]],purple:[[5,6],[6,6],[7,6]],turquoise:[[1,7],[2,7]]};
const obstacles={stone_intact:[[5,0],[5,5]],stone_cracked:[[2,5],[7,4]],root_obstacle:[[0,6],[7,3],[6,3],[5,2]]};
const markers=[[4,0],[1,3],[5,0],[0,6],[4,2]];
const hintCells=[[4,1],[4,2],[4,3]]; // Green line3, legal and empty.
const validCells=[[1,1],[2,1],[1,2],[2,2]]; // Separate valid square footprint.
const invalidCells=[[6,2],[7,2],[6,3],[7,3]]; // Conflicts with a placed block and two roots.
const warning=[4,2]; // Free destination adjacent to root at [5,2].
function has(list,x,y){return list.some(p=>p[0]===x&&p[1]===y)}
async function board(mode){const overlays=[];for(let y=0;y<8;y++)for(let x=0;x<8;x++){
 const depth=Number(terrainRows[y][x]),stack=[['cell_excavated_depth0','cell_soil_depth1','cell_soil_depth2'][depth]];
 for(const [name,list] of Object.entries(obstacles))if(has(list,x,y))stack.push(name);
 for(const [color,list] of Object.entries(blockGroups))if(has(list,x,y))stack.push('block_'+color);
 if(mode==='hint'&&has(hintCells,x,y))stack.push(['block_green',true]);
 if(mode==='hint'&&has(validCells,x,y))stack.push('preview_valid');
 if(mode==='invalid'&&has(invalidCells,x,y))stack.push('preview_invalid');
 if(has(markers,x,y))stack.push('artifact_target_marker');
 if(warning[0]===x&&warning[1]===y)stack.push('root_growth_warning');
 overlays.push({input:await cell(stack,47),left:x*48,top:y*48});
 }
 const file={base:'stress_test_board_8x8.png',hint:'stress_test_hint_valid.png',invalid:'stress_test_invalid.png'}[mode];
 await sharp({create:{width:384,height:384,channels:4,background:'#241f19'}}).composite(overlays).png().toFile(path.join(ROOT,file));
}
async function main(){
 if(items.length!==16)throw Error('Need all 16 exported sprites before reviews');
 const blocked=[...Object.values(blockGroups).flat(),...Object.values(obstacles).flat()].map(p=>p.join(','));if(new Set(blocked).size!==blocked.length)throw Error('Obstacle/block overlap');
 for(const p of [...hintCells,...validCells])if(blocked.includes(p.join(',')))throw Error('Hint/valid collision');
 if(!invalidCells.some(p=>blocked.includes(p.join(','))))throw Error('Invalid must conflict');
 fs.writeFileSync(path.join(ROOT,'review_board_state.json'),JSON.stringify({fixture:'Art stress fixture, not a saved campaign session. Hint and valid footprints shown on separate cells for comparison.',terrainRows,blockGroups,obstacles,markers,hintCells,validCells,invalidCells,warning,layerOrder:['terrain','buried clue (unused)','obstacle','block','hint OR placement','artifact marker','root warning']},null,2)+'\n');
 await materialSheet();await smallSheet();for(const mode of ['base','hint','invalid'])await board(mode);
 console.log('Six required review images created; 48px samples and 384px boards.');
}
main().catch(e=>{console.error(e);process.exit(1)});
