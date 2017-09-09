#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

void die(int code, char *message) {
        fprintf(stderr, "%s\n", message);
        _exit(code);
}

int main(int argc, char **argv) {
        uid_t real_uid;
        int err;
	char *subargs[argc - 4 + 2];
	subargs[0] = argv[3];
	for (int i = 0; i < argc - 4; i++ ) {
		subargs[i + 1] = argv[i + 4];
	}
	subargs[argc - 4 + 1] = NULL;
	
	real_uid = atoi(getenv("SUDO_UID"));
        err = seteuid(0);
        if (err) die(1, "Count not become root!");
        err = chroot(argv[1]);
        if (err) die(1, "Count not change root directory!");
        err = seteuid(real_uid);
        if (err) die(1, "Count not change back from root!");
	err = chdir(argv[2]);
        if (err) die(1, "Count not change directory!");
        execv(argv[3], subargs);
}
