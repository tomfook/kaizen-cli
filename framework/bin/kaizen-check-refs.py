#!/usr/bin/env python3
"""kaizen-check-refs.py — extract Markdown references and check that their targets exist.

One extractor shared by every caller, so that nobody writes a reference regex
on the spot (those miss symlinked trees, code fences, and heading
normalization, and fail without an error).

Usage:
  kaizen-check-refs.py --corpus <knowledge_dir> [<scan_dir>...]
      Body of kaizen-check-knowledge.sh "Broken anchors / section references".
      Checks, for *.md under the scan dirs (default: the whole tree;
      projects/ is never scanned):
        - links with an anchor      [text](./path.md#anchor)
        - section references        `[path/]X.md § Heading`
      Report mode: prints "none" or the findings; findings do not change the
      exit code.
      Exit: 0 = scanned / 2 = incomplete (unreadable file) / 3 = bad arguments

  kaizen-check-refs.py --corpus <knowledge_dir> --staged [<path>...]
      Pre-commit gate for the knowledge repository (kaizen-knowledge-commit.sh).
      Judges only the lines added or changed in `git diff --cached`, in the
      staged *.md under <knowledge_dir> (projects/ excluded; with paths, only
      those files — relative paths start at <knowledge_dir>). Same checks as
      the report mode, plus what the report mode leaves to its caller: a link
      to a missing file, with or without an anchor, and [text](#anchor).
      Result lines: MISS, UNREAD; the last line carries the totals.
      Exit: 0 = no MISS / 1 = MISS / 2 = incomplete / 3 = nothing was judged
            (bad arguments, git unavailable)

  kaizen-check-refs.py --project <root> [--knowledge <dir>] [--exclude <name>]...
                       [--list] [--staged] [<path>...]
      Checks a project's docs/**/*.md and CLAUDE.md (or the given paths;
      relative paths are resolved from <root>):
        - section references        `[path/]X.md § Heading`
        - pointer lines             → [path/]X.md § Heading   (to end of line;
                                    this is the promotion-marker form)
        - links with an anchor      [text](path.md#anchor), [text](#anchor)
        --knowledge  knowledge directory. Default: $KAIZEN_KNOWLEDGE_DIR, then
                     <root>/knowledge.
        --exclude    file or directory name to leave out of the check (past
                     logs, archives). Still counted in the extraction totals.
        --list       extract only. Also lists the § lines from which nothing
                     could be extracted (SKIP), including those in code fences.
        --staged     only lines added or changed in `git diff --cached`
                     (pre-commit gate: judges what was just written, not the
                     existing backlog). `git add` first.
      Result lines: MISS (target file or heading not found), NUM (number-only
      reference such as `X.md § 3`; counted as MISS), OK~ (matches except for
      spaces or symbols), OK with a note (resolved to a heading stub),
      UNREAD (file could not be read). Plain OK lines are not printed; the
      last line carries the totals, including the number of files scanned, so
      "nothing was scanned" cannot be mistaken for "nothing is broken".
      Exit: 0 = no MISS / 1 = MISS (NUM included)
            2 = incomplete (unreadable file, staged file not matched, crash)
            3 = nothing was judged (bad arguments, no target, git unavailable)

How a written path is resolved (--project):
  ./x.md, ../x.md        relative to the referring file
  knowledge/...          <root>/knowledge/..., then the knowledge directory
  .claude/...            <root>/.claude/..., then the distributed framework
  other/dir/X.md         <root>/..., then the knowledge directory
  X.md (no path)         by file name among docs/, CLAUDE.md and the knowledge
                         directory (projects/ excluded); several hits = MISS

Not extracted (visible as SKIP in --list): a reference without a file name
(`§ X`, "the same § X"), a file name and a heading in separate backtick spans
(`X.md` § Heading), and references inside code fences.

Headings are compared after a loose GitHub-style normalization (lowercase,
keep letters / digits / - / _, spaces to hyphens). A `- **Label**:` list item
counts as a heading for § references. python3 standard library only.
"""
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
try:  # `| head` closing the pipe is not an error
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except (ImportError, AttributeError, ValueError):
    pass

