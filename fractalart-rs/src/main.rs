use image::{Rgb, ImageBuffer, RgbImage, buffer::ConvertBuffer};
use std::cmp::{max, min};
use nanorand::{WyRand, RNG};
use gumdrop::Options;
use smallvec::{smallvec, SmallVec};

type R16Image = ImageBuffer<Rgb<u16>, Vec<u16>>;

// convert HSL to RGB, wrapping the hsl crate
fn hsl_to_rgb(h: f64, s: f64, l: f64) -> Rgb<u8> {
    let (r, g, b) = (hsl::HSL { h, s, l }).to_rgb();
    Rgb::from([r, g, b])
}

type IPos = (i32, i32);

// checks if a position is inside the given width/height
fn is_inside((w, h): IPos, (x, y): IPos) -> bool {
    x < w && y < h && x >= 0 && y >= 0
}

// generate a square "ring" around a point with supplied distance
// drops all values outside of grid
fn ring_at(dim: IPos, (x, y): IPos, l: i32) -> impl Iterator<Item = IPos> {
    // use smallvec for higher efficiency if generating small ring for next_color
    // it might be better to just have a separate codepath entirely for size-1 rings really
    // or make it work as an iterator properly
    let mut out: SmallVec<[_; 8]> = smallvec![];
    // top and bottom of ring
    for n in -l..=l {
        out.push((n + x, l + y));
        out.push((n + x, -l + y));
    }
    // sides of ring
    for n in (1 - l)..l {
        out.push((l + x, n + y));
        out.push((-l + x, n + y));
    }
    out.into_iter().filter(move |c| is_inside(dim, *c))
}

// randomly increase/decrease one of the channels in a color by `range`
fn mod_channel(rng: &mut WyRand, range: u16, n: u16) -> u16 {
    // to avoid conversion to signed integers here, do things of some sort
    let rand: u16 = rng.generate::<u16>() % (range * 2 + 2);
    let o = ((n as u32) + (rand as u32)).saturating_sub(range as u32);
    // avoid weird artifacts - just directly using `as` truncates it, i.e. drops the high bytes, which leads to integer-overflow-like issues
    max(min(o, 65535), 1) as u16
}

// randomly adjust all the channels in a color by `range`
fn mod_color(rng: &mut WyRand, range: u16, col: Rgb<u16>) -> Rgb<u16> {
    Rgb([mod_channel(rng, range, col[0]), mod_channel(rng, range, col[1]), mod_channel(rng, range, col[2])])
}

// the original Haskell implementation has a grid of booleans and colors for this
// doing that in this would probably introduce more complexity and reduce efficiency significantly, so just reserve black for uninitialized pixels
const BLANK: Rgb<u16> = Rgb([0, 0, 0]);

// get the next color to use by randomly selecting an adjacent nonblank pixel and randomizing it a bit
fn next_color(opts: &CLIOptions, rng: &mut WyRand, im: &R16Image, pos: IPos) -> Rgb<u16> {
    let (w, h) = im.dimensions();
    let dim = (w as i32, h as i32);
    let mut colors: SmallVec<[_; 8]> = smallvec![];
    for (x, y) in ring_at(dim, pos, 1) {
        let px = *im.get_pixel(x as u32, y as u32);
        if px != BLANK {
            colors.push(px);
        }
    }
    let chosen = colors[rng.generate_range(0, colors.len())];
    mod_color(rng, opts.variance / colors.len() as u16, chosen)
}

// run an iteration by filling in all the pixels in a ring around the start position
fn iter(opts: &CLIOptions, rng: &mut WyRand, im: &mut R16Image, pos: IPos, i: i32) {
    let (w, h) = im.dimensions();
    let dim = (w as i32, h as i32);

    for (x, y) in ring_at(dim, pos, i) {
        im.put_pixel(x as u32, y as u32, next_color(opts, rng, im, (x, y)));
    }
}

#[derive(Options, Debug)]
struct CLIOptions {
    #[options(help = "width of generated image", short = "W", default = "1000")]
    width: u32,
    #[options(help = "height of generated image", short = "H", default = "1000")]
    height: u32,
    #[options(help = "filename to save generated image to", short = "o", default = "./out.png")]
    filename: String,
    // required for gumdrop to provide help text
    #[options(help = "display this help", short = "h")]
    help: bool,
    #[options(help = "max color channel difference from previous pixel", short = "v", default = "2048")]
    variance: u16,
    #[options(help = "base color saturation", short = "s", default = "1.0")]
    saturation: f64,
    #[options(help = "base color lightness", short = "l", default = "0.6")]
    lightness: f64,
    #[options(help = "base color hue (default: random)", short = "u")]
    hue: Option<f64>,
    #[options(help = "random seed (default: random)", short="r")]
    seed: Option<u64>
}

fn main() {
    let opts = CLIOptions::parse_args_default_or_exit();

    let mut rng = match opts.seed {
        Some(seed) => nanorand::WyRand::new_seed(seed),
        None => nanorand::WyRand::new()
    };
    let w = opts.width;
    let h = opts.height;
    let start_x = rng.generate_range(0, w - 1);
    let start_y = rng.generate_range(0, h - 1);

    // generate a starting color
    let hue = opts.hue.unwrap_or_else(|| rng.generate_range(0u64, 360 * 65536) as f64 / 65536.);
    let start_color = hsl_to_rgb(hue, opts.saturation, opts.lightness);
    let start_color = Rgb([start_color[0] as u16 * 256, start_color[1] as u16 * 256, start_color[2] as u16 * 256]);

    let iterations = max(max(start_x, w - 1 - start_x), max(start_y, h - 1 - start_y)) as i32;
    let mut im = R16Image::from_pixel(w, h, BLANK);
    im.put_pixel(start_x, start_y, start_color);
    for i in 1..=iterations {
        iter(&opts, &mut rng, &mut im, (start_x as i32, start_y as i32), i);
    }

    // discard low bits of image pixels before saving, as monitors mostly can't render these and it wastes space
    let low_color_depth_image: RgbImage = im.convert();
    low_color_depth_image.save(&opts.filename).expect("failed to save image");
}
