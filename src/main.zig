const std = @import("std");
const vaxis = @import("vaxis");
const TextInput = vaxis.widgets.TextInput;

const MAX_TASKS = 50;
const TASK_LEN = 40;

const Task = struct {
    desc: [TASK_LEN]u8 = .{0} ** TASK_LEN,
    tag: [16]u8 = .{0} ** 16,
    due_date: [11]u8 = .{0} ** 11,
    priority: u8 = 3,
    done: bool = false,
};

const SortMode = enum { manual, due_date, priority };

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
};

var tasks: [MAX_TASKS]Task = undefined;
var task_count: usize = 0;
var current_selection: usize = 0;
var is_holding: bool = false;
var sort_mode: SortMode = .manual;

const FormField = enum { desc, tag, due_date, priority };

var form_active: bool = false;
var form_field: FormField = .desc;
var form_desc_input: TextInput = undefined;
var form_tag_input: TextInput = undefined;
var form_date_input: TextInput = undefined;
var form_pri_input: TextInput = undefined;
var task_lines: [MAX_TASKS][128]u8 = undefined;
var sort_mode_buf: [64]u8 = undefined;
var footer_buf: [128]u8 = undefined;

fn initTasks() void {
    {
        var t = &tasks[0];
        const desc = "Port fractal math";
        const tag = "DEV";
        const date = "2026-06-12";
        @memcpy(t.desc[0..desc.len], desc);
        t.desc[desc.len] = 0;
        @memcpy(t.tag[0..tag.len], tag);
        t.tag[tag.len] = 0;
        @memcpy(t.due_date[0..date.len], date);
        t.due_date[date.len] = 0;
        t.priority = 1;
        t.done = true;
        task_count = 1;
    }
    {
        var t = &tasks[1];
        const desc = "Install FreeBSD base";
        const tag = "SYS";
        const date = "2026-06-15";
        @memcpy(t.desc[0..desc.len], desc);
        t.desc[desc.len] = 0;
        @memcpy(t.tag[0..tag.len], tag);
        t.tag[tag.len] = 0;
        @memcpy(t.due_date[0..date.len], date);
        t.due_date[date.len] = 0;
        t.priority = 2;
        t.done = false;
        task_count = 2;
    }
    {
        var t = &tasks[2];
        const desc = "Design AST tree struct";
        const tag = "LANG";
        const date = "2026-06-14";
        @memcpy(t.desc[0..desc.len], desc);
        t.desc[desc.len] = 0;
        @memcpy(t.tag[0..tag.len], tag);
        t.tag[tag.len] = 0;
        @memcpy(t.due_date[0..date.len], date);
        t.due_date[date.len] = 0;
        t.priority = 3;
        t.done = false;
        task_count = 3;
    }
}

fn compareDates(context: void, a: Task, b: Task) bool {
    _ = context;
    const ad = std.mem.sliceTo(&a.due_date, 0);
    const bd = std.mem.sliceTo(&b.due_date, 0);
    return std.mem.order(u8, ad, bd) == .lt;
}

fn comparePriority(context: void, a: Task, b: Task) bool {
    _ = context;
    return a.priority < b.priority;
}

fn triggerSort() void {
    switch (sort_mode) {
        .manual => {},
        .due_date => std.sort.block(Task, tasks[0..task_count], {}, compareDates),
        .priority => std.sort.block(Task, tasks[0..task_count], {}, comparePriority),
    }
}

fn deleteTask() void {
    if (task_count == 0) return;
    var i = current_selection;
    while (i < task_count - 1) : (i += 1) {
        tasks[i] = tasks[i + 1];
    }
    task_count -= 1;
    if (current_selection >= task_count and current_selection > 0) {
        current_selection -= 1;
    }
}

