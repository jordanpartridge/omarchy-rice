package render

import (
	"strings"
	"testing"

	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

func TestBannerCarriesPersona(t *testing.T) {
	s := From(palette.Jump())
	out := Banner(72, "Thor", "no-worktrees", s)
	for _, want := range []string{"MAGIC", Slogan, "Thor", "no-worktrees"} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in:\n%s", want, out)
		}
	}
}

func TestDoctorFlagsWorktree(t *testing.T) {
	s := From(palette.Jump())
	out := Doctor(glass.Snapshot{Worktree: true, Cwd: "/tmp/haunted", GitRoot: "/tmp/haunted"}, s)
	if !strings.Contains(out, Slogan) {
		t.Fatal(out)
	}
	if !strings.Contains(strings.ToLower(out), "worktree") {
		t.Fatal(out)
	}
}

func TestScanGroupsByMonitor(t *testing.T) {
	s := From(palette.Jump())
	snap := glass.Snapshot{
		Monitors: []glass.Monitor{
			{Name: "DP-7", Width: 3840, Height: 2160, Focused: true},
		},
		Workspaces: []glass.Workspace{
			{ID: 8, Name: "8", Monitor: "DP-7", Windows: 1},
		},
		Clients: []glass.Client{
			{Class: "foot", Title: "magic", Mapped: true, Workspace: struct {
				ID   int    `json:"id"`
				Name string `json:"name"`
			}{ID: 8, Name: "8"}},
		},
	}
	out := Scan(snap, s)
	if !strings.Contains(out, "DP-7") || !strings.Contains(out, "foot") || !strings.Contains(out, "magic") {
		t.Fatal(out)
	}
}

func TestHelpListsSpells(t *testing.T) {
	h := Help()
	for _, want := range []string{"pulse", "jump", "NO WORKTREES", "full clone"} {
		if !strings.Contains(strings.ToLower(h), strings.ToLower(want)) && !strings.Contains(h, want) {
			t.Fatalf("missing %q", want)
		}
	}
}
