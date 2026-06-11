CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = planner

all: $(TARGET)

$(TARGET): planner.c
	$(CC) $(CFLAGS) planner.c -o $(TARGET) -lncurses

clean:
	rm -f $(TARGET)

.PHONY: all clean
