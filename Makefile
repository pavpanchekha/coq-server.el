CFLAGS=-Werror -Wpedantic -Wall -std=c11 -g -O0

dpipe: dpipe.c
	$(CC) $^ -o $@
