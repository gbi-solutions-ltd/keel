"""Rewrite each keel-labelled subagent row to show the model it runs on, beside the label.

Claude Code runs this as the subagentStatusLine on every refresh tick, with one JSON object on
stdin: a `columns` width and a `tasks` array. It prints one {"id", "content"} JSON line per row it
overrides, and a row it does not name keeps the default rendering (per the vendor docs, not
observed). It names only the rows whose description starts with a label that a keel dispatch
writes: an override replaces the whole row, so naming a subagent of another plugin, or one the user
started, would cost it the elapsed time, live progress and queued count of its default row.
Anything it cannot read prints nothing, so the panel falls back to the default rows.
"""
import json
import sys

SEP = " " + chr(0xB7) + " "
ELLIPSIS = "..."
# The two labels docs/standards.md ("A dispatch names its model, and says so") has a dispatch lead
# its description with, as written there: the profile, a colon and a space.
LABELS = ("inherit: ", "keel-fanout: ")
# Fewest characters of the lead worth showing before its ellipsis. Fewer say nothing about which
# agent it is, and the room is better spent on the label.
LEAD_KEEP = 3


def _clean(value):
    """The printable characters of a string, and "" for anything that is not one.

    The harness parses the JSON and draws `content` as it is, escape sequences included, so a label
    holding an ESC or an OSC 8 opener could leave an unterminated sequence that swallows the model
    printed after it. Cleaning where the text is read also keeps the width arithmetic honest: the
    lengths below count what is drawn.
    """
    if not isinstance(value, str):
        return ""
    return "".join(ch for ch in value if ch.isprintable())


def _tokens(n):
    if isinstance(n, bool) or not isinstance(n, (int, float)) or n < 0:
        return ""
    n = int(n)
    if n >= 1000:
        return f"{n / 1000:.1f}k tokens"
    return "1 token" if n == 1 else f"{n} tokens"


def render(task, columns):
    """The row body for one task, or None to leave the default row alone."""
    tid = task.get("id")
    model = _clean(task.get("model"))
    if not (isinstance(tid, str) and tid and model):
        return None
    # The label is judged as it is drawn, so on the cleaned text. A row that does not start with a
    # keel label was not dispatched by keel: leave its default row alone.
    label = _clean(task.get("description"))
    if not label.startswith(LABELS):
        return None
    # The default row leads with the subagent name, or its agent type when it has none. Keep that:
    # an override replaces the whole row. For an unnamed agent the agent type is how a keel-fanout:
    # label is checked against the agent that actually carries it. A named agent leads with its
    # name, as on the default row, and its type is not on the row. A name or type of spaces only is
    # none, so each is stripped before one is chosen: otherwise a blank name beats the agent type
    # and the row starts with blank space.
    lead = _clean(task.get("name")).strip() or _clean(task.get("agentType")).strip()
    tok = _tokens(task.get("tokenCount"))
    tails = [SEP + model + SEP + tok, SEP + model] if tok else [SEP + model]
    head = lead + SEP if lead else ""
    if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
        return head + label + tails[0]
    # What gives way on a narrow row, in order: the lead, then the token count, then the end of the
    # label. The model never gives way: it is the one thing on the row nothing else shows. The
    # label is the text the feature exists to show, so it is cut only when no form of the row holds
    # it whole, which means a wider pane never shortens it. Each tail is tried with the label
    # whole: the row as it is, then the lead shortened to the room the label and tail leave it
    # (with an ellipsis, if that keeps enough of it to say which agent it is), then the lead
    # dropped.
    for tail in tails:
        if len(head) + len(label) + len(tail) <= columns:
            return head + label + tail
        if lead:
            spare = columns - len(label) - len(tail) - len(SEP)
            if spare >= LEAD_KEEP + len(ELLIPSIS):
                return lead[: spare - len(ELLIPSIS)] + ELLIPSIS + SEP + label + tail
            if len(label) + len(tail) <= columns:
                return label + tail
    # No form of the row holds the whole label, so cut its end beside the model alone, which is the
    # last tail. A bare ellipsis says nothing, so with room for less than one character and the
    # ellipsis the row is the model.
    room = columns - len(tails[-1])
    if room >= len(ELLIPSIS) + 1:
        return label[: room - len(ELLIPSIS)] + ELLIPSIS + tails[-1]
    return model


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    except ValueError:
        return 0
    if not isinstance(data, dict):
        return 0
    tasks = data.get("tasks")
    if not isinstance(tasks, list):
        return 0
    columns = data.get("columns")
    lines = []
    for task in tasks:
        if not isinstance(task, dict):
            continue
        content = render(task, columns)
        if content is not None:
            lines.append(json.dumps({"id": task["id"], "content": content}, ensure_ascii=False))
    if lines:
        # Bytes, not text: under a C locale a text write of the middle dot raises. A lone surrogate
        # cannot be encoded strictly, and one bad row must not lose the others in the same tick, so
        # it is replaced. _clean already drops one from a label, so what reaches here is the id.
        sys.stdout.buffer.write(("\n".join(lines) + "\n").encode("utf-8", "replace"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
