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

func (f *fakeHypr) Config(_ context.Context, lua string) error {
	f.log = append(f.log, lua)
	return nil
}

func baseFake() *fakeHypr {
	return &fakeHypr{opts: map[string]string{
		"general:gaps_in":           "5 5 5 5",
		"general:gaps_out":          "10 10 10 10",
		"general:border_size":       "2",
		"decoration:rounding":       "0",
		"cursor:zoom_factor":        "1",
		"decoration:dim_inactive":   "false",
		"decoration:dim_strength":   "0.5",
		"general:col.active_border": "eee46592 eedebb85 45deg",
	}}
}

func TestPlanRideCrouchThenApex(t *testing.T) {
	base := Look{GapsIn: 5, GapsOut: 10, Border: 2, Zoom: 1, DimStrength: 0.5, BorderA: "e46592ee", BorderB: "debb85ee", Angle: 45}
	beats := PlanRide(base, palette.Jump())
	if len(beats) < 5 {
		t.Fatalf("short ride %d", len(beats))
	}
	if beats[0].Name != "crouch" {
		t.Fatal(beats[0].Name)
	}
	if beats[0].GapsOut >= 10 {
		t.Fatalf("crouch should compress, got %d", beats[0].GapsOut)
	}
	var apex Beat
	for _, b := range beats {
		if b.Zoom > apex.Zoom {
			apex = b
		}
	}
	if apex.Name != "apex" || apex.Zoom < 1.4 {
		t.Fatalf("apex %+v", apex)
	}
	if !strings.Contains(apex.Lua(), "hl.config") {
		t.Fatal(apex.Lua())
	}
	if !strings.Contains(apex.Lua(), "zoom_factor") {
		t.Fatal(apex.Lua())
	}
}

func TestRideRestoresOriginalLua(t *testing.T) {
	h := baseFake()
	msg, err := Ride(context.Background(), h, palette.Jump())
	if err != nil {
		t.Fatal(err)
	}
	if msg != "jumped" {
		t.Fatal(msg)
	}
	if len(h.log) < 4 {
		t.Fatalf("expected a ride, got %d configs", len(h.log))
	}
	last := h.log[len(h.log)-1]
	if !strings.Contains(last, "gaps_in = 5") || !strings.Contains(last, "gaps_out = 10") {
		t.Fatalf("did not land: %s", last)
	}
	if !strings.Contains(last, "zoom_factor = 1.00") {
		t.Fatalf("zoom not restored: %s", last)
	}
}

func TestParseOptionJSONKinds(t *testing.T) {
	v, err := parseOptionJSON([]byte(`{"css":"5 5 5 5"}`))
	if err != nil || v != "5 5 5 5" {
		t.Fatalf("%q %v", v, err)
	}
	v, err = parseOptionJSON([]byte(`{"float":1.45}`))
	if err != nil || v != "1.45" {
		t.Fatalf("%q %v", v, err)
	}
	v, err = parseOptionJSON([]byte(`{"bool":true}`))
	if err != nil || v != "true" {
		t.Fatalf("%q %v", v, err)
	}
}

func TestPackedToRGBA(t *testing.T) {
	if packedToRGBA("eee46592") != "e46592ee" {
		t.Fatal(packedToRGBA("eee46592"))
	}
}

func TestLookLuaUsesEvalConfig(t *testing.T) {
	lua := Look{GapsIn: 5, GapsOut: 10, Border: 2, Zoom: 1, DimStrength: 0.5, BorderA: "e46592ee", BorderB: "debb85ee", Angle: 45}.Lua()
	if strings.Contains(lua, "keyword") {
		t.Fatal("keyword is a no-op on Omarchy")
	}
	if !strings.HasPrefix(lua, "hl.config") {
		t.Fatal(lua)
	}
}
