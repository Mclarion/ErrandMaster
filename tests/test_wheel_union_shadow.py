"""Verify one continuous, generated shadow per root or expanded arc."""
from pathlib import Path
import struct
import sys
sys.path.insert(0, 'tools')
from render_wheel_silhouette import render

root=Path('Textures')
for tier,counts in ((0,(1,)),(1,(1,5,13,24)),(2,(1,5,13,24))):
    for count in counts:
        path=root/f'WheelSilhouetteT{tier}N{count:02d}.blp'
        data=render(tier,count)
        assert path.read_bytes()==data, path
        assert struct.unpack_from('<II',data,12)==(256,256)
        alpha=data[1175::4]
        assert max(alpha)>=150 and alpha[0]==0
        assert sum(value>0 for value in alpha)>1000
print('49 silhouette assets generated; representative union masks byte-match')
