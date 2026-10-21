"""Union-mask wheel shadow: one blur per tier, never one blur per wedge.

The arc is centered on the source's upward ray. Runtime rotates it toward the
selected parent. BLP2 BGRA with padded edges is accepted by the Forever client.
"""
from math import pi
from pathlib import Path
import struct

import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SIZE=256
ART_RADIUS=124/128


def render(tier,count):
    assert tier in (0,1,2) and 1<=count<=24
    coord=(np.arange(SIZE,dtype=np.float32)+.5-SIZE/2)/(SIZE/2)
    dx,dy=np.meshgrid(coord,-coord)
    r=np.hypot(dx,dy)/ART_RADIUS
    lower=(.42,.70,.74)[tier]
    arc=2*pi if tier==0 else min(5.5,max(pi/2,count*.42))
    if tier==0:
        distance=np.minimum(r-lower,1-r)
    else:
        angle=np.abs(np.arctan2(dx,dy))
        distance=np.minimum.reduce((r-lower,1-r,(arc/2-angle)*np.maximum(r,lower)))
    # The faint fill gives the edge a solid base; one Gaussian along the union
    # boundary yields a continuous halo without radial spoke seams.
    strength=.12+.83*np.exp(-((distance-.002)/.047)**2)
    fade=np.clip((distance+.058)/.048,0,1)
    perimeter=np.clip((1.022-r)/.012,0,1)
    alpha=np.asarray(np.rint(np.clip(strength*fade*perimeter,0,1)*255),dtype=np.uint8)
    rgb=np.full((SIZE,SIZE,3),255,dtype=np.uint8)
    raw=np.dstack((rgb[:,:,::-1],alpha)).tobytes()
    header=struct.pack('<4sI4BII',b'BLP2',1,3,8,8,0,SIZE,SIZE)
    header+=struct.pack('<16I',1172,*([0]*15))
    header+=struct.pack('<16I',len(raw),*([0]*15))
    return header+bytes(1024)+raw


if __name__=='__main__':
    output=ROOT/'Textures'
    for tier in (0,1,2):
        for count in (range(1,25) if tier else [1]):
            (output/f'WheelSilhouetteT{tier}N{count:02d}.blp').write_bytes(render(tier,count))
    print('Rendered 49 continuous tier silhouette masks')
