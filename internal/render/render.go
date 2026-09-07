package render

import (
	"fmt"
	"sort"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

const Slogan = "NO WORKTREES"

type Styles struct {
	Banner lipgloss.Style
	Sun    lipgloss.Style
	Muted  lipgloss.Style
	Body   lipgloss.Style
	Box    lipgloss.Style
	Ok     lipgloss.Style
	Bad    lipgloss.Style
	Dim    lipgloss.Style
}

func From(p palette.Palette) Styles {
	banner := lipgloss.Color(palette.Hex(p.Accent))
	sun := lipgloss.Color(palette.Hex(p.Yellow))
	fg := lipgloss.Color(palette.Hex(p.Foreground))
	muted := lipgloss.Color(palette.Hex(p.Muted))
	bg := lipgloss.Color(palette.Hex(p.Background))
	dirt := lipgloss.Color(palette.Hex(p.LighterBackground))
	green := lipgloss.Color(palette.Hex(p.Green))
	red := lipgloss.Color(palette.Hex(p.Red))
	return Styles{
		Banner: lipgloss.NewStyle().Foreground(banner).Bold(true),
		Sun:    lipgloss.NewStyle().Foreground(sun).Bold(true),
		Muted:  lipgloss.NewStyle().Foreground(muted),
		Body:   lipgloss.NewStyle().Foreground(fg),
		Box: lipgloss.NewStyle().
			Border(lipgloss.ThickBorder()).
			BorderForeground(banner).
			Background(bg).
			Padding(0, 1),
		Ok:  lipgloss.NewStyle().Foreground(green),
		Bad: lipgloss.NewStyle().Foreground(red).Bold(true),
		Dim: lipgloss.NewStyle().Foreground(muted).Background(dirt),
	}
}

func Banner(width int, host, theme string, s Styles) string {
	if width < 40 {
		width = 40
	}
	left := s.Banner.Render("MAGIC") + "  " + s.Sun.Render(Slogan)
	right := s.Muted.Render(strings.TrimSpace(host + " · " + theme))
	gap := width - 4 - lipgloss.Width(left) - lipgloss.Width(right)
	if gap < 1 {
		gap = 1
	}
	line := left + strings.Repeat(" ", gap) + right
	return s.Box.Width(width - 2).Render(line + "\n" + s.Muted.Render("biker, not cyclist. full clone or don't."))
}

func Status(snap glass.Snapshot, s Styles) string {
	wt := s.Ok.Render("clone")
	if snap.GitRoot == "" {
		wt = s.Muted.Render("not a git repo")
	}
	if snap.Worktree {
		wt = s.Bad.Render("WORKTREE — haunted tests live here")
	}
	hypr := s.Muted.Render("missing")
	if snap.Hypr {
		hypr = s.Ok.Render("live")
	}
	rows := [][2]string{
		{"host", snap.Host},
		{"user", snap.User},
		{"omarchy", snap.Omarchy},
		{"theme", snap.Theme},
		{"font", snap.Font},
		{"hypr", hypr},
		{"gaps", fmt.Sprintf("%s / %s  border %s", snap.GapsIn, snap.GapsOut, snap.Border)},
		{"plugins", fmt.Sprintf("%d enabled / %d", snap.PluginEnabled, snap.PluginTotal)},
		{"tree", wt},
		{"cwd", snap.Cwd},
	}
	if snap.GitRoot != "" {
		rows = append(rows, [2]string{"git", snap.GitRoot})
	}
	var b strings.Builder
	keyW := 8
	for _, row := range rows {
		k := s.Muted.Render(fmt.Sprintf("%-*s", keyW, row[0]))
		fmt.Fprintf(&b, "  %s  %s\n", k, s.Body.Render(row[1]))
	}
	return b.String()
}

func Doctor(snap glass.Snapshot, s Styles) string {
	var b strings.Builder
	fmt.Fprintln(&b, s.Sun.Render("  "+Slogan))
	check := func(name, val string, ok bool) {
		mark := s.Ok.Render("ok")
		if !ok {
			mark = s.Bad.Render("no")
		}
		fmt.Fprintf(&b, "  %s  %-10s %s\n", mark, name, s.Body.Render(val))
	}
	check("omarchy", snap.Omarchy, snap.Omarchy != "")
	check("hyprctl", boolText(snap.Hypr, "live", "missing"), snap.Hypr)
	check("theme", snap.Theme, snap.Theme != "")
	treeVal := "full clone"
	treeOK := true
	if snap.Worktree {
		treeVal = "git worktree — this is why tests feel haunted"
		treeOK = false
	} else if snap.GitRoot == "" {
		treeVal = "no .git"
	}
	check("tree", treeVal, treeOK)
	check("cwd", snap.Cwd, true)
	return b.String()
}

func Scan(snap glass.Snapshot, s Styles) string {
	byMon := map[string][]glass.Workspace{}
	monOrder := []string{}
	seen := map[string]bool{}
	for _, m := range snap.Monitors {
		if !seen[m.Name] {
			monOrder = append(monOrder, m.Name)
			seen[m.Name] = true
		}
	}
	for _, w := range snap.Workspaces {
		byMon[w.Monitor] = append(byMon[w.Monitor], w)
		if !seen[w.Monitor] {
			monOrder = append(monOrder, w.Monitor)
			seen[w.Monitor] = true
		}
	}
	clientsByWS := map[int][]glass.Client{}
	for _, c := range snap.Clients {
		if !c.Mapped || c.Hidden {
			continue
		}
		clientsByWS[c.Workspace.ID] = append(clientsByWS[c.Workspace.ID], c)
	}
	monMeta := map[string]glass.Monitor{}
	for _, m := range snap.Monitors {
		monMeta[m.Name] = m
	}
	var b strings.Builder
	for _, name := range monOrder {
		m, ok := monMeta[name]
		head := name
		if ok {
			head = fmt.Sprintf("%s  %d×%d", name, m.Width, m.Height)
			if m.Focused {
				head += "  ●"
			}
		}
		fmt.Fprintln(&b, s.Sun.Render("  "+head))
		ws := byMon[name]
		sort.Slice(ws, func(i, j int) bool { return ws[i].ID < ws[j].ID })
		for _, w := range ws {
			mark := " "
			if ok && m.Active.ID == w.ID {
				mark = "●"
			}
			fmt.Fprintf(&b, "    %s %s  %s\n",
				s.Banner.Render(fmt.Sprintf("%d", w.ID)),
				s.Muted.Render(mark),
				s.Body.Render(fmt.Sprintf("%d win", w.Windows)))
			for _, c := range clientsByWS[w.ID] {
				title := strings.TrimSpace(c.Title)
				if title == "" {
					title = c.Class
				}
				if len(title) > 64 {
					title = title[:61] + "…"
				}
				fmt.Fprintf(&b, "        %s  %s\n",
					s.Muted.Render(c.Class),
					s.Body.Render(title))
			}
		}
	}
	if b.Len() == 0 {
		return s.Muted.Render("  no hypr clients")
	}
	return b.String()
}

func Help() string {
	return strings.TrimSpace(`
magic — Omarchy spellbook. NO WORKTREES. Biker, not cyclist.

  magic            open the spellbook
  magic status     machine card
  magic pulse      breathe hypr gaps
  magic flash      banner magenta / sun gold
  magic jump       plant the no-worktrees theme
  magic notify     flag on the glass
  magic scan       workspaces + clients
  magic watch      hypr events
  magic doctor     trees vs clones

  noworktrees      same as magic jump

No git worktrees. Full clone or don't.
`) + "\n"
}

func boolText(ok bool, yes, no string) string {
	if ok {
		return yes
	}
	return no
}
