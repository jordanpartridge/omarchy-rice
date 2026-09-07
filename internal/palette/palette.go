package palette

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

// Palette is an Omarchy colors.toml. Jump() is the no-worktrees persona:
// dusk dirt, banner magenta, sun gold.
type Palette struct {
	Mode               string
	Accent             string
	Selection          string
	Muted              string
	Background         string
	DarkBackground     string
	DarkerBackground   string
	LighterBackground  string
	Foreground         string
	DarkForeground     string
	LightForeground    string
	BrightForeground   string
	Red                string
	Yellow             string
	Orange             string
	Green              string
	Cyan               string
	Blue               string
	Magenta            string
	Brown              string
	BrightRed          string
	BrightYellow       string
	BrightGreen        string
	BrightCyan         string
	BrightBlue         string
	BrightMagenta      string
	HyprActiveBorder   string
	HyprInactiveBorder string
}

// Jump is the fatbike-at-dusk persona. Used when no colors.toml is on disk.
func Jump() Palette {
	return Palette{
		Mode:               "dark",
		Accent:             "#e46592",
		Selection:          "#3a2438",
		Muted:              "#7a5e78",
		Background:         "#140c18",
		DarkBackground:     "#0c0810",
		DarkerBackground:   "#07050b",
		LighterBackground:  "#24182c",
		Foreground:         "#f0e2d0",
		DarkForeground:     "#8a7088",
		LightForeground:    "#e4d0c4",
		BrightForeground:   "#f7eee4",
		Red:                "#c45a6a",
		Yellow:             "#debb85",
		Orange:             "#c47a6a",
		Green:              "#6a7a48",
		Cyan:               "#a888b0",
		Blue:               "#5a4a78",
		Magenta:            "#e46592",
		Brown:              "#5a3840",
		BrightRed:          "#e07080",
		BrightYellow:       "#f0d4a0",
		BrightGreen:        "#8a9a5c",
		BrightCyan:         "#c4a8c8",
		BrightBlue:         "#7a6a98",
		BrightMagenta:      "#f080a8",
		HyprActiveBorder:   "rgba(e46592ee) rgba(debb85ee) 45deg",
		HyprInactiveBorder: "rgba(3a2438aa)",
	}
}

func Load(path string) (Palette, error) {
	f, err := os.Open(path)
	if err != nil {
		return Palette{}, err
	}
	defer f.Close()
	return Parse(f)
}

func Parse(r io.Reader) (Palette, error) {
	p := Jump()
	raw := map[string]string{}
	sc := bufio.NewScanner(r)
	lineNo := 0
	for sc.Scan() {
		lineNo++
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			return Palette{}, fmt.Errorf("colors.toml:%d: missing =", lineNo)
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)
		val = strings.Trim(val, `"`)
		if key == "" || val == "" {
			return Palette{}, fmt.Errorf("colors.toml:%d: empty key or value", lineNo)
		}
		raw[key] = val
	}
	if err := sc.Err(); err != nil {
		return Palette{}, err
	}
	apply(raw, &p)
	return p, nil
}

func apply(raw map[string]string, p *Palette) {
	set := func(dst *string, key string) {
		if v, ok := raw[key]; ok {
			*dst = v
		}
	}
	set(&p.Mode, "mode")
	set(&p.Accent, "accent")
	set(&p.Selection, "selection")
	set(&p.Muted, "muted")
	set(&p.Background, "background")
	set(&p.DarkBackground, "dark_background")
	set(&p.DarkerBackground, "darker_background")
	set(&p.LighterBackground, "lighter_background")
	set(&p.Foreground, "foreground")
	set(&p.DarkForeground, "dark_foreground")
	set(&p.LightForeground, "light_foreground")
	set(&p.BrightForeground, "bright_foreground")
	set(&p.Red, "red")
	set(&p.Yellow, "yellow")
	set(&p.Orange, "orange")
	set(&p.Green, "green")
	set(&p.Cyan, "cyan")
	set(&p.Blue, "blue")
	set(&p.Magenta, "magenta")
	set(&p.Brown, "brown")
	set(&p.BrightRed, "bright_red")
	set(&p.BrightYellow, "bright_yellow")
	set(&p.BrightGreen, "bright_green")
	set(&p.BrightCyan, "bright_cyan")
	set(&p.BrightBlue, "bright_blue")
	set(&p.BrightMagenta, "bright_magenta")
	set(&p.HyprActiveBorder, "hyprland_active_border")
	set(&p.HyprInactiveBorder, "hyprland_inactive_border")
}

func Hex(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "#e46592"
	}
	if strings.HasPrefix(s, "#") {
		return s
	}
	return "#" + s
}
