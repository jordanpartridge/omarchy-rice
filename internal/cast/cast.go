package cast

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

// Hypr is the live glass. Omarchy Hyprland is Lua: hyprctl keyword is a
// no-op ("use eval"). Every mutation goes through hl.config.
type Hypr interface {
	Option(ctx context.Context, name string) (string, error)
	Config(ctx context.Context, lua string) error
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

func (LiveHypr) Config(ctx context.Context, lua string) error {
	cmd := exec.CommandContext(ctx, "hyprctl", "eval", lua)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("hyprctl eval: %w (%s)", err, bytesTrim(out))
	}
	if strings.Contains(strings.ToLower(string(out)), "error:") {
		return fmt.Errorf("hyprctl eval: %s", bytesTrim(out))
	}
	return nil
}

type Look struct {
	GapsIn      int
	GapsOut     int
	Border      int
	Rounding    int
	Zoom        float64
	DimOn       bool
	DimStrength float64
	BorderA     string
	BorderB     string
	Angle       int
}

type Beat struct {
	Name        string
	Wait        time.Duration
	GapsIn      int
	GapsOut     int
	Border      int
	Rounding    int
	Zoom        float64
	DimOn       bool
	DimStrength float64
	BorderA     string
	BorderB     string
	Angle       int
}

func (l Look) Lua() string {
	return Beat{
		GapsIn: l.GapsIn, GapsOut: l.GapsOut, Border: l.Border,
		Rounding: l.Rounding, Zoom: l.Zoom, DimOn: l.DimOn,
		DimStrength: l.DimStrength, BorderA: l.BorderA, BorderB: l.BorderB,
		Angle: l.Angle,
	}.Lua()
}

func (b Beat) Lua() string {
	aa, bb := b.BorderA, b.BorderB
	if aa == "" {
		aa = "e46592ee"
	}
	if bb == "" {
		bb = "debb85ee"
	}
	ang := b.Angle
	if ang == 0 {
		ang = 45
	}
	zoom := b.Zoom
	if zoom < 0.8 {
		zoom = 1
	}
	dim := b.DimStrength
	if dim <= 0 {
		dim = 0.5
	}
	return fmt.Sprintf(
		`hl.config({ general = { gaps_in = %d, gaps_out = %d, border_size = %d, col = { active_border = { colors = { "rgba(%s)", "rgba(%s)" }, angle = %d } } }, decoration = { rounding = %d, dim_inactive = %s, dim_strength = %.2f }, cursor = { zoom_factor = %.2f } })`,
		b.GapsIn, b.GapsOut, b.Border, aa, bb, ang, b.Rounding, luaBool(b.DimOn), dim, zoom,
	)
}

func Snapshot(ctx context.Context, h Hypr) (Look, error) {
	get := func(name string) (string, error) { return h.Option(ctx, name) }
	in, err := get("general:gaps_in")
	if err != nil {
		return Look{}, err
	}
	out, err := get("general:gaps_out")
	if err != nil {
		return Look{}, err
	}
	border, err := get("general:border_size")
	if err != nil {
		return Look{}, err
	}
	round, _ := get("decoration:rounding")
	zoom, _ := get("cursor:zoom_factor")
	dimOn, _ := get("decoration:dim_inactive")
	dimS, _ := get("decoration:dim_strength")
	grad, _ := get("general:col.active_border")
	a, b, ang := parseGradient(grad)
	l := Look{
		GapsIn:      glass.FirstCSSGap(in),
		GapsOut:     glass.FirstCSSGap(out),
		Border:      atoi(border, 2),
		Rounding:    atoi(round, 0),
		Zoom:        atof(zoom, 1),
		DimOn:       dimOn == "true" || dimOn == "1",
		DimStrength: atof(dimS, 0.5),
		BorderA:     a,
		BorderB:     b,
		Angle:       ang,
	}
	if l.Zoom == 0 {
		l.Zoom = 1
	}
	return l, nil
}

