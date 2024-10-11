import torch
from PIL import Image
import math
import numpy

def paint(im: Image.Image, weight: torch.Tensor):
    device = weight.device
    weight = weight.view(-1)
    dim = math.floor(math.sqrt(weight.shape[0]))
    weight = weight[:dim * dim]
    paint = torch.tensor(numpy.asarray(im.resize((dim, dim)).convert("L"))).to(device).reshape(-1)
    permutation = torch.argsort(paint)
    inverse_permutation = torch.argsort(permutation)
    sorted_weights, _ = torch.sort(weight)
    new_weight = sorted_weights[inverse_permutation]
    weight[:] = new_weight

def render(weight: torch.Tensor):
    weight = weight.view(-1)
    dim = math.floor(math.sqrt(weight.shape[0]))
    weight = weight[:dim * dim]
    weight_np = weight.cpu().numpy().reshape((dim, dim))
    weight_np += weight_np.min()
    weight_np /= weight_np.max() - weight_np.min()
    weight_np *= 255
    return Image.fromarray(weight_np.astype(numpy.uint8))

if __name__ == "__main__":
    im = Image.open("test.png")
    weight = torch.randn(256, 256)
    paint(im, weight)
    out_im = render(weight)
    out_im.show()
    out_im.save("out.png")
