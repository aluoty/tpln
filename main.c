#include <ncurses.h>
#include <string.h>
#include <stdlib.h>

#define MAX_TASKS 50
#define TASK_LEN 40

typedef struct {
    char desc[TASK_LEN];
    char tag[16];
    char due_date[11]; // YYYY-MM-DD
    int priority;      // 1 = High, 2 = Medium, 3 = Low
    bool done;
} Task;

Task tasks[MAX_TASKS];
int task_count = 0;
int current_selection = 0;

// State machines for custom modes
bool is_holding = false;
int sort_mode = 0; // 0 = Manual, 1 = Due Date, 2 = Priority

void init_tasks(void) {
    strncpy(tasks[0].desc, "Port fractal math", TASK_LEN);
    strncpy(tasks[0].tag, "DEV", 15);
    strncpy(tasks[0].due_date, "2026-06-12", 10);
    tasks[0].priority = 1;
    tasks[0].done = true;

    strncpy(tasks[1].desc, "Install FreeBSD base", TASK_LEN);
    strncpy(tasks[1].tag, "SYS", 15);
    strncpy(tasks[1].due_date, "2026-06-15", 10);
    tasks[1].priority = 2;
    tasks[1].done = false;

    strncpy(tasks[2].desc, "Design AST tree struct", TASK_LEN);
    strncpy(tasks[2].tag, "LANG", 15);
    strncpy(tasks[2].due_date, "2026-06-14", 10);
    tasks[2].priority = 3;
    tasks[2].done = false;

    task_count = 3;
}

// QSort comparator for sorting by date strings (ASCII comparison works for YYYY-MM-DD)
int compare_dates(const void *a, const void *b) {
    return strcmp(((Task *)a)->due_date, ((Task *)b)->due_date);
}

// QSort comparator for numeric priority (1 = Top)
int compare_priority(const void *a, const void *b) {
    return ((Task *)a)->priority - ((Task *)b)->priority;
}

void trigger_sort(void) {
    if (sort_mode == 1) {
        qsort(tasks, task_count, sizeof(Task), compare_dates);
    } else if (sort_mode == 2) {
        qsort(tasks, task_count, sizeof(Task), compare_priority);
    }
}

void draw_interface(void) {
    clear();
    box(stdscr, 0, 0);

    // Title banner
    attron(A_BOLD | COLOR_PAIR(1));
    mvprintw(1, 2, " === tpln - ADVANCED WORKFLOW CORE === ");
    attroff(A_BOLD | COLOR_PAIR(1));

    // Nav guide panel
    mvprintw(2, 2, "j/k: Move | SPACE: Toggle | e: Grab/Drop Task | d: Delete | s: Cycle Sort Mode");
    mvprintw(3, 2, "Current Sort Mode: %s", sort_mode == 0 ? "Manual" : sort_mode == 1 ? "Due Date" : "Priority");
    mvhline(4, 1, ACS_HLINE, COLS - 2);

    // Data table header labels
    attron(A_UNDERLINE);
    mvprintw(5, 4, "%-30s %-10s %-12s %-8s", "Task Description", "Tag", "Due Date", "Priority");
    attroff(A_UNDERLINE);

    for (int i = 0; i < task_count; i++) {
        int y_pos = 6 + i;
        char pri_str[8];
        snprintf(pri_str, sizeof(pri_str), "P%d", tasks[i].priority);

        // Highlight configurations
        if (i == current_selection) {
            if (is_holding) attron(COLOR_PAIR(3) | A_REVERSE); // Yellow flashing grab highlight
            else attron(A_REVERSE);
            
            mvprintw(y_pos, 2, "%c [%s] %-28s %-10s %-12s %-8s", 
                     is_holding ? '*' : '>', tasks[i].done ? "X" : " ", 
                     tasks[i].desc, tasks[i].tag, tasks[i].due_date, pri_str);
            
            if (is_holding) attroff(COLOR_PAIR(3) | A_REVERSE);
            else attroff(A_REVERSE);
        } else {
            if (tasks[i].done) attron(COLOR_PAIR(2)); // Green muted color style
            mvprintw(y_pos, 2, "  [%s] %-28s %-10s %-12s %-8s", 
                     tasks[i].done ? "X" : " ", 
                     tasks[i].desc, tasks[i].tag, tasks[i].due_date, pri_str);
            if (tasks[i].done) attroff(COLOR_PAIR(2));
        }
    }

    // System footer block
    mvhline(LINES - 3, 1, ACS_HLINE, COLS - 2);
    mvprintw(LINES - 2, 2, "Count: %d | Selection ID: %d | Action Mode: %s", 
             task_count, current_selection, is_holding ? "HOLDING/GRABBED" : "NAV");
    refresh();
}

