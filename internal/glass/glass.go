package glass

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

type Snapshot struct {
	Host          string
	User          string
	Cwd           string
	Omarchy       string
	Theme         string
	Font          string
	Palette       palette.Palette
	Monitors      []Monitor
	Workspaces    []Workspace
	Clients       []Client
	GapsIn        string
	GapsOut       string
	Border        string
	ActiveBorder  string
	Worktree      bool
	GitRoot       string
	Hypr          bool
	PluginEnabled int
	PluginTotal   int
}

type Monitor struct {
	Name     string `json:"name"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
	Focused  bool   `json:"focused"`
	Disabled bool   `json:"disabled"`
	Active   struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"activeWorkspace"`
}

type Workspace struct {
	ID              int    `json:"id"`
	Name            string `json:"name"`
	Monitor         string `json:"monitor"`
	Windows         int    `json:"windows"`
	LastWindowTitle string `json:"lastwindowtitle"`
	MonitorID       int    `json:"monitorID"`
}

type Client struct {
	Class     string          `json:"class"`
	Title     string          `json:"title"`
	Mapped    bool            `json:"mapped"`
	Hidden    bool            `json:"hidden"`
	Floating  bool            `json:"floating"`
	Monitor   json.RawMessage `json:"monitor"`
	Workspace struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"workspace"`
}

func (c Client) MonitorLabel() string {
	var s string
	if json.Unmarshal(c.Monitor, &s) == nil && s != "" {
		return s
	}
	var n int
	if json.Unmarshal(c.Monitor, &n) == nil {
		return strconv.Itoa(n)
	}
	return "?"
}

func Capture(ctx context.Context) Snapshot {
	if _, ok := ctx.Deadline(); !ok {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 4*time.Second)
		defer cancel()
	}
	s := Snapshot{
		Palette: palette.Jump(),
		Hypr:    lookPath("hyprctl"),
	}
	if h, err := os.Hostname(); err == nil {
		s.Host = h
	}
	if u, err := user.Current(); err == nil {
		s.User = u.Username
	}
	if cwd, err := os.Getwd(); err == nil {
		s.Cwd = cwd
		s.Worktree, s.GitRoot = DetectWorktree(cwd)
	}
	s.Omarchy = strings.TrimSpace(runOut(ctx, "omarchy", "version"))
	s.Theme = ThemeName()
	s.Font = strings.TrimSpace(runOut(ctx, "omarchy", "font", "current"))
	if p, err := palette.Load(ThemeColorsPath()); err == nil {
		s.Palette = p
	}
	if s.Hypr {
		_ = json.Unmarshal(runBytes(ctx, "hyprctl", "monitors", "-j"), &s.Monitors)
		_ = json.Unmarshal(runBytes(ctx, "hyprctl", "workspaces", "-j"), &s.Workspaces)
		_ = json.Unmarshal(runBytes(ctx, "hyprctl", "clients", "-j"), &s.Clients)
		s.GapsIn = option(ctx, "general:gaps_in")
		s.GapsOut = option(ctx, "general:gaps_out")
		s.Border = option(ctx, "general:border_size")
		s.ActiveBorder = option(ctx, "general:col.active_border")
	}
	s.PluginEnabled, s.PluginTotal = pluginCounts(ctx)
	return s
}

func ThemeName() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	b, err := os.ReadFile(filepath.Join(home, ".local/state/omarchy/current/theme.name"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func ThemeColorsPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".local/state/omarchy/current/theme/colors.toml")
}

func ThemeSlug(name string) string {
	name = strings.TrimSpace(strings.ToLower(name))
	name = strings.ReplaceAll(name, " ", "-")
	return name
}

func DetectWorktree(dir string) (isWorktree bool, gitRoot string) {
	dir, err := filepath.Abs(dir)
	if err != nil {
		return false, ""
	}
	for {
		git := filepath.Join(dir, ".git")
		info, err := os.Lstat(git)
		if err == nil {
			if info.IsDir() {
				return false, dir
			}
			return true, dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return false, ""
		}
		dir = parent
	}
}

func lookPath(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

func runOut(ctx context.Context, name string, args ...string) string {
	return strings.TrimSpace(string(runBytes(ctx, name, args...)))
}

func runBytes(ctx context.Context, name string, args ...string) []byte {
	cmd := exec.CommandContext(ctx, name, args...)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return nil
	}
	return bytes.TrimSpace(buf.Bytes())
}

type optionJSON struct {
	CSS      string `json:"css"`
	Gradient string `json:"gradient"`
	Str      string `json:"str"`
	Int      *int   `json:"int"`
}

func option(ctx context.Context, name string) string {
	var o optionJSON
	if err := json.Unmarshal(runBytes(ctx, "hyprctl", "getoption", name, "-j"), &o); err != nil {
		return ""
	}
	switch {
	case o.CSS != "":
		return o.CSS
	case o.Gradient != "":
		return o.Gradient
	case o.Str != "":
		return o.Str
	case o.Int != nil:
		return strconv.Itoa(*o.Int)
	}
	return ""
}

func pluginCounts(ctx context.Context) (enabled, total int) {
	raw := runBytes(ctx, "omarchy", "plugin", "list", "--json")
	if len(raw) == 0 {
		return 0, 0
	}
	var plugins []struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.Unmarshal(raw, &plugins); err != nil {
		return 0, 0
	}
	for _, p := range plugins {
		total++
		if p.Enabled {
			enabled++
		}
	}
	return enabled, total
}

func FirstCSSGap(s string) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	field := strings.Fields(s)[0]
	n, _ := strconv.Atoi(field)
	return n
}

func Wallpaper() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	candidates := []string{
		filepath.Join(home, ".local/state/omarchy/current/background"),
		filepath.Join(home, ".config/omarchy/themes/no-worktrees/backgrounds/0-jordan-jump.jpg"),
		filepath.Join(home, ".local/state/omarchy/current/theme/backgrounds/0-jordan-jump.jpg"),
	}
	for _, p := range candidates {
		target := p
		if dest, err := filepath.EvalSymlinks(p); err == nil {
			target = dest
		}
		if st, err := os.Stat(target); err == nil && !st.IsDir() {
			return target
		}
	}
	return ""
}

func EventSocket() string {
	sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if sig == "" || runtime == "" {
		return ""
	}
	return filepath.Join(runtime, "hypr", sig, ".socket2.sock")
}