# Code fences follow CommonMark, with the same rules as kaizen-extract-section.sh.
CODE_FENCE = re.compile(r'^\s*(?:(?:[-*+]|\d{1,9}[.)])\s+)?\s*(`{3,}|~{3,})(.*)$')
INLINE_CODE = re.compile(r'`[^`]*`')
URL_ENC = re.compile(r'%[0-9a-fA-F]{2}')
HEADING = re.compile(r'^(#{1,6})\s+(.+?)\s*$')
LIST_BULLET = re.compile(r'^\s*[-*+]\s+\*\*([^*]+?)\*\*\s*[:.]')
# Relative link with an anchor. URLs (`:`) and absolute paths are not ours to check.
ANCHOR_LINK = re.compile(r'\]\((?!/)([^)\s#:]+\.md)#([^)\s]+)\)')
BARE_ANCHOR = re.compile(r'\]\(#([^)]*)\)')
PLAIN_LINK = re.compile(r'\]\((?!/)([^)\s#:]+\.md)\)')
PATH_PART = r'((?:\.\.?/)*(?:[A-Za-z0-9_.-]+/)*)([A-Za-z_][A-Za-z0-9_-]*\.md)'
# The path must start right after the backtick: a placeholder example such as
# `→ knowledge/XXX.md § ...` has an arrow in between and is not a reference.
TEXT_REF = re.compile(r'`' + PATH_PART + r'\s*§\s*([^`]+)`')
ARROW_REF = re.compile(r'→\s*' + PATH_PART + r'\s*§\s*(.+?)\s*$')
HTML_COMMENT = re.compile(r'\s*<!--.*?-->\s*$')
PROMOTED_SUFFIX = re.compile(r'\s*に(?:昇格|記載)済み.*$')
NUM_ONLY = re.compile(r'^\d+(?:[.\-]\d+)*\.?$')
POINTER = re.compile(r'^\s*→')
QUOTE_LINE = re.compile(r'^\s*>')


def fence_update(line, state):
    """Advance the fence state by one line. Returns (state, is_fence_line);
    state is None outside a fence, else (char, length)."""
    m = CODE_FENCE.match(line)
    if state is None:
        if m and not (m.group(1)[0] == '`' and '`' in m.group(2)):
            return (m.group(1)[0], len(m.group(1))), True
        return None, False
    if m and m.group(1)[0] == state[0] and len(m.group(1)) >= state[1] and not m.group(2).strip():
        return None, True
    return state, False


def iter_lines(text):
    """(lineno, line, in_fence) for every line except the fence delimiters.
    Split on LF only, so line numbers agree with git."""
    state = None
    for n, line in enumerate(text.split('\n'), 1):
        line = line.rstrip('\r')
        state, is_fence = fence_update(line, state)
        if not is_fence:
            yield n, line, state is not None


def normalize(s):
    s = URL_ENC.sub('', s.lower())
    s = ''.join(c for c in s if c.isalnum() or c in '-_' or c.isspace())
    return ''.join('-' if c.isspace() else c for c in s).strip('-')


def loose(s):
    """Looser key than normalize(): letters and digits only."""
    return ''.join(c for c in s.lower() if c.isalnum())


def read_text(path):
    """(text, None) or (None, reason)."""
    try:
        return path.read_text(encoding='utf-8'), None
    except (OSError, UnicodeDecodeError) as e:
        return None, type(e).__name__


class Target:
    """Headings of one file, as a reference target."""

    def __init__(self, text):
        lines = text.split('\n')
        self.raw = []          # raw titles: # headings and bold bullets
        heads = []             # (line index, level, title) of # headings
        for n, line, fenced in iter_lines(text):
            if fenced:
                continue
            m = HEADING.match(line)
            if m:
                heads.append((n - 1, len(m.group(1)), m.group(2)))
                self.raw.append(m.group(2))
                continue
            m = LIST_BULLET.match(line)
            if m:
                self.raw.append(m.group(1))
        self.norm = {normalize(h) for h in self.raw}
        self.loose = {loose(h) for h in self.raw}
        self.slugs = Counter(normalize(t) for _, _, t in heads)
        # Heading stub: the body is a single `→ ... .md ...` pointer line and
        # there is no subheading. The text was moved; the heading only keeps
        # old references alive, so a reference that lands here should be
        # repointed (it would never show up as MISS).
        self.stubs = {}
        for k, (idx, level, title) in enumerate(heads):
            nxt = heads[k + 1] if k + 1 < len(heads) else None
            end = nxt[0] if nxt else len(lines)
            body = [l.strip() for l in lines[idx + 1:end] if l.strip() and l.strip() != '---']
            if (len(body) == 1 and POINTER.match(body[0]) and '.md' in body[0]
                    and (nxt is None or nxt[1] <= level)):
                self.stubs[normalize(title)] = self.stubs[loose(title)] = (title, body[0])

    def has_anchor(self, anchor, headings_only=False):
        """GitHub-style anchor, including the -1 / -2 suffix of repeated headings."""
        key = normalize(anchor)
        pool = self.slugs if headings_only else self.norm
        if key in pool:
            return True
        m = re.match(r'^(.*)-(\d+)$', key)
        return bool(m) and self.slugs.get(m.group(1), 0) > int(m.group(2))

    def near(self, variants, limit=3):
        """Headings that start with the reference text: when the reference was
        cut short, the whole heading shows up here."""
        out = []
        for key_of in (normalize, loose):
            keys = [key_of(v) for v in variants if key_of(v)]
            for h in self.raw:
                if h not in out and any(key_of(h).startswith(k) for k in keys):
                    out.append(h)
        return out[:limit]

    def run_on(self, text):
        """The longest heading that the reference text starts with: an
        undelimited pointer line that continues after the heading."""
        key = normalize(text)
        hits = [h for h in self.raw if normalize(h) and key.startswith(normalize(h))]
        return max(hits, key=len) if hits else None