func PlanRide(base Look, pal palette.Palette) []Beat {
	mag := hexRGB(pal.Accent) + "ff"
	sun := hexRGB(pal.Yellow) + "ff"
	mixA, mixB := base.BorderA, base.BorderB
	if mixA == "" {
		mixA = hexRGB(pal.Accent) + "ee"
	}
	if mixB == "" {
		mixB = hexRGB(pal.Yellow) + "ee"
	}
	in, out := base.GapsIn, base.GapsOut
	if in < 1 {
		in = 5
	}
	if out < 1 {
		out = 10
	}
	return []Beat{
		{Name: "crouch", Wait: 90 * time.Millisecond, GapsIn: max(0, in-4), GapsOut: max(1, out-8), Border: max(2, base.Border), Rounding: 0, Zoom: 1.0, DimOn: true, DimStrength: 0.45, BorderA: mag, BorderB: mag, Angle: 45},
		{Name: "coil", Wait: 110 * time.Millisecond, GapsIn: 0, GapsOut: 2, Border: 3, Rounding: 4, Zoom: 1.08, DimOn: true, DimStrength: 0.62, BorderA: mag, BorderB: sun, Angle: 45},
		{Name: "launch", Wait: 70 * time.Millisecond, GapsIn: in + 10, GapsOut: out + 18, Border: 7, Rounding: 18, Zoom: 1.42, DimOn: true, DimStrength: 0.35, BorderA: mag, BorderB: mag, Angle: 90},
		{Name: "apex", Wait: 140 * time.Millisecond, GapsIn: in + 16, GapsOut: out + 28, Border: 8, Rounding: 22, Zoom: 1.58, DimOn: true, DimStrength: 0.22, BorderA: sun, BorderB: mag, Angle: 45},
		{Name: "hang", Wait: 180 * time.Millisecond, GapsIn: in + 14, GapsOut: out + 24, Border: 6, Rounding: 18, Zoom: 1.38, DimOn: true, DimStrength: 0.28, BorderA: sun, BorderB: sun, Angle: 45},
		{Name: "drop", Wait: 90 * time.Millisecond, GapsIn: in + 4, GapsOut: out + 8, Border: 4, Rounding: 8, Zoom: 1.12, DimOn: true, DimStrength: 0.4, BorderA: mixA, BorderB: mixB, Angle: base.Angle},
	}
}

func Ride(ctx context.Context, h Hypr, pal palette.Palette) (string, error) {
	look, err := Snapshot(ctx, h)
	if err != nil {
		return "", err
	}
	defer func() {
		_ = h.Config(context.Background(), look.Lua())
	}()

	img := glass.Wallpaper()
	go func() {
		nctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_, _ = Notify(nctx, "NO WORKTREES", "biker, not cyclist", img)
	}()

	for _, b := range PlanRide(look, pal) {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		if err := h.Config(ctx, b.Lua()); err != nil {
			return "", err
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(b.Wait):
		}
	}
	return "jumped", nil
}

func Pulse(ctx context.Context, h Hypr) (string, error) {
	look, err := Snapshot(ctx, h)
	if err != nil {
		return "", err
	}
	defer func() { _ = h.Config(context.Background(), look.Lua()) }()
	pal := palette.Jump()
	for _, b := range PlanRide(look, pal)[:3] {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		if err := h.Config(ctx, b.Lua()); err != nil {
			return "", err
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(b.Wait):
		}
	}
	return fmt.Sprintf("pulse restored gaps %d / %d", look.GapsIn, look.GapsOut), nil
}

func Flash(ctx context.Context, h Hypr, pal palette.Palette) (string, error) {
	look, err := Snapshot(ctx, h)
	if err != nil {
		return "", err
	}
	defer func() { _ = h.Config(context.Background(), look.Lua()) }()
	mag := hexRGB(pal.Accent) + "ff"
	sun := hexRGB(pal.Yellow) + "ff"
	for _, pair := range [][2]string{{mag, mag}, {sun, sun}, {mag, sun}, {sun, mag}} {
		b := Beat{
			GapsIn: look.GapsIn, GapsOut: look.GapsOut, Border: look.Border + 4,
			Rounding: 12, Zoom: 1.12, DimOn: true, DimStrength: 0.35,
			BorderA: pair[0], BorderB: pair[1], Angle: 45,
		}
		if err := h.Config(ctx, b.Lua()); err != nil {
			return "", err
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(120 * time.Millisecond):
		}
	}
	return "flash restored the dusk border", nil
}

