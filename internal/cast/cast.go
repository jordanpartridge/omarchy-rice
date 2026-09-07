package cast

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

type Hypr interface {
	Option(ctx context.Context, name string) (string, error)
	Keyword(ctx context.Context, name, value string) error
}

type LiveHypr struct{}

func (LiveHypr) Option(ctx context.Context, name string) (string, error) {
	cmd := exec.CommandContext(ctx, "hyprctl", "getoption", name, "-j")
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return parseOptionJSON(out)
}

func (LiveHypr) Keyword(ctx context.Context, name, value string) error {
	cmd := exec.CommandContext(ctx, "hyprctl", "keyword", name, value)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("hyprctl keyword %s: %w (%s)", name, err, bytesTrim(out))
	}
	return nil
}

type Frame struct {
	GapsIn  int
	GapsOut int
	Border  int
}

func PlanPulse(baseIn, baseOut, baseBorder, extra, steps int) []Frame {
	if steps < 1 {
		steps = 1
	}
	if extra < 1 {
		extra = 8
	}
	out := make([]Frame, 0, steps*2)
	for i := 1; i <= steps; i++ {
		out = append(out, Frame{
			GapsIn:  baseIn + extra*i/steps,
			GapsOut: baseOut + extra*i/steps,
			Border:  baseBorder + extra*i/(steps*2),
		})
	}
	for i := steps - 1; i >= 0; i-- {
		gIn, gOut, b := baseIn, baseOut, baseBorder
		if i > 0 {
			gIn = baseIn + extra*i/steps
			gOut = baseOut + extra*i/steps
			b = baseBorder + extra*i/(steps*2)
		}
		out = append(out, Frame{GapsIn: gIn, GapsOut: gOut, Border: b})
	}
	return out
}

func Pulse(ctx context.Context, h Hypr) (string, error) {
	origIn, origOut, origBorder, err := look(ctx, h)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = h.Keyword(context.Background(), "general:gaps_in", origIn)
		_ = h.Keyword(context.Background(), "general:gaps_out", origOut)
		_ = h.Keyword(context.Background(), "general:border_size", origBorder)
	}()

	baseIn := glass.FirstCSSGap(origIn)
	baseOut := glass.FirstCSSGap(origOut)
	baseBorder := glass.FirstCSSGap(origBorder)
	if baseBorder == 0 {
		baseBorder = 2
	}
	frames := PlanPulse(baseIn, baseOut, baseBorder, 12, 5)
	delay := 70 * time.Millisecond
	for _, f := range frames {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		if err := h.Keyword(ctx, "general:gaps_in", itoa(f.GapsIn)); err != nil {
			return "", err
		}
		if err := h.Keyword(ctx, "general:gaps_out", itoa(f.GapsOut)); err != nil {
			return "", err
		}
		if err := h.Keyword(ctx, "general:border_size", itoa(f.Border)); err != nil {
			return "", err
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(delay):
		}
	}
	return fmt.Sprintf("pulse restored gaps %s / %s", origIn, origOut), nil
}

func Flash(ctx context.Context, h Hypr, p palette.Palette) (string, error) {
	orig, err := h.Option(ctx, "general:col.active_border")
	if err != nil {
		return "", err
	}
	defer func() {
		_ = h.Keyword(context.Background(), "general:col.active_border", restoreBorder(orig, p))
	}()

	banner := fmt.Sprintf("rgba(%sff) rgba(%sff) 45deg", hexRGB(p.Accent), hexRGB(p.Accent))
	sun := fmt.Sprintf("rgba(%sff) rgba(%sff) 45deg", hexRGB(p.Yellow), hexRGB(p.Yellow))
	mix := p.HyprActiveBorder
	if mix == "" {
		mix = palette.Jump().HyprActiveBorder
	}
	for _, color := range []string{banner, sun, banner, sun, mix} {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		if err := h.Keyword(ctx, "general:col.active_border", color); err != nil {
			return "", err
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(140 * time.Millisecond):
		}
	}
	return "flash restored the dusk border", nil
}

func Notify(ctx context.Context, headline, body string) (string, error) {
	if headline == "" {
		headline = "NO WORKTREES"
	}
	if body == "" {
		body = "biker, not cyclist"
	}
	cmd := exec.CommandContext(ctx, "omarchy", "notification", "send",
		"--app-name", "magic",
		headline, body)
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("notify: %w (%s)", err, bytesTrim(out))
	}
	return headline, nil
}

func Jump(ctx context.Context) (string, error) {
	if glass.ThemeSlug(glass.ThemeName()) == "no-worktrees" {
		_, _ = Notify(ctx, "NO WORKTREES", "already planted")
		return "theme already no-worktrees", nil
	}
	cmd := exec.CommandContext(ctx, "omarchy", "theme", "set", "no-worktrees")
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("theme set: %w (%s)", err, bytesTrim(out))
	}
	_, _ = Notify(ctx, "NO WORKTREES", "jump planted")
	return "omarchy theme set no-worktrees", nil
}

func look(ctx context.Context, h Hypr) (gapsIn, gapsOut, border string, err error) {
	gapsIn, err = h.Option(ctx, "general:gaps_in")
	if err != nil {
		return "", "", "", err
	}
	gapsOut, err = h.Option(ctx, "general:gaps_out")
	if err != nil {
		return "", "", "", err
	}
	border, err = h.Option(ctx, "general:border_size")
	if err != nil {
		return "", "", "", err
	}
	return gapsIn, gapsOut, border, nil
}

func restoreBorder(orig string, p palette.Palette) string {
	orig = strings.TrimSpace(orig)
	if strings.Contains(orig, "rgba(") || strings.Contains(orig, "rgb(") {
		return orig
	}
	if p.HyprActiveBorder != "" {
		return p.HyprActiveBorder
	}
	return palette.Jump().HyprActiveBorder
}

func hexRGB(s string) string {
	s = strings.TrimPrefix(palette.Hex(s), "#")
	if len(s) >= 6 {
		return s[:6]
	}
	return "e46592"
}

func itoa(n int) string {
	return fmt.Sprintf("%d", n)
}

func bytesTrim(b []byte) string {
	return strings.TrimSpace(string(b))
}

func parseOptionJSON(raw []byte) (string, error) {
	// tiny parse so cast doesn't import encoding details from glass
	s := strings.TrimSpace(string(raw))
	pick := func(key string) string {
		needle := `"` + key + `":`
		i := strings.Index(s, needle)
		if i < 0 {
			return ""
		}
		rest := strings.TrimSpace(s[i+len(needle):])
		if strings.HasPrefix(rest, `"`) {
			rest = rest[1:]
			j := strings.Index(rest, `"`)
			if j < 0 {
				return ""
			}
			return rest[:j]
		}
		j := 0
		for j < len(rest) && rest[j] >= '0' && rest[j] <= '9' {
			j++
		}
		return rest[:j]
	}
	for _, key := range []string{"css", "gradient", "str"} {
		if v := pick(key); v != "" {
			return v, nil
		}
	}
	if v := pick("int"); v != "" {
		return v, nil
	}
	return "", fmt.Errorf("empty hypr option")
}
