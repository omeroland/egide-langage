(** JUnit XML report, in the de-facto schema understood by CI systems (GitHub Actions test
    reporters, GitLab, Jenkins). *)

type status = Pass | Fail of string | Skip of string

type case = {
  file : string;  (** Test file path, e.g. [tests/conformance/lexical/layout_bad_dedent.egd]. *)
  name : string;  (** Case name: the file's base name without [.egd], plus [[backend]] for runs. *)
  status : status;
  time : float;
}

val to_xml : case list -> string
(** One [<testsuite>] per directory (in order of first appearance), one [<testcase>] per case.
    Failures are [<failure>] elements, skips [<skipped>]. Text is escaped and sanitised: bytes that
    are not valid UTF-8 and characters XML 1.0 forbids are written as [\xNN], so a test that feeds
    the compiler invalid UTF-8 still yields a well-formed report. *)

val sanitize : string -> string
(** The sanitisation step of {!to_xml} alone (no XML escaping). *)
