package poster

import (
	"image"
	"image/color"
	"strings"
	"testing"
)

func TestRenderHalfblocks(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			img.Set(x, y, color.RGBA{R: 0xe4, G: 0x65, B: 0x92, A: 255})
		}
	}
	out := Render(img, 16, 6)
	if !strings.Contains(out, "▀") {
		t.Fatal("expected half-blocks")
	}
	if !strings.Contains(out, "38;2;228;101;146") {
		t.Fatalf("missing banner magenta: %q", out[:min(80, len(out))])
	}
	if !strings.HasSuffix(strings.TrimSpace(out), "\x1b[0m") && !strings.Contains(out, "\x1b[0m") {
		t.Fatal("missing reset")
	}
}