def section_variants(section_path, arrow=False):
    """Candidate heading texts of one reference. `§ A § B` is matched by its
    last level, but a heading may itself contain §, so the whole text is a
    candidate too. Trailing promotion wording is dropped."""
    full = HTML_COMMENT.sub('', section_path).strip() if arrow else section_path.strip()
    last = full.split('§')[-1].strip()
    out = []
    for v in (last, full, PROMOTED_SUFFIX.sub('', last), PROMOTED_SUFFIX.sub('', full)):
        if v and v not in out:
            out.append(v)
    return last, full, out


def extract(text, arrows):
    """One pass over a referring file. Returns a dict of lists:
      refs    (lineno, prefix, filename, section_text, is_arrow)
      links   (lineno, link_path, anchor)        [text](path.md#anchor)
      anchors (lineno, anchor)                   [text](#anchor)
      plain   (lineno, link_path)                [text](path.md)
      skipped (lineno, line)                     § outside a fence, nothing extracted
      fenced  (lineno, line)                     § inside a fence
    """
    out = {'refs': [], 'links': [], 'anchors': [], 'plain': [], 'skipped': [], 'fenced': []}
    for n, line, fenced in iter_lines(text):
        if fenced:
            if '§' in line:
                out['fenced'].append((n, line.strip()))
            continue
        clean = INLINE_CODE.sub('', line)
        found = 0
        for link_path, anchor in ANCHOR_LINK.findall(clean):
            out['links'].append((n, link_path, anchor))
            found += 1   # `[X.md § Section](./X.md#anchor)`: the anchor carries the check
        for anchor in BARE_ANCHOR.findall(clean):
            out['anchors'].append((n, anchor))
        for link_path in PLAIN_LINK.findall(clean):
            out['plain'].append((n, link_path))
        for prefix, filename, section in TEXT_REF.findall(line):
            out['refs'].append((n, prefix, filename, section, False))
            found += 1
        if arrows:
            m = ARROW_REF.search(clean)
            if m:
                out['refs'].append((n, m.group(1), m.group(2), m.group(3), True))
                found += 1
        if '§' in line and not found:
            out['skipped'].append((n, line.strip()))
    return out


def md_files(root, skip_projects_under=None):
    """*.md under root, sorted. Files below a `projects` component (relative
    to skip_projects_under) and below .git are left out."""
    out = []
    for p in root.rglob('*.md'):
        if '.git' in p.parts:
            continue
        if skip_projects_under is not None:
            try:
                if 'projects' in p.relative_to(skip_projects_under).parts:
                    continue
            except ValueError:
                pass
        if p.is_file():
            out.append(p)
    return sorted(out)


def fail(msg):
    print("Error: " + msg, file=sys.stderr)
    return 3


