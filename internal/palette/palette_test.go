package palette

import (
	"strings"
	"testing"
)

func TestJumpPersona(t *testing.T) {
	p := Jump()
	if p.Accent != "#e46592" {
		t.Fatalf("banner magenta: got %s", p.Accent)
	}
	if p.Yellow != "#debb85" {
		t.Fatalf("sun gold: got %s", p.Yellow)
	}
	if p.Background != "#140c18" {
		t.Fatalf("dusk dirt: got %s", p.Background)
	}
}

func TestParseOverridesJump(t *testing.T) {
	in := `
# comment
mode = "dark"
accent = "#ff00aa"
yellow = "#112233"
`
	p, err := Parse(strings.NewReader(in))
	if err != nil {
		t.Fatal(err)
	}
	if p.Accent != "#ff00aa" {
		t.Fatalf("accent: %s", p.Accent)
	}
	if p.Yellow != "#112233" {
		t.Fatalf("yellow: %s", p.Yellow)
	}
	if p.Magenta != "#e46592" {
		t.Fatalf("unset keys should keep Jump: %s", p.Magenta)
	}
}

func TestParseRejectsJunk(t *testing.T) {
	_, err := Parse(strings.NewReader("not a toml line"))
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestHex(t *testing.T) {
	if Hex("e46592") != "#e46592" {
		t.Fatal(Hex("e46592"))
	}
	if Hex("#debb85") != "#debb85" {
		t.Fatal(Hex("#debb85"))
	}
}

func TestLoadNoWorktreesTheme(t *testing.T) {
	p, err := Load("../../config/omarchy/themes/no-worktrees/colors.toml")
	if err != nil {
		t.Fatal(err)
	}
	if p.Accent != "#e46592" {
		t.Fatalf("theme accent %s", p.Accent)
	}
	if p.HyprActiveBorder == "" {
		t.Fatal("missing hypr border")
	}
}
