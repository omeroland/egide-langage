package rt

// Option is the representation of Égide's Option[T] (TYP-004) in generated Go code.
type Option[T any] struct {
	value T
	ok    bool
}

// Some builds a present Option.
func Some[T any](v T) Option[T] { return Option[T]{value: v, ok: true} }

// None builds an absent Option.
func None[T any]() Option[T] { return Option[T]{} }

// Get returns the value and whether it is present.
func (o Option[T]) Get() (T, bool) { return o.value, o.ok }

// Result is the representation of Égide's Result[T, E] (ERR-001) in generated Go code.
type Result[T any, E any] struct {
	value T
	err   E
	ok    bool
}

// Ok builds a successful Result.
func Ok[T any, E any](v T) Result[T, E] { return Result[T, E]{value: v, ok: true} }

// Err builds a failed Result.
func Err[T any, E any](e E) Result[T, E] { return Result[T, E]{err: e} }

// IsOk reports whether the Result is Ok.
func (r Result[T, E]) IsOk() bool { return r.ok }

// Unpack returns the value, the error and whether the Result is Ok; generated code uses it for `?`.
func (r Result[T, E]) Unpack() (T, E, bool) { return r.value, r.err, r.ok }