# ---------------------------------------------------------------------------
# --corpus
# ---------------------------------------------------------------------------
def corpus_scan(kd, sources, lines_of=None):
    """Check the references in `sources` against the knowledge tree `kd`.
    Returns (findings, unread, ok). A finding is (kind, src, lineno, shown,
    why) with kind 'link' or 'ref'.

    With lines_of ({src: line numbers}) only those lines are judged, and the
    cases the report mode leaves to the link check of its caller are findings
    too: a link to a missing file, with or without an anchor, and a
    [text](#anchor) into the file itself."""
    gate = lines_of is not None
    # Targets are indexed over the whole tree even when only a subdirectory is
    # scanned: a reference from the subdirectory to a sibling one is not broken.
    indexed = [p.resolve() for p in md_files(kd, kd)]
    by_name = {}
    for p in indexed:
        by_name.setdefault(p.name, []).append(p)
    indexed_set = set(indexed)
    top_dirs = {p.name for p in kd.iterdir() if p.is_dir()}
    cache = {}
    unread = {}

    def target(p):
        if p not in cache:
            text, why = read_text(p)
            cache[p] = Target(text) if text is not None else None
            if text is None:
                unread[p] = why
        return cache[p]

    def rel(p):
        return p.relative_to(kd).as_posix()

    def resolve(src, prefix, filename):
        """(candidates, verdict): verdict is None, 'skip' or 'missing'."""
        written = prefix + filename
        if prefix.startswith(('./', '../')):
            p = (src.parent / written).resolve()
            if p != kd and kd not in p.parents:
                return [], 'skip'
            return ([p], None) if p in indexed_set else ([], 'missing' if not p.exists() else 'skip')
        if not prefix:
            return by_name.get(filename, []), None
        if written.startswith('knowledge/'):
            written = written[len('knowledge/'):]
        hits = [p for p in indexed if rel(p) == written or rel(p).endswith('/' + written)]
        if hits:
            return hits, None
        # A path that does not start inside the knowledge tree (docs/..., .claude/...)
        # points at a project or the framework and cannot be judged from here.
        return [], ('missing' if written.split('/')[0] in top_dirs else 'skip')

    findings = []
    ok = 0
    for src in sources:
        text, why = read_text(src)
        if text is None:
            unread[src] = why
            continue
        found = extract(text, arrows=False)
        allowed = lines_of.get(src, set()) if gate else None
        links = list(found['links'])
        if gate:
            links += [(n, link_path, None) for n, link_path in found['plain']]
            links += [(n, '', anchor) for n, anchor in found['anchors'] if anchor]
        for lineno, link_path, anchor in links:
            if gate and lineno not in allowed:
                continue
            tgt = (src.parent / link_path).resolve() if link_path else src
            shown = "`%s%s`" % (link_path, '' if anchor is None else '#' + anchor)
            if tgt not in indexed_set:
                # A missing file is reported by the link check of the report's
                # caller; other paths (projects/, outside the tree) are not ours.
                if gate and (tgt == kd or kd in tgt.parents) and not tgt.is_file():
                    findings.append(('link', src, lineno, shown, 'link target not found'))
                continue
            if anchor is None:
                ok += 1
                continue
            t = target(tgt)
            if t is None:
                continue
            if t.has_anchor(anchor):
                ok += 1
            else:
                findings.append(('link', src, lineno, shown, 'no matching heading'))
        for lineno, prefix, filename, section, _ in found['refs']:
            if gate and lineno not in allowed:
                continue
            if QUOTE_LINE.match(text.split('\n')[lineno - 1]):
                continue
            last, _, variants = section_variants(section)
            shown = "`%s%s § %s`" % (prefix, filename, last)
            cands, verdict = resolve(src, prefix, filename)
            if verdict == 'skip':
                continue
            if not cands:
                findings.append(('ref', src, lineno, shown, 'referenced file not found'))
                continue
            if len(cands) > 1:
                names = ', '.join(rel(c) for c in cands)
                findings.append(('ref', src, lineno, shown, 'multiple files named %s: %s' % (filename, names)))
                continue
            t = target(cands[0])
            if t is None:
                continue
            if any(normalize(v) in t.norm for v in variants):
                ok += 1
            else:
                findings.append(('ref', src, lineno, shown, 'no matching heading'))
    return findings, unread, ok


def run_corpus(knowledge_dir, scan_dirs):
    kd = Path(knowledge_dir).resolve()
    if not kd.is_dir():
        return fail("knowledge directory does not exist: %s" % knowledge_dir)
    scans = [Path(p).resolve() for p in scan_dirs] or [kd]
    for s in scans:
        if not s.is_dir():
            return fail("scan directory does not exist: %s" % s)
        if s != kd and kd not in s.parents:
            return fail("scan directory is outside the knowledge directory: %s" % s)

    def rel(p):
        return p.relative_to(kd).as_posix()

    sources = sorted({p.resolve() for s in scans for p in md_files(s, kd)})
    findings, unread, _ = corpus_scan(kd, sources)
    broken_link = ["- %s: %s (%s)" % (rel(src), shown, why)
                   for kind, src, _, shown, why in findings if kind == 'link']
    broken_text = ["- %s: %s (%s)" % (rel(src), shown, why)
                   for kind, src, _, shown, why in findings if kind == 'ref']

    if broken_link:
        print("**Markdown links ([text](path#anchor)):**")
        print("\n".join(broken_link))
        print()
    if broken_text:
        print("**Plain-text refs (`X.md § Y`):**")
        print("\n".join(broken_text))
        print()
    if broken_link or broken_text:
        print("> Note: loose GitHub-style normalization (lowercase + keep alnum/-/_/space + space->hyphen). "
              "Plain-text refs without a path resolve by filename only — verify flagged items manually.")
    elif not unread:
        print("none")
    if unread:
        if broken_link or broken_text:
            print()
        print("**Unreadable files (not checked — the result above is incomplete):**")
        for p in sorted(unread):
            print("- %s (%s)" % (rel(p), unread[p]))
        return 2
    return 0


