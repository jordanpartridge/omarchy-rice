package poster

import (
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"
	"strings"
)

// Write paints a JPEG/PNG as truecolor half-blocks. Chunky on purpose —
// dirt spray, not a gallery print.
func Write(w io.Writer, path string, cols, maxRows int) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		return err
	}
	_, err = io.WriteString(w, Render(img, cols, maxRows))
	return err
}

func Render(img image.Image, cols, maxRows int) string {
	if cols < 24 {
		cols = 24
	}
	if maxRows < 8 {
		maxRows = 8
	}
	b := img.Bounds()
	srcW, srcH := b.Dx(), b.Dy()
	if srcW < 1 || srcH < 1 {
		return ""
	}
	w := cols
	h := srcH * w / srcW
	if h > maxRows*2 {
		h = maxRows * 2
		w = srcW * h / srcH
	}
	if h%2 == 1 {
		h++
	}
	if w < 8 || h < 4 {
		return ""
	}

	var out strings.Builder
	out.Grow(w * h * 20)
	for y := 0; y < h; y += 2 {
		for x := 0; x < w; x++ {
			top := sample(img, b, x, y, w, h)
			bot := sample(img, b, x, y+1, w, h)
			fmt.Fprintf(&out, "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm▀",
				top.R, top.G, top.B, bot.R, bot.G, bot.B)
		}
		out.WriteString("\x1b[0m\n")
	}
	return out.String()
}

func sample(img image.Image, b image.Rectangle, x, y, w, h int) color.RGBA {
	srcW, srcH := b.Dx(), b.Dy()
	sx := b.Min.X + x*srcW/w
	sy := b.Min.Y + y*srcH/h
	if sx >= b.Max.X {
		sx = b.Max.X - 1
	}
	if sy >= b.Max.Y {
		sy = b.Max.Y - 1
	}
	r, g, bl, _ := img.At(sx, sy).RGBA()
	return color.RGBA{uint8(r >> 8), uint8(g >> 8), uint8(bl >> 8), 255}
}
