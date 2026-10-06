"""Offline deliverable checks; reads images, never edits artwork."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent
state = json.loads((root / 'gameplay_state.json').read_text(encoding='utf-8'))
cells = {(c['x'], c['y']): c for c in state['cells']}
assert set(cells) == {(x, y) for x in range(8) for y in range(8)}
assert (state['moves'], state['score'], state['fragments'], state['fragment_total']) == (9, 290, 0, 3)
assert len(state['history']) == 9
assert all(not c['block'] or c['obstacle'] == -1 for c in cells.values())
assert all(cells[tuple(p)]['obstacle'] == -1 and not cells[tuple(p)]['block'] for p in state['hint_cells'])
assert state['hint_cells'] == [[5,6],[6,6],[5,7],[6,7]]
assert [len(p['cells']) for p in state['tray']] == [4,3,5]
assert len([c for c in cells.values() if c['artifact']]) == 3
assert len([c for c in cells.values() if c['obstacle'] == 1]) == 6
assert len([c for c in cells.values() if c['obstacle'] == 0 and c['durability'] == 2]) == 4
assert cells[(1,1)]['soil'] == 1 and cells[(1,1)]['obstacle'] == 0

images = {}
for name in ['master_menu.png','master_gameplay.png','baseline_menu.png','baseline_gameplay.png','baseline_gameplay_hint.png']:
    path = root / name
    with Image.open(path) as im:
        assert abs(im.width / im.height - 9 / 16) < 0.001
        images[name] = {'width': im.width, 'height': im.height, 'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

html = (root / 'index.html').read_text(encoding='utf-8')
links = re.findall(r'(?:src|href)="([^"]+)"', html)
assert all((root / link).is_file() for link in links)

def luminance(hex_color):
    rgb = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    return sum(v*w for v,w in zip(rgb,[.2126,.7152,.0722]))

def contrast(a,b):
    values = sorted([luminance(a),luminance(b)])
    return round((values[1]+.05)/(values[0]+.05),2)

result = {
    'status': 'passed_with_documented_art_risks',
    'images': images,
    'state_checks': '64 unique cells; nine real placements; 290 score; three targets; legal four-cell hint; obstacle/block exclusivity; tray 4/3/5; six roots; four reinforced stones',
    'local_html_links_checked': len(links),
    'target_token_contrast': {'umber_on_parchment': contrast('332A21','E8D7B3'), 'ivory_on_jade': contrast('F1E5CD','346A53')},
    'visual_review': {'native_master': 'manually inspected all 64 cells against runtime screenshot and JSON', 'browser_360px_color': 'inspected; board and controls distinct, secondary text small', 'browser_360px_grayscale': 'inspected; marker ring and hint dash remain distinct', 'mobile_device_runtime_new_art': 'not integrated or tested'},
    'limits': ['Slot unit sizes in raster reference are not uniform; production must use shared unit scale.', 'Depth 1 is occluded by a stone in this real state.', 'New artwork is a reference only, not a pixel-perfect production contract.', 'Runtime capture logs a root certificate store warning; capture completed successfully.'],
    'generation_calls': 3,
    'godot_core_changes': False,
}
(root / 'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
