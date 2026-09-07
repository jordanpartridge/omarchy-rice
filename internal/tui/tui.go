package tui

import (
	"context"
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/jordanpartridge/omarchy-rice/internal/cast"
	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/palette"
	"github.com/jordanpartridge/omarchy-rice/internal/render"
)

type pane int

const (
	paneGlass pane = iota
	paneScan
	paneDoctor
)

type spell struct {
	key   string
	name  string
	blurb string
}

var spells = []spell{
	{"1", "pulse", "breathe hypr gaps"},
	{"2", "flash", "banner / sun border"},
	{"3", "jump", "plant no-worktrees"},
	{"4", "notify", "flag on the glass"},
	{"5", "scan", "who is on the glass"},
	{"6", "doctor", "trees vs clones"},
}

type model struct {
	width  int
	height int
	cursor int
	pane   pane
	snap   glass.Snapshot
	styles render.Styles
	log    []string
	busy   bool
	status string
}

type snapMsg glass.Snapshot
type doneMsg struct{ line string }
type failMsg struct{ err error }
type tickMsg time.Time

func Run() error {
	p := tea.NewProgram(newModel(), tea.WithAltScreen())
	_, err := p.Run()
	return err
}

func newModel() model {
	p := palette.Jump()
	if loaded, err := palette.Load(glass.ThemeColorsPath()); err == nil {
		p = loaded
	}
	return model{
		styles: render.From(p),
		pane:   paneGlass,
		status: "enter casts · q quits",
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(loadSnap, tick())
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil
	case snapMsg:
		m.snap = glass.Snapshot(msg)
		m.styles = render.From(m.snap.Palette)
		return m, nil
	case tickMsg:
		if m.busy {
			return m, tick()
		}
		return m, tea.Batch(loadSnap, tick())
	case doneMsg:
		m.busy = false
		m.push(msg.line)
		m.status = msg.line
		return m, loadSnap
	case failMsg:
		m.busy = false
		m.push("fail  " + msg.err.Error())
		m.status = msg.err.Error()
		return m, nil
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "j", "down":
			if m.cursor < len(spells)-1 {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "1", "2", "3", "4", "5", "6":
			m.cursor = int(msg.String()[0] - '1')
			return m.cast()
		case "enter", " ":
			return m.cast()
		}
	}
	return m, nil
}

func (m model) View() string {
	w := m.width
	if w < 60 {
		w = 60
	}
	banner := render.Banner(w, m.snap.Host, m.snap.Theme, m.styles)
	left := m.spellList()
	right := m.rightPane()
	gap := 2
	leftW := 34
	if w < 80 {
		leftW = 28
	}
	rightW := w - leftW - gap
	if rightW < 24 {
		rightW = 24
	}
	left = lipgloss.NewStyle().Width(leftW).Render(left)
	right = lipgloss.NewStyle().Width(rightW).Render(right)
	body := lipgloss.JoinHorizontal(lipgloss.Top, left, strings.Repeat(" ", gap), right)
	log := m.logView()
	foot := m.styles.Muted.Render("  " + m.status)
	return banner + "\n\n" + body + "\n\n" + log + "\n" + foot
}

func (m model) spellList() string {
	var b strings.Builder
	fmt.Fprintln(&b, m.styles.Sun.Render("  spells"))
	for i, sp := range spells {
		cursor := "  "
		name := m.styles.Body.Render(sp.name)
		if i == m.cursor {
			cursor = m.styles.Banner.Render("▸ ")
			name = m.styles.Banner.Render(sp.name)
		}
		fmt.Fprintf(&b, "%s%s %s  %s\n",
			cursor,
			m.styles.Muted.Render(sp.key),
			name,
			m.styles.Muted.Render(sp.blurb))
	}
	return b.String()
}

func (m model) rightPane() string {
	switch m.pane {
	case paneScan:
		return m.styles.Sun.Render("  glass") + "\n" + render.Scan(m.snap, m.styles)
	case paneDoctor:
		return render.Doctor(m.snap, m.styles)
	default:
		return m.styles.Sun.Render("  glass") + "\n" + render.Status(m.snap, m.styles)
	}
}

func (m model) logView() string {
	if len(m.log) == 0 {
		return m.styles.Muted.Render("  log  ·  jump the clone, don't split the tree")
	}
	n := len(m.log)
	start := 0
	if n > 4 {
		start = n - 4
	}
	var b strings.Builder
	fmt.Fprintln(&b, m.styles.Muted.Render("  log"))
	for _, line := range m.log[start:] {
		fmt.Fprintf(&b, "  · %s\n", m.styles.Body.Render(line))
	}
	return b.String()
}

func (m *model) push(line string) {
	m.log = append(m.log, line)
	if len(m.log) > 24 {
		m.log = m.log[len(m.log)-24:]
	}
}

func (m model) cast() (tea.Model, tea.Cmd) {
	if m.busy {
		return m, nil
	}
	sp := spells[m.cursor]
	switch sp.name {
	case "scan":
		m.pane = paneScan
		m.status = "scan"
		return m, nil
	case "doctor":
		m.pane = paneDoctor
		m.status = "doctor"
		return m, nil
	}
	m.busy = true
	m.status = "casting " + sp.name + "…"
	name := sp.name
	pal := m.snap.Palette
	return m, func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		line, err := runSpell(ctx, name, pal)
		if err != nil {
			return failMsg{err: err}
		}
		return doneMsg{line: line}
	}
}

func runSpell(ctx context.Context, name string, pal palette.Palette) (string, error) {
	h := cast.LiveHypr{}
	switch name {
	case "pulse":
		return cast.Pulse(ctx, h)
	case "flash":
		return cast.Flash(ctx, h, pal)
	case "jump":
		return cast.Jump(ctx)
	case "notify":
		return cast.Notify(ctx, render.Slogan, "biker, not cyclist")
	default:
		return "", fmt.Errorf("unknown spell %s", name)
	}
}

func loadSnap() tea.Msg {
	return snapMsg(glass.Capture(context.Background()))
}

func tick() tea.Cmd {
	return tea.Tick(2*time.Second, func(t time.Time) tea.Msg { return tickMsg(t) })
}
