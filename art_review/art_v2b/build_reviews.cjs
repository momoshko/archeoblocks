// Review-only compositing of V2B art, existing V2A art and separate SVG text.
const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/AKNATE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const HERE=__dirname,REPO=path.resolve(HERE,'../..'),items=JSON.parse(fs.readFileSync(path.join(HERE,'export_report.json'))),by=Object.fromEntries(items.map(i=>[i.name,i]));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;');
function text(x,y,s,size=22,color='#ecdfc8',anchor='start',weight=400){return `<text x="${x}" y="${y}" font-family="Arial" font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}">${esc(s)}</text>`;}
function svg(w,h,body,bg){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${bg?`<rect width="${w}" height="${h}" fill="${bg}"/>`:''}${body}</svg>`);}
async function ui(name,w,h){
 const it=by[name],input=path.join(REPO,it.file),s=Math.min(w/it.width,h/it.height),[l,t,r,b]=it.ninePatchMargins;
 const xs=[0,l,it.width-r,it.width],ys=[0,t,it.height-b,it.height],xd=[0,Math.round(l*s),w-Math.round(r*s),w],yd=[0,Math.round(t*s),h-Math.round(b*s),h],layers=[];
 for(let y=0;y<3;y++)for(let x=0;x<3;x++)layers.push({input:await sharp(input).extract({left:xs[x],top:ys[y],width:xs[x+1]-xs[x],height:ys[y+1]-ys[y]}).resize(xd[x+1]-xd[x],yd[y+1]-yd[y],{fit:'fill'}).png().toBuffer(),left:xd[x],top:yd[y]});
 return sharp({create:{width:w,height:h,channels:4,background:'#00000000'}}).composite(layers).png().toBuffer();
}
async function add(layers,name,x,y,w,h){layers.push({input:await ui(name,w,h),left:x,top:y});}
async function save(name,w,h,layers,body,bg){layers.push({input:svg(w,h,body),left:0,top:0});await sharp(svg(w,h,'',bg)).composite(layers).png().toFile(path.join(HERE,name+'.png'));}
async function overview(){const W=1280,H=1240,layers=[];let body=text(32,42,'ARCHEOBLOCKS / ART V2B / UI FAMILY',30)+text(32,76,'16 blank production assets · generated sandstone family · text and icons remain separate',17,'#bbad94');
 for(let i=0;i<items.length;i++){const it=items[i],x=32+(i%4)*312,y=112+Math.floor(i/4)*274,s=Math.min(276/it.width,205/it.height),w=Math.round(it.width*s),h=Math.round(it.height*s);await add(layers,it.name,x+Math.round((276-w)/2),y+Math.round((205-h)/2),w,h);body+=text(x,y+233,it.name,16)+text(x,y+254,`${it.width} × ${it.height} · ${it.family}`,13,'#b8aa91');}
 await save('ui_family_overview',W,H,layers,body,'#302b24');}
async function readability(){const W=1200,H=1260,layers=[];let body=text(32,42,'MOBILE READABILITY / REAL PIXEL SIZES',28)+text(32,76,'Button bodies: 48 px and 64 px. Blank art above; separate labels below. View at 100%.',17,'#bbad94');
 const buttons=['button_primary','button_secondary','button_disabled'];
 for(let i=0;i<3;i++){const x=32+i*388;body+=text(x,112,buttons[i],18);await add(layers,buttons[i],x,128,256,64);await add(layers,buttons[i],x,212,340,85);body+=text(x+170,264,'Дальше',29,i===0?'#fff4da':i===1?'#392b1b':'#4d4942','middle',600);body+=text(x,324,'48 px blank / 64 px with separate label',14,'#c4b69c');}
 body+=text(32,373,'SELECTED / COMPACT / HEADER TEXT AREAS',19);
 await add(layers,'button_secondary',32,397,256,64);await add(layers,'button_selected_frame',32,397,256,64);body+=text(160,438,'Выбрано',22,'#392b1b','middle',600);
 await add(layers,'button_small_back',340,400,58,58);body+=text(369,439,'Ⅱ',27,'#392b1b','middle',600);
 await add(layers,'panel_label_small',440,397,192,64);body+=text(536,438,'Фигуры',22,'#392b1b','middle',600);
 await add(layers,'panel_header_small',688,397,448,64);body+=text(912,438,'Фрагменты: 0 / 3',22,'#392b1b','middle',600);
 const chapters=['chapter_card_open','chapter_card_locked','chapter_card_completed'];
 body+=text(32,512,'CHAPTER STATES / SAME GEOMETRY',19);
 for(let i=0;i<3;i++){const x=32+i*388;await add(layers,chapters[i],x,538,340,142);body+=text(x+170,609,['Экспедиция','Недоступно','Завершено'][i],24,'#392b1b','middle',600)+text(x,706,chapters[i],16);}
 body+=text(32,756,'SIBLING CARDS / EMPTY TEXT AND ART AREAS',19);
 await add(layers,'piece_slot',32,784,192,160);await add(layers,'collection_card_known',294,784,144,180);await add(layers,'collection_card_unknown',504,784,144,180);await add(layers,'popup_panel',740,776,186,248);await add(layers,'board_frame',958,784,200,200);
 body+=text(32,991,'piece_slot',16)+text(294,991,'known',16)+text(504,991,'unknown',16)+text(740,1051,'popup sample',16)+text(958,1015,'frame sample',16);
 await add(layers,'panel_header_large',32,1084,690,128);body+=text(377,1139,'Заросшие катакомбы 5',26,'#392b1b','middle',600)+text(377,1174,'Заросший проход',23,'#392b1b','middle');
 body+=text(756,1130,'Frame and popup shown as overview.',16)+text(756,1157,'Full gameplay scale: 720 × 1280 mockup.',16)+text(756,1184,'All production art remains blank.',16);
 await save('readability_48px',W,H,layers,body,'#302b24');await sharp(path.join(HERE,'readability_48px.png')).grayscale().png().toFile(path.join(HERE,'grayscale_readability.png'));
}
const v2a=JSON.parse(fs.readFileSync(path.join(REPO,'art_review/art_v2a/manifest.json'))).entries.filter(i=>i.production),v2aBy=Object.fromEntries(v2a.map(i=>[i.name,i]));
async function block(color,size){return sharp(path.join(REPO,v2aBy['block_'+color].file)).extract({left:8,top:8,width:240,height:240}).resize(size,size).png().toBuffer();}
async function gameplay(){const layers=[],W=720,H=1280;let body='';
 await add(layers,'button_small_back',24,48,88,88);body+=text(68,105,'Ⅱ',34,'#392b1b','middle',600);
 await add(layers,'panel_header_large',124,24,572,164);body+=text(410,76,'Заросшие катакомбы 5',28,'#392b1b','middle',600)+text(410,114,'Заросший проход',26,'#392b1b','middle',600)+text(655,150,'Фрагменты: 0 / 3',22,'#51402b','end');
 await add(layers,'panel_header_small',74,188,572,64);body+=text(360,230,'Откройте три части амулета',24,'#392b1b','middle',600);
 body+=text(360,277,'Иногда безопаснее перекрыть предупреждённую клетку,',18,'#efe0c6','middle')+text(360,300,'чем сразу рубить корень.',18,'#efe0c6','middle');
 const frame={x:24,y:310,w:672,h:672},safe=by.board_frame.boardGridSafeRect,s=frame.w/1024,boardSize=Math.floor(safe.width*s/8)*8,boardX=Math.round(frame.x+frame.w/2-boardSize/2),boardY=Math.round(frame.y+frame.h/2-boardSize/2);
 // Quiet well under the transparent opening; pre-existing V2A stress fixture on top.
 layers.push({input:svg(frame.w,frame.h,`<rect x="70" y="70" width="532" height="532" rx="16" fill="#2b241c"/>`),left:frame.x,top:frame.y});
 layers.push({input:await sharp(path.join(REPO,'art_review/art_v2a/stress_test_board_8x8.png')).resize(boardSize,boardSize).png().toBuffer(),left:boardX,top:boardY});await add(layers,'board_frame',frame.x,frame.y,frame.w,frame.h);
 await add(layers,'panel_label_small',264,972,192,48);body+=text(360,1004,'Фигуры',22,'#392b1b','middle',600);
 const slots=[{x:24,color:'red',label:'Квадрат 2×2',shape:[[0,0],[1,0],[0,1],[1,1]]},{x:248,color:'green',label:'Линия 3',shape:[[0,0],[0,1],[0,2]]},{x:472,color:'amber',label:'Большая Г',shape:[[0,0],[0,1],[0,2],[1,2]]}];
 for(const it of slots){await add(layers,'piece_slot',it.x,1022,224,142);body+=text(it.x+112,1061,it.label,20,'#392b1b','middle',600);const size=23,cols=Math.max(...it.shape.map(p=>p[0]))+1,start=it.x+112-cols*size/2;for(const [x,y]of it.shape)layers.push({input:await block(it.color,size),left:Math.round(start+x*size),top:1076+y*size});}
 await add(layers,'button_secondary',28,1170,320,80);await add(layers,'button_secondary',372,1170,320,80);body+=text(188,1220,'Отменить · 1',26,'#392b1b','middle',600)+text(532,1220,'Подсказка',26,'#392b1b','middle',600);
 body+=text(46,1270,'Ходы: 9',21,'#efe0c6')+text(674,1270,'Счёт: 290',21,'#efe0c6','end');
 await save('gameplay_mockup_ui_only',W,H,layers,body,'#665642');return{canvas:[W,H],frame,board:{x:boardX,y:boardY,width:boardSize,height:boardSize,cellPitch:boardSize/8},source:'art_review/art_v2a/stress_test_board_8x8.png',note:'Review-only fixture; separate text. V1 information order and controls retained, lighter supporting info and counters.'};}
async function menu(){const layers=[],W=720,H=1280;let body='';await add(layers,'popup_panel',32,32,656,1216);
 // V2A target motif reused as a review-only discovery emblem; not a new production logo.
 const marker=path.join(REPO,v2aBy.artifact_target_marker.file);layers.push({input:await sharp(marker).extract({left:64,top:64,width:128,height:128}).resize(112,112).png().toBuffer(),left:304,top:146});
 body+=text(360,356,'Археоблоки',55,'#392b1b','middle',600)+text(360,416,'Раскапывай находки,',28,'#51402b','middle')+text(360,452,'собирая линии',28,'#51402b','middle');
 const actions=[['button_primary','Играть'],['button_secondary','Экспедиции'],['button_secondary','Коллекция'],['button_secondary','Настройки']];
 for(let i=0;i<4;i++){const y=520+i*150;await add(layers,actions[i][0],92,y,536,128);body+=text(360,y+80,actions[i][1],37,i===0?'#fff4da':'#392b1b','middle',600);}
 await save('menu_mockup_ui_only',W,H,layers,body,'#665642');return{canvas:[W,H],actions:actions.map(a=>a[1]),backdrop:'plain review color, no generated screen background',emblem:'Existing V2A target center crop; review motif only, not final logo',text:'Composited separately; not baked into production assets'};}
async function main(){await overview();await readability();const gameplayLayout=await gameplay(),menuLayout=await menu();fs.writeFileSync(path.join(HERE,'review_layout.json'),JSON.stringify({gameplay:gameplayLayout,menu:menuLayout},null,2)+'\n');console.log('Created all5 required review images. Board pitch: '+gameplayLayout.board.cellPitch+' px.');}
main().catch(e=>{console.error(e);process.exit(1)});
