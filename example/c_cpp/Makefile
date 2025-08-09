BIN := main.exe

CC := gcc

CFLAGS := -Wall -Wextra -O2
INCLUDE_DIR := .

SRC := main.c
OBJ := $(SRC:.c=.o)

.PHONY: all run clean

all: $(BIN) run

$(BIN): $(OBJ)
	$(CC) $^ -o $@

%.o: %.c
	$(CC) -c $(CFLAGS) $< -I$(INCLUDE_DIR) -o $@

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(BIN) $(OBJ)