fn addTaskFromForm() void {
    if (task_count >= MAX_TASKS) return;

    const alloc_a = form_desc_input.buf.allocator;

    const desc_text = form_desc_input.toOwnedSlice() catch return;
    defer alloc_a.free(desc_text);

    const tag_text = form_tag_input.toOwnedSlice() catch return;
    defer alloc_a.free(tag_text);

    const date_text = form_date_input.toOwnedSlice() catch return;
    defer alloc_a.free(date_text);

    const pri_text = form_pri_input.toOwnedSlice() catch return;
    defer alloc_a.free(pri_text);

    if (desc_text.len > 0) {
        const n = @min(desc_text.len, TASK_LEN - 1);
        @memcpy(tasks[task_count].desc[0..n], desc_text[0..n]);
        tasks[task_count].desc[n] = 0;

        if (tag_text.len > 0) {
            const tl = @min(tag_text.len, 15);
            @memcpy(tasks[task_count].tag[0..tl], tag_text[0..tl]);
            tasks[task_count].tag[tl] = 0;
        } else {
            @memcpy(tasks[task_count].tag[0..4], "NONE");
            tasks[task_count].tag[4] = 0;
        }

        if (date_text.len > 0) {
            const dl = @min(date_text.len, 10);
            @memcpy(tasks[task_count].due_date[0..dl], date_text[0..dl]);
            tasks[task_count].due_date[dl] = 0;
        } else {
            @memcpy(tasks[task_count].due_date[0..10], "9999-12-31");
            tasks[task_count].due_date[10] = 0;
        }

        var p: u8 = 3;
        if (pri_text.len > 0) {
            p = std.fmt.parseInt(u8, pri_text, 10) catch 3;
            if (p < 1 or p > 3) p = 3;
        }
        tasks[task_count].priority = p;
        tasks[task_count].done = false;

        task_count += 1;
        triggerSort();
    }
}

fn resetForm() void {
    form_desc_input.clearRetainingCapacity();
    form_tag_input.clearRetainingCapacity();
    form_date_input.clearRetainingCapacity();
    form_pri_input.clearRetainingCapacity();
    form_field = .desc;
    form_active = false;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(io, &buffer);
    defer tty.deinit();

    var vx = try vaxis.init(io, alloc, init.environ_map, .{});
    defer vx.deinit(alloc, tty.writer());

    var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);
    try loop.start();
    defer loop.stop();

    try loop.installResizeHandler();
    try vx.enterAltScreen(tty.writer());
    // try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    form_desc_input = TextInput.init(alloc);
    form_tag_input = TextInput.init(alloc);
    form_date_input = TextInput.init(alloc);
    form_pri_input = TextInput.init(alloc);

    initTasks();

    while (true) {
        const event = try loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (form_active) {
                    if (key.matches(vaxis.Key.escape, .{})) {
                        resetForm();
                    } else if (key.matches(vaxis.Key.enter, .{})) {
                        switch (form_field) {
                            .desc => form_field = .tag,
                            .tag => form_field = .due_date,
                            .due_date => form_field = .priority,
                            .priority => {
                                addTaskFromForm();
                                resetForm();
                            },
                        }
                    } else if (key.matches(vaxis.Key.tab, .{}) or key.matches(vaxis.Key.down, .{})) {
                        form_field = switch (form_field) {
                            .desc => .tag,
                            .tag => .due_date,
                            .due_date => .priority,
                            .priority => .desc,
                        };
                    } else if (key.matches(vaxis.Key.tab, .{ .shift = true }) or
                        key.matches(vaxis.Key.up, .{}))
                    {
                        form_field = switch (form_field) {
                            .desc => .priority,
                            .tag => .desc,
                            .due_date => .tag,
                            .priority => .due_date,
                        };
                    } else {
                        const current = switch (form_field) {
                            .desc => &form_desc_input,
                            .tag => &form_tag_input,
                            .due_date => &form_date_input,
                            .priority => &form_pri_input,
                        };
                        try current.update(.{ .key_press = key });
                    }
                } else {
                    if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) {
                        break;
                    } else if (key.matches('j', .{}) or key.matches(vaxis.Key.down, .{})) {
                        if (current_selection < task_count - 1) {
                            if (is_holding and sort_mode == .manual) {
                                const tmp = tasks[current_selection];
                                tasks[current_selection] = tasks[current_selection + 1];
                                tasks[current_selection + 1] = tmp;
                            }
                            current_selection += 1;
                        }
                    } else if (key.matches('k', .{}) or key.matches(vaxis.Key.up, .{})) {
                        if (current_selection > 0) {
                            if (is_holding and sort_mode == .manual) {
                                const tmp = tasks[current_selection];
                                tasks[current_selection] = tasks[current_selection - 1];
                                tasks[current_selection - 1] = tmp;
                            }
                            current_selection -= 1;
                        }
                    } else if (key.matches(' ', .{})) {
                        if (task_count > 0) {
                            tasks[current_selection].done = !tasks[current_selection].done;
                        }
                    } else if (key.matches('e', .{})) {
                        if (task_count > 0 and sort_mode == .manual) {
                            is_holding = !is_holding;
                        }
                    } else if (key.matches('d', .{})) {
                        deleteTask();
                    } else if (key.matches('a', .{})) {
                        if (task_count < MAX_TASKS) {
                            resetForm();
                            form_active = true;
                        }
                    } else if (key.matches('s', .{})) {
                        sort_mode = switch (sort_mode) {
                            .manual => .due_date,
                            .due_date => .priority,
                            .priority => .manual,
                        };
                        is_holding = false;
                        triggerSort();
                    } else if (key.matches('l', .{ .ctrl = true })) {
                        vx.queueRefresh();
                    }
                }
            },
            .winsize => |ws| try vx.resize(alloc, tty.writer(), ws),
            else => {},
        }

        const win = vx.window();
        win.clear();

        if (form_active) {
            drawForm(win);
        } else {
            drawMain(win);
        }

        try vx.render(tty.writer());
    }
}

