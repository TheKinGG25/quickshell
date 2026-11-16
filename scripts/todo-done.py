#!/usr/bin/env python3
"""todo-done.py <ID> - marks a task in ~/Documents/claude-notes/todo.md as done.

Called by TodoPanel.qml. Removes the task's table row and its "### <ID> · ..." details entry,
which is what todo.md asks for when a task is done. The previous version is kept in
~/.cache/quickshell/todo.md.bak. Prints "ok" or an error.
"""
import os
import re
import sys
import tempfile

TODO = os.environ.get("TODO_FILE") or os.path.expanduser("~/Documents/claude-notes/todo.md")
BACKUP = os.path.expanduser("~/.cache/quickshell/todo.md.bak")


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"[A-Za-z]+\d+", sys.argv[1]):
        print("usage: todo-done.py <ID>")
        return 1
    task_id = sys.argv[1]

    with open(TODO, encoding="utf-8") as f:
        lines = f.read().split("\n")

    out, removed_row, removed_details, skipping = [], False, False, False
    for line in lines:
        if skipping:
            if line.startswith("### ") or line.startswith("## "):
                skipping = False
            else:
                continue
        if re.match(rf"^\|\s*{task_id}\s*\|", line):
            removed_row = True
            continue
        if re.match(rf"^###\s+{task_id}\s+·", line):
            removed_details = True
            skipping = True
            continue
        out.append(line)

    if not removed_row:
        print(f"{task_id} not found")
        return 1

    os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
    with open(BACKUP, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    text = "\n".join(out)
    if removed_details and not text.endswith("\n"):
        text += "\n"
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(TODO), prefix=".todo-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, TODO)
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
