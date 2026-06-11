#include <ncurses.h>
#include <string.h>
#include <stdlib.h>

#define MAX_TASKS 20
#define TASK_LEN 50

typedef struct {
    char desc[TASK_LEN];
    bool done;
} Task;

Task tasks[MAX_TASKS];
int task_count = 0;
int current_selection = 0;

// Seed some initial demo entries into our planner storage matrix
void init_tasks(void) {
    strncpy(tasks[0].desc, "Rewrite fractal core engine in C", TASK_LEN);
    tasks[0].done = true;
    
    strncpy(tasks[1].desc, "Explore FreeBSD base system specifications", TASK_LEN);
    tasks[1].done = false;
    
    strncpy(tasks[2].desc, "Design compiled language parser tree", TASK_LEN);
    tasks[2].done = false;
    
    task_count = 3;
}

void draw_interface(void) {
    clear();
    
    // Draw structural window borders and headers
    box(stdscr, 0, 0);
    attron(A_BOLD | COLOR_PAIR(1));
    mvprintw(1, 2, " === AETHERPLAN - SYSTEM TASK MANAGER === ");
    attroff(A_BOLD | COLOR_PAIR(1));
    
    mvprintw(2, 2, "Use ARROWS to navigate | SPACE to toggle status | 'a' to add | 'q' to quit");
    mvhline(3, 1, ACS_HLINE, COLS - 2);

    // Render the active tasks panel grid space
    for (int i = 0; i < task_count; i++) {
        int y_pos = 5 + i;
        
        // Highlight the row currently tracked by the selection index pointer
        if (i == current_selection) {
            attron(A_REVERSE);
            mvprintw(y_pos, 2, " > [%s] %-55s ", tasks[i].done ? "X" : " ", tasks[i].desc);
            attroff(A_REVERSE);
        } else {
            // Give completed items a muted color theme style look
            if (tasks[i].done) attron(COLOR_PAIR(2));
            mvprintw(y_pos, 2, "   [%s] %-55s ", tasks[i].done ? "X" : " ", tasks[i].desc);
            if (tasks[i].done) attroff(COLOR_PAIR(2));
        }
    }

    // Render footer status tracking data blocks
    mvhline(ROWS - 3, 1, ACS_HLINE, COLS - 2);
    mvprintw(ROWS - 2, 2, "Total Tasks Tracked: %d | Active Focus Index ID: %d", task_count, current_selection);
    
    refresh();
}

void append_new_task(void) {
    if (task_count >= MAX_TASKS) return;

    // Temporarily exit terminal raw execution state to parse text input string cleanly
    echo();
    curs_set(1);
    
    char buffer[TASK_LEN] = {0};
    mvprintw(ROWS - 2, 2, "Enter New Task: %-60s", " "); // Clear specific line space region
    mvprintw(ROWS - 2, 2, "Enter New Task: ");
    
    getnstr(buffer, TASK_LEN - 1);
    
    // Strip trailing newlines or whitespaces if detected
    if (strlen(buffer) > 0) {
        strncpy(tasks[task_count].desc, buffer, TASK_LEN);
        tasks[task_count].done = false;
        task_count++;
    }

    // Re-engage silent automated keystroke monitoring rulesets
    noecho();
    curs_set(0);
}

int main(void) {
    // Fire up the ncurses terminal shell abstraction layers
    initscr();
    cbreak();             // Forward keystroke inputs immediately without waiting for enter
    noecho();             // Prevent key entries from cluttering up the terminal grid surface
    keypad(stdscr, TRUE); // Enable tracking of special hardware input strokes like Arrow keys
    curs_set(0);          // Make terminal cursor hidden to avoid blinking UI artifacts

    // Establish operational color profile pairs inside system registers
    start_color();
    init_pair(1, COLOR_CYAN, COLOR_BLACK);
    init_pair(2, COLOR_GREEN, COLOR_BLACK);

    init_tasks();

    int input_ch;
    bool running = true;

    while (running) {
        draw_interface();
        input_ch = getch();

        switch (input_ch) {
            case KEY_UP:
                if (current_selection > 0) current_selection--;
                break;
                
            case KEY_DOWN:
                if (current_selection < task_count - 1) current_selection++;
                break;
                
            case ' ': // Spacebar key identifier mapping configuration
                if (task_count > 0) {
                    tasks[current_selection].done = !tasks[current_selection].done;
                }
                break;
                
            case 'a':
                append_new_task();
                break;
                
            case 'q':
                running = false;
                break;
        }
    }

    // Clean up ncurses window states safely to return terminal configuration settings to normal
    endwin();
    return 0;
}
