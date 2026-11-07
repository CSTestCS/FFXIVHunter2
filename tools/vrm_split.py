"""Split the provided VRoid VRM files into reusable game parts.

Outputs (game/assets/characters/):
  base_<race>_<sex>.gltf   full body + face + smallclothes (body skin is never culled)
  hairback_default.gltf    default VRoid scalp hair layer
  hair_<n>.gltf            hairstyles isolated from the hairstyle samples (sample body removed)
  ears_miqote.gltf / tail_miqote.gltf   Miqo'te accessories, separated so other races can omit them
  <race>_<sex>_<item>.gltf clothing items isolated from the clothing samples (sample body removed)
  textures/*.png           shared, de-duplicated, downscaled textures

Every part is rebound to the standard VRoid humanoid bones (J_Bip_*, bust, eye),
so any part can be worn by any base skeleton. MToon toon materials are replaced
with physically based materials for realistic lighting.

Usage: python3 -I vrm_split.py <dir with .vrm files> <output dir>
"""
import hashlib, io, json, os, struct, sys
import numpy as np
from PIL import Image

MAX_TEX = 1024
KEEP_MORPHS = ['Fcl_ALL_Neutral', 'Fcl_ALL_Angry', 'Fcl_ALL_Joy', 'Fcl_ALL_Sorrow', 'Fcl_ALL_Surprised',
               'Fcl_EYE_Close', 'Fcl_MTH_A', 'Fcl_MTH_O']
COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load_glb(path):
    data = open(path, 'rb').read()
    off, js, binc = 12, None, None
    while off < len(data):
        clen, ctype = struct.unpack_from('<II', data, off); off += 8
        chunk = data[off:off + clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk)
        elif ctype == 0x004E4942: binc = chunk
    return js, binc


def read_acc(j, b, idx):
    a = j['accessors'][idx]
    bv = j['bufferViews'][a['bufferView']]
    dt = COMP[a['componentType']]; n = NCOMP[a['type']]
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0)
    isz = np.dtype(dt).itemsize * n
    if stride and stride != isz:
        raw = np.frombuffer(b, np.uint8, a['count'] * stride, start).reshape(a['count'], stride)[:, :isz]
        arr = np.frombuffer(raw.tobytes(), dt).reshape(a['count'], n)
    else:
        arr = np.frombuffer(b, dt, a['count'] * n, start).reshape(a['count'], n)
    if a.get('normalized') and dt != np.float32:
        arr = arr.astype(np.float32) / np.iinfo(dt).max
    return arr.copy()


def allowed_bone(name):
    return name == 'Root' or name.startswith('J_Bip_') or 'Bust' in name and not name.endswith('_end') or name.startswith('J_Adj_')