fn drawMain(win: vaxis.Window) void {
    const header_style: vaxis.Style = .{ .fg = .{ .index = 6 } };
    const done_style: vaxis.Style = .{ .fg = .{ .index = 2 } };
    const highlight_style: vaxis.Style = .{ .reverse = true };
    const grab_style: vaxis.Style = .{ .reverse = true, .fg = .{ .index = 3 } };
    const normal_style: vaxis.Style = .{};

    // Title
    _ = win.print(&.{vaxis.Segment{
        .text = " === tpln - ADVANCED WORKFLOW CORE === ",
        .style = .{ .bold = true, .fg = .{ .index = 6 } },
    }}, .{ .row_offset = 0, .col_offset = 2 });

    // Controls help
    _ = win.print(&.{vaxis.Segment{
        .text = "j/k: Move | SPACE: Toggle | e: Grab/Drop | d: Del | a: Add | s: Sort | q: Quit",
        .style = normal_style,
    }}, .{ .row_offset = 1, .col_offset = 2 });

    // Sort mode
    const sort_text = std.fmt.bufPrint(&sort_mode_buf, "Current Sort Mode: {s}", .{
        @tagName(sort_mode),
    }) catch "Sort Mode: ?";
    _ = win.print(&.{vaxis.Segment{
        .text = sort_text,
        .style = header_style,
    }}, .{ .row_offset = 2, .col_offset = 2 });

    // Separator
    const sep_row: u16 = 3;
    for (0..win.width) |c| {
        win.writeCell(@intCast(c), sep_row, .{
            .char = .{ .grapheme = "─", .width = 1 },
            .style = .{},
        });
    }

    // Table header
    const hdr_row: u16 = 4;
    _ = win.print(&.{vaxis.Segment{
        .text = "Task Description                  Tag         Due Date     Priority",
        .style = .{ .ul_style = .single },
    }}, .{ .row_offset = hdr_row, .col_offset = 2 });

    // Task rows
    var row: u16 = 5;
    var i: usize = 0;
    while (i < task_count and row < win.height) : (i += 1) {
        const is_selected = i == current_selection;

        var marker: u8 = ' ';
        if (is_selected) {
            marker = if (is_holding) '*' else '>';
        }

        var pri_buf: [4]u8 = undefined;
        const pri_str = std.fmt.bufPrint(&pri_buf, "P{}", .{tasks[i].priority}) catch "P?";

        const done_char: u8 = if (tasks[i].done) 'X' else ' ';

        const line = std.fmt.bufPrint(&task_lines[i], "{c} [{c}] {s:<28} {s:<10} {s:<12} {s:<8}", .{
            marker,
            done_char,
            std.mem.sliceTo(&tasks[i].desc, 0),
            std.mem.sliceTo(&tasks[i].tag, 0),
            std.mem.sliceTo(&tasks[i].due_date, 0),
            pri_str,
        }) catch continue;

        const style: vaxis.Style = if (is_selected) blk: {
            if (is_holding) break :blk grab_style;
            break :blk highlight_style;
        } else if (tasks[i].done) done_style else normal_style;

        _ = win.print(&.{vaxis.Segment{
            .text = line,
            .style = style,
        }}, .{ .row_offset = row, .col_offset = 2 });

        row += 1;
    }

    // Footer separator
    if (row < win.height) {
        const footer_sep = win.height -| 2;
        for (0..win.width) |c| {
            win.writeCell(@intCast(c), footer_sep, .{
                .char = .{ .grapheme = "─", .width = 1 },
                .style = .{},
            });
        }

        const mode_str = if (is_holding) "HOLDING/GRABBED" else "NAV";
        const footer = std.fmt.bufPrint(&footer_buf,
            "Count: {d} | Selection ID: {d} | Action Mode: {s}",
            .{ task_count, current_selection, mode_str },
        ) catch "Count: ?";
        _ = win.print(&.{vaxis.Segment{
            .text = footer,
            .style = normal_style,
        }}, .{ .row_offset = footer_sep + 1, .col_offset = 2 });
    }
}

