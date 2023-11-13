import requests
from PIL import Image
import io

min_x = -8
max_x = 7
min_z = -8
max_z = 7
imsize = 128
vsize = (max_z - min_z + 1)
hsize = (max_x - min_x + 1)

composite = Image.new("RGBA", (hsize * imsize, vsize * imsize))

for x in range(min_x, max_x + 1):
    for z in range(min_z, max_z + 1):
        url = f"https://dynmap.switchcraft.pw/tiles/world/flat/{x}_{z}/zzzzzz_{x * 64}_{z * 64}.png"
        data = requests.get(url).content
        i = Image.open(io.BytesIO(data))
        composite.paste(i, ((x - min_x) * imsize, (vsize - (z - min_z)) * imsize))

composite.show()
composite.save("composite.png")