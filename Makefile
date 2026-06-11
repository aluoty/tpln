CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = tpln

all: $(TARGET)

$(TARGET): main.c
	$(CC) $(CFLAGS) main.c -o $(TARGET) -lncurses

clean:
	rm -f $(TARGET)

.PHONY: all clean