void append_new_task(void) {
    if (task_count >= MAX_TASKS) return;

    echo();
    curs_set(1);
    char buf_desc[TASK_LEN] = {0};
    char buf_tag[16] = {0};
    char buf_date[11] = {0};
    char buf_pri[4] = {0};

    // Sub-prompt input execution blocks
    mvprintw(LINES - 2, 2, "%-70s", " "); // Clear buffer space line
    mvprintw(LINES - 2, 2, "Description: ");
    getnstr(buf_desc, TASK_LEN - 1);

    mvprintw(LINES - 2, 2, "%-70s", " ");
    mvprintw(LINES - 2, 2, "Tag (e.g. DEV): ");
    getnstr(buf_tag, 15);

    mvprintw(LINES - 2, 2, "%-70s", " ");
    mvprintw(LINES - 2, 2, "Due Date (YYYY-MM-DD): ");
    getnstr(buf_date, 10);

    mvprintw(LINES - 2, 2, "%-70s", " ");
    mvprintw(LINES - 2, 2, "Priority (1=High, 2=Med, 3=Low): ");
    getnstr(buf_pri, 2);

    if (strlen(buf_desc) > 0) {
        strncpy(tasks[task_count].desc, buf_desc, TASK_LEN);
        strncpy(tasks[task_count].tag, strlen(buf_tag) > 0 ? buf_tag : "NONE", 15);
        strncpy(tasks[task_count].due_date, strlen(buf_date) > 0 ? buf_date : "9999-12-31", 10);
        
        int p = atoi(buf_pri);
        tasks[task_count].priority = (p >= 1 && p <= 3) ? p : 3;
        tasks[task_count].done = false;
        
        task_count++;
        trigger_sort();
    }

    noecho();
    curs_set(0);
}

void delete_task(void) {
    if (task_count == 0) return;

    // Shift subsequent contiguous memory elements back one array address node index slot
    for (int i = current_selection; i < task_count - 1; i++) {
        tasks[i] = tasks[i + 1];
    }
    task_count--;

    // Keep selection within bounds
    if (current_selection >= task_count && current_selection > 0) {
        current_selection--;
    }
}

int main(void) {
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    start_color();
    init_pair(1, COLOR_CYAN, COLOR_BLACK);
    init_pair(2, COLOR_GREEN, COLOR_BLACK);
    init_pair(3, COLOR_YELLOW, COLOR_BLACK); // For hold and drag alert visibility

    init_tasks();

    int ch;
    while ((ch = getch()) != 'q') {
        switch (ch) {
            case 'j': // Vim Down Key
                if (current_selection < task_count - 1) {
                    if (is_holding && sort_mode == 0) {
                        // Swap neighboring structure blocks inside the dynamic layout array
                        Task temp = tasks[current_selection];
                        tasks[current_selection] = tasks[current_selection + 1];
                        tasks[current_selection + 1] = temp;
                    }
                    current_selection++;
                }
                break;

            case 'k': // Vim Up Key
                if (current_selection > 0) {
                    if (is_holding && sort_mode == 0) {
                        Task temp = tasks[current_selection];
                        tasks[current_selection] = tasks[current_selection - 1];
                        tasks[current_selection - 1] = temp;
                    }
                    current_selection--;
                }
                break;

            case ' ': // Space to toggle done status
                if (task_count > 0) {
                    tasks[current_selection].done = !tasks[current_selection].done;
                }
                break;

            case 'e': // Hold and shift item selection engine toggle
                if (task_count > 0 && sort_mode == 0) {
                    is_holding = !is_holding;
                }
                break;

            case 'd': // Wipe selected index from memory block maps
                delete_task();
                break;

            case 'a': // Append new entry
                append_new_task();
                break;

            case 's': // Cycle calculation modes: Manual -> Due Date -> Priority
                sort_mode = (sort_mode + 1) % 3;
                is_holding = false; // Disable any active drag parameters if sort method changes
                trigger_sort();
                break;
        }
        draw_interface();
    }

    endwin();
    return 0;
}