def run_corpus_gate(knowledge_dir, paths):
    """--corpus --staged: judge what is about to be committed to the knowledge
    repository, not the existing backlog."""
    kd = Path(knowledge_dir).resolve()
    if not kd.is_dir():
        return fail("knowledge directory does not exist: %s" % knowledge_dir)
    top, added, names, unparsed = staged_added_lines(kd)
    if top is None:
        return fail("--staged needs a git repository and the git command")
    wanted = None
    if paths:
        wanted = {(Path(p) if Path(p).is_absolute() else kd / p).resolve() for p in paths}
    in_tree = {p.resolve() for p in md_files(kd, kd)}
    staged = [(top / n).resolve() for n in names]
    in_scope = [p for p in staged if p in in_tree and (wanted is None or p in wanted)]

    def rel(p):
        return p.relative_to(kd).as_posix()

    lines_of, staged_missing = {}, []
    for p in in_scope:
        key = p.relative_to(top).as_posix()
        if key in added:
            lines_of[p] = added[key]
        elif unparsed:
            # The file header could not be parsed, so its added lines are lost.
            staged_missing.append(p)
    note = "staged .md %d / checked %d" % (len(staged), len(lines_of))
    if len(staged) > len(in_scope):
        note += " / out of scope %d" % (len(staged) - len(in_scope))
    if not lines_of and not staged_missing:
        print("--staged: nothing was checked — no staged .md in scope (%s)" % note)
        return 0

    findings, unread, ok = corpus_scan(kd, sorted(lines_of), lines_of)
    print("### Reference gate (lines added or changed in `git diff --cached`; %s)" % note)
    print()
    body = ["MISS %s:%d  %s (%s)" % (rel(src), lineno, shown, why) for _, src, lineno, shown, why in findings]
    body += ["UNREAD %s  (staged file was not matched to its diff; its added lines were not checked)" % rel(p)
             for p in staged_missing]
    body += ["UNREAD %s  (cannot read the file: %s; references in or into it were not checked)" % (rel(p), unread[p])
             for p in sorted(unread)]
    for line in body:
        print(line)
    if body:
        print()
    incomplete = bool(unread or staged_missing)
    print("total: checked %d file(s) / OK %d / MISS %d%s"
          % (len(lines_of), ok, len(findings),
             " / UNREAD %d" % (len(unread) + len(staged_missing)) if incomplete else ""))
    if incomplete:
        print()
        print("==== result: incomplete (see the UNREAD lines; the MISS count is a lower bound)")
        return 2
    return 1 if findings else 0


