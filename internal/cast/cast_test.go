package cast

import (
	"context"
	"strings"
	"testing"

	"github.com/jordanpartridge/omarchy-rice/internal/palette"
)

type fakeHypr struct {
	opts map[string]string
	log  []string
}

func (f *fakeHypr) Option(_ context.Context, name string) (string, error) {
	return f.opts[name], nil
}

func (f *fakeHypr) Keyword(_ context.Context, name, value string) error {
	f.log = append(f.log, name+"="+value)
	f.opts[name] = value
	return nil
}

func TestPlanPulseReturnsHome(t *testing.T) {
	frames := PlanPulse(5, 10, 2, 12, 4)
	if len(frames) == 0 {
		t.Fatal("no frames")
	}
	peak := frames[0]
	for _, f := range frames {
		if f.GapsIn > peak.GapsIn {
			peak = f
		}
	}
	if peak.GapsIn != 5+12 {
		t.Fatalf("peak in %d", peak.GapsIn)
	}
	last := frames[len(frames)-1]
	if last.GapsIn != 5 || last.GapsOut != 10 {
		t.Fatalf("did not restore: %+v", last)
	}
}

func TestPulseRestoresOriginal(t *testing.T) {
	h := &fakeHypr{opts: map[string]string{
		"general:gaps_in":     "5 5 5 5",
		"general:gaps_out":    "10 10 10 10",
		"general:border_size": "2",
	}}
	msg, err := Pulse(context.Background(), h)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(msg, "restored") {
		t.Fatal(msg)
	}
	if h.opts["general:gaps_in"] != "5 5 5 5" {
		t.Fatalf("gaps_in ended at %s", h.opts["general:gaps_in"])
	}
	if h.opts["general:gaps_out"] != "10 10 10 10" {
		t.Fatalf("gaps_out ended at %s", h.opts["general:gaps_out"])
	}
	if len(h.log) < 6 {
		t.Fatalf("expected a breathe, got %d keywords", len(h.log))
	}
}

func TestFlashUsesPersonaColors(t *testing.T) {
	h := &fakeHypr{opts: map[string]string{
		"general:col.active_border": "rgba(e46592ee) rgba(debb85ee) 45deg",
	}}
	p := palette.Jump()
	if _, err := Flash(context.Background(), h, p); err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(h.log, "\n")
	if !strings.Contains(joined, "e46592") {
		t.Fatal("missing banner magenta")
	}
	if !strings.Contains(joined, "debb85") {
		t.Fatal("missing sun gold")
	}
}

func TestParseOptionJSON(t *testing.T) {
	v, err := parseOptionJSON([]byte(`{"option":"general:gaps_in","css":"5 5 5 5","set":true}`))
	if err != nil || v != "5 5 5 5" {
		t.Fatalf("%q %v", v, err)
	}
	v, err = parseOptionJSON([]byte(`{"int":2,"set":true}`))
	if err != nil || v != "2" {
		t.Fatalf("%q %v", v, err)
	}
}