class Writer:
    """Accumulates a new glTF with external .bin and shared textures."""

    def __init__(self, tex_dir, tex_registry):
        self.g = {'asset': {'version': '2.0', 'generator': 'ffxivhunter vrm_split'}, 'scene': 0, 'scenes': [{'nodes': []}],
                  'nodes': [], 'meshes': [], 'skins': [], 'materials': [], 'textures': [], 'images': [],
                  'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}],
                  'accessors': [], 'bufferViews': [], 'buffers': []}
        self.bin = bytearray()
        self.tex_dir, self.reg = tex_dir, tex_registry
        self.img_map = {}

    def add_acc(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr.astype(COMP[ctype]))
        while len(self.bin) % 4: self.bin.append(0)
        bv = {'buffer': 0, 'byteOffset': len(self.bin), 'byteLength': arr.nbytes}
        if target: bv['target'] = target
        self.bin += arr.tobytes()
        self.g['bufferViews'].append(bv)
        acc = {'bufferView': len(self.g['bufferViews']) - 1, 'componentType': ctype,
               'count': int(arr.shape[0]), 'type': atype}
        if minmax:
            acc['min'] = arr.min(axis=0).tolist(); acc['max'] = arr.max(axis=0).tolist()
        self.g['accessors'].append(acc)
        return len(self.g['accessors']) - 1

    def add_image(self, src_j, src_b, img_idx, kind):
        key = (id(src_j), img_idx, kind)
        if key in self.img_map: return self.img_map[key]
        im = src_j['images'][img_idx]
        bv = src_j['bufferViews'][im['bufferView']]
        raw = src_b[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
        img = Image.open(io.BytesIO(raw))
        img.load()
        if kind == 'tint':
            # Hair / iris: store as neutral luminance so the creator's colour picker drives the hue.
            rgba = img.convert('RGBA'); a = rgba.getchannel('A')
            lum = np.asarray(rgba.convert('L'), np.float32)
            lum = np.clip(lum / max(np.percentile(lum[np.asarray(a) > 8], 90) if (np.asarray(a) > 8).any() else 255, 1) * 235, 0, 255)
            img = Image.merge('RGBA', [Image.fromarray(lum.astype(np.uint8))] * 3 + [a])
        if max(img.size) > MAX_TEX:
            s = MAX_TEX / max(img.size)
            img = img.resize((max(4, int(img.size[0] * s)), max(4, int(img.size[1] * s))), Image.LANCZOS)
        if img.mode not in ('RGB', 'RGBA'): img = img.convert('RGBA')
        if img.mode == 'RGBA' and np.asarray(img.getchannel('A')).min() == 255: img = img.convert('RGB')
        buf = io.BytesIO(); img.save(buf, 'PNG', optimize=True)
        h = hashlib.sha1(buf.getvalue()).hexdigest()[:12]
        fname = f'{kind}_{h}.png'
        if h not in self.reg:
            open(os.path.join(self.tex_dir, fname), 'wb').write(buf.getvalue()); self.reg[h] = fname
        self.g['images'].append({'uri': 'textures/' + fname})
        self.g['textures'].append({'sampler': 0, 'source': len(self.g['images']) - 1})
        self.img_map[key] = len(self.g['textures']) - 1
        return self.img_map[key]

    def add_material(self, src_j, src_b, mat_idx):
        m = src_j['materials'][mat_idx]
        name = m['name'].replace(' (Instance)', '')
        kind = 'tint' if ('_HAIR' in name or 'EyeIris' in name) else 'col'
        pbr = m.get('pbrMetallicRoughness', {})
        out = {'name': name, 'pbrMetallicRoughness': {'baseColorFactor': pbr.get('baseColorFactor', [1, 1, 1, 1]),
                                                     'metallicFactor': 0.0}}
        if 'baseColorTexture' in pbr:
            out['pbrMetallicRoughness']['baseColorTexture'] = {
                'index': self.add_image(src_j, src_b, src_j['textures'][pbr['baseColorTexture']['index']]['source'], kind)}
        nt = m.get('normalTexture')
        if nt is not None:
            nimg = src_j['images'][src_j['textures'][nt['index']]['source']]
            if 'NoneNormal' not in (nimg.get('name') or ''):
                out['normalTexture'] = {'index': self.add_image(src_j, src_b, src_j['textures'][nt['index']]['source'], 'nrm')}
        # Physically based roughness per surface type.
        rough = 0.85
        if '_SKIN' in name: rough = 0.58
        elif '_HAIR' in name: rough = 0.42
        elif '_EYE' in name: rough = 0.12
        elif 'FACE' in name: rough = 0.6
        out['pbrMetallicRoughness']['roughnessFactor'] = rough
        mode = m.get('alphaMode', 'OPAQUE')
        # Hair cards use alpha-scissor (cheaper than blending, still sorts correctly).
        if '_HAIR' in name and mode == 'BLEND': mode = 'MASK'
        out['alphaMode'] = mode
        if mode == 'MASK': out['alphaCutoff'] = m.get('alphaCutoff', 0.5)
        out['doubleSided'] = bool(m.get('doubleSided', False)) or '_HAIR' in name or '_CLOTH' in name
        self.g['materials'].append(out)
        return len(self.g['materials']) - 1

    def save(self, path):
        base = os.path.splitext(os.path.basename(path))[0]
        self.g['buffers'] = [{'uri': base + '.bin', 'byteLength': len(self.bin)}]
        for k in list(self.g):
            if isinstance(self.g[k], list) and not self.g[k]: del self.g[k]
        json.dump(self.g, open(path, 'w'), separators=(',', ':'))
        open(os.path.join(os.path.dirname(path), base + '.bin'), 'wb').write(bytes(self.bin))


def build_part(src_path, prim_filter, out_path, tex_dir, reg, with_face=False, node_name='Part'):
    """Copy the humanoid skeleton plus only the selected primitives from a VRM."""
    j, b = load_glb(src_path)
    w = Writer(tex_dir, reg)
    nodes = j['nodes']
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get('children', []): parent[c] = i
    # Skeleton: allowed bones only, hierarchy rebuilt (removed nodes are leaf chains).
    keep = [i for i, n in enumerate(nodes) if allowed_bone(n['name']) and 'mesh' not in n]
    new_idx = {}
    for i in keep:
        n = nodes[i]
        nn = {'name': n['name']}
        for k in ('translation', 'rotation', 'scale'):
            if k in n: nn[k] = n[k]
        new_idx[i] = len(w.g['nodes']); w.g['nodes'].append(nn)
    for i in keep:
        kids = [new_idx[c] for c in nodes[i].get('children', []) if c in new_idx]
        if kids: w.g['nodes'][new_idx[i]]['children'] = kids
    root = new_idx[[i for i in keep if nodes[i]['name'] == 'Root'][0]]
    w.g['scenes'][0]['nodes'].append(root)

    def nearest_allowed(node):
        while node not in new_idx: node = parent[node]
        return node

    src_skin = j['skins'][0]
    src_ibm = read_acc(j, b, src_skin['inverseBindMatrices']).reshape(-1, 16)
    joint_nodes = keep
    ibm_of = {nd: src_ibm[k] for k, nd in enumerate(src_skin['joints'])}
    ibms = np.array([ibm_of[nd] for nd in joint_nodes], np.float32)
    skin = {'joints': [new_idx[n] for n in joint_nodes], 'skeleton': root,
            'inverseBindMatrices': w.add_acc(ibms, 5126, 'MAT4')}
    w.g['skins'].append(skin)
    joint_pos = {nd: k for k, nd in enumerate(joint_nodes)}

    for mi, mesh in enumerate(j['meshes']):
        mnode = [n for n in nodes if n.get('mesh') == mi][0]
        skin_src = j['skins'][mnode.get('skin', 0)]
        is_face = mesh['name'].startswith('Face')
        names = mesh.get('extras', {}).get('targetNames', [])
        prims = []
        for pr in mesh['primitives']:
            mname = j['materials'][pr['material']]['name']
            if not (with_face and is_face) and not prim_filter(mname): continue
            idx = read_acc(j, b, pr['indices']).reshape(-1)
            used, inv = np.unique(idx, return_inverse=True)
            attrs = {}
            pos = read_acc(j, b, pr['attributes']['POSITION'])[used]
            attrs['POSITION'] = w.add_acc(pos, 5126, 'VEC3', 34962, True)
            attrs['NORMAL'] = w.add_acc(read_acc(j, b, pr['attributes']['NORMAL'])[used], 5126, 'VEC3', 34962)
            attrs['TEXCOORD_0'] = w.add_acc(read_acc(j, b, pr['attributes']['TEXCOORD_0'])[used], 5126, 'VEC2', 34962)
            jo = read_acc(j, b, pr['attributes']['JOINTS_0'])[used].astype(np.int64)
            we = read_acc(j, b, pr['attributes']['WEIGHTS_0'])[used].astype(np.float32)
            # Remap every influence onto the nearest standard humanoid bone and merge duplicates.
            lut = np.array([joint_pos[nearest_allowed(nd)] for nd in skin_src['joints']])
            jo = lut[jo]
            nj = np.zeros_like(jo); nw = np.zeros_like(we)
            for v in range(jo.shape[0]):
                acc = {}
                for k in range(4):
                    if we[v, k] > 0: acc[jo[v, k]] = acc.get(jo[v, k], 0) + we[v, k]
                items = sorted(acc.items(), key=lambda x: -x[1])[:4]
                s = sum(x[1] for x in items) or 1
                for k, (jj, ww) in enumerate(items): nj[v, k] = jj; nw[v, k] = ww / s
            attrs['JOINTS_0'] = w.add_acc(nj, 5123, 'VEC4', 34962)
            attrs['WEIGHTS_0'] = w.add_acc(nw, 5126, 'VEC4', 34962)
            p = {'attributes': attrs, 'indices': w.add_acc(inv.astype(np.uint32), 5125, 'SCALAR', 34963),
                 'material': w.add_material(j, b, pr['material'])}
            if is_face and pr.get('targets'):
                tg = []
                for nm in KEEP_MORPHS:
                    t = pr['targets'][names.index(nm)]
                    d = {}
                    for an in ('POSITION', 'NORMAL'):
                        if an in t: d[an] = w.add_acc(read_acc(j, b, t[an])[used], 5126, 'VEC3', 34962, an == 'POSITION')
                    tg.append(d)
                p['targets'] = tg
            prims.append(p)
        if not prims: continue
        m = {'name': ('Face' if is_face else node_name), 'primitives': prims}
        if is_face: m['extras'] = {'targetNames': KEEP_MORPHS}; m['weights'] = [0.0] * len(KEEP_MORPHS)
        w.g['meshes'].append(m)
        w.g['nodes'].append({'name': m['name'], 'mesh': len(w.g['meshes']) - 1, 'skin': 0})
        w.g['scenes'][0]['nodes'].append(len(w.g['nodes']) - 1)
    w.save(out_path)
    return out_path


def main():
    src, out = sys.argv[1], sys.argv[2]
    tex = os.path.join(out, 'textures'); os.makedirs(tex, exist_ok=True)
    reg = {}
    P = lambda f: os.path.join(src, f)
    O = lambda f: os.path.join(out, f)
    body = lambda n: ('Body_00_SKIN' in n or 'Onepiece' in n)
    for race, sex, fa, cl in [('hyur', 'f', 'HyurFA', 'HyurFSampleClothes'), ('hyur', 'm', 'HyurMA', 'HyurMSampleClothes'),
                              ('miqote', 'f', 'MiqoFA', 'MiqoFSampleClothes'), ('miqote', 'm', 'MiqoMA', 'MiqoMSampleClothes')]:
        # Full base body: face, intact skin and smallclothes. Nothing hidden under clothes is removed.
        build_part(P(fa + '.vrm'), body, O(f'base_{race}_{sex}.gltf'), tex, reg, with_face=True, node_name='Body')
        for item, key in [('tops', 'Tops_01'), ('bottoms', 'Bottoms_01'), ('shoes', 'Shoes_01'), ('cap', 'BaseballCap')]:
            build_part(P(cl + '.vrm'), lambda n, k=key: k in n, O(f'{race}_{sex}_{item}.gltf'), tex, reg, node_name=item)
        if race == 'miqote':
            build_part(P(fa + '.vrm'), lambda n: 'CatEar' in n, O(f'ears_miqote_{sex}.gltf'), tex, reg, node_name='ears')
            build_part(P(fa + '.vrm'), lambda n: 'FoxTail' in n, O(f'tail_miqote_{sex}.gltf'), tex, reg, node_name='tail')
        build_part(P(fa + '.vrm'), lambda n: 'HairBack' in n, O(f'hairback_{sex}.gltf'), tex, reg, node_name='hairback')
    # Hairstyles: the sample body is discarded, only the hair (and its scalp layer) is kept.
    for i, f in enumerate(['HairstyleSample', 'HairstyleSample2'], 1):
        build_part(P(f + '.vrm'), lambda n: '_HAIR' in n, O(f'hair_{i}.gltf'), tex, reg, node_name='hair')
    print('textures:', len(reg))


if __name__ == '__main__':
    main()