# ---------------------------------------------------------------------------
# --project
# ---------------------------------------------------------------------------
def staged_added_lines(root):
    """(toplevel, {repo-relative path: added line numbers}, staged .md names,
    number of file headers that could not be parsed). (None, ...) without git."""
    def git(*args):
        return subprocess.run(['git', '-C', str(root)] + list(args), capture_output=True, check=True).stdout

    try:
        top = git('rev-parse', '--show-toplevel').decode('utf-8', 'replace').strip()
        # R is needed: a rename with edits would otherwise pass the gate unread.
        names = git('diff', '--cached', '--name-only', '-z', '--diff-filter=AMR', '--', '*.md')
        # Pin every setting that changes the shape of the file headers.
        diff = git('-c', 'core.quotepath=false', '-c', 'diff.noprefix=false', '-c', 'diff.mnemonicPrefix=false',
                   'diff', '--cached', '-U0', '--no-color', '--src-prefix=a/', '--dst-prefix=b/',
                   '--diff-filter=AMR', '--', '*.md')
    except (OSError, subprocess.CalledProcessError):
        return None, None, None, 0
    added, unparsed, cur = {}, 0, None
    for line in diff.decode('utf-8', 'surrogateescape').split('\n'):
        if line.startswith('+++ '):
            name = line[4:]
            if name.endswith('\t'):   # git appends a tab when the name contains a space
                name = name[:-1]
            if name.startswith('b/'):
                cur = name[2:]
                added.setdefault(cur, set())
            else:                     # C-quoted name ("b/...")
                cur = None
                unparsed += 1
        elif line.startswith('@@') and cur is not None:
            m = re.match(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', line)
            if m:
                count = int(m.group(2)) if m.group(2) is not None else 1
                added[cur].update(range(int(m.group(1)), int(m.group(1)) + count))
    staged = [n.decode('utf-8', 'surrogateescape') for n in names.split(b'\0') if n]
    return Path(top).resolve(), added, staged, unparsed


def run_project(root_arg, knowledge_arg, excludes, list_only, staged, paths):
    root = Path(root_arg).resolve()
    if not root.is_dir():
        return fail("project directory does not exist: %s" % root_arg)
    if knowledge_arg:
        know = Path(knowledge_arg).resolve()
        if not know.is_dir():
            return fail("knowledge directory does not exist: %s" % knowledge_arg)
    else:
        know = (root / 'knowledge').resolve() if (root / 'knowledge').is_dir() else None
    framework = Path(__file__).resolve().parent.parent   # .../framework

    targets = []
    if paths:
        for p in paths:
            pp = Path(p) if Path(p).is_absolute() else root / p
            if pp.is_dir():
                targets.extend(md_files(pp))
            elif pp.is_file():
                targets.append(pp)
            else:
                return fail("path does not exist: %s (resolved to %s; relative paths start at the project root)" % (p, pp))
    else:
        if (root / 'docs').is_dir():
            targets.extend(md_files(root / 'docs'))
        if (root / 'CLAUDE.md').is_file():
            targets.append(root / 'CLAUDE.md')
    if not targets:
        return fail("no .md file to scan (neither docs/ nor CLAUDE.md under %s)" % root)

    staged_lines = None
    staged_note = ''
    staged_missing = []
    if staged:
        top, added, names, unparsed = staged_added_lines(root)
        if top is None:
            return fail("--staged needs a git repository and the git command")
        target_set = {t.resolve() for t in targets}
        in_scope = [n for n in names if (top / n).resolve() in target_set]
        # A staged file whose header could not be parsed has lost its added
        # lines. Say so instead of reporting a clean result for it.
        if unparsed:
            staged_missing = [n for n in in_scope if n not in added]
        kept = [t for t in targets
                if top in t.resolve().parents and t.resolve().relative_to(top).as_posix() in added]
        staged_lines = {t.resolve(): added[t.resolve().relative_to(top).as_posix()] for t in kept}
        staged_note = "staged .md %d / checked %d" % (len(in_scope), len(kept))
        if len(names) > len(in_scope):
            staged_note += " / out of scope %d" % (len(names) - len(in_scope))
        if not kept and not staged_missing:
            print("--staged: nothing was checked — no staged .md in scope (%s)" % staged_note)
            return 0
        targets = kept

    index = {}
    search = [root / 'docs'] + ([know] if know else [])
    for base in search:
        if base.is_dir():
            for f in md_files(base, know if base == know else None):
                index.setdefault(f.name, set()).add(f.resolve())
    if (root / 'CLAUDE.md').is_file():
        index.setdefault('CLAUDE.md', set()).add((root / 'CLAUDE.md').resolve())

    cache = {}
    unread_targets = {}

    def target(p):
        if p not in cache:
            text, why = read_text(p)
            cache[p] = Target(text) if text is not None else None
            if text is None:
                unread_targets[p] = why
        return cache[p]

    def resolve(src, prefix, filename):
        written = prefix + filename
        if prefix.startswith(('./', '../')):
            tries = [src.parent / written]
        elif prefix:
            tries = [root / written]
            if know is not None:
                if written.startswith('knowledge/'):
                    tries.append(know / written[len('knowledge/'):])
                tries.append(know / written)
            if written.startswith('.claude/'):
                tries.append(framework / written)
        else:
            return sorted(index.get(filename, set()))
        found = []
        for t in tries:
            if t.is_file() and t.resolve() not in found:
                found.append(t.resolve())
        return found

    def shown(p):
        p = Path(p)
        for base, label in ((root, ''), (know, 'knowledge/')):
            if base is not None:
                try:
                    return label + p.resolve().relative_to(base).as_posix()
                except ValueError:
                    pass
        return p.as_posix()

    def excluded(p):
        try:
            parts = p.resolve().relative_to(root).parts
        except ValueError:
            parts = p.parts
        return p.name in excludes or any(part in excludes for part in parts[:-1])

    per_file = []
    unread_srcs = []
    for src in targets:
        text, why = read_text(src)
        if text is None:
            unread_srcs.append((src, why))
            continue
        found = extract(text, arrows=True)
        if staged_lines is not None:
            allowed = staged_lines.get(src.resolve(), set())
            for key in ('refs', 'links', 'anchors', 'skipped', 'fenced'):
                found[key] = [item for item in found[key] if item[0] in allowed]
        per_file.append((src, found))

    n_refs = sum(len(f['refs']) for _, f in per_file)
    n_skipped = sum(len(f['skipped']) for _, f in per_file)
    n_nofile = sum(1 for _, f in per_file for _, l in f['skipped'] if '.md' not in l)
    n_lines = sum(len({r[0] for r in f['refs']}) + len(f['skipped']) for _, f in per_file)
    n_anchors = sum(len(f['anchors']) + len(f['links']) for _, f in per_file)

    print("### Reference extraction (`[path/]X.md § Heading`, `→ [path/]X.md § Heading`; code fences excluded)")
    print()
    if staged_lines is not None:
        print("--staged: only lines added or changed in `git diff --cached` (%s)" % staged_note)
    print("knowledge directory: %s" % (know if know is not None else
          "(none — a reference into knowledge/ is reported as a missing file)"))
    print("scanned %d file(s) / § lines outside fences %d / references extracted %d / § lines not extracted %d%s"
          % (len(targets), n_lines, n_refs, n_skipped,
             " (no file name %d / other %d)" % (n_nofile, n_skipped - n_nofile) if n_skipped else ""))
    print("link anchors (`[text](path.md#anchor)`, `[text](#anchor)`; counted separately): %d" % n_anchors)
    for src, f in per_file:
        if f['refs'] or f['skipped'] or f['anchors'] or f['links']:
            print("- %s: references %d / not extracted %d / anchors %d"
                  % (shown(src), len(f['refs']), len(f['skipped']), len(f['anchors']) + len(f['links'])))
    print()

    unread_lines = ["UNREAD %s  (staged file was not matched to its diff; its added lines were not checked)" % n
                    for n in staged_missing]
    unread_lines += ["UNREAD %s  (cannot read the file: %s; its references were not checked)" % (shown(s), why)
                     for s, why in unread_srcs]

    def ref_text(prefix, filename, section, arrow):
        if arrow:
            return "→ %s%s § %s" % (prefix, filename, HTML_COMMENT.sub('', section).strip())
        return "`%s%s § %s`" % (prefix, filename, section.strip())

    if list_only:
        print("### Extracted (--list)")
        print()
        for src, f in per_file:
            name = shown(src)
            for n, prefix, filename, section, arrow in f['refs']:
                print("REF  %s:%d  %s" % (name, n, ref_text(prefix, filename, section, arrow)))
            for n, line in f['skipped']:
                print("SKIP %s:%d  %s" % (name, n, line[:120]))
            for n, line in f['fenced']:
                print("SKIP %s:%d  [in code fence] %s" % (name, n, line[:120]))
            for n, anchor in f['anchors']:
                print("ANCH %s:%d  `#%s`" % (name, n, anchor))
            for n, link_path, anchor in f['links']:
                print("ANCH %s:%d  `%s#%s`" % (name, n, link_path, anchor))
        for line in unread_lines:
            print(line)
        if unread_lines:
            print()
            print("==== result: incomplete (see the UNREAD lines)")
            return 2
        return 0

    ok = loose_ok = num = stub = excluded_n = anchor_ok = 0
    notes, miss, anchor_miss, unread_refs = [], [], [], []
    for src, f in per_file:
        name = shown(src)
        if excluded(src):
            excluded_n += len(f['refs'])
            continue
        for n, link_path, anchor in [(n, '', a) for n, a in f['anchors']] + f['links']:
            dest = (src.parent / link_path).resolve() if link_path else src.resolve()
            text = "`%s#%s`" % (link_path, anchor)
            if not dest.is_file():
                anchor_miss.append("MISS %s:%d  %s (link target not found)" % (name, n, text))
                continue
            t = target(dest)
            if t is None:
                unread_refs.append("UNREAD %s:%d  %s (cannot read the target %s: %s; the anchor was not checked)"
                                   % (name, n, text, shown(dest), unread_targets[dest]))
            elif anchor and t.has_anchor(anchor, headings_only=True):
                anchor_ok += 1
            else:
                near = t.near([anchor]) if anchor else []
                detail = "no matching heading in %s" % shown(dest)
                if near:
                    detail += "; similar: " + ', '.join('"%s"' % h for h in near)
                anchor_miss.append("MISS %s:%d  %s (%s)" % (name, n, text, detail))
        for n, prefix, filename, section, arrow in f['refs']:
            text = ref_text(prefix, filename, section, arrow)
            last, _, variants = section_variants(section, arrow)
            cands = resolve(src, prefix, filename)
            if not cands:
                miss.append("MISS %s:%d  %s (referenced file not found)" % (name, n, text))
                continue
            if len(cands) > 1:
                miss.append("MISS %s:%d  %s (several files named %s: %s — write the path)"
                            % (name, n, text, filename, ', '.join(shown(c) for c in cands)))
                continue
            t = target(cands[0])
            where = shown(cands[0])
            if t is None:
                unread_refs.append("UNREAD %s:%d  %s (cannot read the target %s: %s; the heading was not checked)"
                                   % (name, n, text, where, unread_targets[cands[0]]))
                continue

            def stub_note(key):
                hit = t.stubs.get(key)
                if not hit:
                    return ''
                return ' (resolves to a heading stub: "%s" %s — repoint to where the text now lives)' % hit

            key = next((normalize(v) for v in variants if normalize(v) in t.norm), None)
            lkey = next((loose(v) for v in variants if loose(v) in t.loose), None)
            if key is not None:
                ok += 1
                if stub_note(key):
                    stub += 1
                    notes.append("OK   %s:%d  %s%s" % (name, n, text, stub_note(key)))
            elif lkey is not None:
                loose_ok += 1
                stub += 1 if stub_note(lkey) else 0
                notes.append("OK~  %s:%d  %s (differs from the heading in spaces or symbols)%s"
                             % (name, n, text, stub_note(lkey)))
            elif NUM_ONLY.match(last):
                near = t.near(variants)
                num += 1
                miss.append("NUM  %s:%d  %s (number-only reference: write the whole heading%s; %s)"
                            % (name, n, text, ' → "%s"' % near[0] if near else '', where))
            else:
                near = t.near(variants)
                detail = "no matching heading in %s" % where
                nested = [h for h in near if '`' in h]
                longer = t.run_on(last) if arrow else None
                if nested and not arrow:
                    detail += ('; the heading contains inline code — drop its backticks inside the reference: "%s"'
                               % nested[0].replace('`', ''))
                elif longer:
                    detail += ('; text follows the heading "%s" — put the reference in backticks to delimit it'
                               % longer)
                elif near:
                    detail += "; similar: " + ', '.join('"%s"' % h for h in near)
                miss.append("MISS %s:%d  %s (%s)" % (name, n, text, detail))

    print("### Results")
    print()
    body = notes + miss + anchor_miss + unread_refs + unread_lines
    for line in body:
        print(line)
    if body:
        print()
    if n_anchors:
        print("anchors: OK %d / MISS %d" % (anchor_ok, len(anchor_miss)))
    if stub:
        print("via heading stub: %d (counted in OK; warning only)" % stub)
    summary = "OK %d / OK~ %d / MISS %d" % (ok, loose_ok, len(miss))
    if num:
        summary += " (NUM %d)" % num
    if unread_refs:
        summary += " / UNREAD %d" % len(unread_refs)
    if excluded_n:
        summary += " / excluded %d" % excluded_n
    # Everything a reader needs is on this last line: a run that scanned
    # nothing and a run that found nothing must not look alike under `tail`.
    print("total: scanned %d file(s) / references %s (%d of %d extracted accounted for)%s"
          % (len(targets), summary, ok + loose_ok + len(miss) + len(unread_refs) + excluded_n, n_refs,
             " / anchors OK %d / MISS %d" % (anchor_ok, len(anchor_miss)) if n_anchors else ""))
    if unread_srcs or unread_refs or staged_missing:
        print()
        print("==== result: incomplete (see the UNREAD lines; the MISS count is a lower bound)")
        return 2
    return 1 if (miss or anchor_miss) else 0


def usage(msg=''):
    if msg:
        print("Error: " + msg, file=sys.stderr)
    print(__doc__.split('Usage:')[1].split('How a written path')[0].rstrip(), file=sys.stderr)
    return 3


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        usage()
        return 0 if argv else 3
    mode, rest = argv[0], argv[1:]
    if mode == '--corpus':
        if not rest:
            return usage("--corpus needs <knowledge_dir>")
        if '--staged' in rest[1:]:
            return run_corpus_gate(rest[0], [a for a in rest[1:] if a != '--staged'])
        return run_corpus(rest[0], rest[1:])
    if mode != '--project':
        return usage("unknown mode: %s" % mode)
    if not rest:
        return usage("--project needs <root>")
    root, knowledge, excludes, flags, paths = rest[0], None, [], set(), []
    i = 1
    while i < len(rest):
        a = rest[i]
        if a in ('--knowledge', '--exclude'):
            if i + 1 >= len(rest):
                return usage("%s needs a value" % a)
            if a == '--knowledge':
                knowledge = rest[i + 1]
            else:
                excludes.append(rest[i + 1])
            i += 2
            continue
        if a in ('--list', '--staged'):
            flags.add(a)
        elif a.startswith('--'):
            return usage("unknown option: %s" % a)
        else:
            paths.append(a)
        i += 1
    if knowledge is None:
        knowledge = os.environ.get('KAIZEN_KNOWLEDGE_DIR') or None
    return run_project(root, knowledge, excludes, '--list' in flags, '--staged' in flags, paths)


def run(argv):
    """An uncaught exception would exit 1, the same value as "MISS found"."""
    try:
        return main(argv)
    except Exception as e:  # noqa: BLE001 - last-resort guard
        import traceback
        traceback.print_exc()
        print("\n==== result: incomplete (crashed with %s: %s; the output above is partial)"
              % (type(e).__name__, str(e)[:200]))
        return 2


if __name__ == '__main__':
    sys.exit(run(sys.argv[1:]))
