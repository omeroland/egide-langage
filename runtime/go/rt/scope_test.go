package rt

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

// spec: CON-001
func TestRunWaitsForAllTasks(t *testing.T) {
	var n atomic.Int32
	err := Run(context.Background(), 0, func(s *Scope) error {
		for i := 0; i < 10; i++ {
			Spawn(s, func(ctx context.Context) (int, error) {
				time.Sleep(time.Millisecond)
				n.Add(1)
				return 0, nil
			})
		}
		return nil
	})
	if err != nil || n.Load() != 10 {
		t.Fatalf("err=%v n=%d", err, n.Load())
	}
}

// spec: CON-003
func TestFirstErrorCancelsSiblings(t *testing.T) {
	boom := errors.New("boom")
	err := Run(context.Background(), 0, func(s *Scope) error {
		Spawn(s, func(ctx context.Context) (int, error) { return 0, boom })
		Spawn(s, func(ctx context.Context) (int, error) {
			select {
			case <-ctx.Done():
				return 0, ctx.Err()
			case <-time.After(5 * time.Second):
				return 0, errors.New("sibling was not cancelled")
			}
		})
		return nil
	})
	if !errors.Is(err, boom) {
		t.Fatalf("want boom, got %v", err)
	}
}

// spec: CON-003, ERR-040
func TestPanicBecomesError(t *testing.T) {
	err := Run(context.Background(), 0, func(s *Scope) error {
		Spawn(s, func(ctx context.Context) (int, error) { panic("bug") })
		return nil
	})
	var p *PanicError
	if !errors.As(err, &p) || p.Value != "bug" {
		t.Fatalf("want PanicError(bug), got %v", err)
	}
}

// spec: CON-004
func TestTimeout(t *testing.T) {
	err := Run(context.Background(), 10*time.Millisecond, func(s *Scope) error {
		Spawn(s, func(ctx context.Context) (int, error) {
			<-ctx.Done()
			return 0, nil
		})
		return nil
	})
	if !errors.Is(err, ErrTimeout) {
		t.Fatalf("want ErrTimeout, got %v", err)
	}
}

// spec: CON-002
func TestJoinReturnsValue(t *testing.T) {
	var got int
	err := Run(context.Background(), 0, func(s *Scope) error {
		task := Spawn(s, func(ctx context.Context) (int, error) { return 42, nil })
		v, err := task.Join()
		got = v
		return err
	})
	if err != nil || got != 42 {
		t.Fatalf("err=%v got=%d", err, got)
	}
}
