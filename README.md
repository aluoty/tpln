# tpln — Terminal Planner

A lightweight TUI task planner built with Zig 0.16.0 and libvaxis.

## Build & Run

```bash
zig build
./zig-out/bin/tpln
```

## Controls

| Key | Action |
|-----|--------|
| `j` / `↓` | Move selection down |
| `k` / `↑` | Move selection up |
| `Space` | Toggle task done/undone |
| `g` | Grab/drop task (drag-and-drop reorder in manual mode) |
| `e` | Edit selected task |
| `d` | Delete selected task |
| `a` | Add new task |
| `s` | Cycle sort mode (manual → due date → priority) |
| `q` / `Ctrl+C` | Quit |

### Form controls (when adding/editing)

| Key | Action |
|-----|--------|
| `Tab` / `↓` | Next field |
| `Shift+Tab` / `↑` | Previous field |
| `Enter` | Submit / next field |
| `Esc` | Cancel |

## Features

- 5 priority ranks (1=Critical … 5=Trivial)
- Sort by due date, priority, or manual order
- Drag-and-drop reorder with grab/drop
- Completion tracking with percentage
- Tags and due dates per task
- Centered modal form for adding/editing

## Color Legend

- **Cyan** — Headers and labels
- **Green** — Completed tasks
- **Red** — Critical priority (P1)
- **Yellow** — High priority (P2)
- **Reverse** — Selected task
