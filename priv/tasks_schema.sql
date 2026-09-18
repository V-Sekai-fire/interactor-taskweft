-- Task state for taskweft-mcp, one plan per project, stored in SQLite over the
-- FoundationDB VFS (weft_fdb_vfs).
--
-- Essential Tuple Normal Form: vocabularies are interned, optional facts live in
-- satellite relations rather than nullable columns, and nothing derivable is
-- stored. A step with no outcome has no row in step_outcome — absence is the
-- fact, not a NULL.

PRAGMA foreign_keys = ON;

-- A project is the unit of scope. The key is the git remote of the checkout,
-- normalised, so the same project is one row from any desk that clones it.
CREATE TABLE IF NOT EXISTS project (
  project_id INTEGER PRIMARY KEY,
  key        TEXT NOT NULL UNIQUE
) STRICT;

-- One plan is one planner run. domain_digest identifies the RECTGTN domain the
-- plan came from, so a plan can be traced back to what produced it.
CREATE TABLE IF NOT EXISTS plan (
  plan_id       INTEGER PRIMARY KEY,
  project_id    INTEGER NOT NULL REFERENCES project(project_id),
  domain_digest TEXT NOT NULL,
  created_at    INTEGER NOT NULL
) STRICT;

-- The current plan for a project. A separate relation rather than a flag on
-- plan, so "current" is one row that moves rather than a column to keep in sync.
CREATE TABLE IF NOT EXISTS project_current_plan (
  project_id INTEGER PRIMARY KEY REFERENCES project(project_id),
  plan_id    INTEGER NOT NULL REFERENCES plan(plan_id)
) STRICT;

-- Steps are ordered within a plan. `ord` is the planner's own 0-based index, the
-- one `replan <fail_step>` takes.
CREATE TABLE IF NOT EXISTS step (
  plan_id INTEGER NOT NULL REFERENCES plan(plan_id),
  ord     INTEGER NOT NULL,
  task    TEXT NOT NULL,
  PRIMARY KEY (plan_id, ord)
) STRICT;

-- Dependencies as a relation, so a step with two predecessors is two rows and a
-- step with none is no rows.
CREATE TABLE IF NOT EXISTS step_needs (
  plan_id     INTEGER NOT NULL,
  ord         INTEGER NOT NULL,
  needs_ord   INTEGER NOT NULL,
  PRIMARY KEY (plan_id, ord, needs_ord),
  FOREIGN KEY (plan_id, ord) REFERENCES step(plan_id, ord),
  FOREIGN KEY (plan_id, needs_ord) REFERENCES step(plan_id, ord),
  CHECK (needs_ord < ord)
) STRICT;

-- Interned outcome vocabulary. Seeded below; a value outside it cannot be
-- written, which is what keeps "done" from arriving as "Done" tomorrow.
CREATE TABLE IF NOT EXISTS outcome_kind (
  outcome_kind_id INTEGER PRIMARY KEY,
  name            TEXT NOT NULL UNIQUE
) STRICT;

INSERT OR IGNORE INTO outcome_kind (outcome_kind_id, name)
VALUES (1, 'done'), (2, 'failed'), (3, 'skipped');

-- Satellite: a step that has not run has no row here. No nullable status column,
-- so "not started" and "unknown" cannot be confused.
CREATE TABLE IF NOT EXISTS step_outcome (
  plan_id         INTEGER NOT NULL,
  ord             INTEGER NOT NULL,
  outcome_kind_id INTEGER NOT NULL REFERENCES outcome_kind(outcome_kind_id),
  at              INTEGER NOT NULL,
  PRIMARY KEY (plan_id, ord),
  FOREIGN KEY (plan_id, ord) REFERENCES step(plan_id, ord)
) STRICT;

-- Satellite: a note is optional, so it is its own relation rather than a column
-- that is empty for most rows.
CREATE TABLE IF NOT EXISTS step_note (
  plan_id INTEGER NOT NULL,
  ord     INTEGER NOT NULL,
  note    TEXT NOT NULL,
  PRIMARY KEY (plan_id, ord),
  FOREIGN KEY (plan_id, ord) REFERENCES step(plan_id, ord)
) STRICT;
