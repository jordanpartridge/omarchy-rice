package main

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/jordanpartridge/omarchy-rice/internal/cast"
	"github.com/jordanpartridge/omarchy-rice/internal/glass"
	"github.com/jordanpartridge/omarchy-rice/internal/render"
	"github.com/jordanpartridge/omarchy-rice/internal/tui"
)

func main() {
	os.Exit(run(os.Args))
}

func run(args []string) int {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	bin := filepath.Base(args[0])
	if bin == "noworktrees" {
		return wrap(cast.Jump(ctx))
	}

	if len(args) < 2 {
		if isTTY() {
			if err := tui.Run(); err != nil {
				fmt.Fprintln(os.Stderr, err)
				return 1
			}
			return 0
		}
		return cmdStatus(ctx)
	}

	switch args[1] {
	case "help", "-h", "--help":
		fmt.Fprint(os.Stdout, render.Help())
		return 0
	case "status":
		return cmdStatus(ctx)
	case "pulse":
		return wrap(cast.Pulse(ctx, cast.LiveHypr{}))
	case "flash":
		snap := glass.Capture(ctx)
		return wrap(cast.Flash(ctx, cast.LiveHypr{}, snap.Palette))
	case "jump":
		return wrap(cast.Jump(ctx))
	case "notify":
		headline, body := render.Slogan, "biker, not cyclist"
		if len(args) > 2 {
			headline = args[2]
		}
		if len(args) > 3 {
			body = strings.Join(args[3:], " ")
		}
		return wrap(cast.Notify(ctx, headline, body))
	case "scan":
		return cmdScan(ctx)
	case "doctor":
		return cmdDoctor(ctx)
	case "watch":
		return cmdWatch(ctx)
	default:
		fmt.Fprintf(os.Stderr, "unknown spell %q\n\n%s", args[1], render.Help())
		return 2
	}
}

func cmdStatus(ctx context.Context) int {
	snap := glass.Capture(ctx)
	s := render.From(snap.Palette)
	fmt.Println(render.Banner(72, snap.Host, snap.Theme, s))
	fmt.Print(render.Status(snap, s))
	return 0
}

func cmdScan(ctx context.Context) int {
	snap := glass.Capture(ctx)
	s := render.From(snap.Palette)
	fmt.Println(render.Banner(72, snap.Host, snap.Theme, s))
	fmt.Print(render.Scan(snap, s))
	return 0
}

func cmdDoctor(ctx context.Context) int {
	snap := glass.Capture(ctx)
	s := render.From(snap.Palette)
	fmt.Println(render.Banner(72, snap.Host, snap.Theme, s))
	fmt.Print(render.Doctor(snap, s))
	if snap.Worktree {
		return 2
	}
	return 0
}

func cmdWatch(ctx context.Context) int {
	sock := glass.EventSocket()
	if sock == "" {
		fmt.Fprintln(os.Stderr, "no HYPRLAND_INSTANCE_SIGNATURE")
		return 1
	}
	d := net.Dialer{}
	conn, err := d.DialContext(ctx, "unix", sock)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer conn.Close()
	go func() {
		<-ctx.Done()
		_ = conn.SetReadDeadline(time.Now())
	}()
	sc := bufio.NewScanner(conn)
	for sc.Scan() {
		fmt.Println(sc.Text())
	}
	return 0
}

func wrap(msg string, err error) int {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	if msg != "" {
		fmt.Println(msg)
	}
	return 0
}

func isTTY() bool {
	fi, err := os.Stdout.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}
