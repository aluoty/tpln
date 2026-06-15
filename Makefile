CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = build/tpln

all: $(TARGET)

$(TARGET): src/main.c
	mkdir -p build
	$(CC) $(CFLAGS) src/main.c -o $(TARGET) -lncurses

clean:
	rm -f $(TARGET)

.PHONY: all clean
