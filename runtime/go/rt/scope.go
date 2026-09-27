package rt

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// ErrTimeout is returned by Run when the scope's deadline expires (CON-004).
var ErrTimeout = errors.New("egide: scope timed out")

// PanicError wraps a panic raised by a task (ERR-040, CON-003).
type PanicError struct {
	Value any
}

func (p *PanicError) Error() string { return fmt.Sprintf("egide: task panicked: %v", p.Value) }

// Scope groups tasks: Run returns only when every task spawned on the scope has finished (CON-001).
// The first failure cancels all sibling tasks (CON-003).
type Scope struct {
	ctx    context.Context
	cancel context.CancelCauseFunc
	wg     sync.WaitGroup
	once   sync.Once
	err    error
}

// Task is a handle on a task started with Spawn (CON-002).
type Task[T any] struct {
	done  chan struct{}
	value T
	err   error
}

// Run executes body with a new scope derived from parent. A zero timeout means no deadline.
// Cancellation of parent propagates to the scope and its tasks (CON-011).
func Run(parent context.Context, timeout time.Duration, body func(s *Scope) error) (err error) {
	ctx, cancel := context.WithCancelCause(parent)
	if timeout > 0 {
		var cancelTimeout context.CancelFunc
		ctx, cancelTimeout = context.WithTimeoutCause(ctx, timeout, ErrTimeout)
		defer cancelTimeout()
	}
	s := &Scope{ctx: ctx, cancel: cancel}
	defer cancel(nil)

	bodyErr := func() (e error) {
		defer func() {
			if r := recover(); r != nil {
				e = &PanicError{Value: r}
			}
		}()
		return body(s)
	}()
	if bodyErr != nil {
		s.fail(bodyErr)
	}
	s.wg.Wait()
	if s.err != nil {
		return s.err
	}
	if cause := context.Cause(ctx); errors.Is(cause, ErrTimeout) {
		return ErrTimeout
	}
	return nil
}

// Context returns the scope's context, cancelled when the scope fails, times out or its parent is cancelled.
func (s *Scope) Context() context.Context { return s.ctx }

func (s *Scope) fail(err error) {
	s.once.Do(func() {
		s.err = err
		s.cancel(err)
	})
}

// Spawn starts f as a task of s. A panic or an error returned by f cancels the whole scope.
func Spawn[T any](s *Scope, f func(ctx context.Context) (T, error)) *Task[T] {
	t := &Task[T]{done: make(chan struct{})}
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		defer close(t.done)
		defer func() {
			if r := recover(); r != nil {
				t.err = &PanicError{Value: r}
				s.fail(t.err)
			}
		}()
		t.value, t.err = f(s.ctx)
		if t.err != nil {
			s.fail(t.err)
		}
	}()
	return t
}

// Join waits for the task and returns its result.
func (t *Task[T]) Join() (T, error) {
	<-t.done
	return t.value, t.err
}
