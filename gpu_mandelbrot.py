import torch
import torchvision.transforms.functional as T
import math
torch.set_grad_enabled(False)

device = torch.device("cuda:0")
size = 6144
steps = 2048
xs = torch.linspace(-1, 1, size, dtype=torch.cfloat, device=device).tile(size, 1)
ys = torch.linspace(-1, 1, size, dtype=torch.cfloat, device=device).tile(size, 1).t() * 1j
zs = xs + ys
ws = zs.clone()
aws = abs(ws)
dead = torch.zeros_like(xs, dtype=torch.bool, device=device)
counts = torch.zeros_like(xs, dtype=torch.float, device=device)

for i in range(steps):
    zs *= zs
    zs += ws
    dead |= abs(zs) > 4
    counts += torch.where(dead, 1, 0)

zero = torch.zeros((size, size, 3), dtype=torch.float, device=device)
blue = torch.zeros((size, size, 3), dtype=torch.float, device=device)
blue[..., 2] = 1
itr = torch.log((steps - counts) / steps)
itr /= math.log(steps)
m = itr.reshape((size, size, 1)).repeat_interleave(3, -1) 
z = m * blue
i = T.to_pil_image(z.permute(2, 0, 1))

i.save("/tmp/mandel.png")