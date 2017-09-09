CFLAGS=-Werror -Wpedantic -Wall -std=c11 -g -O0

%: %.c
	$(CC) $(CFLAGS) $^ -o $@ -D_DEFAULT_SOURCE

clean:
	rm dpipe chroot-into