func Notify(ctx context.Context, headline, body, image string) (string, error) {
	if headline == "" {
		headline = "NO WORKTREES"
	}
	if body == "" {
		body = "biker, not cyclist"
	}
	args := []string{"notification", "send", "--app-name", "magic", "-u", "normal", "-t", "2200"}
	if image != "" {
		args = append(args, "--image", image)
	}
	args = append(args, headline, body)
	cmd := exec.CommandContext(ctx, "omarchy", args...)
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("notify: %w (%s)", err, bytesTrim(out))
	}
	return headline, nil
}

func Plant(ctx context.Context) (string, error) {
	if glass.ThemeSlug(glass.ThemeName()) == "no-worktrees" {
		return "theme already no-worktrees", nil
	}
	cmd := exec.CommandContext(ctx, "omarchy", "theme", "set", "no-worktrees")
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("theme set: %w (%s)", err, bytesTrim(out))
	}
	return "omarchy theme set no-worktrees", nil
}

func Jump(ctx context.Context) (string, error) {
	if msg, err := Plant(ctx); err != nil {
		return msg, err
	}
	return Ride(ctx, LiveHypr{}, palette.Jump())
}

func parseOptionJSON(raw []byte) (string, error) {
	var o struct {
		CSS      string   `json:"css"`
		Gradient string   `json:"gradient"`
		Str      string   `json:"str"`
		Float    *float64 `json:"float"`
		Int      *int     `json:"int"`
		Bool     *bool    `json:"bool"`
	}
	if err := json.Unmarshal(raw, &o); err != nil {
		return "", err
	}
	switch {
	case o.CSS != "":
		return o.CSS, nil
	case o.Gradient != "":
		return o.Gradient, nil
	case o.Str != "":
		return o.Str, nil
	case o.Float != nil:
		return strconv.FormatFloat(*o.Float, 'f', -1, 64), nil
	case o.Int != nil:
		return strconv.Itoa(*o.Int), nil
	case o.Bool != nil:
		return strconv.FormatBool(*o.Bool), nil
	}
	return "", fmt.Errorf("empty hypr option")
}

func parseGradient(s string) (a, b string, angle int) {
	a, b, angle = "e46592ee", "debb85ee", 45
	fields := strings.Fields(strings.TrimSpace(s))
	if len(fields) == 0 {
		return a, b, angle
	}
	if strings.Contains(s, "rgba(") {
		// already lua-ish; leave defaults if we can't split
		return a, b, angle
	}
	if len(fields) >= 1 {
		a = packedToRGBA(fields[0])
	}
	if len(fields) >= 2 && !strings.Contains(fields[1], "deg") {
		b = packedToRGBA(fields[1])
	} else {
		b = a
	}
	for _, f := range fields {
		if strings.HasSuffix(f, "deg") {
			angle = atoi(strings.TrimSuffix(f, "deg"), 45)
		}
	}
	return a, b, angle
}

func packedToRGBA(p string) string {
	p = strings.TrimPrefix(strings.ToLower(p), "0x")
	if len(p) == 8 {
		// aarrggbb -> rrggbbaa
		return p[2:] + p[:2]
	}
	if len(p) == 6 {
		return p + "ee"
	}
	return "e46592ee"
}

func hexRGB(s string) string {
	s = strings.TrimPrefix(palette.Hex(s), "#")
	if len(s) >= 6 {
		return s[:6]
	}
	return "e46592"
}

func luaBool(v bool) string {
	if v {
		return "true"
	}
	return "false"
}

func atoi(s string, fallback int) int {
	fields := strings.Fields(strings.TrimSpace(s))
	if len(fields) == 0 {
		return fallback
	}
	n, err := strconv.Atoi(fields[0])
	if err != nil {
		return fallback
	}
	return n
}

func atof(s string, fallback float64) float64 {
	f, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return fallback
	}
	return f
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func bytesTrim(b []byte) string {
	return strings.TrimSpace(string(b))
}
