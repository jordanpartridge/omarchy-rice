package glass

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDetectWorktree_CloneVsPointer(t *testing.T) {
	root := t.TempDir()

	clone := filepath.Join(root, "clone")
	if err := os.MkdirAll(filepath.Join(clone, ".git"), 0o755); err != nil {
		t.Fatal(err)
	}
	wt, gitRoot := DetectWorktree(clone)
	if wt {
		t.Fatal("full clone must not look like a worktree")
	}
	if gitRoot != clone {
		t.Fatalf("git root %s", gitRoot)
	}

	pointer := filepath.Join(root, "worktree")
	if err := os.MkdirAll(pointer, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(pointer, ".git"), []byte("gitdir: /tmp/somewhere\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	wt, gitRoot = DetectWorktree(filepath.Join(pointer, "src"))
	if !wt {
		t.Fatal("pointer .git file is a worktree — this is the haunted path")
	}
	if gitRoot != pointer {
		t.Fatalf("git root %s", gitRoot)
	}
}

func TestDetectWorktree_NotGit(t *testing.T) {
	wt, root := DetectWorktree(t.TempDir())
	if wt || root != "" {
		t.Fatalf("plain dir: wt=%v root=%s", wt, root)
	}
}

func TestThemeSlug(t *testing.T) {
	if ThemeSlug("No Worktrees") != "no-worktrees" {
		t.Fatal(ThemeSlug("No Worktrees"))
	}
	if ThemeSlug("jordan-os") != "jordan-os" {
		t.Fatal(ThemeSlug("jordan-os"))
	}
}

func TestFirstCSSGap(t *testing.T) {
	if FirstCSSGap("5 5 5 5") != 5 {
		t.Fatal(FirstCSSGap("5 5 5 5"))
	}
	if FirstCSSGap("10") != 10 {
		t.Fatal(FirstCSSGap("10"))
	}
	if FirstCSSGap("") != 0 {
		t.Fatal("empty")
	}
}

func TestClientMonitorLabel(t *testing.T) {
	c := Client{Monitor: []byte(`1`)}
	if c.MonitorLabel() != "1" {
		t.Fatal(c.MonitorLabel())
	}
	c.Monitor = []byte(`"DP-7"`)
	if c.MonitorLabel() != "DP-7" {
		t.Fatal(c.MonitorLabel())
	}
}