fn drawForm(win: vaxis.Window) void {
    const form_width: u16 = 50;
    const form_height: u16 = 10;
    const form_x = win.width / 2 - form_width / 2;
    const form_y = win.height / 2 - form_height / 2;

    const form_win = win.child(.{
        .x_off = form_x,
        .y_off = form_y,
        .width = form_width,
        .height = form_height,
        .border = .{
            .where = .all,
            .style = .{ .fg = .{ .index = 6 } },
        },
    });

    _ = form_win.print(&.{vaxis.Segment{
        .text = " Add Task ",
        .style = .{ .bold = true, .fg = .{ .index = 6 } },
    }}, .{ .row_offset = 0, .col_offset = 2 });

    const fields = [_]struct {
        label: []const u8,
        input: *TextInput,
    }{
        .{ .label = "Description", .input = &form_desc_input },
        .{ .label = "Tag (e.g. DEV)", .input = &form_tag_input },
        .{ .label = "Due Date (YYYY-MM-DD)", .input = &form_date_input },
        .{ .label = "Priority (1=High, 2=Med, 3=Low)", .input = &form_pri_input },
    };

    const label_col: u16 = 1;
    const input_col: u16 = 24;
    const input_width = form_width - input_col - 2;

    inline for (fields, 0..) |f, idx| {
        const frow: u16 = @intCast(idx + 2);
        const current_field: FormField = @enumFromInt(idx);
        const is_active = form_field == current_field;

        const label_style: vaxis.Style = if (is_active)
            .{ .bold = true, .fg = .{ .index = 6 } }
        else
            .{};

        _ = form_win.print(&.{vaxis.Segment{
            .text = f.label,
            .style = label_style,
        }}, .{ .row_offset = frow, .col_offset = label_col });

        const input_win = form_win.child(.{
            .x_off = input_col,
            .y_off = frow,
            .width = input_width,
            .height = 1,
        });

        if (is_active) {
            f.input.drawWithStyle(input_win, .{ .fg = .{ .index = 2 } });
        } else {
            f.input.draw(input_win);
        }
    }

    // Help text at bottom
    const help_row = form_height - 2;
    _ = form_win.print(&.{vaxis.Segment{
        .text = "Tab/Arrows: Next Field  Enter: Submit  Esc: Cancel",
        .style = .{ .dim = true },
    }}, .{ .row_offset = help_row, .col_offset = 1 });
}
